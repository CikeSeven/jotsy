import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway.dart';
import 'package:node_diary/core/services/todo_reminders/todo_reminder_planner.dart';

var _nextId = 0;

TodoRow _todo({
  String title = 't',
  String? due,
  int? minute,
  List<TodoReminder> reminders = const <TodoReminder>[],
  TodoRepeatRule? repeat,
  DateTime? snoozedUntil,
  DateTime? completedAt,
  int repeatDone = 0,
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
    reminders: encodeTodoReminders(reminders),
    repeat: encodeTodoRepeat(repeat),
    steps: '[]',
    completedAt: completedAt,
    snoozedUntil: snoozedUntil,
    sortOrder: 0,
    metadata: repeatDone == 0 ? '{}' : '{"repeatDone":$repeatDone}',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  final now = DateTime(2026, 11, 10, 8);

  test(
    'timed reminders fire relative to the due time; past ones are skipped',
    () {
      final plan = planTodoReminders(
        now: now,
        todos: <TodoRow>[
          _todo(
            due: '2026-11-10',
            minute: 9 * 60,
            reminders: const <TodoReminder>[
              TodoReminder.beforeDue(0),
              TodoReminder.beforeDue(15),
              TodoReminder.beforeDue(24 * 60),
            ],
          ),
        ],
      );
      expect(plan.map((r) => r.fireAt), <DateTime>[
        DateTime(2026, 11, 10, 8, 45),
        DateTime(2026, 11, 10, 9),
      ]);
    },
  );

  test('all-day todos ignore before-due reminders and use on-day times', () {
    final plan = planTodoReminders(
      now: now,
      todos: <TodoRow>[
        _todo(
          due: '2026-11-12',
          reminders: const <TodoReminder>[
            TodoReminder.beforeDue(15),
            TodoReminder.onDay(days: -1, minute: 20 * 60),
            TodoReminder.onDay(days: 0, minute: 9 * 60),
          ],
        ),
      ],
    );
    expect(plan.map((r) => r.fireAt), <DateTime>[
      DateTime(2026, 11, 11, 20),
      DateTime(2026, 11, 12, 9),
    ]);
    expect(plan.first.dueMinute, isNull);
  });

  test('repeating todos expand within the horizon and respect the count', () {
    final rule = TodoRepeatRule(
      frequency: TodoRepeatFrequency.daily,
      anchor: DateTime(2026, 11, 10),
      count: 5,
    );
    final plan = planTodoReminders(
      now: now,
      todos: <TodoRow>[
        _todo(
          due: '2026-11-10',
          minute: 21 * 60,
          reminders: const <TodoReminder>[TodoReminder.beforeDue(0)],
          repeat: rule,
          repeatDone: 2,
        ),
      ],
    );
    // 一共 5 次、已完成 2 次：当前这次加后面 2 次。
    expect(plan.map((r) => r.occurrence), <DateTime>[
      DateTime(2026, 11, 10),
      DateTime(2026, 11, 11),
      DateTime(2026, 11, 12),
    ]);
  });

  test(
    'snooze is planned even without a due date; completed todos are not',
    () {
      final snoozed = DateTime(2026, 11, 10, 8, 10);
      final plan = planTodoReminders(
        now: now,
        todos: <TodoRow>[
          _todo(title: 'snoozed', snoozedUntil: snoozed),
          _todo(
            title: 'done',
            due: '2026-11-10',
            minute: 12 * 60,
            reminders: const <TodoReminder>[TodoReminder.beforeDue(0)],
            completedAt: DateTime(2026, 11, 9),
          ),
        ],
      );
      expect(plan.single.title, 'snoozed');
      expect(plan.single.snooze, isTrue);
      expect(plan.single.fireAt, snoozed);
    },
  );

  test('the horizon and the limit cap the plan, earliest first', () {
    final todos = <TodoRow>[
      for (var day = 11; day <= 30; day++)
        _todo(
          due: '2026-11-$day',
          minute: 9 * 60,
          reminders: const <TodoReminder>[TodoReminder.beforeDue(0)],
        ),
      _todo(
        due: '2027-03-01',
        minute: 9 * 60,
        reminders: const <TodoReminder>[TodoReminder.beforeDue(0)],
      ),
    ];
    final plan = planTodoReminders(now: now, todos: todos, limit: 5);
    expect(plan, hasLength(5));
    expect(plan.first.occurrence, DateTime(2026, 11, 11));
    expect(
      planTodoReminders(now: now, todos: todos).length,
      20,
      reason: '30 天外的不排',
    );
  });

  test('ids are stable and payloads round-trip with extras', () {
    final fireAt = DateTime(2026, 11, 10, 9);
    expect(
      todoReminderNotificationId('a', fireAt),
      todoReminderNotificationId('a', fireAt),
    );
    expect(
      todoReminderNotificationId('a', fireAt),
      isNot(todoReminderNotificationId('b', fireAt)),
    );
    final reminder = PlannedReminder(
      id: 1,
      todoId: 'todo-x',
      title: 'x',
      occurrence: DateTime(2026, 11, 10),
      dueMinute: 540,
      fireAt: fireAt,
    );
    final request = TodoNotificationRequest(
      reminder: reminder,
      body: 'b',
      languageCode: 'zh',
      snoozeMinutes: 15,
      hideOnLockScreen: true,
    );
    final decoded = decodeTodoReminderPayload(request.payload)!;
    expect(decoded.todoId, 'todo-x');
    expect(decoded.occurrence, '2026-11-10');
    final extras = decodeTodoNotificationExtras(request.payload)!;
    expect(extras.languageCode, 'zh');
    expect(extras.hide, isTrue);
    expect(decodeTodoReminderPayload('other:{}'), isNull);
  });

  test('notification responses map to events', () {
    const payload = 'todo:{"t":"id1","o":"2026-11-10"}';
    expect(
      TodoNotificationEvent.fromResponse(
        actionId: null,
        payload: payload,
      )!.action,
      TodoNotificationAction.open,
    );
    expect(
      TodoNotificationEvent.fromResponse(
        actionId: kTodoCompleteActionId,
        payload: payload,
      )!.action,
      TodoNotificationAction.complete,
    );
    final snooze = TodoNotificationEvent.fromResponse(
      actionId: todoNotificationActionId(30),
      payload: payload,
    )!;
    expect(snooze.action, TodoNotificationAction.snooze);
    expect(snooze.snoozeMinutes, 30);
    expect(
      TodoNotificationEvent.fromResponse(actionId: null, payload: 'x'),
      isNull,
    );
  });
}
