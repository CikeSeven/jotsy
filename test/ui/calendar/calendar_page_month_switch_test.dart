import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/providers/calendar_diary_providers.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  testWidgets('next month in week view switches to month view of next month', (
    tester,
  ) async {
    // 日历面板左右合计 41.6dp 内缩（含 0.8 边框），默认 800 宽测试窗口下
    // PageView 页宽为 758.4，乘以数千页后触发 SliverFillViewport 的浮点精度
    // 断言；取 401.6 让页宽为整数 360。
    tester.view.physicalSize = const Size(401.6, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarMonthMarkersProvider.overrideWith(
            (ref, month) => Stream.value(const <DiaryCalendarMarker>[]),
          ),
          calendarDayDiariesProvider.overrideWith(
            (ref, day) => Stream.value(const <DiaryWithTags>[]),
          ),
          moodOptionsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    CalendarFormat currentFormat() => tester
        .widget<TableCalendar<DiaryCalendarMarker>>(
          find.byType(TableCalendar<DiaryCalendarMarker>),
        )
        .calendarFormat;

    // 上滑日历切到周视图。
    await tester.fling(
      find.byType(TableCalendar<DiaryCalendarMarker>),
      const Offset(0, -300),
      1200,
    );
    await tester.pumpAndSettle();
    expect(currentFormat(), CalendarFormat.week);

    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    await tester.tap(find.byTooltip(l10n.autoT0185));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    expect(currentFormat(), CalendarFormat.month);
    expect(
      find.text(DateFormat('yyyy年MM月', 'zh').format(nextMonth)),
      findsOneWidget,
    );
  });
}
