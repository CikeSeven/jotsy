import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_summary.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../support/calendar_test_harness.dart';

CalendarDisplayOptions _gridOptions(WidgetTester tester) {
  return tester
      .widget<CalendarDayCell>(find.byType(CalendarDayCell).first)
      .options;
}

void main() {
  testWidgets('the week starts on Monday in Chinese and Sunday in English', (
    tester,
  ) async {
    await pumpCalendarPage(tester);
    expect(
      tester.getTopLeft(find.text('一')).dx,
      lessThan(tester.getTopLeft(find.text('日')).dx),
    );

    await pumpCalendarPage(tester, locale: const Locale('en'));
    final sundayAndSaturday = find.text('S');
    final mondayX = tester.getTopLeft(find.text('M')).dx;
    final xs = [
      for (final element in sundayAndSaturday.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dx,
    ]..sort();
    expect(xs.first, lessThan(mondayX));
    expect(xs.last, greaterThan(mondayX));
  });

  testWidgets(
    'picking a cell style in the sheet restyles the grid and persists',
    (tester) async {
      final settings = await pumpCalendarPage(tester);
      final l10n = tester.element(find.byType(CalendarPage)).l10n;
      expect(_gridOptions(tester).cellStyle, CalendarCellStyle.mood);

      await tester.tap(find.byTooltip(l10n.calendarDisplayOptionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.calendarCellStyleHeat));
      await tester.pumpAndSettle();

      // 面板保持打开，网格已在遮罩后方换成热力样式。
      expect(find.text(l10n.calendarOptionsTitle), findsOneWidget);
      expect(_gridOptions(tester).cellStyle, CalendarCellStyle.heat);
      expect(
        CalendarDisplayOptions.decode(
          settings.calendarDisplayOptionsRaw,
        ).cellStyle,
        CalendarCellStyle.heat,
      );

      await tester.tap(find.text(l10n.calendarOptionsReset));
      await tester.pumpAndSettle();
      expect(_gridOptions(tester).cellStyle, CalendarCellStyle.mood);
      expect(settings.calendarDisplayOptionsRaw, isNull);
    },
  );

  testWidgets('saved options are applied when the page opens', (tester) async {
    await pumpCalendarPage(
      tester,
      prefs: <String, Object>{
        'app.settings.calendar_display_options': const CalendarDisplayOptions(
          cellStyle: CalendarCellStyle.tags,
          defaultFormat: CalendarDefaultFormat.week,
          showMonthSummary: false,
        ).encode(),
      },
    );

    expect(_gridOptions(tester).cellStyle, CalendarCellStyle.tags);
    expect(
      tester
          .widget<TableCalendar<DiaryCalendarMarker>>(
            find.byType(TableCalendar<DiaryCalendarMarker>),
          )
          .calendarFormat,
      CalendarFormat.week,
    );
    expect(find.byType(CalendarMonthSummary), findsNothing);
  });

  testWidgets('"last used" remembers the week view', (tester) async {
    final settings = await pumpCalendarPage(
      tester,
      prefs: <String, Object>{
        'app.settings.calendar_display_options': const CalendarDisplayOptions(
          defaultFormat: CalendarDefaultFormat.remember,
        ).encode(),
      },
    );

    await tester.fling(
      find.byType(TableCalendar<DiaryCalendarMarker>),
      const Offset(0, -300),
      1200,
    );
    await tester.pumpAndSettle();

    expect(
      CalendarDisplayOptions.decode(
        settings.calendarDisplayOptionsRaw,
      ).rememberedFormat,
      CalendarGridFormat.week,
    );
  });

  testWidgets('the monthly summary counts this month\'s entries', (
    tester,
  ) async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1, 9);
    await pumpCalendarPage(
      tester,
      markers: <DiaryCalendarMarker>[
        DiaryCalendarMarker(diaryId: 'a', createdAt: firstDay, charCount: 40),
        DiaryCalendarMarker(
          diaryId: 'b',
          createdAt: firstDay.add(const Duration(hours: 2)),
          charCount: 2,
        ),
      ],
    );
    final l10n = tester.element(find.byType(CalendarPage)).l10n;

    expect(find.byType(CalendarMonthSummary), findsOneWidget);
    expect(find.byTooltip(l10n.calendarSummaryEntries(2)), findsOneWidget);
    expect(find.byTooltip(l10n.calendarSummaryStreak(1)), findsOneWidget);
  });
}
