import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_agenda.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_calendar_index.dart';

final _day = DateTime(2026, 11, 26);

TodoCalendarEntry _todo(
  String id, {
  int? minute,
  bool done = false,
  bool projected = false,
}) => TodoCalendarEntry(
  row: TodoRow(
    id: id.hashCode,
    todoId: id,
    title: id,
    note: '',
    priority: 0,
    dueDate: formatAnniversaryDate(_day),
    dueMinute: minute,
    reminders: '[]',
    steps: '[]',
    completedAt: done ? _day : null,
    sortOrder: 0,
    metadata: '{}',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  occurrence: _day,
  projected: projected,
);

DiaryWithTags _diary(String id, int hour, int minute) => DiaryWithTags(
  diary: Diary(
    id: id.hashCode,
    diaryId: id,
    title: id,
    content: '[]',
    contentText: '',
    metadata: '{}',
    createdAt: DateTime(2026, 11, 26, hour, minute),
    updatedAt: DateTime(2026, 11, 26, hour, minute),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[],
);

/// 时间线的每一条写成 id，方便比顺序。
List<String> _timedIds(CalendarDayAgenda agenda) => <String>[
  for (final item in agenda.timed)
    switch (item) {
      CalendarAgendaDiary(:final diary) => diary.diary.diaryId,
      CalendarAgendaTodo(:final entry) => entry.row.todoId,
    },
];

void main() {
  test('all-day to-dos come first and timed items interleave by minute', () {
    final agenda = CalendarDayAgenda.build(
      diaries: <DiaryWithTags>[
        _diary('morning', 8, 12),
        _diary('afternoon', 13, 40),
        _diary('night', 21, 5),
      ],
      todos: <TodoCalendarEntry>[
        _todo('all-day open'),
        _todo('meeting', minute: 14 * 60),
        _todo('all-day done', done: true),
        // 已完成的定时待办留在原来的时刻，不挪到最后。
        _todo('done call', minute: 9 * 60, done: true),
      ],
    );

    expect(agenda.allDay.map((entry) => entry.row.todoId), <String>[
      'all-day open',
      'all-day done',
    ]);
    expect(_timedIds(agenda), <String>[
      'morning',
      'done call',
      'afternoon',
      'meeting',
      'night',
    ]);
    expect(agenda.overdue, isEmpty);
    expect(agenda.hasDiaries, isTrue);
    expect(agenda.hasTodos, isTrue);
  });

  test('a diary and a to-do at the same minute keep the diary first', () {
    final agenda = CalendarDayAgenda.build(
      diaries: <DiaryWithTags>[_diary('note', 9, 0)],
      todos: <TodoCalendarEntry>[_todo('standup', minute: 9 * 60)],
    );
    expect(_timedIds(agenda), <String>['note', 'standup']);
  });

  test('an overdue repeat is not listed again as today\'s projection', () {
    final late = _todo('daily');
    final agenda = CalendarDayAgenda.build(
      diaries: const <DiaryWithTags>[],
      todos: <TodoCalendarEntry>[
        _todo('daily', projected: true),
        _todo('fresh', minute: 10 * 60),
      ],
      overdue: <TodoCalendarEntry>[late],
    );

    expect(agenda.overdue.single.row.todoId, 'daily');
    expect(agenda.allDay, isEmpty);
    expect(_timedIds(agenda), <String>['fresh']);
    expect(agenda.hasDiaries, isFalse);
  });

  test('without to-dos the agenda is the diaries in order', () {
    final agenda = CalendarDayAgenda.build(
      diaries: <DiaryWithTags>[_diary('a', 7, 0), _diary('b', 7, 30)],
    );
    expect(_timedIds(agenda), <String>['a', 'b']);
    expect(agenda.hasTodos, isFalse);
    expect(
      CalendarDayAgenda.build(diaries: const <DiaryWithTags>[]).isEmpty,
      isTrue,
    );
  });
}
