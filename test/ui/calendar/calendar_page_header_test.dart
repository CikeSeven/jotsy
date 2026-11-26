import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_heading.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_year_view.dart';
import 'package:node_diary/ui/widgets/page_header.dart';

import '../../support/calendar_test_harness.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

Finder _monthTitle(DateTime month) => find.descendant(
  of: find.byType(CalendarHeader),
  matching: find.text(DateFormat.yMMM('zh').format(month)),
);

void main() {
  testWidgets('the header is one fixed row titled with the month', (
    tester,
  ) async {
    // 视口不高：月视图 + 选中日区域足以向下滚动。
    await pumpCalendarPage(tester, height: 600);
    final l10n = _l10n(tester);
    final now = DateTime.now();

    // 与其他 Tab 同一个页头：单行 64dp，标题就是当前月份，手机上不放翻月
    // 箭头（靠左右滑网格）。
    expect(find.byType(PageHeader), findsOneWidget);
    expect(
      tester.getSize(find.byType(PageHeader)).height,
      CalendarHeader.height,
    );
    expect(_monthTitle(now), findsOneWidget);
    expect(find.text(l10n.autoT0183), findsNothing);
    expect(find.byTooltip(l10n.autoT0184), findsNothing);
    expect(find.byTooltip(l10n.autoT0185), findsNothing);
    final headerRect = tester.getRect(find.byType(PageHeader));
    final gridTop = tester.getTopLeft(find.byType(CalendarMonthGrid)).dy;
    expect(gridTop, greaterThan(headerRect.bottom));

    // 往上拖（网格上的竖向滑动是切换月 / 周，从选中日标题处拖）：页头
    // 不动，内容从它下面滚过。
    await tester.drag(find.byType(CalendarDayHeading), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PageHeader)), headerRect);
    expect(
      tester.getTopLeft(find.byType(CalendarMonthGrid)).dy,
      lessThan(gridTop),
    );
    expect(find.byTooltip(l10n.autoT0180).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping the grid changes the month in the title', (
    tester,
  ) async {
    await pumpCalendarPage(tester);
    final now = DateTime.now();

    await swipeCalendarPage(tester);
    expect(_monthTitle(DateTime(now.year, now.month + 1)), findsOneWidget);
    await swipeCalendarPage(tester, forward: false);
    expect(_monthTitle(now), findsOneWidget);
  });

  testWidgets('tapping the month title opens the year view whose own arrows '
      'change the year on a phone', (tester) async {
    await pumpCalendarPage(tester);
    final l10n = _l10n(tester);
    final year = DateTime.now().year;

    await tester.tap(_monthTitle(DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarYearView), findsOneWidget);
    final yearTitle = find.descendant(
      of: find.byType(CalendarHeader),
      matching: find.text(DateFormat.y('zh').format(DateTime(year))),
    );
    expect(yearTitle, findsOneWidget);

    // 年视图不能左右滑：手机上上一年 / 下一年在年视图里，页头仍没有箭头。
    final nextYear = find.descendant(
      of: find.byType(CalendarYearView),
      matching: find.byTooltip(l10n.calendarNextYear),
    );
    expect(nextYear, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CalendarHeader),
        matching: find.byTooltip(l10n.calendarNextYear),
      ),
      findsNothing,
    );
    await tester.tap(nextYear);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CalendarYearView>(find.byType(CalendarYearView)).year,
      year + 1,
    );
    await tester.tap(find.byTooltip(l10n.calendarPreviousYear));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CalendarYearView>(find.byType(CalendarYearView)).year,
      year,
    );
  });

  testWidgets('a wide window keeps the arrows in the header only', (
    tester,
  ) async {
    await pumpCalendarPage(tester, width: 800, height: 900);
    final l10n = _l10n(tester);
    final now = DateTime.now();

    await tester.tap(find.byTooltip(l10n.autoT0185));
    await tester.pumpAndSettle();
    expect(_monthTitle(DateTime(now.year, now.month + 1)), findsOneWidget);

    await tester.tap(_monthTitle(DateTime(now.year, now.month + 1)));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(CalendarYearView),
        matching: find.byTooltip(l10n.calendarNextYear),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(CalendarHeader),
        matching: find.byTooltip(l10n.calendarNextYear),
      ),
      findsOneWidget,
    );
  });
}
