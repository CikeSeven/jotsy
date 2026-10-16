import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_summary.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_range_header.dart';

import '../../support/calendar_test_harness.dart';

Finder _cellOf(int day) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is CalendarDayCell && !widget.isOutside && widget.day.day == day,
);

CalendarDayCell _cell(WidgetTester tester, int day) =>
    tester.widget<CalendarDayCell>(_cellOf(day));

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

Future<void> _startRangeAt(WidgetTester tester, int day) async {
  await tester.longPress(_cellOf(day));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n(tester).calendarDayActionRange));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  DiaryCalendarMarker entry(String id, int day, {int chars = 10}) =>
      DiaryCalendarMarker(
        diaryId: id,
        createdAt: DateTime(now.year, now.month, day, 9),
        charCount: chars,
      );
  final markers = <DiaryCalendarMarker>[
    entry('a', 5),
    entry('b', 5),
    entry('c', 12),
    // 范围之外：不应计入范围统计。
    entry('d', 20),
  ];

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('a range from the long-press menu shows its own stats', (
        tester,
      ) async {
        await pumpCalendarPage(
          tester,
          brightness: brightness,
          markers: markers,
        );
        final l10n = _l10n(tester);
        // 月度概览统计整月 4 篇。
        expect(find.byTooltip(l10n.calendarSummaryEntries(4)), findsOneWidget);

        await _startRangeAt(tester, 12);
        final format = DateFormat.MMMd(l10n.localeName);
        expect(
          find.text(
            l10n.calendarRangePickEnd(
              format.format(DateTime(now.year, now.month, 12)),
            ),
          ),
          findsOneWidget,
        );
        expect(_cell(tester, 12).isSelected, isTrue);

        // 终点点在起点之前：自动交换为 3 日 – 12 日。
        await tester.tap(_cellOf(3));
        await tester.pumpAndSettle();
        expect(
          find.text(
            l10n.calendarRangeTitle(
              format.format(DateTime(now.year, now.month, 3)),
              format.format(DateTime(now.year, now.month, 12)),
              10,
            ),
          ),
          findsOneWidget,
        );
        expect(_cell(tester, 3).isSelected, isTrue);
        expect(_cell(tester, 12).isSelected, isTrue);
        expect(_cell(tester, 7).inRange, isTrue);
        expect(_cell(tester, 13).inRange, isFalse);
        expect(find.byTooltip(l10n.calendarSummaryEntries(3)), findsOneWidget);
        expect(find.byTooltip(l10n.calendarSummaryStreak(1)), findsOneWidget);

        await tester.tap(find.byTooltip(l10n.calendarRangeExit));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarRangeHeader), findsNothing);
        expect(_cell(tester, 7).inRange, isFalse);
        expect(_cell(tester, 12).isSelected, isFalse);
        expect(_cell(tester, 3).isSelected, isTrue);
        expect(find.byTooltip(l10n.calendarSummaryEntries(4)), findsOneWidget);
      });

      testWidgets(
        'range stats show even with the monthly summary turned off, and '
        'returning to today leaves the range',
        (tester) async {
          await pumpCalendarPage(
            tester,
            brightness: brightness,
            markers: markers,
            prefs: <String, Object>{
              'app.settings.calendar_display_options':
                  const CalendarDisplayOptions(
                    showMonthSummary: false,
                  ).encode(),
            },
          );
          expect(find.byType(CalendarMonthSummary), findsNothing);

          await _startRangeAt(tester, 20);
          await tester.tap(_cellOf(25));
          await tester.pumpAndSettle();
          final l10n = _l10n(tester);
          expect(find.byType(CalendarRangeHeader), findsOneWidget);
          expect(
            find.byTooltip(l10n.calendarSummaryEntries(1)),
            findsOneWidget,
          );

          await tester.tap(find.byTooltip(l10n.autoT0180));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarMonthSummary), findsNothing);
          expect(_cell(tester, 22).inRange, isFalse);
        },
      );
    });
  }
}
