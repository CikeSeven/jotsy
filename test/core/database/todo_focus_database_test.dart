import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 专注记录的读写：太短的不记、时长规整、按待办累计、按开始时刻取一段；
/// 删除待办（含撤销）不动专注记录。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  TodoFocusInput input({
    String? todoId = 't1',
    DateTime? startedAt,
    int planned = 1500,
    int focused = 1500,
  }) {
    final start = startedAt ?? DateTime(2026, 11, 28, 9);
    return TodoFocusInput(
      todoId: todoId,
      startedAt: start,
      endedAt: start.add(Duration(seconds: focused)),
      plannedSeconds: planned,
      focusedSeconds: focused,
      outcome: TodoFocusOutcome.completed,
    );
  }

  test('short sessions are not recorded; seconds are clamped', () async {
    expect(await db.addTodoFocusSession(input(focused: 30)), isNull);
    final id = await db.addTodoFocusSession(input(planned: 600, focused: 900));
    final row = await (db.select(
      db.todoFocusSessions,
    )..where((t) => t.sessionId.equals(id!))).getSingle();
    expect(row.plannedSeconds, 600);
    expect(row.focusedSeconds, 600, reason: '不超过计划时长');
    expect(TodoFocusOutcome.of(row.outcome), TodoFocusOutcome.completed);
    expect(TodoFocusOutcome.of('??'), TodoFocusOutcome.stopped);
  });

  test('totals per to-do and sessions since a moment', () async {
    await db.addTodoFocusSession(input(focused: 1500));
    await db.addTodoFocusSession(input(focused: 600));
    await db.addTodoFocusSession(input(todoId: 't2', focused: 300));
    await db.addTodoFocusSession(
      input(startedAt: DateTime(2026, 11, 20), focused: 120),
    );
    expect(await db.watchTodoFocusSeconds('t1').first, 2220);
    expect(await db.watchTodoFocusSeconds('none').first, 0);
    final recent = await db.watchTodoFocusSince(DateTime(2026, 11, 27)).first;
    expect(recent.map((row) => row.focusedSeconds), <int>[1500, 600, 300]);
  });

  test(
    'deleting a to-do leaves its sessions; undo brings totals back',
    () async {
      final id = await db.createTodo(const TodoInput(title: '写报告'));
      await db.addTodoFocusSession(input(todoId: id));
      final deleted = await db.deleteTodo(id);
      expect(await db.watchTodoFocusSeconds(id).first, 1500);
      await db.restoreTodos(<TodoRow>[deleted!]);
      expect((await db.getTodo(id))!.title, '写报告');
      expect(await db.watchTodoFocusSeconds(id).first, 1500);
    },
  );
}
