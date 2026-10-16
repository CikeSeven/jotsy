import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../support/expressive_test_theme.dart';

/// 网格固定在 2026 年 10 月（内置放假数据覆盖的最后一年），不依赖今天的
/// 日期：整页测试以 DateTime.now() 定位，数据过期后会失去假日可测。
void main() {
  final october = DateTime(2026, 10, 15);

  Future<void> pumpGrid(
    WidgetTester tester, {
    required Locale locale,
    CalendarDisplayOptions options = const CalendarDisplayOptions(),
  }) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CalendarMonthGrid(
            focusedDay: october,
            selectedDay: october,
            format: CalendarFormat.month,
            options: options,
            summaries: const <DateTime, CalendarDaySummary>{},
            inlineImages: const <String, String>{},
            onDaySelected: (_, _) {},
            onPageChanged: (_) {},
            onFormatChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CalendarDayCell cellOf(WidgetTester tester, int month, int day) {
    return tester
        .widgetList<CalendarDayCell>(find.byType(CalendarDayCell))
        .firstWhere((cell) => cell.day.month == month && cell.day.day == day);
  }

  testWidgets('Chinese marks the National Day break and its workdays', (
    tester,
  ) async {
    await pumpGrid(tester, locale: const Locale('zh'));
    for (var day = 1; day <= 7; day++) {
      expect(cellOf(tester, 10, day).holiday?.isWork, isFalse);
    }
    expect(cellOf(tester, 10, 10).holiday?.isWork, isTrue);
    expect(cellOf(tester, 10, 8).holiday, isNull);
    expect(find.text('休'), findsNWidgets(7));
    expect(find.text('班'), findsOneWidget);
  });

  testWidgets('English hides holidays unless they are switched on', (
    tester,
  ) async {
    await pumpGrid(tester, locale: const Locale('en'));
    expect(
      tester
          .widgetList<CalendarDayCell>(find.byType(CalendarDayCell))
          .every((cell) => cell.holiday == null),
      isTrue,
    );

    await pumpGrid(
      tester,
      locale: const Locale('en'),
      options: const CalendarDisplayOptions(
        holidayMode: CalendarLunarMode.always,
      ),
    );
    expect(cellOf(tester, 10, 1).holiday?.isWork, isFalse);
    // 英文一周从周日开始，首行带出 9 月 27 日（中秋假期最后一天）。
    expect(cellOf(tester, 9, 27).holiday?.isWork, isFalse);
    expect(find.text('Off'), findsNWidgets(8));
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('Chinese can hide holidays and keep the lunar dates', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      locale: const Locale('zh'),
      options: const CalendarDisplayOptions(
        holidayMode: CalendarLunarMode.never,
      ),
    );
    expect(find.text('休'), findsNothing);
    expect(cellOf(tester, 10, 1).lunar, isNotNull);
  });
}
