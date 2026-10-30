import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_fold.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_planner_fixture_records.dart';

export 'sync_planner_fixture_records.dart';

/// 规划器单元测试的夹具：用生产的折叠规则（`foldSyncObservation`）维护历史、
/// 墓碑与改名，并以“按需取数”的方式跑完整的两段规划。规范记录的拼法见
/// `sync_planner_fixture_records.dart`。

/// 一台规范层面的测试设备：记录 + 生产的折叠规则。
///
/// [commit] 相当于一次刷新检查点：把上次提交以来的差异折进历史 / 墓碑 /
/// 改名。标签改名用 [renameTag]（同一个本地 id 换名字）。
class PlanDevice {
  PlanDevice(this.id, {this.restoredPending = false, this.settings = false});

  final String id;
  bool restoredPending;
  bool settings;
  final Map<SyncKey, SyncRecord> records = <SyncKey, SyncRecord>{};
  final SyncStateData state = SyncStateData();
  final Map<String, int> _tagIds = <String, int>{};
  int _nextTagId = 1;
  SyncObservation? checkpoint;

  void put(SyncRecord record) {
    records[record.key] = record;
    if (record.key.entity == SyncEntity.tag) {
      _tagIds.putIfAbsent(record.key.id, () => _nextTagId++);
    }
  }

  void putAll(Iterable<SyncRecord> list) => list.forEach(put);

  void remove(SyncKey key) {
    records.remove(key);
    if (key.entity == SyncEntity.tag) _tagIds.remove(key.id);
  }

  /// 标签 [from] 原地改名为 [to]（颜色不变，本地 id 不变）。
  void renameTag(String from, String to) {
    final old = records.remove(tagKey(from))!;
    records[tagKey(to)] = SyncRecord(tagKey(to), old.facets);
    _tagIds[to] = _tagIds.remove(from)!;
  }

  SyncManifest get manifest => SyncManifest.fromRecords(records.values);

  SyncObservation observe() => SyncObservation(
    manifest: manifest,
    trackedValues: <SyncKey, Map<String, Object?>>{
      for (final record in records.values)
        if (record.facets.keys.any(
          (facet) => SyncFacet.tracksValue(record.key.entity, facet),
        ))
          record.key: <String, Object?>{
            for (final facet in record.facets.entries)
              if (SyncFacet.tracksValue(record.key.entity, facet.key))
                facet.key: facet.value,
          },
    },
    tagLocalIds: Map<String, int>.of(_tagIds),
    observed: <SyncEntity>{
      for (final entity in SyncEntity.values)
        if (entity != SyncEntity.settings || settings) entity,
    },
  );

  /// [seenAtOverrides] 同生产的写入后折叠（`SyncSidePlan.historySeenAt`）。
  void commit(
    int now, {
    Map<SyncKey, Map<String, int>> seenAtOverrides =
        const <SyncKey, Map<String, int>>{},
  }) {
    checkpoint = foldSyncObservation(
      previous: checkpoint,
      current: observe(),
      state: state,
      now: now,
      seenAtOverrides: seenAtOverrides,
    );
  }

  /// 全知的一侧（历史、墓碑、记录全部可答）。
  SyncPlanSideData fullSide() => SyncPlanSideData(
    deviceId: id,
    manifest: manifest,
    participatesInSettings: settings,
    restoredPending: restoredPending,
    allHistoryKnown: true,
    tombstones: state.tombstones,
    renames: state.renames,
    history: state.history,
    records: records.values,
  );

  /// 只有清单、墓碑键与改名的一侧（[local] 为 true 时历史与墓碑详情可答）。
  SyncPlanSideData lazySide({required bool local}) => SyncPlanSideData(
    deviceId: id,
    manifest: manifest,
    participatesInSettings: settings,
    restoredPending: restoredPending,
    allHistoryKnown: local,
    tombstoneKeys: state.tombstones.keys,
    tombstones: local ? state.tombstones : null,
    renames: state.renames,
    history: local ? state.history : null,
  );

  /// 执行计划并按生产流程在写入后折叠（含历史时间继承，规格 §4.1.1）。
  void applyAndCommit(SyncSidePlan plan, int now) {
    apply(plan);
    commit(now, seenAtOverrides: plan.historySeenAt);
  }

  /// 在规范层面执行一侧的计划（改名 → 写入），不模拟由别的记录推出的值。
  void apply(SyncSidePlan plan) {
    for (final rename in plan.renames) {
      renameTag(rename.from, rename.to);
      put(rename.record);
    }
    for (final write in plan.writes) {
      final record = write.record;
      if (record == null) {
        remove(write.key);
      } else {
        put(record);
      }
    }
  }
}

/// 一次规划的结果与取数记录。
class PlanRun {
  PlanRun(this.plan, this.fetches);

  final SyncPlan plan;
  final List<SyncFetchRequest> fetches;

