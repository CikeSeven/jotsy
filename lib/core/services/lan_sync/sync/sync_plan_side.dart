import 'package:meta/meta.dart';

import 'sync_model.dart';
import 'sync_state_model.dart';

/// 规划器眼中的一侧（本机或对方）：清单、按需取得的完整记录、分面历史、
/// 墓碑与标签改名（规格 §4）。
///
/// 规划分两段：`planSyncFetch` 反复列出还要取的数据，会话层取回后再问，
/// 直到不再缺数据；`planSync` 只读取取过的数据。实现只需回答取到的部分：
/// 没取的记录 [recordOf] 返回 null，没取的历史 [hasHistory] 返回 false，
/// 没取的墓碑详情 [tombstoneOf] 返回 null（[hasTombstone] 仍要如实回答，
/// 墓碑键随清单一起送达）。规划器保证不依赖没要过的数据（测试用“只回答
/// 已取数据”的实现与全知实现对比兜底）。
///
/// 本机一侧是 `SyncLocalPlanSide`（`sync_local_plan_side.dart`，适配
/// `SyncLocalSnapshot`）：历史、墓碑、改名都在内存里，[hasHistory] 恒为 true；
/// 记录经 `buildRecords` 只构建要过的键。对方一侧由会话消息逐步填充（见
/// [SyncPlanSideData]）。
abstract interface class SyncPlanSide {
  String get deviceId;

  SyncManifest get manifest;

  /// 这一侧清单覆盖的实体（不含 settings，它由 [participatesInSettings]
  /// 决定）。不在两侧共同覆盖范围里的实体整类跳过：缺少某类实体从不当作删除。
  Set<SyncEntity> get entities;

  /// 这一侧是否开启了“同步设置”。两侧都开启时 settings 才参与。
  bool get participatesInSettings;

  /// 这一侧刚做过覆盖恢复、还没与任何设备同步过（`store.json` 的标记）。
  bool get restoredPending;

  /// [key] 的完整记录；没取过（或不存在）时为 null。
  SyncRecord? recordOf(SyncKey key);

  /// 能否回答 [key] 的历史（本机恒为 true；对方为取过 `history.get` 的键）。
  bool hasHistory(SyncKey key);

  /// [key] / [facet] 的历史，新的在前；[hasHistory] 为 false 时不会被调用。
  List<SyncHistoryEntry> historyOf(SyncKey key, String facet);

  /// 这一侧是否有 [key] 的墓碑（墓碑键列表随清单一起送达）。
  bool hasTombstone(SyncKey key);

  /// 墓碑详情；没有墓碑或还没取到详情时为 null。
  SyncTombstone? tombstoneOf(SyncKey key);

  /// 这一侧的标签改名：旧名 → 记录（全部改名随清单一起送达）。
  SyncTagRename? renameOf(String oldName);
}

/// [SyncPlanSide] 的内存实现：会话层边取边填，测试直接构造。
///
/// [allHistoryKnown] 为 true（本机一侧、全知的测试替身）时任何键的历史都
/// 算已知，没有记录的键即“没有历史”。
class SyncPlanSideData implements SyncPlanSide {
  SyncPlanSideData({
    required this.deviceId,
    required this.manifest,
    Set<SyncEntity>? entities,
    this.participatesInSettings = false,
    this.restoredPending = false,
    this.allHistoryKnown = false,
    Iterable<SyncKey> tombstoneKeys = const <SyncKey>[],
    Map<SyncKey, SyncTombstone>? tombstones,
    Map<String, SyncTagRename>? renames,
    Map<SyncKey, Map<String, List<SyncHistoryEntry>>>? history,
    Iterable<SyncRecord> records = const <SyncRecord>[],
  }) : entities =
           entities ??
           <SyncEntity>{
             for (final entity in SyncEntity.values)
               if (entity != SyncEntity.settings) entity,
           },
       _tombstoneKeys = <SyncKey>{...tombstoneKeys, ...?tombstones?.keys},
       _tombstones = <SyncKey, SyncTombstone>{...?tombstones},
       _renames = <String, SyncTagRename>{...?renames},
       _history = <SyncKey, Map<String, List<SyncHistoryEntry>>>{...?history},
       _records = <SyncKey, SyncRecord>{
         for (final record in records) record.key: record,
       };

