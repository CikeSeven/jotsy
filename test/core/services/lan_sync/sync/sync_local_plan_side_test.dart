import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_state.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_planner_fixture_records.dart';
import 'sync_test_devices.dart';

/// 本机一侧适配器 [SyncLocalPlanSide]：真实的 `SyncLocalState`（内存数据库 +
/// 临时状态目录）对着一个 [SyncPlanSideData] 的对方，按会话层的方式跑完
/// “取数循环 → planSync”。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice device;
  late SyncLocalState state;

  setUp(() async {
    device = await SyncTestDevice.create('plan_side');
    state = SyncLocalState(
      database: device.db,
      stateDir: device.stateDir,
      clock: () => DateTime.utc(2026, 10, 1),
    );
    await seedEveryEntity(device);
  });

  tearDown(() => device.dispose());

  /// 会话层的取数循环：本机记录经适配器构建，对方的从 [remoteRecords] 取。
  Future<(SyncPlan, List<SyncFetchRequest>)> plan(
    SyncLocalPlanSide local,
    SyncPlanSideData remote, {
    Map<SyncKey, SyncRecord> remoteRecords = const <SyncKey, SyncRecord>{},
    Map<SyncKey, SyncTombstone> remoteTombstones =
        const <SyncKey, SyncTombstone>{},
  }) async {
    const options = SyncPlanOptions(nowMillis: 0);
    final fetches = <SyncFetchRequest>[];
    while (true) {
      final request = planSyncFetch(
        local: local,
        remote: remote,
        options: options,
      );
      if (request.isEmpty) break;
      fetches.add(request);
      await local.loadRecords(state, request.localRecords);
      remote
        ..addRecords([
          for (final key in request.remoteRecords) remoteRecords[key]!,
        ])
        ..addHistory({
          for (final key in request.remoteHistory)
            key: <String, List<SyncHistoryEntry>>{},
        })
        ..addTombstones({
          for (final key in request.remoteTombstones)
            key: remoteTombstones[key]!,
        });
    }
    return (planSync(local: local, remote: remote, options: options), fetches);
  }

  test('对着一台新设备：本机全部记录推过去，对方独有的记录写到本机', () async {
    final snapshot = await state.refreshCheckpoint();
    final local = SyncLocalPlanSide(deviceId: 'local', snapshot: snapshot);
    final theirs = diaryRecord('remote-only', title: 'from remote');
    final remote = SyncPlanSideData(
      deviceId: 'remote',
      manifest: SyncManifest.fromRecords([theirs]),
    );
    final (result, fetches) = await plan(
      local,
      remote,
      remoteRecords: {theirs.key: theirs},
    );
    expect(fetches, hasLength(1));
    expect(local.recordKeys.toSet(), snapshot.manifest.keys.toSet());
    final pushed = {
      for (final write in result.remote.writes)
        if (write.isInsert) write.key,
    };
    expect(pushed, snapshot.manifest.keys.toSet());
    final pulled = result.local.writes.single;
    expect(pulled.key, theirs.key);
    expect(pulled.isInsert, isTrue);
    expect(result.local.mediaNeeded, isEmpty);
    expect(result.remote.mediaNeeded, isNotEmpty);
  });

  test('对方的墓碑覆盖本机记录：先取墓碑详情，删除不构建记录', () async {
    final snapshot = await state.refreshCheckpoint();
    const doomed = SyncKey(SyncEntity.comment, 'comment-1');
    final hashes = snapshot.manifest[doomed]!;
    // 对方有本机的全部记录（与本机相同），只是删掉了这条留言。
    final local = SyncLocalPlanSide(deviceId: 'local', snapshot: snapshot);
    final remote = SyncPlanSideData(
      deviceId: 'remote',
      manifest: SyncManifest({
        for (final entry in snapshot.manifest.entries.entries)
          if (entry.key != doomed) entry.key: entry.value,
      }),
      tombstoneKeys: [doomed],
    );
    final (result, fetches) = await plan(
      local,
      remote,
      remoteTombstones: {
        doomed: SyncTombstone(
          deletedAt: 1,
          known: {
            for (final facet in hashes.entries) facet.key: [facet.value],
          },
        ),
      },
    );
    expect(fetches.single.remoteTombstones, [doomed]);
    expect(local.recordKeys, isEmpty);
    expect(result.local.writes.single.key, doomed);
    expect(result.local.writes.single.isDelete, isTrue);
    expect(result.remote.writes, isEmpty);
  });
}
