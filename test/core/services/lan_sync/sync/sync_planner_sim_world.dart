import 'dart:math';

import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_planner_fixtures.dart' show describePlan;
import 'sync_planner_sim_apply.dart';
import 'sync_planner_sim_ops.dart';
import 'sync_planner_sim_replica.dart';

/// 收敛模拟的世界：几台设备、全局时钟、随机操作与两两同步。
///
/// 同步完全按生产流程：双方刷新检查点（折叠）→ 发起方按需取数规划 →
/// 双方写入（可模拟中断：只有一侧写入）→ 写入的一侧再折叠。
class SimWorld {
  SimWorld(this.seed, int count, {bool skewed = true}) : random = Random(seed) {
    ops = SimOps(random, () => now);
    replicas = <SimReplica>[
      for (var i = 0; i < count; i++)
        SimReplica(
          String.fromCharCode(0x41 + i),
          skew: skewed ? (random.nextInt(7) - 3) * 1000 : 0,
        ),
    ];
    for (final replica in replicas) {
      replica.refresh(now);
    }
  }

  final int seed;
  final Random random;
  late final SimOps ops;
  late final List<SimReplica> replicas;
  int now = 1700000000000;

  final Set<String> _paired = <String>{};

  /// 已执行（至少一侧写入）的计划列出过的冲突副本 id。
  final Set<String> listedCopies = <String>{};

  /// 冲突副本 id → 曾经拥有过它的设备。副本 id 只由数据决定：两对互不相干
  /// 的设备各自遇到同一个冲突时会各自生成同一个 id（之后作为同一条记录
  /// 合并），这是设计如此；只有发起同步的两台里有一台曾经有过它（中断后
  /// 重新规划、或删掉之后）还再生成，才是重复。
  final Map<String, Set<String>> copyHolders = <String, Set<String>>{};
  int syncs = 0;
  int interrupted = 0;
  int fetchRounds = 0;
  int fullCompares = 0;

  /// 随机丢失某台设备的同步状态（覆盖恢复）。
  bool loseState = false;
  int lostStates = 0;
  int renameOps = 0;
  int deletes = 0;
  int writes = 0;
  int sideChoice = 0;
  int guards = 0;

  void tick() => now += 1000;

  /// [a] 发起与 [b] 的同步。
  SyncPlan sync(
    SimReplica a,
    SimReplica b, {
    bool applyLocal = true,
    bool applyRemote = true,
    bool compareFull = false,
  }) {
    tick();
    a.refresh(now);
    b.refresh(now);
    final pair = ([a.name, b.name]..sort()).join();
    final first = _paired.add(pair);
    final options = SyncPlanOptions(
      nowMillis: now,
      firstSyncWithPeer: first,
      localLoserTitleSuffix: ' [copy · ${a.name}]',
      remoteLoserTitleSuffix: ' [copy · ${b.name}]',
      sideChoice: first
          ? SyncSideChoice.values[random.nextInt(SyncSideChoice.values.length)]
          : SyncSideChoice.keepBoth,
    );
    final localRecords = a.records();
    final remoteRecords = b.records();
    final l = a.planSide(local: true, peer: b.name);
    final r = b.planSide(local: false, peer: a.name);
    for (var round = 0; ; round++) {
      if (round > 10) throw StateError('取数轮次过多（seed $seed）');
      final request = planSyncFetch(local: l, remote: r, options: options);
      if (request.isEmpty) break;
      fetchRounds++;
      r.addHistory(<SyncKey, Map<String, List<SyncHistoryEntry>>>{
        for (final key in request.remoteHistory)
          key: b.state.history[key] ?? <String, List<SyncHistoryEntry>>{},
      });
      r.addTombstones(<SyncKey, SyncTombstone>{
        for (final key in request.remoteTombstones)
          key: b.state.tombstones[key]!,
      });
      r.addRecords(<SyncRecord>[
        for (final key in request.remoteRecords) remoteRecords[key]!,
      ]);
      l.addRecords(<SyncRecord>[
        for (final key in request.localRecords) localRecords[key]!,
      ]);
    }
    final plan = planSync(local: l, remote: r, options: options);
    if (compareFull) {
      fullCompares++;
      final full = planSync(
        local: a.planSide(local: true, peer: b.name, full: true),
        remote: b.planSide(local: false, peer: a.name, full: true),
        options: options,
      );
      if (describePlan(full) != describePlan(plan)) {
        throw StateError('按需取数与全知规划不一致（seed $seed）');
      }
    }
    syncs++;
    for (final side in [plan.local, plan.remote]) {
      renameOps += side.renames.length;
      writes += side.writes.length;
      deletes += side.writes.where((w) => w.record == null).length;
    }
    sideChoice += plan.confirmations.sideChoiceConflicts;
    guards += plan.confirmations.deletionGuards.length;
    if (!applyLocal || !applyRemote) interrupted++;
    if (applyLocal || applyRemote) {
      for (final copy in plan.conflictCopies) {
        listedCopies.add(copy.copyId);
        final holders = copyHolders[copy.copyId] ?? const <String>{};
        if (holders.contains(a.name) || holders.contains(b.name)) {
          throw StateError('冲突副本 ${copy.copyId} 被重复生成（seed $seed）');
        }
      }
    }
    if (applyLocal) _apply(a, plan.local);
    if (applyRemote) _apply(b, plan.remote);
    if (applyLocal && applyRemote) {
      a.restoredPendingWith.remove(b.name);
      b.restoredPendingWith.remove(a.name);
    }
    return plan;
  }

