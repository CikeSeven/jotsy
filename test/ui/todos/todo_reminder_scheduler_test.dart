import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_actions.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway.dart';
import 'package:node_diary/ui/todos/controllers/todo_reminder_scheduler.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';

import '../../support/fake_todo_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTodoNotificationGateway gateway;
  late TodoReminderScheduler scheduler;
  final opened = <String>[];
  // 固定的“现在”：明天 9 点的提醒总在窗口里。
  final now = DateTime(2026, 11, 10, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeTodoNotificationGateway();
    opened.clear();
    scheduler = TodoReminderScheduler(
      gateway: gateway,
      database: db,
      onOpen: opened.add,
      now: () => now,
    )..locale = const Locale('zh');
  });
  tearDown(() async {
    scheduler.dispose();
    await db.close();
  });

  Future<void> feed() async {
    scheduler.todos = await db.getOpenTodos();
    await scheduler.replanNow();
  }

  Future<String> addTodo({
    String title = '交周报',
    List<TodoReminder> reminders = const <TodoReminder>[
      TodoReminder.beforeDue(15),
    ],
  }) => db.createTodo(
    TodoInput(
      title: title,
      dueDate: DateTime(2026, 11, 11),
      dueMinute: 9 * 60,
      reminders: reminders,
    ),
  );

  test(
    'enabling schedules the planned reminders with a due-time body',
    () async {
      await addTodo();
      scheduler.enabled = true;
      await Future<void>.delayed(Duration.zero);
      await feed();
      expect(gateway.initialized, isTrue);
      final request = gateway.scheduled.values.single;
      expect(request.reminder.fireAt, DateTime(2026, 11, 11, 8, 45));
      expect(request.reminder.title, '交周报');
      expect(request.body, contains('明天'));
      expect(request.snoozeMinutes, TodoSettings.defaults.snoozeMinutes);
    },
  );

  test('reconciling only touches what changed', () async {
    final id = await addTodo();
    scheduler.enabled = true;
    await Future<void>.delayed(Duration.zero);
    await feed();
    expect(gateway.scheduleCalls, 1);

    await feed();
    expect(gateway.scheduleCalls, 1, reason: '没有变化时不重排');

    await db.setTodoTitle(id, '交月报');
    await feed();
    expect(gateway.scheduleCalls, 2, reason: '标题变了，内容指纹变了要重排');
    expect(gateway.scheduled.values.single.reminder.title, '交月报');

    await db.setTodoReminders(id, const <TodoReminder>[]);
    await feed();
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'completing removes the reminders; turning the feature off cancels all',
    () async {
      final id = await addTodo();
      await addTodo(title: '另一条');
      scheduler.enabled = true;
      await Future<void>.delayed(Duration.zero);
      await feed();
      expect(gateway.scheduled, hasLength(2));

      await db.completeTodo(id);
      await feed();
      expect(gateway.scheduled, hasLength(1));

      scheduler.enabled = false;
      await scheduler.replanNow();
      expect(gateway.scheduled, isEmpty);
    },
  );

  test('settings changes reach the notifications', () async {
    await addTodo();
    scheduler.enabled = true;
    await Future<void>.delayed(Duration.zero);
    await feed();
    scheduler.settings = const TodoSettings(
      snoozeMinutes: 30,
      hideContentOnLockScreen: true,
    );
    await scheduler.replanNow();
    final request = gateway.scheduled.values.single;
    expect(request.snoozeMinutes, 30);
    expect(request.hideOnLockScreen, isTrue);
  });

  test('notification taps open the todo; buttons write the database', () async {
    final id = await addTodo();
    scheduler.enabled = true;
    await Future<void>.delayed(Duration.zero);

    gateway.emit(
      TodoNotificationEvent(
        action: TodoNotificationAction.open,
        todoId: id,
        occurrence: '2026-11-11',
      ),
    );
    expect(opened, <String>[id]);

    gateway.emit(
      TodoNotificationEvent(
        action: TodoNotificationAction.snooze,
        todoId: id,
        occurrence: '2026-11-11',
        snoozeMinutes: 10,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await db.getTodo(id))!.snoozedUntil,
      now.add(const Duration(minutes: 10)),
    );

    gateway.emit(
      TodoNotificationEvent(
        action: TodoNotificationAction.complete,
        todoId: id,
        occurrence: '2026-11-11',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await db.getTodo(id))!.completedAt, isNotNull);
  });

  test('a cold-start tap is delivered once', () async {
    gateway.launchEvent = const TodoNotificationEvent(
      action: TodoNotificationAction.open,
      todoId: 'launched',
      occurrence: '2026-11-11',
    );
    scheduler.enabled = true;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(opened, <String>['launched']);
  });

  test('completing from a stale notification does nothing', () async {
    final id = await db.createTodo(
      TodoInput(
        title: '浇花',
        dueDate: DateTime(2026, 11, 11),
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.daily,
          anchor: DateTime(2026, 11, 11),
        ),
      ),
    );
    // 另一台设备已经完成了 11 号这次，推到了 12 号。
    await db.completeTodo(id, now: DateTime(2026, 11, 11, 10));
    final wrote = await applyTodoNotificationAction(
      db,
      TodoNotificationEvent(
        action: TodoNotificationAction.complete,
        todoId: id,
        occurrence: '2026-11-11',
      ),
    );
    expect(wrote, isFalse);
    expect((await db.getTodo(id))!.dueDate, '2026-11-12');
  });

  test('permission is requested once per run', () async {
    gateway
      ..enabled = false
      ..grantOnRequest = false;
    expect(await scheduler.ensurePermission(), isFalse);
    expect(await scheduler.ensurePermission(), isFalse);
    expect(gateway.permissionRequests, 1);
  });
}