  @override
  final String deviceId;

  @override
  final SyncManifest manifest;

  @override
  final Set<SyncEntity> entities;

  @override
  final bool participatesInSettings;

  @override
  final bool restoredPending;

  final bool allHistoryKnown;

  final Set<SyncKey> _tombstoneKeys;
  final Map<SyncKey, SyncTombstone> _tombstones;
  final Map<String, SyncTagRename> _renames;
  final Map<SyncKey, Map<String, List<SyncHistoryEntry>>> _history;
  final Map<SyncKey, SyncRecord> _records;

  /// 已经取得的记录键。
  Iterable<SyncKey> get recordKeys => _records.keys;

  void addRecords(Iterable<SyncRecord> records) {
    for (final record in records) {
      _records[record.key] = record;
    }
  }

  /// 并入一批历史（键 → 分面 → 历史）。取回的键即使没有任何历史，也要以
  /// 空 Map 并入，表示“问过了、确实没有”。
  void addHistory(Map<SyncKey, Map<String, List<SyncHistoryEntry>>> history) {
    for (final entry in history.entries) {
      _history[entry.key] = <String, List<SyncHistoryEntry>>{
        ...?_history[entry.key],
        ...entry.value,
      };
    }
  }

  void addTombstones(Map<SyncKey, SyncTombstone> tombstones) {
    _tombstones.addAll(tombstones);
    _tombstoneKeys.addAll(tombstones.keys);
  }

  @override
  SyncRecord? recordOf(SyncKey key) => _records[key];

  @override
  bool hasHistory(SyncKey key) => allHistoryKnown || _history.containsKey(key);

  @override
  List<SyncHistoryEntry> historyOf(SyncKey key, String facet) =>
      _history[key]?[facet] ?? const <SyncHistoryEntry>[];

  @override
  bool hasTombstone(SyncKey key) => _tombstoneKeys.contains(key);

  @override
  SyncTombstone? tombstoneOf(SyncKey key) => _tombstones[key];

  @override
  SyncTagRename? renameOf(String oldName) => _renames[oldName];
}

/// 规划前还要取的数据（规格 §4 第一阶段）。会话层反复调用 `planSyncFetch`、
/// 取回其中列出的数据，直到 [isEmpty] 再调用 `planSync`。
@immutable
class SyncFetchRequest {
  SyncFetchRequest({
    required Set<SyncKey> remoteHistory,
    required Set<SyncKey> remoteTombstones,
    required Set<SyncKey> remoteRecords,
    required Set<SyncKey> localRecords,
  }) : remoteHistory = _sorted(remoteHistory),
       remoteTombstones = _sorted(remoteTombstones),
       remoteRecords = _sorted(remoteRecords),
       localRecords = _sorted(localRecords);

  /// 对方这些键的分面历史（全部分面，对应 `history.get{keys}`）。
  final List<SyncKey> remoteHistory;

  /// 对方这些键的墓碑详情。
  final List<SyncKey> remoteTombstones;

  /// 对方的完整记录。
  final List<SyncKey> remoteRecords;

  /// 本机的完整记录（不走网络，但要解码正文，同样只取需要的）。
  final List<SyncKey> localRecords;

  /// 是否要经网络向对方取数据（只差本机记录时不必往返）。
  bool get needsRemote =>
      remoteHistory.isNotEmpty ||
      remoteTombstones.isNotEmpty ||
      remoteRecords.isNotEmpty;

  bool get isEmpty => !needsRemote && localRecords.isEmpty;

  static List<SyncKey> _sorted(Set<SyncKey> keys) =>
      List<SyncKey>.unmodifiable(keys.toList()..sort());

  @override
  String toString() =>
      'SyncFetchRequest(history ${remoteHistory.length}, tombstones '
      '${remoteTombstones.length}, remote ${remoteRecords.length}, '
      'local ${localRecords.length})';
}
