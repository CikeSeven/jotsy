import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/models/todo_view.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_groups.dart';

final DateTime _today = DateTime(2026, 11, 10);
var _nextId = 0;

TodoRow _todo(
  String title, {
  String? due,
  int? minute,
  String? listId,
  int priority = 0,
  DateTime? completedAt,
  DateTime? createdAt,
  double sortOrder = 0,
}) {
  final id = _nextId++;
  final created = createdAt ?? DateTime(2026, 11, 1, 0, id);
  return TodoRow(
    id: id,
    todoId: 'todo-$id',
    listId: listId,
    title: title,
    note: '',
    priority: priority,
    dueDate: due,
    dueMinute: minute,
    reminders: '[]',
    steps: '[]',
    completedAt: completedAt,
    sortOrder: sortOrder,
    metadata: '{}',
    createdAt: created,
    updatedAt: created,
  );
}

List<String> _titles(TodoGroup group) =>
    group.rows.map((r) => r.title).toList();

void main() {
  List<TodoGroup> groups(
    TodoView view, {
    List<TodoRow> open = const <TodoRow>[],
    List<TodoRow> completed = const <TodoRow>[],
    TodoSortMode sort = TodoSortMode.manual,
    bool showCompleted = true,
    List<String> listOrder = const <String>['work'],
  }) => buildTodoGroups(
    view: view,
    open: open,
    completed: completed,
    listOrder: listOrder,
    sort: sort,
    today: _today,
    showCompleted: showCompleted,
  );

  test('today splits overdue from today and orders by time', () {
    final result = groups(
      TodoView.today,
      open: <TodoRow>[
        _todo('later today', due: '2026-11-10', minute: 18 * 60),
        _todo('tomorrow', due: '2026-11-11'),
        _todo('last week', due: '2026-11-03'),
        _todo('all day', due: '2026-11-10'),
        _todo('no date'),
      ],
    );
    expect(result.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.overdue,
      TodoGroupKind.today,
    ]);
    expect(_titles(result[0]), <String>['last week']);
    expect(_titles(result[1]), <String>['all day', 'later today']);
  });

  test('planned buckets by time ranges', () {
    final result = groups(
      const TodoView.smart(TodoSmartView.planned),
      open: <TodoRow>[
        _todo('far', due: '2026-12-25'),
        _todo('week', due: '2026-11-15'),
        _todo('tomorrow', due: '2026-11-11'),
        _todo('none'),
      ],
    );
    expect(result.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.tomorrow,
      TodoGroupKind.nextDays,
      TodoGroupKind.later,
    ]);
  });

  test('all groups by list with the inbox first and dangling lists in it', () {
    final result = groups(
      const TodoView.smart(TodoSmartView.all),
      open: <TodoRow>[
        _todo('work item', listId: 'work'),
        _todo('inbox item'),
        _todo('orphan', listId: 'deleted-list'),
      ],
    );
    expect(result.map((g) => g.listId), <String?>[null, 'work']);
    expect(_titles(result[0]), <String>['inbox item', 'orphan']);
  });

  test('a list shows its completed at the bottom unless hidden', () {
    final open = <TodoRow>[_todo('open', listId: 'work'), _todo('elsewhere')];
    final completed = <TodoRow>[
      _todo('done', listId: 'work', completedAt: DateTime(2026, 11, 9)),
      _todo('done inbox', completedAt: DateTime(2026, 11, 9)),
    ];
    final shown = groups(
      const TodoView.list('work'),
      open: open,
      completed: completed,
    );
    expect(shown.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.plain,
      TodoGroupKind.completed,
    ]);
    expect(_titles(shown[1]), <String>['done']);
    final hidden = groups(
      const TodoView.list('work'),
      open: open,
      completed: completed,
      showCompleted: false,
    );
    expect(hidden.map((g) => g.kind), <TodoGroupKind>[TodoGroupKind.plain]);
  });

  test('completed groups by completion day, newest first', () {
    final result = groups(
      const TodoView.smart(TodoSmartView.completed),
      completed: <TodoRow>[
        _todo('b', completedAt: DateTime(2026, 11, 10, 9)),
        _todo('a', completedAt: DateTime(2026, 11, 10, 8)),
        _todo('c', completedAt: DateTime(2026, 11, 8)),
      ],
    );
    expect(result.map((g) => g.day), <DateTime>[
      DateTime(2026, 11, 10),
      DateTime(2026, 11, 8),
    ]);
    expect(_titles(result[0]), <String>['b', 'a']);
  });

  test('sort modes are stable and keep manual order on ties', () {
    final rows = <TodoRow>[
      _todo('low', priority: 1, due: '2026-11-20'),
      _todo('high late', priority: 3, due: '2026-11-30'),
      _todo('high soon', priority: 3, due: '2026-11-12'),
      _todo('none'),
    ];
    expect(
      sortTodoRows(rows, TodoSortMode.priority).map((r) => r.title),
      <String>['high soon', 'high late', 'low', 'none'],
    );
    expect(sortTodoRows(rows, TodoSortMode.due).map((r) => r.title), <String>[
      'high soon',
      'low',
      'high late',
      'none',
    ]);
    expect(sortTodoRows(rows, TodoSortMode.manual), rows);
  });

  test('smart view counts', () {
    final counts = todoSmartViewCounts(<TodoRow>[
      _todo('overdue', due: '2026-11-01', priority: 3),
      _todo('future', due: '2026-11-20', listId: 'work'),
      _todo('plain'),
    ], _today);
    expect(counts[TodoSmartView.today], 1);
    expect(counts[TodoSmartView.planned], 2);
    expect(counts[TodoSmartView.important], 1);
    expect(counts[TodoSmartView.all], 3);
    expect(counts[TodoSmartView.inbox], 2);
  });

  test('views parse their keys and know where new todos go', () {
    expect(
      TodoView.parse('planned'),
      const TodoView.smart(TodoSmartView.planned),
    );
    expect(TodoView.parse('list:abc'), const TodoView.list('abc'));
    expect(TodoView.parse('list:'), isNull);
    expect(TodoView.parse('bogus'), isNull);
    expect(TodoView.today.createListId('fallback'), 'fallback');
    expect(TodoView.inbox.createListId('fallback'), isNull);
    expect(const TodoView.list('x').createListId('fallback'), 'x');
  });

  test('settings decode tolerantly and drop the key at defaults', () {
    expect(TodoSettings.defaults.encode(), isNull);
    const custom = TodoSettings(
      showCompleted: false,
      defaultListId: 'work',
      sort: TodoSortMode.priority,
      defaultViewKey: 'list:work',
      allDayReminderMinute: 8 * 60,
      snoozeMinutes: 30,
      hideContentOnLockScreen: true,
    );
    expect(TodoSettings.decode(custom.encode()), custom);
    expect(
      TodoSettings.decode(
        '{"showCompleted":"no","sort":"weird","snoozeMinutes":7,'
        '"allDayReminderMinute":9999,"defaultView":"nope"}',
      ),
      TodoSettings.defaults,
    );
    expect(TodoSettings.decode('not json'), TodoSettings.defaults);
  });
}
