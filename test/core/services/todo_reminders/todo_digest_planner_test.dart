import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/todo_reminders/todo_digest_planner.dart';
import 'package:node_diary/core/services/todo_reminders/todo_reminder_format.dart';
import 'package:node_diary/core/services/todo_reminders/todo_reminder_planner.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

void main() {
  late AppDatabase db;
  // 11 月 10 日 7:00，摘要排在每天 8:00。
  final now = DateTime(2026, 11, 10, 7);
  const minute = 8 * 60;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> add(
    String title, {
    DateTime? due,
    int? dueMinute,
    TodoPriority priority = TodoPriority.none,
  }) => db.createTodo(
    TodoInput(
      title: title,
      dueDate: due,
      dueMinute: dueMinute,
      priority: priority,
    ),
  );

  test(
    'counts what is due by each day and how much of it is overdue',
    () async {
      await add('逾期', due: DateTime(2026, 11, 8));
      await add('今天', due: DateTime(2026, 11, 10));
      await add('后天', due: DateTime(2026, 11, 12));
      await add('没日期');
      final done = await add('完成了', due: DateTime(2026, 11, 10));
      await db.completeTodo(done);

      final digests = planTodoDigests(
        todos: await db.getOpenTodos(),
        now: now,
        minute: minute,
      );

      expect(digests, hasLength(kTodoDigestDays));
      final today = digests.first;
      expect(today.day, DateTime(2026, 11, 10));
      expect(today.fireAt, DateTime(2026, 11, 10, 8));
      expect((today.count, today.overdue), (2, 1));
      // 明天：今天的那条也算逾期了；后天：再多一条当天的。
      expect((digests[1].count, digests[1].overdue), (2, 2));
      expect((digests[2].count, digests[2].overdue), (3, 2));
      expect(
        digests.map((digest) => digest.id).toSet(),
        hasLength(kTodoDigestDays),
        reason: '每天一个 id',
      );
    },
  );

  test('days with nothing to do are skipped', () async {
    await add('下周', due: DateTime(2026, 11, 13));

    final digests = planTodoDigests(
      todos: await db.getOpenTodos(),
      now: now,
      minute: minute,
    );

    expect(digests.first.day, DateTime(2026, 11, 13));
    expect(digests, hasLength(kTodoDigestDays - 3));
    expect(
      planTodoDigests(todos: const <TodoRow>[], now: now, minute: minute),
      isEmpty,
    );
  });

  test(
    'titles put the overdue first, then by time and priority, at most three',
    () async {
      await add('全天', due: DateTime(2026, 11, 10));
      await add('下午', due: DateTime(2026, 11, 10), dueMinute: 15 * 60);
      await add(
        '上午重要',
        due: DateTime(2026, 11, 10),
        dueMinute: 10 * 60,
        priority: TodoPriority.high,
      );
      await add('上午', due: DateTime(2026, 11, 10), dueMinute: 10 * 60);
      await add('昨天', due: DateTime(2026, 11, 9));

      final today = planTodoDigests(
        todos: await db.getOpenTodos(),
        now: now,
        minute: minute,
      ).first;

      expect(today.count, 5);
      expect(today.titles, <String>['昨天', '上午重要', '上午']);
    },
  );

  test(
    'a digest whose time has passed stays only while the system holds it',
    () async {
      await add('今天', due: DateTime(2026, 11, 10));
      final todos = await db.getOpenTodos();
      final late = DateTime(2026, 11, 10, 9);

      final fresh = planTodoDigests(todos: todos, now: late, minute: minute);
      expect(fresh.first.day, DateTime(2026, 11, 11));

      final todayId = todoReminderNotificationId(
        kTodoDigestIdKey,
        DateTime(2026, 11, 10, 8),
      );
      final held = planTodoDigests(
        todos: todos,
        now: late,
        minute: minute,
        pendingIds: <int>{todayId},
      );
      expect(held.first.day, DateTime(2026, 11, 10));
      expect(held.first.id, todayId);
    },
  );

  test('the notification names the count, the overdue and the titles', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final digest = PlannedTodoDigest(
      id: 1,
      day: DateTime(2026, 11, 10),
      fireAt: DateTime(2026, 11, 10, 8),
      count: 5,
      overdue: 2,
      titles: const <String>['交周报', '买菜'],
    );

    final text = formatTodoDigestNotification(l10n, digest);
    expect(text.title, '今天有 5 件待办');
    expect(text.body, '其中 2 件已逾期\n交周报 · 买菜');

    final reminder = digest.toReminder(text.title);
    expect(reminder.digest, isTrue);
    expect(reminder.todoId, isEmpty);
    expect(decodeTodoReminderPayload(reminder.payload)?.todoId, isEmpty);

    final calm = formatTodoDigestNotification(
      lookupAppLocalizations(const Locale('en')),
      PlannedTodoDigest(
        id: 1,
        day: DateTime(2026, 11, 10),
        fireAt: DateTime(2026, 11, 10, 8),
        count: 1,
        overdue: 0,
        titles: const <String>['Pay bill'],
      ),
    );
    expect(calm.title, '1 to-do for today');
    expect(calm.body, 'Pay bill');
  });
}
