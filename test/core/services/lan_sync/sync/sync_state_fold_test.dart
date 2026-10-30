import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_state.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_fold.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_test_devices.dart';

/// 写入后折叠的历史时间继承（规格 §4.1.1）：`seenAtOverrides` 只改“两边都有、
/// 哈希变了”的分面进历史时的 seenAt，墓碑与新记录照旧。
void main() {
  const kept = SyncKey(SyncEntity.diary, 'kept');
  const gone = SyncKey(SyncEntity.diary, 'gone');

  SyncObservation observation(Map<SyncKey, Map<String, String>> entries) =>
      SyncObservation(
        manifest: SyncManifest(entries),
        trackedValues: const <SyncKey, Map<String, Object?>>{},
        tagLocalIds: const <String, int>{},
        observed: SyncEntity.values.toSet(),
      );

  final previous = observation(<SyncKey, Map<String, String>>{
    kept: <String, String>{'pin': 'p1', 'trash': 't1', 'tags': 'g1'},
    gone: <String, String>{'pin': 'x1'},
  });
  final current = observation(<SyncKey, Map<String, String>>{
    kept: <String, String>{'pin': 'p2', 'trash': 't2', 'tags': 'g1'},
  });

  test('有覆盖值的分面以它为 seenAt，其余分面用 now', () {
    final data = SyncStateData();
    foldSyncObservation(
      previous: previous,
      current: current,
      state: data,
      now: 9000,
      seenAtOverrides: <SyncKey, Map<String, int>>{
        kept: <String, int>{'pin': 4000},
      },
    );
    expect(data.history[kept]!['pin']!.single.hash, 'p1');
    expect(data.history[kept]!['pin']!.single.seenAt, 4000);
    expect(data.history[kept]!['trash']!.single.seenAt, 9000);
  });

  test('没有覆盖值时一律用 now', () {
    final data = SyncStateData();
    foldSyncObservation(
      previous: previous,
      current: current,
      state: data,
      now: 9000,
    );
    expect(data.history[kept]!['pin']!.single.seenAt, 9000);
    expect(data.history[kept]!['trash']!.single.seenAt, 9000);
  });

  test('覆盖了没变化或不存在的分面、被删除的记录时忽略', () {
    final data = SyncStateData();
    foldSyncObservation(
      previous: previous,
      current: current,
      state: data,
      now: 9000,
      seenAtOverrides: <SyncKey, Map<String, int>>{
        kept: <String, int>{'tags': 1, 'missing': 2},
        gone: <String, int>{'pin': 3},
        const SyncKey(SyncEntity.tag, 'never'): <String, int>{'color': 4},
      },
    );
    expect(data.history[kept]!.containsKey('tags'), isFalse);
    expect(data.history[kept]!.containsKey('missing'), isFalse);
    expect(data.history[kept]!['pin']!.single.seenAt, 9000);
    expect(data.tombstones[gone]!.deletedAt, 9000);
    expect(data.history.containsKey(gone), isFalse);
  });

  test('recordAppliedState 把计划的 historySeenAt 交给折叠', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final device = await SyncTestDevice.create('fold');
    addTearDown(device.dispose);
    final state = SyncLocalState(
      database: device.db,
      stateDir: device.stateDir,
      clock: () => DateTime.utc(2026, 10, 1),
    );
    await seedEveryEntity(device);
    await state.refreshCheckpoint();
    await (device.db.update(device.db.diaries)
          ..where((t) => t.diaryId.equals('diary-rich')))
        .write(const DiariesCompanion(isPinned: Value(false)));
    final after = await state.observeRows(await device.db.readSyncRows());
    const rich = SyncKey(SyncEntity.diary, 'diary-rich');
    await state.recordAppliedState(
      after,
      historySeenAt: <SyncKey, Map<String, int>>{
        rich: <String, int>{SyncFacet.pin: 1234},
      },
    );
    final snapshot = await state.snapshot();
    expect(snapshot.history(rich, SyncFacet.pin).single.seenAt, 1234);
  });
}