  void _apply(SimReplica replica, SyncSidePlan plan) {
    final skipped = simApply(replica, plan);
    if (skipped != 0) {
      throw StateError('${replica.name} 跳过了 $skipped 条写入（seed $seed）');
    }
    tick();
    replica.refresh(now, seenAtOverrides: plan.historySeenAt);
    for (final diary in replica.diaries.values) {
      final metadata = diary.metadata;
      if (metadata is Map && metadata['sync'] is Map) {
        (copyHolders[diary.id] ??= <String>{}).add(replica.name);
      }
    }
  }

  /// 随机一步：某台设备做几次操作，或随机两台同步（可能中断）。
  void step() {
    if (loseState && random.nextInt(200) == 0) {
      final replica = replicas[random.nextInt(replicas.length)];
      tick();
      replica
        ..loseSyncState([
          for (final other in replicas)
            if (other != replica) other.name,
        ])
        ..refresh(now);
      lostStates++;
      return;
    }
    if (random.nextInt(100) < 55) {
      final replica = replicas[random.nextInt(replicas.length)];
      for (var i = random.nextInt(3); i >= 0; i--) {
        tick();
        ops.randomOp(replica);
      }
      return;
    }
    final i = random.nextInt(replicas.length);
    var j = random.nextInt(replicas.length - 1);
    if (j >= i) j++;
    final cut = random.nextInt(10) == 0;
    final keepLocal = random.nextBool();
    sync(
      replicas[i],
      replicas[j],
      applyLocal: !cut || keepLocal,
      applyRemote: !cut || !keepLocal,
      compareFull: random.nextInt(5) == 0,
    );
  }

  bool get converged {
    final first = syncCanonicalJson(replicas.first.manifest().toJson());
    return replicas.every(
      (r) => syncCanonicalJson(r.manifest().toJson()) == first,
    );
  }

  /// 反复两两同步直到全部相同；返回用了几轮。
  int converge({int maxRounds = 4}) {
    for (var round = 1; round <= maxRounds; round++) {
      for (var i = 0; i < replicas.length; i++) {
        for (var j = i + 1; j < replicas.length; j++) {
          final flip = random.nextBool();
          sync(
            flip ? replicas[i] : replicas[j],
            flip ? replicas[j] : replicas[i],
          );
        }
      }
      if (converged) return round;
    }
    throw StateError('$maxRounds 轮后仍未收敛（seed $seed）');
  }
}
