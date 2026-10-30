import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../../database/app_database.dart';
import '../../settings_service.dart';
import 'sync_canonical_settings.dart';
import 'sync_hash_cache.dart';
import 'sync_manifest_builder.dart';
import 'sync_model.dart';
import 'sync_state_files.dart';
import 'sync_state_fold.dart';
import 'sync_state_json.dart';
import 'sync_state_model.dart';

/// 本机同步状态（规格 §3）：检查点、分面历史、墓碑、标签改名与哈希缓存。
///
/// - 输入（构造注入）：数据库、状态目录 `stateDir`、设置服务（只在请求
///   settings 时使用）、时钟；不在内部解析任何真实目录，测试里同一进程可以
///   跑两台“设备”；
/// - 输出：[refreshCheckpoint] 给出当前清单与规划器要查的历史 / 墓碑 / 改名；
///   [buildRecords] 给出完整规范记录；
/// - 副作用：读写 `stateDir` 下的 `checkpoint.json.gz`、`history.json.gz`、
///   `tombstones.json.gz`、`renames.json.gz`、`hash_cache.json.gz`。
///
/// 时序：所有公开方法经 [_serialized] 依次执行（会话开始的刷新、写入后的
/// 记录、覆盖恢复后的重置不会交错）。每次折叠后先写历史、墓碑、改名，最后
/// 写检查点：中途失败时检查点仍是旧的，下次刷新会把同一份差异再折一遍——
/// 历史按哈希去重、墓碑按键覆盖，重做是无害的。
///
/// 读取到损坏的状态文件时当作空（见 [SyncStateFiles]），最坏结果是这一次
/// 按并集合并。
class SyncLocalState {
  SyncLocalState({
    required this.database,
    required Directory stateDir,
    this.settings,
    DateTime Function()? clock,
  }) : _files = SyncStateFiles(stateDir),
       _clock = clock ?? DateTime.now;

  static const String checkpointFile = 'checkpoint.json.gz';
  static const String historyFile = 'history.json.gz';
  static const String tombstonesFile = 'tombstones.json.gz';
  static const String renamesFile = 'renames.json.gz';
  static const String hashCacheFile = 'hash_cache.json.gz';

  final AppDatabase database;
  final SettingsService? settings;
  final SyncStateFiles _files;
  final DateTime Function() _clock;

  Future<void> _queue = Future<void>.value();
  _LoadedState? _loaded;

  /// 算出当前清单 C，与检查点 P 比较并折进历史、墓碑与改名，持久化后返回
  /// C 与查询入口。会话开始时（冲刷编辑会话之后）调用。
  ///
  /// [includeSettings] 为 true 时 settings 也参与（需要构造时给了 [settings]）；
  /// 为 false 时检查点里 settings 的旧条目原样保留，不会被当成删除。
  Future<SyncLocalSnapshot> refreshCheckpoint({bool includeSettings = false}) {
    return _serialized(() async {
      final current = await _observeNow(includeSettings: includeSettings);
      final state = await _state();
      _fold(state, current);
      await _persist(state);
      return state.snapshot(current);
    });
  }

  /// 同步写入之后，用写入后的观测 [after] 按同一套规则更新历史、墓碑与检查点
  /// （被同步删掉的记录写墓碑，被替换的值进历史）。[after] 由 [observeRows]
  /// 从写入事务里读出的行算出。
  ///
  /// [historySeenAt] 是这一侧计划的 `SyncSidePlan.historySeenAt`：直接采纳了
  /// 另一侧值的分面，旧值进历史时继承那个值的确立时间而不是现在（规格
  /// §4.1.1，见 [foldSyncObservation] 的 `seenAtOverrides`）。写入层原样传入。
  Future<void> recordAppliedState(
    SyncObservation after, {
    Map<SyncKey, Map<String, int>> historySeenAt =
        const <SyncKey, Map<String, int>>{},
  }) {
    return _serialized(() async {
      final state = await _state();
      _fold(state, after, seenAtOverrides: historySeenAt);
      await _persist(state);
    });
  }

