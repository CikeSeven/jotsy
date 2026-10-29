import 'dart:convert';

import '../../app_background_storage_service.dart';
import '../../backup_settings.dart';
import '../../settings_service.dart';
import '../../tag_order_codec.dart';
import 'sync_media_refs.dart';
import 'sync_model.dart';

/// 设置 ↔ 规范记录（规格 §2.2 的 settings 行；只在两端都开启“同步设置”时
/// 由调用方请求）。
///
/// - 取值（[syncCaptureSettings]，主 isolate）：`BackupSettings.capture` 的键，
///   去掉 `appLockEnabled`（应用锁是本机安全设置）与
///   `rememberedTagFilterIdsRaw`（本地标签 id、本机的筛选记忆）；
/// - 规范化（[syncSettingsRecord]，可在后台 isolate）：每个键一个分面
///   `{"value": …}`；`tagOrderRaw`（本地标签 id 串）换成分面 `tagOrderNames`
///   （按名称的列表，经标签表换算，查不到的 id 丢掉）；`appSurfaceRaw` 里的
///   背景文件名换成媒体引用 `jotsy-media:app_backgrounds/<文件名>`；
/// - 反向（[syncSettingsRestoreNode]）：给出 `BackupSettings.restore` 能直接
///   使用的部分节点，只含调用方要应用的分面。
///
/// 无副作用（[syncCaptureSettings] 只读设置服务）。

/// 不参与同步的设置键。
const Set<String> kSyncExcludedSettingsKeys = <String>{
  'appLockEnabled',
  'rememberedTagFilterIdsRaw',
};

const String _kTagOrderRawKey = 'tagOrderRaw';
const String _kAppSurfaceRawKey = 'appSurfaceRaw';

/// settings 记录里代替 `tagOrderRaw` 的分面名。
const String kSyncTagOrderNamesFacet = 'tagOrderNames';

/// 读出参与同步的设置原值（纯 JSON 值，可以送进后台 isolate）。
Map<String, Object?> syncCaptureSettings(
  SettingsService settings,
) => <String, Object?>{
  for (final entry in BackupSettings.capture(settings).entries)
    if (!kSyncExcludedSettingsKeys.contains(entry.key)) entry.key: entry.value,
};

/// 由 [syncCaptureSettings] 的结果生成 settings 记录。[tagNamesById] 为本机
/// 标签本地 id → 名称。
SyncRecord syncSettingsRecord(
  Map<String, Object?> captured,
  Map<int, String> tagNamesById,
) {
  final facets = <String, Object?>{};
  for (final entry in captured.entries) {
    if (kSyncExcludedSettingsKeys.contains(entry.key)) continue;
    if (entry.key == _kTagOrderRawKey) {
      final raw = entry.value;
      facets[kSyncTagOrderNamesFacet] = <String, Object?>{
        'value': <String>[
          for (final id in decodeTagOrder(raw is String ? raw : null))
            ?tagNamesById[id],
        ],
      };
      continue;
    }
    var value = syncNormalizeMediaRefs(entry.value);
    if (entry.key == _kAppSurfaceRawKey && value is String) {
      value = _mapAppSurfaceImages(value, _backgroundNameToRef);
    }
    facets[entry.key] = <String, Object?>{'value': value};
  }
  return SyncRecord(
    const SyncKey(SyncEntity.settings, kSyncSettingsId),
    facets,
  );
}

/// 由 settings 记录生成 `BackupSettings.restore` 的部分节点。
///
/// [facets] 为要应用的分面（规划出的“本次有变化的键”）；为 null 时给出全部。
/// [tagIdsByName] 为本机（写入标签之后的）标签名称 → 本地 id，`tagOrderNames`
/// 据此换回 `tagOrderRaw`，本机没有的名称丢掉。[dataRoot] 用于还原设置值里
/// 可能出现的日记媒体引用。
///
/// 注意 `BackupSettings.restore` 对部分键的空值不做任何事（如 `tagOrderRaw`
/// 为空串、`diarySortModeRaw` 为 null 时保留本机值），写入层需要单独处理
/// “清空”这种变化，见 docs/lan_sync.md §6 第 5 步。
Map<String, Object?> syncSettingsRestoreNode(
  SyncRecord record, {
  Iterable<String>? facets,
  required Map<String, int> tagIdsByName,
  required String dataRoot,
}) {
  if (record.key.entity != SyncEntity.settings) {
    throw ArgumentError.value(record.key, 'record', '不是设置记录');
  }
  final wanted = facets?.toSet() ?? record.facets.keys.toSet();
  final node = <String, Object?>{};
  for (final entry in record.facets.entries) {
    if (!wanted.contains(entry.key)) continue;
    final facet = entry.value;
    if (facet is! Map || !facet.containsKey('value')) {
      throw FormatException('设置分面 ${entry.key} 格式不对', facet);
    }
    final value = facet['value'];
    if (entry.key == kSyncTagOrderNamesFacet) {
      final names = value is List ? value : const <Object?>[];
      node[_kTagOrderRawKey] = encodeTagOrder(<int>[
        for (final name in names) ?tagIdsByName[name],
      ]);
      continue;
    }
    var restored = value;
    if (entry.key == _kAppSurfaceRawKey && restored is String) {
      restored = _mapAppSurfaceImages(restored, _backgroundRefToName);
    }
    node[entry.key] = syncRebindMediaRefs(restored, dataRoot);
  }
  return node;
}

const String _kBackgroundRefPrefix =
    '$kSyncMediaRefPrefix$kSyncBackgroundKeyPrefix';

String? _backgroundNameToRef(String name) =>
    AppBackgroundStorageService.isValidName(name)
    ? '$_kBackgroundRefPrefix$name'
    : null;

String? _backgroundRefToName(String ref) {
  if (!ref.startsWith(_kBackgroundRefPrefix)) return null;
  final name = ref.substring(_kBackgroundRefPrefix.length);
  return AppBackgroundStorageService.isValidName(name) ? name : null;
}

/// 改写“背景与材质”设置里的背景图字段：`global.image` 与
/// `areas.<区域>.background.image`（与 `AppSurfaceSettings.referencedImages`
/// 同一范围）。[map] 返回 null 的值不动。
///
/// 能解析成 JSON 对象时按规范 JSON 重新编码（两个方向都如此，往返后逐字节
/// 相同）；不是 JSON 的原文原样返回（应用读取时按默认处理）。
String _mapAppSurfaceImages(String raw, String? Function(String) map) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return raw;
  }
  if (decoded is! Map) return raw;
  final json = decoded.cast<String, Object?>();

  Map<String, Object?>? mapBackground(Object? background) {
    if (background is! Map) return null;
    final image = background['image'];
    if (image is! String) return null;
    final mapped = map(image);
    if (mapped == null) return null;
    return <String, Object?>{
      ...background.cast<String, Object?>(),
      'image': mapped,
    };
  }

  final global = mapBackground(json['global']);
  if (global != null) json['global'] = global;
  final areas = json['areas'];
  if (areas is Map) {
    final mappedAreas = <String, Object?>{};
    for (final entry in areas.entries) {
      final area = entry.value;
      final background = area is Map ? mapBackground(area['background']) : null;
      mappedAreas[entry.key as String] = background == null
          ? area
          : <String, Object?>{
              ...(area as Map).cast<String, Object?>(),
              'background': background,
            };
    }
    json['areas'] = mappedAreas;
  }
  return syncCanonicalJson(json);
}
