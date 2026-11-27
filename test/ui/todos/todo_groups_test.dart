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

  test('planned groups each day within a week, then later', () {
    final result = groups(
      const TodoView.smart(TodoSmartView.planned),
      open: <TodoRow>[
        _todo('far', due: '2026-12-25'),
        _todo('sunday', due: '2026-11-15'),
        _todo('friday', due: '2026-11-13'),
        _todo('friday too', due: '2026-11-13'),
        _todo('tomorrow', due: '2026-11-11'),
        _todo('none'),
      ],
    );
    expect(result.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.tomorrow,
      TodoGroupKind.day,
      TodoGroupKind.day,
      TodoGroupKind.later,
    ]);
    expect(result[1].day, DateTime(2026, 11, 13));
    expect(_titles(result[1]), hasLength(2));
    expect(result[2].day, DateTime(2026, 11, 15));
    // 每天一组的键各不相同（折叠与动效按它对应）。
    expect(result[1].key, isNot(result[2].key));
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
    expect(TodoSettings.defaults.sort, TodoSortMode.priority);
    const custom = TodoSettings(
      showCompleted: false,
      defaultListId: 'work',
      sort: TodoSortMode.manual,
      defaultViewKey: 'list:work',
      allDayReminderMinute: 8 * 60,
      snoozeMinutes: 30,
      hideContentOnLockScreen: true,
      smartParse: false,
      swipeLeft: TodoSwipeAction.reschedule,
    );
    expect(TodoSettings.decode(custom.encode()), custom);
    expect(
      TodoSettings.decode('{"swipeLeft":"archive"}').swipeLeft,
      TodoSwipeAction.delete,
      reason: '认不出的左滑动作退回删除',
    );
    expect(
      TodoSettings.decode('{"smartParse":"off"}').smartParse,
      isTrue,
      reason: '认不出的值退回默认（开）',
    );
    expect(
      TodoSettings.decode(
        '{"showCompleted":"no","sort":"weird","snoozeMinutes":7,'
        '"allDayReminderMinute":9999,"defaultView":"nope"}',
      ),
      TodoSettings.defaults,
    );
    expect(TodoSettings.decode('not json'), TodoSettings.defaults);
  });

  test('the daily digest time is kept only when it is on and valid', () {
    const on = TodoSettings(digestMinute: 7 * 60 + 30);
    expect(TodoSettings.decode(on.encode()).digestMinute, 7 * 60 + 30);
    expect(
      on.copyWith(clearDigest: true),
      TodoSettings.defaults,
      reason: '关掉后回到默认、设置键可以移除',
    );
    const other = TodoSettings(snoozeMinutes: 30);
    expect(
      other.encode(),
      isNot(contains('digestMinute')),
      reason: '关着时不写，旧设置升级后逐字节不变',
    );
    expect(TodoSettings.decode('{"digestMinute":1440}').digestMinute, isNull);
    expect(TodoSettings.decode('{"digestMinute":"8:00"}').digestMinute, isNull);
  });

  test('sort moves old implicit manual to priority but keeps real choices', () {
    TodoSortMode sortOf(String raw) => TodoSettings.decode(raw).sort;
    // 旧版本顺带写出的默认值“手动”当作没选，换成新的默认值。
    expect(
      sortOf('{"showCompleted":false,"sort":"manual"}'),
      TodoSortMode.priority,
    );
    // 旧版本里主动选过的其他排序保留。
    expect(sortOf('{"sort":"due"}'), TodoSortMode.due);
    expect(sortOf('{"sort":"created"}'), TodoSortMode.created);
    // 新字段里的“手动”是新版本里选的，记住它，也优先于旧字段。
    expect(sortOf('{"sortMode":"manual","sort":"due"}'), TodoSortMode.manual);
    expect(sortOf('{"sortMode":"weird","sort":"due"}'), TodoSortMode.due);
    final manual = TodoSettings.defaults.copyWith(sort: TodoSortMode.manual);
    expect(manual.encode(), contains('"sortMode":"manual"'));
    expect(manual.encode(), isNot(contains('"sort":')));
    expect(TodoSettings.decode(manual.encode()).sort, TodoSortMode.manual);
  });

  test('default sort puts higher priority first within a day', () {
    final result = groups(
      TodoView.today,
      sort: TodoSettings.defaults.sort,
      open: <TodoRow>[
        _todo('none early', due: '2026-11-10', minute: 8 * 60),
        _todo('low', due: '2026-11-10', priority: 1),
        _todo('high late', due: '2026-11-10', minute: 20 * 60, priority: 3),
        _todo('high early', due: '2026-11-10', minute: 9 * 60, priority: 3),
        _todo('overdue medium', due: '2026-11-09', priority: 2),
      ],
    );
    expect(result.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.overdue,
      TodoGroupKind.today,
    ]);
    expect(_titles(result.last), <String>[
      'high early',
      'high late',
      'low',
      'none early',
    ]);
  });

  test('today ends with what was completed today unless hidden', () {
    final open = <TodoRow>[_todo('今天的', due: '2026-11-10')];
    final completed = <TodoRow>[
      _todo('刚做完', due: '2026-11-10', completedAt: DateTime(2026, 11, 10, 9)),
      _todo('昨天做完', due: '2026-11-09', completedAt: DateTime(2026, 11, 9, 22)),
    ];
    final shown = groups(TodoView.today, open: open, completed: completed);
    expect(shown.map((g) => g.kind), <TodoGroupKind>[
      TodoGroupKind.today,
      TodoGroupKind.completedToday,
    ]);
    expect(_titles(shown.last), <String>['刚做完']);
    expect(
      groups(
        TodoView.today,
        open: open,
        completed: completed,
        showCompleted: false,
      ).map((g) => g.kind),
      <TodoGroupKind>[TodoGroupKind.today],
    );
    // 今天什么都没有、也没做完什么时没有任何一组。
    expect(
      groups(TodoView.today, completed: <TodoRow>[completed.last]),
      isEmpty,
    );
  });

  test('today summary counts remaining, overdue and done today', () {
    final summary = todoTodaySummary(
      <TodoRow>[
        _todo('逾期', due: '2026-11-08'),
        _todo('今天', due: '2026-11-10'),
        _todo('明天', due: '2026-11-11'),
        _todo('没日期'),
      ],
      <TodoRow>[
        _todo('做完', completedAt: DateTime(2026, 11, 10, 8)),
        _todo('昨天做完', completedAt: DateTime(2026, 11, 9, 8)),
      ],
      _today,
    );
    expect(summary.remaining, 2);
    expect(summary.overdue, 1);
    expect(summary.doneToday, 1);
    expect(summary.total, 3);
    expect(summary.fraction, closeTo(1 / 3, 1e-9));
    expect(
      todoTodaySummary(const <TodoRow>[], const <TodoRow>[], _today).fraction,
      0,
    );
  });
}
