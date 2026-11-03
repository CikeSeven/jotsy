import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_options.dart';
import 'lan_sync/sync/sync_media_index.dart';
import 'lan_sync/sync/sync_state_files.dart';

/// 网盘增量备份在本机的状态，放在 `<数据根>/cloud_backup_state/`。
///
/// - 完整备份只导出列出的托管目录、覆盖恢复只换入这些目录，这里既不进
///   备份，也不会被恢复覆盖；删掉它只会让下一次备份重新计算哈希、重新
///   下载索引，不会丢数据；
/// - `media_index.json.gz`：整机一份媒体哈希缓存，复用局域网同步的
///   [SyncMediaIndex]（按大小 + 修改时间缓存 sha256），与局域网同步的实例
///   各用各的目录、互不干扰；
/// - `<位置 id>/state.json.gz`：[CloudBackupTargetState]；
/// - `<位置 id>/idx/<索引文件名>.json.gz`：下载并解开过的索引。索引写入后
///   不再改变，可以一直缓存；清理删掉远端索引时一并删掉缓存。
class CloudBackupLocalState {
  CloudBackupLocalState({required this.root, required Directory dataRoot})
    : mediaIndex = SyncMediaIndex(stateDir: root, dataRoot: dataRoot);

  static const String directoryName = 'cloud_backup_state';
  static const String _stateFileName = 'state.json.gz';

  final Directory root;
  final SyncMediaIndex mediaIndex;

  /// 任一位置的状态写入后递增；界面据此刷新“自动备份 · 上次 …”状态行。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SyncStateFiles _files(String targetId) =>
      SyncStateFiles(Directory(p.join(root.path, targetId)));

  SyncStateFiles _indexFiles(String targetId) =>
      SyncStateFiles(Directory(p.join(root.path, targetId, 'idx')));

  Future<CloudBackupTargetState> read(String targetId) async =>
      CloudBackupTargetState.fromJson(
        await _files(targetId).readJson(_stateFileName),
      );

  Future<void> write(String targetId, CloudBackupTargetState state) async {
    await _files(targetId).writeJson(_stateFileName, state.toJson());
    revision.value++;
  }

  Future<CloudBackupTargetState> update(
    String targetId,
    CloudBackupTargetState Function(CloudBackupTargetState state) change,
  ) async {
    final next = change(await read(targetId));
    await write(targetId, next);
    return next;
  }

  /// 缓存里的索引；没有、损坏或不是用 [password] 打开的都为 null（重新
  /// 下载）。缓存与当时打开它的密码绑定：换一个密码不能凭缓存“通过”核对，
  /// 否则输错的密码会被当成这条链的密码，新上传的包就用错了密码。
  Future<IncrementalIndex?> cachedIndex(
    String targetId,
    String fileName, {
    required String? password,
  }) async {
    final json = await _indexFiles(targetId).readJson('$fileName.json.gz');
    if (json is! Map ||
        json['check'] != _passwordCheck(fileName, password) ||
        json['index'] is! String) {
      return null;
    }
    try {
      return IncrementalIndex.decode(json['index'] as String);
    } on FormatException {
      return null;
    }
  }

  /// 不核对密码，只看缓存里有没有这份索引（判断它是否加密用）。
  Future<bool?> cachedIndexEncrypted(String targetId, String fileName) async {
    final json = await _indexFiles(targetId).readJson('$fileName.json.gz');
    if (json is! Map || json['encrypted'] is! bool) return null;
    return json['encrypted'] as bool;
  }

  Future<void> cacheIndex(
    String targetId,
    String fileName,
    IncrementalIndex index, {
    required String? password,
  }) => _indexFiles(targetId).writeJson('$fileName.json.gz', <String, Object?>{
    'check': _passwordCheck(fileName, password),
    'encrypted': index.encrypted,
    'index': index.encode(),
  });

  static String _passwordCheck(String fileName, String? password) => sha256
      .convert(utf8.encode('jotsy-idx\u0000$fileName\u0000${password ?? ''}'))
      .toString();

