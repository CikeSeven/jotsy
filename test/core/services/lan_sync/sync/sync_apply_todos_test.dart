import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_apply.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import '../../../../support/lan_sync_two_devices.dart';
import 'sync_apply_test_support.dart';
import 'sync_test_devices.dart';

/// 待办与清单的写入层（规格 §6、§4.6 写入层须知第 3 条）与两台设备端到端：
/// 按原值写入、同步删清单不连带删待办、坏记录单独跳过、删清单与另一侧新加
/// 的待办收敛到收集箱。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(EditingSessionRegistry.instance.debugReset);

  group('写入层', () {
    late SyncTestDevice a;

    setUp(() async {
      a = await SyncTestDevice.create('todo_apply');
      await seedEveryEntity(a);
    });

    tearDown(() => a.dispose());

    Future<TodoRow?> todo(String id) => (a.db.select(
      a.db.todos,
    )..where((t) => t.todoId.equals(id))).getSingleOrNull();

    test('按原值写列：updatedAt 不刷新，顺序保持浮点；不存在的行插入', () async {
      final rig = SyncApplyRig(a);
      final records = await rig.records();
      final full = records[const SyncKey(SyncEntity.todo, 'todo-full')]!;
      final edited = withFacet(full, SyncFacet.main, <String, Object?>{
        'title': 'Buy oat milk',
        'sortOrder': 0.125,
        'completedAt': 1700009000 * 1000,
        'updatedAt': 1700009000 * 1000,
      });
      final fresh = SyncRecord(
        const SyncKey(SyncEntity.todo, 'todo-new'),
        <String, Object?>{
          SyncFacet.main: <String, Object?>{
            ...(full.facets[SyncFacet.main]! as Map).cast<String, Object?>(),
            'title': 'From the other device',
            'listId': null,
          },
        },
      );
      final result = await rig.applier.apply(
        await rig.planFor(<SyncRecord>[edited, fresh]),
      );

      expect(result.skipped, isEmpty);
      final row = (await todo('todo-full'))!;
      expect(row.title, 'Buy oat milk');
      expect(row.sortOrder, 0.125);
      expect(row.updatedAt, at(1700009000));
      expect(row.completedAt, at(1700009000));
      expect((await todo('todo-new'))!.title, 'From the other device');
      final after = await rig.records();
      expect(after[edited.key]!.hashes, edited.hashes);
      expect(after[fresh.key]!.hashes, fresh.hashes);
    });

    test('同步删除清单只删这一行，其中的待办不连带删除', () async {
      final rig = SyncApplyRig(a);
      await rig.applier.apply(
        await rig.planFor(
          const <SyncRecord>[],
          deletes: const [SyncKey(SyncEntity.todoList, 'list-1')],
        ),
      );

      final lists = await a.db.select(a.db.todoLists).get();
      expect(lists.map((row) => row.listId), ['list-2']);
      expect((await todo('todo-full'))!.listId, 'list-1');
    });

    test('删除日记清掉待办的日记关联；删除待办只删那一条', () async {
      final rig = SyncApplyRig(a);
      await rig.applier.apply(
        await rig.planFor(
          const <SyncRecord>[],
          deletes: const [
            SyncKey(SyncEntity.diary, 'diary-rich'),
            SyncKey(SyncEntity.todo, 'todo-inbox'),
          ],
        ),
      );

      expect((await todo('todo-full'))!.linkedDiaryId, isNull);
      expect(await todo('todo-inbox'), isNull);
      expect(await a.db.select(a.db.todos).get(), hasLength(1));
    });

    test('规划之后用户又改了待办：前置条件不符，跳过这一条（不覆盖用户的编辑）', () async {
      final rig = SyncApplyRig(a);
      final records = await rig.records();
      final full = records[const SyncKey(SyncEntity.todo, 'todo-full')]!;
      final plan = await rig.planFor(<SyncRecord>[
        withFacet(full, SyncFacet.main, <String, Object?>{'title': 'Synced'}),
      ]);
      await a.db.customStatement(
        "UPDATE todos SET completed_at = 1700008000 WHERE todo_id = 'todo-full'",
      );
      final result = await rig.applier.apply(plan);

      expect(result.skipped.map((skip) => (skip.key, skip.reason)), [
        (full.key, SyncSkipReason.precondition),
      ]);
      final row = (await todo('todo-full'))!;
      expect(row.title, 'Buy milk');
      expect(row.completedAt, at(1700008000));
    });

    test('标题为空的坏记录记为 invalidRecord 跳过，其余照常写入', () async {
      final rig = SyncApplyRig(a);
      final records = await rig.records();
      final full = records[const SyncKey(SyncEntity.todo, 'todo-full')]!;
      final list = records[const SyncKey(SyncEntity.todoList, 'list-1')]!;
      final result = await rig.applier.apply(
        await rig.planFor(<SyncRecord>[
          withFacet(full, SyncFacet.main, <String, Object?>{'title': ''}),
          withFacet(list, SyncFacet.main, <String, Object?>{'name': 'Food'}),
        ]),
      );

      expect(result.skipped.map((skip) => (skip.key, skip.reason)), [
        (full.key, SyncSkipReason.invalidRecord),
      ]);
      expect((await todo('todo-full'))!.title, 'Buy milk');
      final renamed = await (a.db.select(
        a.db.todoLists,
      )..where((t) => t.listId.equals('list-1'))).getSingle();
      expect(renamed.name, 'Food');
    });
  });

  group('两台设备', () {
    late LanSyncTestDevice a;
    late LanSyncTestDevice b;

    setUp(() async {
      final clock = LanSyncTestClock();
      a = await LanSyncTestDevice.create('device-a', clock: clock);
      b = await LanSyncTestDevice.create('device-b', clock: clock);
      for (final device in [a, b]) {
        await device.db.customStatement(
          'INSERT INTO todo_lists (list_id, name, sort_order, created_at, '
          "updated_at) VALUES ('list-x', 'Trip', 0.0, 1700000000, 1700000000)",
        );
        await device.db.customStatement(
          'INSERT INTO todos (todo_id, list_id, title, sort_order, '
          "created_at, updated_at) VALUES ('t1', 'list-x', 'Passport', 1.0, "
          '1700000000, 1700000000)',
        );
      }
    });

    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    Future<void> converge(
      LanSyncTestDevice initiator,
      LanSyncTestDevice responder,
    ) async {
      final round = await runLanSyncRound(initiator, responder);
      expect(round.initiatorResult?.skipped ?? const [], isEmpty);
      expect(round.responderResult?.skipped ?? const [], isEmpty);
      expect(await a.canonical(), await b.canonical());
      expect((await planLanSyncRound(a, b)).isEmpty, isTrue);
      expect((await planLanSyncRound(b, a)).isEmpty, isTrue);
    }

    Future<Map<String, TodoRow>> todos(LanSyncTestDevice device) async => {
      for (final row in await device.db.select(device.db.todos).get())
        row.todoId: row,
    };

    test('一侧删清单（连同其中的待办），另一侧之后新加进清单的待办移到收集箱', () async {
      await converge(a, b);
      // 应用删清单：连同其中的待办一起删。
      await a.db.customStatement("DELETE FROM todos WHERE list_id = 'list-x'");
      await a.db.customStatement(
        "DELETE FROM todo_lists WHERE list_id = 'list-x'",
      );
      await b.db.customStatement(
        'INSERT INTO todos (todo_id, list_id, title, sort_order, created_at, '
        "updated_at) VALUES ('t2', 'list-x', 'Tickets', 2.0, 1700000100, "
        '1700000100)',
      );
      await converge(a, b);

      for (final device in [a, b]) {
        expect(await device.db.select(device.db.todoLists).get(), isEmpty);
        final rows = await todos(device);
        expect(rows.keys, ['t2']);
        expect(rows['t2']!.listId, isNull);
        expect(rows['t2']!.sortOrder, 2.0);
      }
    });

    test('两侧都改了同一条待办：整条取后改的一侧，两边一致', () async {
      await converge(a, b);
      await a.db.customStatement(
        "UPDATE todos SET completed_at = 1700000500, updated_at = 1700000500 "
        "WHERE todo_id = 't1'",
      );
      await b.db.customStatement(
        "UPDATE todos SET title = 'Passport + visa', sort_order = 0.5, "
        "updated_at = 1700000400 WHERE todo_id = 't1'",
      );
      await converge(b, a);

      for (final device in [a, b]) {
        final row = (await todos(device))['t1']!;
        // 真冲突按变化时间（历史头条的 seenAt）取一侧：整条记录取自同一侧，
        // 不会拼出两台都没有过的组合（既完成又改名）。
        final completed = row.completedAt != null;
        final renamed = row.title == 'Passport + visa';
        expect(completed != renamed, isTrue);
      }
    });
  });
}