  /// 由调用方读出的行（如写入事务里 `readSyncRows` 的结果）算出观测，更新
  /// 哈希缓存，不折叠。[settingsCaptured] 为 [syncCaptureSettings] 的结果，
  /// null 表示不含 settings。
  Future<SyncObservation> observeRows(
    SyncRawSnapshot rows, {
    Map<String, Object?>? settingsCaptured,
  }) {
    return _serialized(
      () => _observe(rows, settingsCaptured: settingsCaptured),
    );
  }

  /// 当前数据库里 [keys] 的完整规范记录（不存在的键不出现在结果里）。
  /// 含 settings 键时需要构造时给了 [settings]。
  Future<List<SyncRecord>> buildRecords(Iterable<SyncKey> keys) async {
    final wanted = keys.toSet();
    if (wanted.isEmpty) return const <SyncRecord>[];
    final rows = await database.readSyncRows();
    final captured =
        wanted.contains(const SyncKey(SyncEntity.settings, kSyncSettingsId))
        ? syncCaptureSettings(_requireSettings())
        : null;
    return _buildInIsolate(rows, captured, wanted);
  }

  /// 不刷新、直接给出最近一次检查点及历史 / 墓碑 / 改名（没有检查点时清单为空）。
  Future<SyncLocalSnapshot> snapshot() {
    return _serialized(() async {
      final state = await _state();
      return state.snapshot(state.checkpoint ?? _emptyObservation());
    });
  }

