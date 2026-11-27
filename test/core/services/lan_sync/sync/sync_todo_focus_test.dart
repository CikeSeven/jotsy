import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_todo_focus.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import '../../../../support/lan_sync_two_devices.dart';

/// 专注记录的同步（格式版本 6）：规范记录往返；两台设备各自记下的专注取
/// 并集；删掉待办后专注记录与它的 `todoId` 原样保留（不置空）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(EditingSessionRegistry.instance.debugReset);

  test('the canonical record round-trips the columns', () {
    const row = SyncRawTodoFocus(
      localId: 7,
      sessionId: 'f1',
      todoId: 't1',
      startedAt: 1700000000,
      endedAt: 1700001500,
      plannedSeconds: 1500,
      focusedSeconds: 1440,
      outcome: 'completed',
      metadata: '{"x":1}',
    );
    final record = syncTodoFocusRecord(row);
    expect(record.key, const SyncKey(SyncEntity.todoFocus, 'f1'));
    final columns = SyncTodoFocusColumns.fromRecord(record);
    expect(columns.sessionId, 'f1');
    expect(columns.todoId, 't1');
    expect(columns.startedAt.millisecondsSinceEpoch, 1700000000 * 1000);
    expect(columns.plannedSeconds, 1500);
    expect(columns.focusedSeconds, 1440);
    expect(columns.metadata, '{"x":1}');
    expect(
      () => SyncTodoFocusColumns.fromRecord(
        SyncRecord(record.key, <String, Object?>{
          SyncFacet.main: <String, Object?>{
            ...(record.facets[SyncFacet.main]! as Map).cast<String, Object?>(),
            'focusedSeconds': -1,
          },
        }),
      ),
      throwsFormatException,
    );
  });

  group('两台设备', () {
    late LanSyncTestDevice a;
    late LanSyncTestDevice b;

    setUp(() async {
      final clock = LanSyncTestClock();
      a = await LanSyncTestDevice.create('focus-a', clock: clock);
      b = await LanSyncTestDevice.create('focus-b', clock: clock);
      for (final device in [a, b]) {
        await device.db.customStatement(
          'INSERT INTO todos (todo_id, title, sort_order, created_at, '
          "updated_at) VALUES ('t1', 'Write report', 1.0, 1700000000, "
          '1700000000)',
        );
      }
    });

    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    Future<void> converge() async {
      final round = await runLanSyncRound(a, b);
      expect(round.initiatorResult?.skipped ?? const [], isEmpty);
      expect(round.responderResult?.skipped ?? const [], isEmpty);
      expect(await a.canonical(), await b.canonical());
      expect((await planLanSyncRound(a, b)).isEmpty, isTrue);
    }

    Future<Map<String, TodoFocusRow>> sessions(LanSyncTestDevice d) async => {
      for (final row in await d.db.select(d.db.todoFocusSessions).get())
        row.sessionId: row,
    };

    Future<String> focus(LanSyncTestDevice d, {String? todoId}) async =>
        (await d.db.addTodoFocusSession(
          TodoFocusInput(
            todoId: todoId,
            startedAt: DateTime(2026, 11, 28, 9),
            endedAt: DateTime(2026, 11, 28, 9, 25),
            plannedSeconds: 1500,
            focusedSeconds: 1500,
            outcome: TodoFocusOutcome.completed,
          ),
        ))!;

    test('sessions recorded on both sides are unioned', () async {
      await converge();
      final fromA = await focus(a, todoId: 't1');
      final fromB = await focus(b);
      await converge();
      for (final device in [a, b]) {
        final rows = await sessions(device);
        expect(rows.keys, unorderedEquals(<String>[fromA, fromB]));
        expect(rows[fromA]!.todoId, 't1');
        expect(rows[fromB]!.todoId, isNull);
      }
    });

    test('deleting the to-do keeps its sessions and their link', () async {
      final id = await focus(a, todoId: 't1');
      await converge();
      await b.db.deleteTodo('t1');
      await converge();
      for (final device in [a, b]) {
        expect(await device.db.getTodo('t1'), isNull);
        expect((await sessions(device))[id]!.todoId, 't1');
      }
    });
  });
}
