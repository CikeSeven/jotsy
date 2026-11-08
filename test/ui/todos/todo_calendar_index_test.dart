import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/diary_todo_items.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_calendar_index.dart';

var _nextId = 0;

TodoRow _todo(
  String title, {
  String? due,
  int? minute,
  TodoRepeatRule? repeat,
  DateTime? completedAt,
}) {
  final id = _nextId++;
  return TodoRow(
    id: id,
    todoId: 'todo-$id',
    title: title,
    note: '',
    priority: 0,
    dueDate: due,
    dueMinute: minute,
    reminders: '[]',
    repeat: encodeTodoRepeat(repeat),
    steps: '[]',
    completedAt: completedAt,
    sortOrder: 0,
    metadata: '{}',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  final today = DateTime(2026, 11, 10);

  test('open, completed and projected repeats land on their days', () {
    final index = TodoCalendarIndex.build(
      today: today,
      open: <TodoRow>[
        _todo('timed', due: '2026-11-10', minute: 15 * 60),
        _todo('all day', due: '2026-11-10'),
        _todo(
          'weekly',
          due: '2026-11-11',
          repeat: TodoRepeatRule(
            frequency: TodoRepeatFrequency.weekly,
            anchor: DateTime(2026, 11, 11),
            count: 3,
          ),
        ),
        _todo('undated'),
      ],
      completed: <TodoRow>[
        _todo('done', due: '2026-11-10', completedAt: today),
      ],
    );
    expect(index.entriesOn(today).map((e) => e.row.title), <String>[
      'all day',
      'timed',
      'done',
    ]);
    expect(index.hasOpenOn(today), isTrue);
    final weekly = index.entriesOn(DateTime(2026, 11, 18)).single;
    expect(weekly.projected, isTrue);
    expect(index.entriesOn(DateTime(2026, 11, 11)).single.projected, isFalse);
    expect(index.entriesOn(DateTime(2026, 11, 25)), hasLength(1));
    expect(index.entriesOn(DateTime(2026, 12, 2)), isEmpty, reason: '一共 3 次');
    expect(index.hasOpenOn(DateTime(2026, 11, 12)), isFalse);
  });

  test('a day with only completed to-dos has no open mark', () {
    final index = TodoCalendarIndex.build(
      today: today,
      open: const <TodoRow>[],
      completed: <TodoRow>[
        _todo('done', due: '2026-11-09', completedAt: today),
      ],
    );
    expect(index.entriesOn(DateTime(2026, 11, 9)), hasLength(1));
    expect(index.hasOpenOn(DateTime(2026, 11, 9)), isFalse);
  });

  test('checklist items are read from a diary body in document order', () {
    final body = jsonEncode(<String, Object?>{
      'document': <String, Object?>{
        'type': 'page',
        'children': <Object?>[
          <String, Object?>{
            'type': 'todo_list',
            'data': <String, Object?>{
              'checked': false,
              'delta': <Object?>[
                <String, Object?>{'insert': '买菜'},
              ],
            },
          },
          <String, Object?>{
            'type': 'paragraph',
            'data': <String, Object?>{
              'delta': <Object?>[
                <String, Object?>{'insert': '普通段落'},
              ],
            },
          },
          <String, Object?>{
            'type': 'todo_list',
            'data': <String, Object?>{
              'checked': true,
              'delta': <Object?>[
                <String, Object?>{'insert': '洗碗'},
              ],
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'todo_list',
                'data': <String, Object?>{
                  'delta': <Object?>[
                    <String, Object?>{'insert': '  擦桌子 '},
                  ],
                },
              },
            ],
          },
          <String, Object?>{
            'type': 'todo_list',
            'data': <String, Object?>{
              'delta': <Object?>[
                <String, Object?>{'insert': '   '},
              ],
            },
          },
        ],
      },
    });
    final items = diaryTodoItems(body);
    expect(items.map((i) => (i.text, i.checked)), <(String, bool)>[
      ('买菜', false),
      ('洗碗', true),
      ('擦桌子', false),
    ]);
    expect(diaryTodoItems('纯文本日记'), isEmpty);
  });
}