  /// 全部取数请求的并集（按类别）。
  Set<SyncKey> get remoteHistory => <SyncKey>{
    for (final fetch in fetches) ...fetch.remoteHistory,
  };
  Set<SyncKey> get remoteTombstones => <SyncKey>{
    for (final fetch in fetches) ...fetch.remoteTombstones,
  };
  Set<SyncKey> get remoteRecords => <SyncKey>{
    for (final fetch in fetches) ...fetch.remoteRecords,
  };
  Set<SyncKey> get localRecords => <SyncKey>{
    for (final fetch in fetches) ...fetch.localRecords,
  };
}

/// 按会话层的方式规划：反复 `planSyncFetch` 取数，再 `planSync`；并与全知
/// 两侧的规划逐项对比，保证规划器不依赖没要过的数据。
PlanRun planBetween(
  PlanDevice local,
  PlanDevice remote, {
  SyncPlanOptions options = const SyncPlanOptions(nowMillis: 0),
}) {
  final l = local.lazySide(local: true);
  final r = remote.lazySide(local: false);
  final fetches = <SyncFetchRequest>[];
  for (var round = 0; ; round++) {
    if (round > 12) throw StateError('取数轮次过多');
    final request = planSyncFetch(local: l, remote: r, options: options);
    if (request.isEmpty) break;
    fetches.add(request);
    r.addHistory(<SyncKey, Map<String, List<SyncHistoryEntry>>>{
      for (final key in request.remoteHistory)
        key: remote.state.history[key] ?? <String, List<SyncHistoryEntry>>{},
    });
    r.addTombstones(<SyncKey, SyncTombstone>{
      for (final key in request.remoteTombstones)
        key: remote.state.tombstones[key]!,
    });
    r.addRecords(<SyncRecord>[
      for (final key in request.remoteRecords) remote.records[key]!,
    ]);
    l.addRecords(<SyncRecord>[
      for (final key in request.localRecords) local.records[key]!,
    ]);
  }
  final plan = planSync(local: l, remote: r, options: options);
  final full = planSync(
    local: local.fullSide(),
    remote: remote.fullSide(),
    options: options,
  );
  final a = describePlan(plan);
  final b = describePlan(full);
  if (a != b) {
    throw StateError('按需取数与全知规划不一致：\n$a\n---\n$b');
  }
  return PlanRun(plan, fetches);
}

/// 计划的确定性文本描述（比较用）。
String describePlan(SyncPlan plan) {
  final out = StringBuffer();
  for (final role in SyncSideRole.values) {
    final side = plan.sideOf(role);
    out.writeln('[${role.name}]');
    for (final rename in side.renames) {
      out.writeln(
        'rename ${rename.from}->${rename.to} ${rename.expected} '
        '${syncCanonicalJson(rename.record.facets)}',
      );
    }
    for (final write in side.writes) {
      out.writeln(
        '${write.key} ${write.expected} '
        '${write.record == null ? 'DELETE' : syncCanonicalJson(write.record!.facets)}',
      );
    }
    out.writeln('media ${side.mediaNeeded}');
    final inherited = side.historySeenAt.keys.toList()..sort();
    out.writeln(
      'seenAt ${[for (final k in inherited) '$k:${side.historySeenAt[k]}']}',
    );
    final stats = side.stats.keys.toList()..sort((a, b) => a.index - b.index);
    out.writeln(
      'stats ${[for (final e in stats) '${e.name}:${side.stats[e]}']}',
    );
  }
  for (final copy in plan.conflictCopies) {
    out.writeln('copy ${copy.originalId} ${copy.copyId} ${copy.title}');
  }
  final c = plan.confirmations;
  out.writeln(
    'guards ${[for (final g in c.deletionGuards) '${g.side.name}:${g.count}/${g.total}']} '
    'sideChoice ${c.sideChoiceConflicts}',
  );
  return out.toString();
}

/// 计划里 [role] 一侧对 [key] 的写入（没有为 null）。
SyncWrite? writeFor(SyncPlan plan, SyncSideRole role, SyncKey key) {
  for (final write in plan.sideOf(role).writes) {
    if (write.key == key) return write;
  }
  return null;
}

/// 两台设备执行计划后，清单应当相同。
void applyBoth(PlanDevice local, PlanDevice remote, SyncPlan plan) {
  local.apply(plan.local);
  remote.apply(plan.remote);
}

/// 两台设备从同一份 [base] 出发（各自提交一次，之后历史里都有它），再各自
/// 改成 [left] / [right] 并提交。
(PlanDevice, PlanDevice) forkDevices(
  List<SyncRecord> base,
  List<SyncRecord> left,
  List<SyncRecord> right, {
  int leftAt = 5000,
  int rightAt = 6000,
}) {
  final a = PlanDevice('a');
  final b = PlanDevice('b');
  for (final device in [a, b]) {
    device.putAll(base);
    device.commit(1000);
  }
  a
    ..putAll(left)
    ..commit(leftAt);
  b
    ..putAll(right)
    ..commit(rightAt);
  return (a, b);
}

/// 写入记录里的分面值（没有写入或删除为 null）。
Object? facetOf(SyncWrite? write, String name) => write?.record?.facets[name];
