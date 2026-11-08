import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/todos/widgets/todo_calendar_section.dart';

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
  final today = DateUtils.dateOnly(DateTime.now());

  Finder cellOn(DateTime day) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is CalendarDayCell &&
        widget.day.month == day.month &&
        widget.day.day == day.day,
  );

  testWidgets('with to-dos on, days are marked and the day card lists them', (
    tester,
  ) async {
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
      openTodos: <TodoRow>[_todo('交周报', today)],
      completedTodos: <TodoRow>[_todo('已经做完', today, completedAt: today)],
    );
    expect(
      tester.widget<CalendarDayCell>(cellOn(today).first).hasOpenTodo,
      isTrue,
    );
    expect(find.byType(TodoCalendarSection), findsOneWidget);
    expect(find.text('交周报'), findsOneWidget);
    expect(find.text('已经做完'), findsOneWidget);
  });

  testWidgets('the long-press sheet offers adding a to-do', (tester) async {
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{_featuresKey: '{"todos":true}'},
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    await tester.longPress(cellOn(today).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarAddTodo), findsOneWidget);
  });

  testWidgets('with the feature off nothing about to-dos shows', (
    tester,
  ) async {
    await pumpCalendarPage(tester, openTodos: <TodoRow>[_todo('交周报', today)]);
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    expect(
      tester.widget<CalendarDayCell>(cellOn(today).first).hasOpenTodo,
      isFalse,
    );
    expect(find.byType(TodoCalendarSection), findsNothing);
    await tester.longPress(cellOn(today).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarAddTodo), findsNothing);
  });

  testWidgets('the display option turns the to-dos off', (tester) async {
    await pumpCalendarPage(
      tester,
      prefs: const <String, Object>{
        _featuresKey: '{"todos":true}',
        _optionsKey: '{"showTodos":false}',
      },
      openTodos: <TodoRow>[_todo('交周报', today)],
    );
    expect(find.byType(TodoCalendarSection), findsNothing);
    expect(
      tester.widget<CalendarDayCell>(cellOn(today).first).hasOpenTodo,
      isFalse,
    );
  });
}
