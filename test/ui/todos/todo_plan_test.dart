import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_day_plan.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_reschedule.dart';
import 'package:node_diary/ui/todos/widgets/todo_week_strip.dart';

import 'todos_page_harness.dart';

TodoRow _todo(
  String title, {
  String? due,
  int priority = 0,
  DateTime? created,
  String metadata = '{}',
}) {
  final at = created ?? DateTime(2026, 11, 1);
  return TodoRow(
    id: title.hashCode,
    todoId: title,
    title: title,
    note: '',
    priority: priority,
    reminders: '[]',
    steps: '[]',
    sortOrder: 0,
    metadata: metadata,
    dueDate: due,
    createdAt: at,
    updatedAt: at,
  );
}

/// 改期的快捷日子、规划今天的建议、改期面板、规划面板、计划视图周条与
/// 桌面右键的改期。
void main() {
  test('reschedule days around the week', () {
    // 2026-11-11 是周三。
    final wed = TodoRescheduleDays.of(DateTime(2026, 11, 11, 15));
    expect(wed.tomorrow, DateTime(2026, 11, 12));
    expect(wed.weekend, DateTime(2026, 11, 14));
    expect(wed.nextMonday, DateTime(2026, 11, 16));
    expect(wed.inAWeek, DateTime(2026, 11, 18));
    // 周六：本周末就是今天；周日：下周六；周一：下周一为七天后。
    expect(
      TodoRescheduleDays.of(DateTime(2026, 11, 14)).weekend,
      DateTime(2026, 11, 14),
    );
    expect(
      TodoRescheduleDays.of(DateTime(2026, 11, 15)).weekend,
      DateTime(2026, 11, 21),
    );
    expect(
      TodoRescheduleDays.of(DateTime(2026, 11, 16)).nextMonday,
      DateTime(2026, 11, 23),
    );
  });

  test('the day plan groups what is worth a look today', () {
    final today = DateTime(2026, 11, 11);
    final plan = TodoDayPlan.build(<TodoRow>[
      _todo('late', due: '2026-11-09'),
      _todo('today', due: '2026-11-11'),
      _todo('saturday', due: '2026-11-14'),
      _todo('friday', due: '2026-11-13'),
      _todo('far', due: '2026-11-30'),
      _todo('vip', priority: TodoPriority.high.index),
      _todo('fresh', created: DateTime(2026, 11, 10, 8)),
      _todo('old'),
    ], today);
    List<String> titles(TodoPlanSection s) =>
        (plan.sections[s] ?? const <TodoRow>[]).map((r) => r.title).toList();
    expect(plan.sections.keys, TodoPlanSection.values);
    expect(titles(TodoPlanSection.overdue), <String>['late']);
    // 按截止先后，不按传入顺序。
    expect(titles(TodoPlanSection.soon), <String>['friday', 'saturday']);
    expect(titles(TodoPlanSection.important), <String>['vip']);
    expect(titles(TodoPlanSection.recent), <String>['fresh']);
    expect(
      TodoDayPlan.build(<TodoRow>[
        _todo('today', due: '2026-11-11'),
      ], today).isEmpty,
      isTrue,
    );
  });

  testWidgets('plan today lifts an overdue todo into today', (tester) async {
    final db = await pumpTodosPage(
      tester,
      height: 1000,
      seed: (db) async {
        await db.createTodo(
          TodoInput(
            title: '回邮件',
            dueDate: todoToday.subtract(const Duration(days: 2)),
          ),
        );
        await db.createTodo(
          const TodoInput(title: '大事', priority: TodoPriority.high),
        );
      },
    );
    final l10n = todoL10n(tester);
    await tester.tap(find.text(l10n.todoPlanToday));
    await settleTodos(tester);
    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);
    expect(inSheet(find.text(l10n.todoPlanOverdue)), findsOneWidget);
    expect(inSheet(find.text(l10n.todoPlanImportant)), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byTooltip(l10n.todoPlanAddToToday),
          )
          .first,
    );
    await settleTodos(tester);
    expect(
      (await todoRowTitled(tester, db, '回邮件')).dueDate,
      formatAnniversaryDate(todoToday),
    );
    // 安排过的从面板里收走。
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('回邮件')),
      findsNothing,
    );
    await unmountTodos(tester);
  });

  testWidgets('the due sheet offers this weekend and in a week', (
    tester,
  ) async {
    final db = await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(swipeLeft: TodoSwipeAction.reschedule),
      seed: (db) async {
        await db.createTodo(TodoInput(title: '理发', dueDate: todoToday));
      },
    );
    final l10n = todoL10n(tester);
    await tester.drag(find.text('理发'), const Offset(-300, 0));
    await settleTodos(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.todoDueThisWeekend), findsOneWidget);
    await tester.tap(find.text(l10n.todoDueInAWeek));
    await settleTodos(tester);
    expect(
      (await todoRowTitled(tester, db, '理发')).dueDate,
      formatAnniversaryDate(todoToday.add(const Duration(days: 7))),
    );
    await unmountTodos(tester);
  });

  testWidgets('the planned view shows a week strip with counts', (
    tester,
  ) async {
    await pumpTodosPage(
      tester,
      todoSettings: const TodoSettings(defaultViewKey: 'planned'),
      seed: (db) async {
        await db.createTodo(TodoInput(title: '一', dueDate: todoToday));
        await db.createTodo(TodoInput(title: '二', dueDate: todoToday));
      },
    );
    final strip = tester.widget<TodoWeekStrip>(find.byType(TodoWeekStrip));
    expect(strip.counts[formatAnniversaryDate(todoToday)], 2);
    final l10n = todoL10n(tester);
    // 翻到下一周再翻回来。
    await tester.tap(find.byTooltip(l10n.todoWeekNext));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip(l10n.todoWeekPrev));
    await tester.pump(const Duration(milliseconds: 400));
    // 点今天：在今天新建。
    await tester.tap(find.text('${todoToday.day}').first);
    await settleTodos(tester);
    expect(find.text(l10n.todoNew), findsOneWidget);
    await unmountTodos(tester);
  });

  testWidgets('desktop right click offers reschedule', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pumpTodosPage(
        tester,
        width: 1280,
        seed: (db) async {
          await db.createTodo(TodoInput(title: '周报', dueDate: todoToday));
        },
      );
      final l10n = todoL10n(tester);
      await tester.tapAt(
        tester.getCenter(find.text('周报')),
        buttons: kSecondaryButton,
      );
      await settleTodos(tester);
      await tester.tap(find.text(l10n.todoReschedule));
      await settleTodos(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.todoDueThisWeekend), findsOneWidget);
      await unmountTodos(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
