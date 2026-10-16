import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';

import '../../support/calendar_test_harness.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

Future<void> _openPreviousYearMarch(WidgetTester tester) async {
  final l10n = _l10n(tester);
  await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(l10n.calendarPreviousYear));
  await tester.pumpAndSettle();
  await tester.tap(find.text(DateFormat.MMM('zh').format(DateTime(2000, 3))));
  await tester.pumpAndSettle();
}

void _expectMonth(WidgetTester tester, DateTime month) {
  final grid = tester.widget<CalendarMonthGrid>(find.byType(CalendarMonthGrid));
  expect(grid.focusedDay.year, month.year);
  expect(grid.focusedDay.month, month.month);
  // 同时检查实际显示页，避免只更新了标题/输入状态而网格仍停在旧月份。
  final pager = tester.widget<PageView>(
    find.descendant(
      of: find.byType(CalendarMonthGrid),
      matching: find.byType(PageView),
    ),
  );
  final first = CalendarMonthGrid.firstDay;
  expect(
    pager.controller!.page,
    (month.year - first.year) * 12 + month.month - first.month,
  );
  expect(find.text(DateFormat.yMMM('zh').format(month)), findsOneWidget);
}

Future<void> _pickYear(WidgetTester tester, int year) async {
  final l10n = _l10n(tester);
  await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(l10n.autoT0177));
  await tester.pumpAndSettle();
  final pickerFinder = find.byType(CalendarDatePicker);
  final picker = tester.widget<CalendarDatePicker>(pickerFinder);
  final localizations = MaterialLocalizations.of(tester.element(pickerFinder));
  await tester.tap(
    find.descendant(
      of: pickerFinder,
      matching: find.text(localizations.formatMonthYear(picker.initialDate!)),
    ),
  );
  await tester.pumpAndSettle();
  final yearFinder = find.descendant(
    of: find.byType(YearPicker),
    matching: find.text(localizations.formatYear(DateTime(year))),
  );
  await tester.scrollUntilVisible(
    yearFinder,
    year < picker.initialDate!.year ? -200 : 200,
    scrollable: find.descendant(
      of: find.byType(YearPicker),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(yearFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.commonConfirm));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('choosing a year after paging keeps the requested month', (
        tester,
      ) async {
        await pumpCalendarPage(tester, brightness: brightness);
        final now = DateTime.now();
        final nextMonth = DateTime(now.year, now.month + 1);
        await tester.tap(find.byTooltip(_l10n(tester).autoT0185));
        await tester.pumpAndSettle();

        await _openPreviousYearMarch(tester);

        _expectMonth(tester, DateTime(nextMonth.year - 1, 3));

        // 连续切年后仍从新月份继续浏览，不能读回第一次翻页留下的旧页码。
        await _openPreviousYearMarch(tester);
        _expectMonth(tester, DateTime(nextMonth.year - 2, 3));
        await tester.tap(find.byTooltip(_l10n(tester).autoT0185));
        await tester.pumpAndSettle();
        _expectMonth(tester, DateTime(nextMonth.year - 2, 4));
      });

      testWidgets(
        'choosing a year after scrolling the list does not jump to 2010',
        (tester) async {
          final now = DateTime.now();
          await pumpCalendarPage(
            tester,
            brightness: brightness,
            dayDiaries: (day) => [
              for (var index = 0; index < 12; index++)
                calendarTestDiary(
                  'scroll-year-$index',
                  DateTime(day.year, day.month, day.day, index),
                  title: 'Diary $index',
                ),
            ],
          );
          await tester.dragFrom(const Offset(200, 750), const Offset(0, -400));
          await tester.pumpAndSettle();
          final listPosition = Scrollable.of(
            tester.element(find.byType(CalendarMonthGrid)),
          ).position;
          expect(listPosition.pixels, greaterThan(0));
          await tester.dragFrom(const Offset(200, 750), const Offset(0, 800));
          await tester.pumpAndSettle();
          expect(listPosition.pixels, 0);

          await _openPreviousYearMarch(tester);

          _expectMonth(tester, DateTime(now.year - 1, 3));
        },
      );

      testWidgets(
        'the date picker opens at the browsed year and cancel keeps it',
        (tester) async {
          await pumpCalendarPage(tester, brightness: brightness);
          final now = DateTime.now();
          final l10n = _l10n(tester);
          await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(l10n.calendarPreviousYear));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(l10n.autoT0177));
          await tester.pumpAndSettle();

          final picker = tester.widget<CalendarDatePicker>(
            find.byType(CalendarDatePicker),
          );
          expect(picker.initialDate, DateTime(now.year - 1, now.month));

          await tester.tap(find.text(l10n.commonCancel));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarDatePicker), findsNothing);
          expect(
            find.text(DateFormat.y('zh').format(DateTime(now.year - 1))),
            findsOne,
          );
        },
      );

      testWidgets(
        'picking boundary years and returning today displays each choice',
        (tester) async {
          await pumpCalendarPage(tester, brightness: brightness);
          final now = DateTime.now();
          for (final year in [2010, 2100, 2015]) {
            await _pickYear(tester, year);
            _expectMonth(tester, DateTime(year, now.month));
            final grid = tester.widget<CalendarMonthGrid>(
              find.byType(CalendarMonthGrid),
            );
            expect(grid.selectedDay.year, year);
          }
          await tester.tap(find.byTooltip(_l10n(tester).autoT0180));
          await tester.pumpAndSettle();
          _expectMonth(tester, now);
        },
      );
    });
  }
}
