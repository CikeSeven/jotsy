import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_on_this_day_strip.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_timeline_section.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_year_view.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';

import '../../support/calendar_test_harness.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

/// 当前网格中的某个日期数字（月视图里 15 号这类中段日期只出现一次）。
Finder _gridDay(int day) => find.descendant(
  of: find.byType(CalendarMonthGrid),
  matching: find.text('$day'),
);

void main() {
  testWidgets('the month title zooms out to the year and a month zooms back', (
    tester,
  ) async {
    await pumpCalendarPage(tester);
    final l10n = _l10n(tester);
    final now = DateTime.now();

    await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarYearView), findsOneWidget);
    expect(find.byType(CalendarMonthGrid), findsNothing);
    expect(find.text(DateFormat.y('zh').format(now)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.calendarPreviousYear));
    await tester.pumpAndSettle();
    final lastYear = DateTime(now.year - 1);
    expect(find.text(DateFormat.y('zh').format(lastYear)), findsOneWidget);

    await tester.tap(find.text(DateFormat.MMM('zh').format(DateTime(2000, 3))));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarYearView), findsNothing);
    final grid = tester.widget<CalendarMonthGrid>(
      find.byType(CalendarMonthGrid),
    );
    expect(grid.focusedDay.year, now.year - 1);
    expect(grid.focusedDay.month, 3);
    expect(
      find.text(DateFormat.yMMM('zh').format(DateTime(now.year - 1, 3))),
      findsOneWidget,
    );
  });

  testWidgets('the year coloring choice is saved', (tester) async {
    final settings = await pumpCalendarPage(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.calendarYearBasisWords));
    await tester.pumpAndSettle();

    expect(
      CalendarDisplayOptions.decode(
        settings.calendarDisplayOptionsRaw,
      ).yearBasis,
      CalendarYearBasis.words,
    );
    expect(
      tester.widget<CalendarYearView>(find.byType(CalendarYearView)).basis,
      CalendarYearBasis.words,
    );
  });

  testWidgets('on this day lists other years and hides sealed capsules', (
    tester,
  ) async {
    final now = DateTime.now();
    final twoYearsAgo = DateTime(now.year - 2, now.month, now.day, 9);
    await pumpCalendarPage(
      tester,
      onThisDay: [
        calendarTestDiary('otd-visible', twoYearsAgo, title: 'Two years back'),
        calendarTestDiary(
          'otd-sealed',
          DateTime(now.year - 1, now.month, now.day, 9),
          title: 'Still sealed',
          capsuleUnlockAt: now.add(const Duration(days: 3)),
        ),
      ],
    );
    final l10n = _l10n(tester);

    expect(find.byType(CalendarOnThisDayStrip), findsOneWidget);
    expect(find.text('Two years back'), findsOneWidget);
    expect(find.textContaining(l10n.calendarOnThisDayYearsAgo(2)), findsOne);
    expect(find.text('Still sealed'), findsNothing);
  });

  testWidgets('on this day can be switched off', (tester) async {
    final now = DateTime.now();
    await pumpCalendarPage(
      tester,
      prefs: <String, Object>{
        'app.settings.calendar_display_options': const CalendarDisplayOptions(
          showOnThisDay: false,
        ).encode(),
      },
      onThisDay: [
        calendarTestDiary(
          'otd-hidden',
          DateTime(now.year - 1, now.month, now.day, 9),
          title: 'Hidden memory',
        ),
      ],
    );

    expect(find.byType(CalendarOnThisDayStrip), findsNothing);
    expect(find.text('Hidden memory'), findsNothing);
  });

  testWidgets('card style shows the day with diary list cards', (tester) async {
    final now = DateTime.now();
    await pumpCalendarPage(
      tester,
      prefs: <String, Object>{
        'app.settings.calendar_display_options': const CalendarDisplayOptions(
          dayContentStyle: CalendarDayContentStyle.cards,
        ).encode(),
      },
      dayDiaries: (day) => DateUtils.isSameDay(day, now)
          ? [
              calendarTestDiary(
                'card-style',
                DateTime(now.year, now.month, now.day, 8),
                title: 'Morning pages',
              ),
            ]
          : const [],
    );

    expect(find.byType(DiariesListSection), findsOneWidget);
    expect(find.byType(CalendarTimelineSection), findsNothing);
    expect(find.text('Morning pages'), findsOneWidget);
  });

  testWidgets('an empty future day offers a time capsule', (tester) async {
    await pumpCalendarPage(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.byTooltip(l10n.autoT0185));
    await tester.pumpAndSettle();
    await tester.tap(_gridDay(15));
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarFutureCapsuleAction), findsOneWidget);
    expect(find.text(l10n.autoT0181), findsNothing);
  });

  testWidgets('long pressing a day offers its actions', (tester) async {
    await pumpCalendarPage(tester);
    final l10n = _l10n(tester);
    final now = DateTime.now();
    final nextMonth15 = DateTime(now.year, now.month + 1, 15);

    await tester.tap(find.byTooltip(l10n.autoT0185));
    await tester.pumpAndSettle();
    await tester.longPress(_gridDay(15));
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarDayActionView), findsOneWidget);
    expect(find.text(l10n.calendarDayActionWrite), findsOneWidget);
    expect(find.text(l10n.calendarDayActionCapsule), findsOneWidget);

    await tester.tap(find.text(l10n.calendarDayActionView));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarDayActionView), findsNothing);
    expect(
      find.text(DateFormat.MMMd('zh').format(nextMonth15)),
      findsOneWidget,
    );

    // 过去的日期没有“时间胶囊”一项。
    await tester.tap(find.byTooltip(l10n.autoT0184));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.autoT0184));
    await tester.pumpAndSettle();
    await tester.longPress(_gridDay(15));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarDayActionWrite), findsOneWidget);
    expect(find.text(l10n.calendarDayActionCapsule), findsNothing);
  });
}