  /// 只保留 [keep] 里的索引缓存（远端已删除的索引不再需要）。
  Future<void> retainIndexes(String targetId, Set<String> keep) async {
    final directory = Directory(p.join(root.path, targetId, 'idx'));
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.json.gz')) continue;
      final indexName = name.substring(0, name.length - '.json.gz'.length);
      if (!keep.contains(indexName)) await entity.delete();
    }
  }

  /// 删除备份位置时一并删掉它的状态与索引缓存。
  Future<void> removeTarget(String targetId) async {
    final directory = Directory(p.join(root.path, targetId));
    if (await directory.exists()) await directory.delete(recursive: true);
    revision.value++;
  }
}

/// 自动备份上一次的结果。
enum CloudAutoBackupOutcome {
  /// 上传成功。
  uploaded,

  /// 数据没有变化，没有上传。
  unchanged,

  /// 新增媒体超过自动备份的上限，等用户手动备份。
  needsManual,

  /// 失败；原因见 [CloudAutoBackupStatus.failure]。
  failed;

  static CloudAutoBackupOutcome? fromName(Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

@immutable
class CloudAutoBackupStatus {
  const CloudAutoBackupStatus({
    required this.at,
    required this.outcome,
    this.failure,
    this.bytes,
  });

  final DateTime at;
  final CloudAutoBackupOutcome outcome;

  /// [CloudAutoBackupOutcome.failed] 的原因；不是网盘错误（如本机文件读写
  /// 失败）时为 null。
  final CloudBackupFailure? failure;

  /// [CloudAutoBackupOutcome.needsManual] 时需要上传的字节数。
  final int? bytes;

  static CloudAutoBackupStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'] is String ? DateTime.tryParse(json['at']) : null;
    final outcome = CloudAutoBackupOutcome.fromName(json['outcome']);
    if (at == null || outcome == null) return null;
    CloudBackupFailure? failure;
    for (final value in CloudBackupFailure.values) {
      if (value.name == json['failure']) failure = value;
    }
    return CloudAutoBackupStatus(
      at: at.toLocal(),
      outcome: outcome,
      failure: failure,
      bytes: json['bytes'] is int ? json['bytes'] as int : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toUtc().toIso8601String(),
    'outcome': outcome.name,
    if (failure != null) 'failure': failure!.name,
    if (bytes != null) 'bytes': bytes,
  };
}

/// 一个备份位置的增量备份状态。
///
/// [pendingPacks] 是续传日志：已上传、但还没有被任何索引引用的媒体包
/// （包名 → 其中的哈希）。上传中途断网、被系统杀掉或在 iOS 后台被挂起
/// 时，下一次备份确认这些包仍在网盘上就直接沿用，不必重新上传；成功提交
/// 一份索引后清空。
@immutable
class CloudBackupTargetState {
  const CloudBackupTargetState({
    this.lastIndexName,
    this.lastFingerprint,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastAuto,
    this.pendingPacks = const <String, List<String>>{},
  });

  /// 本机最近一次成功提交（或确认没有变化）时的索引文件名与整体指纹。
  final String? lastIndexName;
  final String? lastFingerprint;

  /// 最近一次成功（含“没有变化”）的时间，自动备份据此计算间隔。
  final DateTime? lastSuccessAt;

  /// 最近一次自动备份失败的时间，失败后至少隔一小时再试。
  final DateTime? lastFailureAt;
  final CloudAutoBackupStatus? lastAuto;
  final Map<String, List<String>> pendingPacks;

  static CloudBackupTargetState fromJson(Object? json) {
    if (json is! Map) return const CloudBackupTargetState();
    DateTime? time(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;
    final pending = <String, List<String>>{};
    final rawPending = json['pendingPacks'];
    if (rawPending is Map) {
      for (final entry in rawPending.entries) {
        final hashes = entry.value;
        if (entry.key is String && hashes is List) {
          pending[entry.key as String] = hashes.whereType<String>().toList();
        }
      }
    }
    return CloudBackupTargetState(
      lastIndexName: json['lastIndex'] is String
          ? json['lastIndex'] as String
          : null,
      lastFingerprint: json['lastFingerprint'] is String
          ? json['lastFingerprint'] as String
          : null,
      lastSuccessAt: time(json['lastSuccessAt']),
      lastFailureAt: time(json['lastFailureAt']),
      lastAuto: CloudAutoBackupStatus.fromJson(json['lastAuto']),
      pendingPacks: pending,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'lastIndex': ?lastIndexName,
    'lastFingerprint': ?lastFingerprint,
    if (lastSuccessAt != null)
      'lastSuccessAt': lastSuccessAt!.toUtc().toIso8601String(),
    if (lastFailureAt != null)
      'lastFailureAt': lastFailureAt!.toUtc().toIso8601String(),
    if (lastAuto != null) 'lastAuto': lastAuto!.toJson(),
    if (pendingPacks.isNotEmpty) 'pendingPacks': pendingPacks,
  };

  /// 成功提交一份索引（或确认没有变化）之后的状态。
  CloudBackupTargetState succeeded({
    required String indexName,
    required String fingerprint,
    required DateTime at,
    CloudAutoBackupStatus? auto,
  }) => CloudBackupTargetState(
    lastIndexName: indexName,
    lastFingerprint: fingerprint,
    lastSuccessAt: at,
    lastFailureAt: lastFailureAt,
    lastAuto: auto ?? lastAuto,
  );

  CloudBackupTargetState withPendingPack(
    String packName,
    List<String> hashes,
  ) => CloudBackupTargetState(
    lastIndexName: lastIndexName,
    lastFingerprint: lastFingerprint,
    lastSuccessAt: lastSuccessAt,
    lastFailureAt: lastFailureAt,
    lastAuto: lastAuto,
    pendingPacks: <String, List<String>>{...pendingPacks, packName: hashes},
  );

  CloudBackupTargetState withAuto(
    CloudAutoBackupStatus status, {
    bool failed = false,
  }) => CloudBackupTargetState(
    lastIndexName: lastIndexName,
    lastFingerprint: lastFingerprint,
    lastSuccessAt: lastSuccessAt,
    lastFailureAt: failed ? status.at : lastFailureAt,
    lastAuto: status,
    pendingPacks: pendingPacks,
  );

  /// 本机记住的链换了（重新开始一条链、忘记密码）：上一条链的指纹与续传
  /// 日志都不再适用。
  CloudBackupTargetState forgetChain() => CloudBackupTargetState(
    lastSuccessAt: lastSuccessAt,
    lastFailureAt: lastFailureAt,
    lastAuto: lastAuto,
  );
}

/// 自动备份失败后至少隔多久再试。
const Duration cloudAutoBackupRetryDelay = Duration(hours: 1);

/// 某个备份位置现在该不该自动备份（纯函数）：
/// - 开关开着，且本机已经成功做过一次这条链的增量备份——第一次的大上传与
///   密码设定都由用户手动完成；
/// - 上次失败不满 [cloudAutoBackupRetryDelay] 不试；
/// - 上次因新媒体太多而停下的，在一个间隔内不再提醒式地反复尝试；
/// - 距上次成功（含“没有变化”）已满间隔。
bool isCloudAutoBackupDue({
  required CloudBackupOptions options,
  required CloudBackupTargetState state,
  required DateTime now,
}) {
  if (!options.autoBackup || !options.hasChain) return false;
  if (state.lastIndexName == null) return false;
  final failedAt = state.lastFailureAt;
  if (failedAt != null &&
      now.difference(failedAt) < cloudAutoBackupRetryDelay) {
    return false;
  }
  final interval = options.autoInterval.duration;
  final auto = state.lastAuto;
  if (auto != null &&
      auto.outcome == CloudAutoBackupOutcome.needsManual &&
      now.difference(auto.at) < interval) {
    return false;
  }
  final last = state.lastSuccessAt;
  return last == null || now.difference(last) >= interval;
}
