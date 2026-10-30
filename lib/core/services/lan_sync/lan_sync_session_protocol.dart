// 同步会话的消息类型、上限与载荷编解码（docs/lan_sync.md §5.3）。
//
// 职责边界：纯数据变换，无 I/O。会话状态机（lan_sync_session.dart）只经这里
// 拼消息、解析消息；对端来的每个字段都校验，不合格抛 FormatException，由
// 会话当作协议错误中止。消息信封沿用 [LanSyncMessage]（`{"type": …}`）。
import 'dart:convert';
import 'dart:io';

import 'lan_sync_failure.dart';
import 'lan_sync_messages.dart';
import 'sync/sync_model.dart';
import 'sync/sync_state_json.dart';
import 'sync/sync_state_model.dart';

/// 会话消息类型（顺序与字段见 docs §5.3）。
abstract final class LanSyncSessionMessages {
  static const String hello = 'sync.hello';
  static const String reject = 'sync.reject';
  static const String manifestGet = 'sync.manifest.get';
  static const String manifest = 'sync.manifest';
  static const String historyGet = 'sync.history.get';
  static const String history = 'sync.history';
  static const String recordsGet = 'sync.records.get';
  static const String records = 'sync.records';
  static const String plan = 'sync.plan';
  static const String mediaHave = 'sync.media.have';
  static const String mediaStatus = 'sync.media.status';
  static const String mediaPut = 'sync.media.put';
  static const String mediaGet = 'sync.media.get';
  static const String mediaEnd = 'sync.media.end';
  static const String applyPart = 'sync.apply.part';
  static const String apply = 'sync.apply';
  static const String applied = 'sync.applied';
  static const String finish = 'sync.finish';
  static const String done = 'sync.done';
  static const String ping = 'sync.ping';
  static const String abort = 'sync.abort';
}

/// 一条 `*.get` 请求里最多的键数（发起方分批请求）。
const int kLanSyncKeysPerRequest = 2000;

/// 分段消息（`sync.records`、`sync.apply.part`）每段的目标字节数（按 JSON
/// 估算）。单条记录本身超过它时单独成一段；整条消息仍受信道 32 MiB 上限。
const int kLanSyncPartBytes = 4 * 1024 * 1024;

/// 清单数据块（gzip）的上限。
const int kLanSyncManifestMaxBytes = 64 * 1024 * 1024;

/// `sync.reject` 的原因。
enum LanSyncRejectReason {
  /// 同步格式版本或实体集合不同。
  version,

  /// 对方正在编辑，或正在与别的设备同步。
  busy,

  /// 对方不接受这次（自动）同步：它关掉了自动同步或这台设备的自动同步。
  declined;

  static LanSyncRejectReason? tryParse(Object? name) =>
      name is String ? values.asNameMap()[name] : null;

  LanSyncFailure get failure => switch (this) {
    version => LanSyncFailure.incompatibleVersion,
    busy => LanSyncFailure.busy,
    declined => LanSyncFailure.declined,
  };
}

/// `sync.abort{reason}` 的原因用发送方的 [LanSyncFailure] 名称；接收方据此
/// 得出自己的失败原因（对方取消在本机是“对方取消”）。
LanSyncFailure lanSyncFailureFromPeerAbort(Object? reason) {
  final failure = LanSyncFailure.fromName(reason);
  return switch (failure) {
    LanSyncFailure.cancelled => LanSyncFailure.peerCancelled,
    LanSyncFailure.peerCancelled => LanSyncFailure.cancelled,
    _ => failure,
  };
}

/// 双方的 `sync.hello`。
class LanSyncSessionHello {
  const LanSyncSessionHello({
    required this.formatVersion,
    required this.appVersion,
    required this.entities,
    required this.syncSettings,
    required this.restoredPending,
    this.automatic = false,
  });

  factory LanSyncSessionHello.parse(LanSyncMessage message) {
    final rawEntities = message.fields['entities'];
    if (rawEntities is! List || rawEntities.length > 64) {
      throw const FormatException('invalid "entities" in sync.hello');
    }
    final entities = <String>{
      for (final name in rawEntities)
        if (name is String && name.length <= 32)
          name
        else
          throw const FormatException('invalid entity in sync.hello'),
    };
    return LanSyncSessionHello(
      formatVersion: message.requireInt('f'),
      appVersion: message.optionalString('app', maxLength: 64) ?? '',
      entities: entities,
      syncSettings: _bool(message, 'settings'),
      restoredPending: _bool(message, 'restored'),
      automatic: _bool(message, 'auto'),
    );
  }

  final int formatVersion;
  final String appVersion;

  /// 参与同步的实体名（不含 settings，它由 [syncSettings] 决定）。
  final Set<String> entities;
  final bool syncSettings;

  /// 这一方对另一方的“覆盖恢复待确认”标记。
  final bool restoredPending;

  /// 只在发起方的 hello 里有意义：是不是自动同步。
  final bool automatic;

