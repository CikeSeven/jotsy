import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/controllers/todo_reorder.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_groups.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_list_entries.dart';

TodoRow _todo(String id) {
  final created = DateTime(2026, 11, 1);
  return TodoRow(
    id: id.hashCode,
    todoId: id,
    title: id,
    note: '',
    priority: 0,
    reminders: '[]',
    steps: '[]',
    sortOrder: 0,
    metadata: '{}',
    createdAt: created,
    updatedAt: created,
  );
}

/// 列表拍平成列表项（键与分组）以及拖动松手后的本地顺序。
void main() {
  group('buildTodoListEntries', () {
    test('headers, gaps and rows keep one key per todo across groups', () {
      final a = _todo('a');
      final b = _todo('b');
      final c = _todo('c');
      final entries = buildTodoListEntries(<TodoGroup>[
        TodoGroup(kind: TodoGroupKind.today, rows: <TodoRow>[a]),
        TodoGroup(kind: TodoGroupKind.plain, rows: <TodoRow>[b]),
        TodoGroup(kind: TodoGroupKind.completedToday, rows: <TodoRow>[c]),
      ]);
      expect(entries.map((entry) => entry.key), <String>[
        'h:today',
        'r:a',
        'g:plain',
        'r:b',
        // 可折叠的已完成组不出标题（由已完成区块画），只出行。
        'r:c',
      ]);
      expect(entries.last.inDoneSection, isTrue);
      expect(entries.first.inDoneSection, isFalse);
      // 同一条待办换了组键不变：数据变化动效按它滑过去。
      expect(
        TodoRowEntry(
          const TodoGroup(kind: TodoGroupKind.tomorrow, rows: <TodoRow>[]),
          a,
        ).key,
        entries[1].key,
      );
    });
  });

  group('TodoReorder local order', () {
    test('applies the dropped order until the database catches up', () {
      final reorder = TodoReorder(onChanged: () {});
      final a = _todo('a');
      final b = _todo('b');
      final c = _todo('c');
      final x = _todo('x');
      final before = <TodoRow>[a, b, c, x];
      expect(reorder.apply(before), same(before));

      // 只动属于本地顺序的行，别的行（x）留在原位。
      reorder.drop(
        _NoWriteDatabase.instance,
        <TodoRow>[a, b, c],
        0,
        2,
        readOpen: () => <TodoRow>[a, b, c],
      );
      expect(reorder.order, <String>['b', 'c', 'a']);
      expect(reorder.apply(before).map((row) => row.todoId), <String>[
        'b',
        'c',
        'a',
        'x',
      ]);

      // 推送来的还是旧顺序：留着本地顺序。
      reorder.settle(before);
      expect(reorder.order, isNotNull);

      // 库里已是新顺序：撤掉，以库为准。
      reorder.settle(<TodoRow>[b, c, a, x]);
      expect(reorder.order, isNull);
    });
  });
}

/// 不真的写库：本组测试只看本地顺序。
class _NoWriteDatabase implements AppDatabase {
  _NoWriteDatabase._();

  static final _NoWriteDatabase instance = _NoWriteDatabase._();

  @override
  Future<void> moveTodo(String todoId, {String? aboveId, String? belowId}) =>
      Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
