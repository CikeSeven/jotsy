import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_actions.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway.dart';
import 'package:node_diary/ui/todos/controllers/todo_reminder_scheduler.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/providers/todo_reminder_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_todo_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTodoNotificationGateway gateway;
  late TodoReminderScheduler scheduler;
  final opened = <String>[];
  // 固定的“现在”：明天 9 点的提醒总在窗口里。
  late DateTime now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeTodoNotificationGateway();
    opened.clear();
    now = DateTime(2026, 11, 10, 8);
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
      expect(request.body, contains('今天'));
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
    expect(gateway.cancelled, isEmpty);

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

  test(
    'cold startup waits for saved settings before clearing the queue',
    () async {
      await addTodo();
      scheduler.enabled = true;
      await feed();
      scheduler.dispose();
      expect(gateway.scheduled, hasLength(1));

      SharedPreferences.setMockInitialValues({});
      final ready = Completer<SettingsService>();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          todoNotificationGatewayProvider.overrideWithValue(gateway),
          settingsServiceProvider.overrideWith((_) => ready.future),
        ],
      );
      addTearDown(container.dispose);
      final restarted = container.read(todoReminderSchedulerProvider)!;
      await restarted.replanNow();
      expect(gateway.scheduled, hasLength(1));

      ready.complete(await SettingsService.create());
      await container.read(settingsServiceProvider.future);
      await restarted.replanNow();
      expect(gateway.scheduled, isEmpty);
    },
  );

  test(
    'an overdue pending alarm survives until delivered or removed',
    () async {
      final id = await addTodo();
      scheduler.enabled = true;
      await feed();
      final alarm = gateway.scheduled.values.single;
      now = alarm.reminder.fireAt.add(const Duration(minutes: 10));
      await feed();
      expect(gateway.scheduled.values.single, alarm);
      expect(gateway.scheduleCalls, 1);
      expect(gateway.cancelled, isEmpty);

      await db.setTodoReminders(id, const <TodoReminder>[]);
      await feed();
      expect(gateway.scheduled, isEmpty);
    },
  );

  test(
    'Android alarms are repaired when the exact permission changes',
    () async {
      await addTodo();
      scheduler.enabled = true;
      await feed();
      final alarm = gateway.scheduled.values.single;
      expect(alarm.androidExact, isTrue);

      gateway.exact = false;
      await scheduler.replanNow();
      expect(gateway.scheduled[alarm.id]!.androidExact, isFalse);
      expect(gateway.cancelled, isEmpty);
      expect(gateway.scheduleCalls, 2);
    },
  );

  test('an unsuccessful replacement keeps the previous alarm', () async {
    final id = await addTodo();
    scheduler.enabled = true;
    await feed();
    final alarm = gateway.scheduled.values.single;

    gateway.scheduleFailures.add(alarm.id);
    await db.setTodoTitle(id, '更新标题');
    await addTodo(title: '第二项');
    await feed();
    expect(gateway.scheduled[alarm.id], alarm);
    expect(gateway.scheduled, hasLength(2));
    expect(gateway.cancelled, isEmpty);

    await scheduler.replanNow();
    expect(gateway.scheduled[alarm.id]!.reminder.title, '更新标题');
    expect(gateway.scheduleCalls, 4);
  });

  testWidgets('startup retries plugin initialization and pending reads', (
    tester,
  ) async {
    final rows = await tester.runAsync(() async {
      await addTodo();
      return db.getOpenTodos();
    });
    gateway
      ..initializationFailures = 1
      ..pendingFailures = 1;
    final retryingScheduler = TodoReminderScheduler(
      gateway: gateway,
      database: db,
      onOpen: opened.add,
      now: () => now,
    );
    try {
      retryingScheduler
        ..todos = rows!
        ..enabled = true;
      await tester.pump(Duration.zero);
      expect(gateway.initializationFailures, 0);
      expect(gateway.initialized, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(gateway.initialized, isTrue);
      expect(gateway.scheduled, isEmpty);
      await tester.pump(const Duration(seconds: 10));
      expect(gateway.scheduled, hasLength(1));
    } finally {
      retryingScheduler.dispose();
    }
  });

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

  test(
    'the daily digest is scheduled without buttons and follows the setting',
    () async {
      await addTodo(reminders: const <TodoReminder>[]);
      scheduler.enabled = true;
      await Future<void>.delayed(Duration.zero);
      await feed();
      expect(gateway.scheduled, isEmpty, reason: '默认关');

      scheduler.settings = const TodoSettings(digestMinute: 9 * 60);
      await scheduler.replanNow();
      // 今天 9 点还没到；待办截止在明天，所以今天的件数为 0、不排。
      final digests = gateway.scheduled.values.toList()
        ..sort((a, b) => a.reminder.fireAt.compareTo(b.reminder.fireAt));
      expect(digests, isNotEmpty);
      final first = digests.first;
      expect(first.reminder.digest, isTrue);
      expect(first.reminder.todoId, isEmpty);
      expect(first.reminder.fireAt, DateTime(2026, 11, 11, 9));
      expect(first.reminder.title, '今天有 1 件待办');
      expect(first.body, '交周报');
      expect(digests[1].body, startsWith('其中 1 件已逾期'));

      gateway.emit(
        const TodoNotificationEvent(
          action: TodoNotificationAction.open,
          todoId: '',
          occurrence: '2026-11-11',
        ),
      );
      expect(opened, <String>[''], reason: '首页据此切到“今天”');

      scheduler.settings = TodoSettings.defaults;
      await scheduler.replanNow();
      expect(gateway.scheduled, isEmpty);
    },
  );

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

  test(
    'cancelTodoOccurrenceNotifications only cancels the targeted occurrence',
    () async {
      final todoA = await db.createTodo(
        TodoInput(
          title: '吃药',
          dueDate: DateTime(2026, 11, 11),
          dueMinute: 9 * 60,
          reminders: const <TodoReminder>[
            TodoReminder.beforeDue(15),
            TodoReminder.beforeDue(0),
          ],
          repeat: TodoRepeatRule(
            frequency: TodoRepeatFrequency.daily,
            anchor: DateTime(2026, 11, 11),
          ),
        ),
      );
      await addTodo(title: '另一项');
      scheduler.enabled = true;
      await feed();
      final totalBefore = gateway.scheduled.length;
      expect(totalBefore, greaterThan(4));

      await cancelTodoOccurrenceNotifications(
        gateway,
        todoId: todoA,
        occurrence: '2026-11-11',
      );
      expect(gateway.scheduled.length, totalBefore - 2);
      expect(
        gateway.scheduled.values.where(
          (r) =>
              r.reminder.todoId == todoA &&
              r.reminder.occurrence == DateTime(2026, 11, 11),
        ),
        isEmpty,
      );
    },
  );
}