  LanSyncMessage toMessage() => LanSyncMessage(LanSyncSessionMessages.hello, {
    'f': formatVersion,
    'app': appVersion,
    'entities': entities.toList()..sort(),
    'settings': syncSettings,
    'restored': restoredPending,
    'auto': automatic,
  });

  /// 两端同步的是不是同一套东西。
  bool compatibleWith(LanSyncSessionHello other) =>
      formatVersion == other.formatVersion &&
      entities.length == other.entities.length &&
      entities.containsAll(other.entities);

  static bool _bool(LanSyncMessage message, String key) {
    final value = message.fields[key];
    if (value == null) return false;
    if (value is! bool) throw FormatException('invalid "$key" in sync.hello');
    return value;
  }
}

/// 本机参与同步的实体名（不含 settings）。
Set<String> lanSyncEntityNames() => <String>{
  for (final entity in SyncEntity.values)
    if (entity != SyncEntity.settings) entity.name,
};

// -----------------------------------------------------------------------------
// 清单数据块
// -----------------------------------------------------------------------------

/// 响应方的清单、墓碑键与改名：gzip 的 JSON，作为数据块发送（不经 base64，
/// 也不受单条消息上限）。
List<int> lanSyncEncodeManifest(
  SyncManifest manifest,
  Iterable<SyncKey> tombstoneKeys,
  Map<String, SyncTagRename> renames,
) {
  final keys = tombstoneKeys.map((key) => key.toString()).toList()..sort();
  return gzip.encode(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'manifest': manifest.toJson(),
        'tombstones': keys,
        'renames': syncEncodeRenames(renames),
      }),
    ),
  );
}

typedef LanSyncRemoteManifest = ({
  SyncManifest manifest,
  List<SyncKey> tombstoneKeys,
  Map<String, SyncTagRename> renames,
});

LanSyncRemoteManifest lanSyncDecodeManifest(List<int> bytes) {
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(gzip.decode(bytes)));
  } on Object catch (error) {
    throw FormatException('manifest blob is not gzip JSON: $error');
  }
  if (json is! Map || json['tombstones'] is! List) {
    throw const FormatException('invalid manifest payload');
  }
  return (
    manifest: SyncManifest.fromJson(json['manifest']),
    tombstoneKeys: [
      for (final raw in json['tombstones'] as List) SyncKey.parse('$raw'),
    ],
    renames: syncDecodeRenames(json['renames']),
  );
}

// -----------------------------------------------------------------------------
// 键列表、记录、历史
// -----------------------------------------------------------------------------

List<String> lanSyncKeyStrings(Iterable<SyncKey> keys) => [
  for (final key in keys) key.toString(),
];

/// 解析请求里的键列表；超过 [kLanSyncKeysPerRequest] 或格式不对时抛错。
List<SyncKey> lanSyncParseKeys(LanSyncMessage message, String field) {
  final raw = message.fields[field];
  if (raw == null) return const <SyncKey>[];
  if (raw is! List || raw.length > kLanSyncKeysPerRequest) {
    throw FormatException('invalid "$field" in ${message.type}');
  }
  return [for (final item in raw) SyncKey.parse('$item')];
}

/// 解析字符串列表（媒体键）。
List<String> lanSyncParseStrings(LanSyncMessage message, String field) {
  final raw = message.fields[field];
  if (raw is! List || raw.length > kLanSyncKeysPerRequest * 8) {
    throw FormatException('invalid "$field" in ${message.type}');
  }
  return [
    for (final item in raw)
      if (item is String && item.length <= 1024)
        item
      else
        throw FormatException('invalid item in "$field"'),
  ];
}

/// `sync.history` 的历史部分与墓碑部分。
Map<String, Object?> lanSyncEncodeHistoryReply(
  Map<SyncKey, Map<String, List<SyncHistoryEntry>>> history,
  Map<SyncKey, SyncTombstone> tombstones,
) => <String, Object?>{
  'history': syncEncodeHistory(history),
  'tombstones': syncEncodeTombstones(tombstones),
};

/// 把 [items] 按 JSON 估算大小切成若干段，每段不超过 [kLanSyncPartBytes]
/// （单项超过时独占一段）。
List<List<Object?>> lanSyncChunkBySize(Iterable<Object?> items) {
  final parts = <List<Object?>>[];
  var current = <Object?>[];
  var size = 0;
  for (final item in items) {
    final itemSize = utf8.encode(jsonEncode(item)).length;
    if (current.isNotEmpty && size + itemSize > kLanSyncPartBytes) {
      parts.add(current);
      current = <Object?>[];
      size = 0;
    }
    current.add(item);
    size += itemSize;
  }
  if (current.isNotEmpty) parts.add(current);
  return parts;
}

List<SyncRecord> lanSyncParseRecords(LanSyncMessage message) {
  final raw = message.fields['records'];
  if (raw is! List) throw const FormatException('invalid "records"');
  return [for (final item in raw) SyncRecord.fromJson(item)];
}
