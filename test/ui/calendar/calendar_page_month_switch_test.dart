import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/providers/day_mood_providers.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/providers/calendar_diary_providers.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../support/calendar_test_harness.dart';

/// 当前月立即返回空打点；其他月份按 [otherMonthDelay] 模拟查询耗时。
Future<void> _pumpCalendar(
  WidgetTester tester, {
  Duration otherMonthDelay = Duration.zero,
  Locale locale = const Locale('zh'),
  double width = 401.6,
}) async {
  // 日历面板左右合计 25.6dp 内缩（含 0.8 边框），手机宽度下 PageView 页宽
  // 不是整数时，乘以数千页后触发 SliverFillViewport 的浮点精度断言；取
  // 401.6 让页宽为整数 376。宽窗口（≥ 600）的网格自己取整。
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarMonthMarkersProvider.overrideWith((ref, month) {
          if (month.year == now.year && month.month == now.month) {
            return Stream.value(const <DiaryCalendarMarker>[]);
          }
          return Stream.fromFuture(
            Future<List<DiaryCalendarMarker>>.delayed(
              otherMonthDelay,
              () => const <DiaryCalendarMarker>[],
            ),
          );
        }),
        calendarDayDiariesProvider.overrideWith(
          (ref, day) => Stream.value(const <DiaryWithTags>[]),
        ),
        calendarOnThisDayProvider.overrideWith(
          (ref, day) => Stream.value(const <DiaryWithTags>[]),
        ),
        moodOptionsProvider.overrideWith(
          (ref) => Stream.value(const <String>[]),
        ),
        anniversaryListProvider.overrideWith(
          (ref) => Stream.value(const <Anniversary>[]),
        ),
        dayMoodsProvider.overrideWith(
          (ref) => Stream.value(const <DateTime, DayMood>{}),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CalendarPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('next month in week view switches to month view of next month', (
    tester,
  ) async {
    // 页头的翻月箭头只在宽窗口（与桌面）出现。
    await _pumpCalendar(tester, width: 800);

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
    expect(find.text(DateFormat.yMMM('zh').format(nextMonth)), findsOneWidget);
  });

  testWidgets('fast month query does not flash the loading capsule', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      otherMonthDelay: const Duration(milliseconds: 60),
    );

    await swipeCalendarPage(tester, settle: false);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byType(ExpressiveLoadingIndicator),
        findsNothing,
        reason: 'frame $frame',
      );
    }
    await tester.pumpAndSettle();
  });

  testWidgets('slow month query still shows the loading capsule', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      otherMonthDelay: const Duration(milliseconds: 900),
    );

    await swipeCalendarPage(tester, settle: false);
    // 逐帧推进：翻页过半才切换焦点月份并开始加载。
    for (var frame = 0; frame < 45; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(ExpressiveLoadingIndicator), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
  });

  for (final (locale, weekdayLabels, monthTitle, dayTitle)
      in <
        (
          Locale,
          List<String>,
          String Function(DateTime),
          String Function(DateTime),
        )
      >[
        (
          const Locale('zh'),
          const <String>['一', '二', '三', '四', '五', '六', '日'],
          (date) => '${date.year}年${date.month}月',
          (date) => '${date.month}月${date.day}日',
        ),
        (
          const Locale('en'),
          const <String>['M', 'T', 'W', 'F', 'S'],
          (date) => DateFormat('MMM yyyy', 'en').format(date),
          (date) => DateFormat('MMM d', 'en').format(date),
        ),
      ]) {
    testWidgets('calendar labels follow the ${locale.languageCode} locale', (
      tester,
    ) async {
      await _pumpCalendar(tester, locale: locale);
      final now = DateTime.now();

      // 星期栏、月份标题与选中日标题均由 intl 按语言区域生成。
      for (final label in weekdayLabels) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text(monthTitle(now)), findsOneWidget);
      expect(find.text(dayTitle(now)), findsOneWidget);
    });
  }
}