  /// 覆盖恢复（`DataArchiveService` 的 replaceAll）成功后调用：删除检查点、
  /// 历史、墓碑、改名与哈希缓存。恢复进来的数据与本机之前的同步记忆无关，
  /// 留着旧检查点会把整份恢复误记成本机的编辑与删除。`restoredPending`
  /// 标记由服务层写在 `store.json`（docs/lan_sync.md §3“覆盖恢复”）。
  Future<void> resetAfterRestore() {
    return _serialized(() async {
      for (final name in <String>[
        checkpointFile,
        historyFile,
        tombstonesFile,
        renamesFile,
        hashCacheFile,
      ]) {
        await _files.delete(name);
      }
      _loaded = null;
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  SettingsService _requireSettings() {
    final service = settings;
    if (service == null) {
      throw StateError('同步设置需要在构造 SyncLocalState 时传入 SettingsService');
    }
    return service;
  }

  Future<SyncObservation> _observeNow({required bool includeSettings}) async {
    final rows = await database.readSyncRows();
    final captured = includeSettings
        ? syncCaptureSettings(_requireSettings())
        : null;
    return _observe(rows, settingsCaptured: captured);
  }

  Future<SyncObservation> _observe(
    SyncRawSnapshot rows, {
    Map<String, Object?>? settingsCaptured,
  }) async {
    final cache = syncHashCacheFromJson(await _files.readJson(hashCacheFile));
    final result = await _observeInIsolate(rows, settingsCaptured, cache);
    await _files.writeJson(hashCacheFile, syncHashCacheToJson(result.cache));
    return result.observation;
  }

  void _fold(
    _LoadedState state,
    SyncObservation current, {
    Map<SyncKey, Map<String, int>> seenAtOverrides =
        const <SyncKey, Map<String, int>>{},
  }) {
    state.checkpoint = foldSyncObservation(
      previous: state.checkpoint,
      current: current,
      state: state.data,
      now: _clock().millisecondsSinceEpoch,
      seenAtOverrides: seenAtOverrides,
    );
  }

  Future<_LoadedState> _state() async {
    final loaded = _loaded;
    if (loaded != null) return loaded;
    final checkpointJson = await _files.readJson(checkpointFile);
    SyncObservation? checkpoint;
    if (checkpointJson != null) {
      try {
        checkpoint = SyncObservation.fromJson(checkpointJson);
      } on FormatException catch (error) {
        debugPrint('LAN sync checkpoint discarded: $error');
      }
    }
    return _loaded = _LoadedState(
      checkpoint,
      SyncStateData(
        history: syncDecodeHistory(await _files.readJson(historyFile)),
        tombstones: syncDecodeTombstones(await _files.readJson(tombstonesFile)),
        renames: syncDecodeRenames(await _files.readJson(renamesFile)),
      ),
    );
  }

  Future<void> _persist(_LoadedState state) async {
    await _files.writeJson(historyFile, syncEncodeHistory(state.data.history));
    await _files.writeJson(
      tombstonesFile,
      syncEncodeTombstones(state.data.tombstones),
    );
    await _files.writeJson(renamesFile, syncEncodeRenames(state.data.renames));
    await _files.writeJson(checkpointFile, state.checkpoint!.toJson());
  }
}

/// 在后台 isolate 里算观测 / 构建记录。放在顶层函数里创建闭包：闭包只捕获
/// 这几个参数，不会把 [SyncLocalState]（持有数据库连接，不能跨 isolate）一起
/// 带过去。
Future<SyncObserveResult> _observeInIsolate(
  SyncRawSnapshot rows,
  Map<String, Object?>? settings,
  Map<String, SyncHashCacheEntry> cache,
) => Isolate.run(() => syncObserveRows(rows, settings: settings, cache: cache));

Future<List<SyncRecord>> _buildInIsolate(
  SyncRawSnapshot rows,
  Map<String, Object?>? settings,
  Set<SyncKey> keys,
) => Isolate.run(() => syncBuildRecords(rows, settings: settings, only: keys));

SyncObservation _emptyObservation() => SyncObservation(
  manifest: SyncManifest(const <SyncKey, Map<String, String>>{}),
  trackedValues: const <SyncKey, Map<String, Object?>>{},
  tagLocalIds: const <String, int>{},
  observed: const <SyncEntity>{},
);

class _LoadedState {
  _LoadedState(this.checkpoint, this.data);

  SyncObservation? checkpoint;
  final SyncStateData data;

  /// 外层浅拷贝即可：折叠对改动的键整块替换内层集合（写时复制），快照里
  /// 引用的旧集合不会被改。
  SyncLocalSnapshot snapshot(SyncObservation current) => SyncLocalSnapshot(
    observation: current,
    history: Map<SyncKey, Map<String, List<SyncHistoryEntry>>>.of(data.history),
    tombstones: Map<SyncKey, SyncTombstone>.of(data.tombstones),
    renames: Map<String, SyncTagRename>.of(data.renames),
  );
}

/// 一次刷新的结果：当前清单与规划器需要的查询。
class SyncLocalSnapshot {
  SyncLocalSnapshot({
    required this.observation,
    required this._history,
    required this._tombstones,
    required Map<String, SyncTagRename> renames,
  }) : renames = Map<String, SyncTagRename>.unmodifiable(renames);

  final SyncObservation observation;
  final Map<SyncKey, Map<String, List<SyncHistoryEntry>>> _history;
  final Map<SyncKey, SyncTombstone> _tombstones;

  /// 本机的标签改名：旧名 → 记录。
  final Map<String, SyncTagRename> renames;

  SyncManifest get manifest => observation.manifest;

  /// [key] 的 [facet] 的历史，新的在前（没有时为空列表）。
  List<SyncHistoryEntry> history(SyncKey key, String facet) =>
      _history[key]?[facet] ?? const <SyncHistoryEntry>[];

  /// [key] 各分面的历史。
  Map<String, List<SyncHistoryEntry>> historyOf(SyncKey key) =>
      Map<String, List<SyncHistoryEntry>>.unmodifiable(
        _history[key] ?? const <String, List<SyncHistoryEntry>>{},
      );

  /// [key] 的 [facet] 曾经有过的哈希（规划器记号 H_L）。
  Set<String> historyHashes(SyncKey key, String facet) => <String>{
    for (final entry in history(key, facet)) entry.hash,
  };

  SyncTombstone? tombstone(SyncKey key) => _tombstones[key];

  Iterable<SyncKey> get tombstoneKeys => _tombstones.keys;

  SyncTagRename? renameOf(String oldName) => renames[oldName];
}
