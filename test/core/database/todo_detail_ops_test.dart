import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 详情页的整理操作：推迟次数、步骤转为独立待办、备注清单行转步骤与重复
/// 待办的完成记录。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<TodoRow> rowOf(String id) async => (await db.getTodo(id))!;

  group('postpone count', () {
    test('counts only pushing an open todo to a later day', () async {
      final id = await db.createTodo(
        TodoInput(title: '交报告', dueDate: DateTime(2026, 11, 10)),
      );
      final none = await db.createTodo(const TodoInput(title: '没日期'));

      await db.setTodoDue(id, date: DateTime(2026, 11, 12));
      expect(todoPostponeCount(await rowOf(id)), 1);
      // 同一天只换时刻、改早都不算。
      await db.setTodoDue(id, date: DateTime(2026, 11, 12), minute: 600);
      await db.setTodoDue(id, date: DateTime(2026, 11, 11));
      expect(todoPostponeCount(await rowOf(id)), 1);
      // 批量改期同样计数；第一次设日期不算。
      await db.setTodosDue(<String>[id, none], date: DateTime(2026, 11, 20));
      expect(todoPostponeCount(await rowOf(id)), 2);
      expect(todoPostponeCount(await rowOf(none)), 0);
      // 别的 metadata 键原样保留。
      final source = await db.createTodo(
        TodoInput(
          title: '从日记来',
          dueDate: DateTime(2026, 11, 1),
          sourceDiaryId: 'diary-1',
        ),
      );
      await db.setTodoDue(source, date: DateTime(2026, 11, 3));
      final metadata = decodeTodoMetadata((await rowOf(source)).metadata);
      expect(metadata[TodoMetadataKeys.sourceDiaryId], 'diary-1');
      expect(metadata[TodoMetadataKeys.postponeCount], 1);
    });
  });

  group('step to todo', () {
    test('moves the step out into its own todo in the same list', () async {
      final listId = await db.createTodoList(name: '家');
      final id = await db.createTodo(
        TodoInput(
          title: '搬家',
          listId: listId,
          steps: const <TodoStep>[
            TodoStep(id: 's0', title: '打包'),
            TodoStep(id: 's1', title: '退押金', done: true),
          ],
        ),
      );
      final open = await db.convertTodoStepToTodo(id, 's0');
      final done = await db.convertTodoStepToTodo(id, 's1');
      expect(await db.convertTodoStepToTodo(id, 'missing'), isNull);

      expect(decodeTodoSteps((await rowOf(id)).steps), isEmpty);
      final openRow = await rowOf(open!);
      expect(openRow.title, '打包');
      expect(openRow.listId, listId);
      expect(openRow.completedAt, isNull);
      expect((await rowOf(done!)).completedAt, isNotNull);
    });
  });

  group('note checklist', () {
    test('splits checklist lines out of the note', () {
      final split = splitTodoNoteChecklist(
        '先看看\n- [ ] 买菜\n* [x] 订票\n[ ] 打电话\n- [ ]   \n结尾',
      );
      expect(split.note, '先看看\n- [ ]   \n结尾');
      expect(split.steps.map((s) => (s.title, s.done)), <(String, bool)>[
        ('买菜', false),
        ('订票', true),
        ('打电话', false),
      ]);
      expect(splitTodoNoteChecklist('没有清单').steps, isEmpty);
    });

    test('moves checklist lines to the end of the steps', () async {
      final id = await db.createTodo(
        const TodoInput(
          title: '周末',
          note: '记得：\n- [ ] 洗车\n- [x] 加油',
          steps: <TodoStep>[TodoStep(id: 's0', title: '已有')],
        ),
      );
      expect(await db.moveTodoNoteChecklistToSteps(id), 2);
      final row = await rowOf(id);
      expect(row.note, '记得：');
      expect(
        decodeTodoSteps(row.steps).map((s) => (s.title, s.done)),
        <(String, bool)>[('已有', false), ('洗车', false), ('加油', true)],
      );
      expect(await db.moveTodoNoteChecklistToSteps(id), 0);
    });
  });

  test('occurrences of a repeating todo are its completed copies', () async {
    final id = await db.createTodo(
      TodoInput(
        title: '浇花',
        dueDate: DateTime(2026, 11, 2),
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.weekly,
          anchor: DateTime(2026, 11, 2),
        ),
      ),
    );
    final other = await db.createTodo(
      TodoInput(
        title: '别的',
        dueDate: DateTime(2026, 11, 2),
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.daily,
          anchor: DateTime(2026, 11, 2),
        ),
      ),
    );
    await db.completeTodo(id, now: DateTime(2026, 11, 2, 9));
    await db.completeTodo(id, now: DateTime(2026, 11, 9, 9));
    await db.completeTodo(other, now: DateTime(2026, 11, 2, 9));
    final rows = await db.watchTodoOccurrences(id).first;
    expect(rows, hasLength(2));
    expect(rows.first.dueDate, '2026-11-09');
    expect(await db.watchTodoOccurrences(other).first, hasLength(1));
  });
}
