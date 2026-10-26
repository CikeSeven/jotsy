import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_heading.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_year_view.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../support/calendar_test_harness.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

Finder _gridDay(int day) => find.descendant(
  of: find.byType(CalendarMonthGrid),
  matching: find.text('$day'),
);

/// 当月里与今天不同的一个中段日期（只在网格里出现一次）。
int _otherMidMonthDay(DateTime now) => now.day == 15 ? 16 : 15;

/// 选中 [day] 当天的若干篇日记，标题为“`日` 号 第 `n` 篇”。
List<DiaryWithTags> _diariesOn(DateTime day, {int count = 1}) => [
  for (var i = 0; i < count; i++)
    calendarTestDiary(
      'wide-${day.month}-${day.day}-$i',
      DateTime(day.year, day.month, day.day, 8 + i),
      title: '${day.day} 号 第 $i 篇',
    ),
];

void main() {
  testWidgets('a 1280 wide window shows the calendar and the day side by side '
      'and picking a day updates the right column', (tester) async {
    final now = DateTime.now();
    final other = DateTime(now.year, now.month, _otherMidMonthDay(now));
    await pumpCalendarPage(
      tester,
      width: 1280,
      height: 800,
      prefs: <String, Object>{
        'app.settings.calendar_display_options': const CalendarDisplayOptions(
          dayContentStyle: CalendarDayContentStyle.cards,
        ).encode(),
      },
      dayDiaries: (day) => DateUtils.isSameDay(day, other)
          ? _diariesOn(other, count: 8)
          : const <DiaryWithTags>[],
    );
    final l10n = _l10n(tester);

    final gridRect = tester.getRect(find.byType(CalendarMonthGrid));
    final headingRect = tester.getRect(find.byType(CalendarDayHeading));
    // 左栏 600 宽（1280 × 0.5 夹到 600），右栏在其右侧 16 之外。
    expect(gridRect.width, lessThanOrEqualTo(600));
    expect(headingRect.left, greaterThan(gridRect.right));
    expect(headingRect.top, lessThan(gridRect.bottom));
    // 内容容器居中到 1200：左缘 40 处是日历卡片。
    expect(gridRect.left, greaterThanOrEqualTo(40));
    // 宽格子的行高随格宽加高，不再是手机上的 52。
    expect(
      tester
          .widget<TableCalendar<DiaryCalendarMarker>>(
            find.byType(TableCalendar<DiaryCalendarMarker>),
          )
          .rowHeight,
      greaterThan(CalendarMonthGrid.rowHeight),
    );
    // 月份行在左栏卡片正上方、与卡片同宽，页头只留标题栏。
    expect(find.byTooltip(l10n.autoT0184).hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CalendarHeader),
        matching: find.byType(CalendarMonthBar),
      ),
      findsNothing,
    );
    final monthBar = tester.getRect(find.byType(CalendarMonthBar));
    expect(monthBar.left, 40);
    expect(monthBar.width, 600);
    expect(monthBar.bottom, lessThan(gridRect.top));
    // 日期高亮保持手机比例：选中的今天最宽 64，居中在格子里。
    final cellRect = tester.getRect(
      find
          .descendant(
            of: find.byType(CalendarDayCell),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(cellRect.width, lessThanOrEqualTo(64));

    await tester.tap(_gridDay(other.day));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CalendarDayHeading>(find.byType(CalendarDayHeading)).day,
      other,
    );
    expect(find.text('${other.day} 号 第 0 篇'), findsOneWidget);

    // 右栏单独滚动，左栏的日历不动。
    final firstTitle = find.text('${other.day} 号 第 0 篇');
    final titleTop = tester.getTopLeft(firstTitle).dy;
    await tester.drag(firstTitle, const Offset(0, -120), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CalendarMonthGrid)), gridRect);
    expect(find.byTooltip(l10n.autoT0184).hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(firstTitle).dy, lessThan(titleTop - 60));
  });

  testWidgets('the year view stays in the left column of a wide window', (
    tester,
  ) async {
    await pumpCalendarPage(tester, width: 1280, height: 800);
    final l10n = _l10n(tester);

    await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
    await tester.pumpAndSettle();

    final yearRect = tester.getRect(find.byType(CalendarYearView));
    expect(yearRect.width, lessThanOrEqualTo(600));
    expect(
      tester.getRect(find.byType(CalendarDayHeading)).left,
      greaterThan(yearRect.right),
    );
  });

  testWidgets('a 900 wide window keeps one column centred at 720', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpCalendarPage(
      tester,
      width: 900,
      height: 700,
      dayDiaries: (day) => DateUtils.isSameDay(day, now)
          ? _diariesOn(now)
          : const <DiaryWithTags>[],
    );
    final l10n = _l10n(tester);

    final gridRect = tester.getRect(find.byType(CalendarMonthGrid));
    final headingRect = tester.getRect(find.byType(CalendarDayHeading));
    // 单列：标题在日历下方，两者都在居中的 720 列里（左右各 90 留白）。
    expect(headingRect.top, greaterThanOrEqualTo(gridRect.bottom));
    expect(gridRect.left, greaterThanOrEqualTo(90));
    expect(gridRect.right, lessThanOrEqualTo(810));
    expect(headingRect.left, greaterThanOrEqualTo(90));
    expect(headingRect.right, lessThanOrEqualTo(810));
    expect(gridRect.center.dx, moreOrLessEquals(450, epsilon: 1));
    // 页头底色铺满，按钮行与这一列对齐。
    expect(
      tester.getTopLeft(find.text(l10n.autoT0183)).dx,
      moreOrLessEquals(106, epsilon: 1),
    );
  });

  testWidgets('a phone width keeps the fixed row height', (tester) async {
    await pumpCalendarPage(tester);

    expect(
      tester
          .widget<TableCalendar<DiaryCalendarMarker>>(
            find.byType(TableCalendar<DiaryCalendarMarker>),
          )
          .rowHeight,
      CalendarMonthGrid.lunarRowHeight,
    );
    final gridRect = tester.getRect(find.byType(CalendarMonthGrid));
    expect(
      tester.getRect(find.byType(CalendarDayHeading)).top,
      greaterThanOrEqualTo(gridRect.bottom),
    );
  });

  test('wide rows follow 0.6 of the cell width within 56 to 76', () {
    expect(CalendarMonthGrid.wideRowHeight(300, lunar: false), 56);
    expect(
      CalendarMonthGrid.wideRowHeight(700, lunar: false),
      moreOrLessEquals(60),
    );
    expect(
      CalendarMonthGrid.wideRowHeight(700, lunar: true),
      moreOrLessEquals(68),
    );
    expect(CalendarMonthGrid.wideRowHeight(1400, lunar: false), 76);
    expect(CalendarMonthGrid.wideRowHeight(1400, lunar: true), 84);
  });

  for (final size in const <Size>[Size(1183.2, 800), Size(901.6, 700)]) {
    testWidgets('a fractional ${size.width} wide window pages months '
        'without a precision assertion', (tester) async {
      await pumpCalendarPage(tester, width: size.width, height: size.height);
      final l10n = _l10n(tester);
      final now = DateTime.now();

      expect(
        tester.getSize(find.byType(TableCalendar<DiaryCalendarMarker>)).width %
            1,
        0,
      );
      // 按钮翻一页、再左滑翻一页。
      await tester.tap(find.byTooltip(l10n.autoT0185));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CalendarMonthGrid),
        const Offset(-400, 0),
        1500,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final focused = tester
          .widget<CalendarMonthGrid>(find.byType(CalendarMonthGrid))
          .focusedDay;
      expect(
        DateTime(focused.year, focused.month),
        DateTime(now.year, now.month + 2),
      );
    });
  }
}
