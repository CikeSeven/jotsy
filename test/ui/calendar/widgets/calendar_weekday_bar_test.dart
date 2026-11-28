import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_summary.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_weekday_bar.dart';

import '../../../support/calendar_test_harness.dart';

const String _optionsKey = 'app.settings.calendar_display_options';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'weekday bar draws a divider aligned with the summary divider in '
      '${brightness.name} theme',
      (tester) async {
        await pumpCalendarPage(tester, brightness: brightness);

        final weekdayBar = find.byType(CalendarWeekdayBar);
        final topDivider = find.descendant(
          of: weekdayBar,
          matching: find.byType(CalendarPanelDivider),
        );
        final bottomDivider = find.descendant(
          of: find.byType(CalendarMonthSummary),
          matching: find.byType(CalendarPanelDivider),
        );
        expect(topDivider, findsOneWidget);
        expect(bottomDivider, findsOneWidget);

        final topLine = tester.widget<Divider>(
          find.descendant(of: topDivider, matching: find.byType(Divider)),
        );
        final bottomLine = tester.widget<Divider>(
          find.descendant(of: bottomDivider, matching: find.byType(Divider)),
        );
        expect(topLine.thickness, 0.6);
        expect(topLine.color, bottomLine.color);

        // 分隔线位于星期文字下方、第一行日期格上方，且与底部概览条分隔线左右对齐。
        final mondayRect = tester.getRect(find.text('一'));
        final topRect = tester.getRect(topDivider);
        final bottomRect = tester.getRect(bottomDivider);
        final firstCellRect = tester.getRect(
          find.byType(CalendarDayCell).first,
        );
        expect(topRect.top, greaterThan(mondayRect.bottom));
        expect(topRect.bottom, lessThan(firstCellRect.top));
        expect(topRect.left, moreOrLessEquals(bottomRect.left, epsilon: 0.5));
        expect(topRect.right, moreOrLessEquals(bottomRect.right, epsilon: 0.5));
      },
    );
  }

  testWidgets('weekday labels stay aligned with day columns when week numbers '
      'are shown under enlarged text scaling', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpCalendarPage(
      tester,
      width: 321.6,
      prefs: <String, Object>{
        _optionsKey: const CalendarDisplayOptions(
          showWeekNumbers: true,
          highlightWeekends: true,
        ).encode(),
      },
    );

    const labels = <String>['一', '二', '三', '四', '五', '六', '日'];
    final cells = find.byType(CalendarDayCell);
    for (var col = 0; col < labels.length; col++) {
      final headerX = tester.getCenter(find.text(labels[col])).dx;
      final cellX = tester.getCenter(cells.at(col)).dx;
      expect(
        headerX,
        moreOrLessEquals(cellX, epsilon: 1),
        reason: 'column $col (${labels[col]})',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide window weekend weekday pill aligns with weekend cells and '
      'stays fixed while swiping months', (tester) async {
    await pumpCalendarPage(
      tester,
      width: 1280,
      height: 800,
      prefs: <String, Object>{
        _optionsKey: const CalendarDisplayOptions(
          highlightWeekends: true,
        ).encode(),
      },
    );

    final saturdayHeader = find.text('六');
    final sundayHeader = find.text('日');
    final saturdayCell = find.byType(CalendarDayCell).at(5);
    final sundayCell = find.byType(CalendarDayCell).at(6);
    expect(
      tester.getCenter(saturdayHeader).dx,
      moreOrLessEquals(tester.getCenter(saturdayCell).dx, epsilon: 1),
    );
    expect(
      tester.getCenter(sundayHeader).dx,
      moreOrLessEquals(tester.getCenter(sundayCell).dx, epsilon: 1),
    );

    final barRectBefore = tester.getRect(find.byType(CalendarWeekdayBar));
    final beforeMonth = tester
        .widget<CalendarMonthGrid>(find.byType(CalendarMonthGrid))
        .focusedDay;
    await swipeCalendarPage(tester);
    final afterMonth = tester
        .widget<CalendarMonthGrid>(find.byType(CalendarMonthGrid))
        .focusedDay;
    expect(
      DateTime(afterMonth.year, afterMonth.month),
      DateTime(beforeMonth.year, beforeMonth.month + 1),
    );
    expect(tester.getRect(find.byType(CalendarWeekdayBar)), barRectBefore);
    expect(tester.takeException(), isNull);
  });
}
