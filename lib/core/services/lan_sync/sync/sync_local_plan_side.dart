import 'sync_local_state.dart';
import 'sync_model.dart';
import 'sync_plan_side.dart';
import 'sync_state_model.dart';

/// 规划器的本机一侧：把 [SyncLocalSnapshot]（会话开始时
/// `SyncLocalState.refreshCheckpoint` 的结果）适配成 [SyncPlanSide]（规格 §4.0）。
///
/// - 清单、分面历史、墓碑详情、标签改名都取自快照，本机历史恒可答；
/// - 完整记录按 `planSyncFetch` 列出的本机键，经 [loadRecords]（内部调用
///   `SyncLocalState.buildRecords`）构建后填进来——只解码要用的行；
/// - `restoredPending`、是否同步设置、实体集合由会话层按本机状态与本次协商
///   结果传入。
///
/// 单独成文件：快照与 `SyncLocalState` 牵涉数据库与 Flutter，规划器本身
/// （`sync_planner.dart`、`sync_plan_side.dart`）要保持纯 Dart。
class SyncLocalPlanSide implements SyncPlanSide {
  SyncLocalPlanSide({
    required this.deviceId,
    required this.snapshot,
    Set<SyncEntity>? entities,
    this.participatesInSettings = false,
    this.restoredPending = false,
  }) : entities =
           entities ??
           <SyncEntity>{
             for (final entity in snapshot.observation.observed)
               if (entity != SyncEntity.settings) entity,
           };

  @override
  final String deviceId;

  final SyncLocalSnapshot snapshot;

  /// 默认取快照这次观测覆盖的实体（不含 settings）。
  @override
  final Set<SyncEntity> entities;

  @override
  final bool participatesInSettings;

  @override
  final bool restoredPending;

  final Map<SyncKey, SyncRecord> _records = <SyncKey, SyncRecord>{};

  /// 已经构建的记录键。
  Iterable<SyncKey> get recordKeys => _records.keys;

  void addRecords(Iterable<SyncRecord> records) {
    for (final record in records) {
      _records[record.key] = record;
    }
  }

  /// 构建 [keys] 的本机记录并填进来（已有的不重复构建）。
  ///
  /// 记录由数据库的当前内容现算：会话期间编辑页被登记为阻塞者、不会写库
  /// （规格 §7），所以与快照的清单一致；万一不一致，规划出的写入会因
  /// `expected` 不符被写入层跳过，下次同步再处理。
  Future<void> loadRecords(SyncLocalState state, Iterable<SyncKey> keys) async {
    final missing = <SyncKey>[
      for (final key in keys)
        if (!_records.containsKey(key)) key,
    ];
    if (missing.isEmpty) return;
    addRecords(await state.buildRecords(missing));
  }

  @override
  SyncManifest get manifest => snapshot.manifest;

  @override
  SyncRecord? recordOf(SyncKey key) => _records[key];

  @override
  bool hasHistory(SyncKey key) => true;

  @override
  List<SyncHistoryEntry> historyOf(SyncKey key, String facet) =>
      snapshot.history(key, facet);

  @override
  bool hasTombstone(SyncKey key) => snapshot.tombstone(key) != null;

  @override
  SyncTombstone? tombstoneOf(SyncKey key) => snapshot.tombstone(key);

  @override
  SyncTagRename? renameOf(String oldName) => snapshot.renameOf(oldName);
}
