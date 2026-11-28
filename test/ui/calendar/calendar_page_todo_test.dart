import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_empty_state.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_timeline_section.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:node_diary/ui/widgets/todo_check_box.dart';

import '../../support/calendar_test_harness.dart';

const _featuresKey = 'app.settings.app_features';
const _optionsKey = 'app.settings.calendar_display_options';

TodoRow _todo(String title, DateTime due, {DateTime? completedAt}) => TodoRow(
  id: title.hashCode,
  todoId: 'todo-$title',
  title: title,
  note: '',
  priority: 0,
  dueDate: formatAnniversaryDate(due),
  reminders: '[]',
  steps: '[]',
  completedAt: completedAt,
  sortOrder: 0,
  metadata: '{}',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  DateTime currentToday() => DateUtils.dateOnly(DateTime.now());

  Finder cellOn(DateTime day) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is CalendarDayCell &&
        widget.day.month == day.month &&
        widget.day.day == day.day,
  );

  testWidgets('with to-dos on, days are marked and the timeline lists them', (
    tester,
  ) async {
    final today = currentToday();
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
      openTodos: <TodoRow>[_todo('交周报', today)],
      completedTodos: <TodoRow>[_todo('已经做完', today, completedAt: today)],
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    expect(
      tester.widget<CalendarDayCell>(cellOn(today).first).hasOpenTodo,
      isTrue,
    );
    // 当天没有日记：待办直接排进时间线，末尾是写日记与添加待办，不再是
    // 整块空状态。
    final timeline = find.byType(CalendarTimelineSection);
    expect(timeline, findsOneWidget);
    expect(find.byType(CalendarDayEmptyState), findsNothing);
    for (final text in <String>['交周报', '已经做完', l10n.calendarAddTodo]) {
      expect(
        find.descendant(of: timeline, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(find.byType(TodoTile), findsNWidgets(2));
  });

  testWidgets('today also lists overdue to-dos', (tester) async {
    final today = currentToday();
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
      openTodos: <TodoRow>[
        _todo('上周的事', today.subtract(const Duration(days: 3))),
      ],
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    expect(find.text(l10n.todoGroupOverdue), findsOneWidget);
    expect(find.text('上周的事'), findsOneWidget);

    // 别的日子不列逾期。
    final other = today.day == 15 ? 16 : 15;
    await tester.tap(
      find.descendant(
        of: cellOn(DateTime(today.year, today.month, other)).first,
        matching: find.text('$other'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.todoGroupOverdue), findsNothing);
  });

  testWidgets('the card style lists to-dos above the diary cards', (
    tester,
  ) async {
    final today = currentToday();
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{
        _featuresKey: '{"todos":true}',
        _optionsKey: '{"dayContentStyle":"cards"}',
      },
      openTodos: <TodoRow>[_todo('交周报', today)],
      dayDiaries: (day) => DateUtils.isSameDay(day, today)
          ? <DiaryWithTags>[
              calendarTestDiary(
                'cards-with-todo',
                DateTime(today.year, today.month, today.day, 9),
                title: '早上的日记',
              ),
            ]
          : const <DiaryWithTags>[],
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;

    expect(
      tester.getTopLeft(find.text('交周报')).dy,
      lessThan(tester.getTopLeft(find.text('早上的日记')).dy),
    );
    // 日记以卡片列在下面：只有待办的那条时间线末尾不放“写日记”。
    expect(find.text(l10n.calendarAddTodo), findsOneWidget);
    expect(find.text(l10n.autoT0181), findsNothing);
  });

  testWidgets('an empty day offers adding a to-do beside writing', (
    tester,
  ) async {
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    final empty = find.byType(CalendarDayEmptyState);
    expect(empty, findsOneWidget);
    expect(
      find.descendant(of: empty, matching: find.text(l10n.calendarAddTodo)),
      findsOneWidget,
    );
  });

  testWidgets('checking a to-do on the calendar completes it', (tester) async {
    final today = currentToday();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final id = await tester.runAsync(
      () => database.createTodo(TodoInput(title: '浇花', dueDate: today)),
    );
    final row = (await tester.runAsync(() => database.getTodo(id!)))!;
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
      openTodos: <TodoRow>[row],
      extraOverrides: [appDatabaseProvider.overrideWithValue(database)],
    );

    await tester.tap(find.byType(TodoCheckBoxVisual));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final after = await tester.runAsync(() => database.getTodo(id!));
    expect(after!.completedAt, isNotNull);
    await tester.pumpAndSettle();
  });

  testWidgets('the long-press sheet offers adding a to-do', (tester) async {
    final today = currentToday();
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    // 空的一天，空状态里已经有一个“添加待办”；面板里再多一项。
    expect(find.text(l10n.calendarAddTodo), findsOneWidget);
    await tester.longPress(cellOn(today).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarAddTodo), findsNWidgets(2));
    expect(find.text(l10n.calendarDayActionRange), findsOneWidget);
  });

  testWidgets('with the feature off nothing about to-dos shows', (
    tester,
  ) async {
    final today = currentToday();
    await pumpCalendarPage(tester, openTodos: <TodoRow>[_todo('交周报', today)]);
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    expect(
      tester.widget<CalendarDayCell>(cellOn(today).first).hasOpenTodo,
      isFalse,
    );
    expect(find.byType(TodoTile), findsNothing);
    expect(find.text(l10n.calendarAddTodo), findsNothing);
    await tester.longPress(cellOn(today).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarAddTodo), findsNothing);
  });

  testWidgets('the display option turns the to-dos off', (tester) async {
    final today = currentToday();
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{
        _featuresKey: '{"todos":true}',
        _optionsKey: '{"showTodos":false}',
      },
      openTodos: <TodoRow>[_todo('交周报', today)],
    );
    expect(find.byType(TodoTile), findsNothing);
    expect(
      tester.widget<CalendarDayCell>(cellOn(today).first).hasOpenTodo,
      isFalse,
    );
  });
}
