import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';

import '../../support/calendar_test_harness.dart';

const _optionsKey = 'app.settings.calendar_display_options';

Finder get _todayCell => find.byWidgetPredicate(
  (Widget widget) => widget is CalendarDayCell && widget.isToday,
);

Iterable<CalendarDayCell> _cells(WidgetTester tester) =>
    tester.widgetList<CalendarDayCell>(find.byType(CalendarDayCell));

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('Chinese shows lunar dates by default, English does not', (
        tester,
      ) async {
        final today = DateUtils.dateOnly(DateTime.now());
        final lunar = CalendarLunarDay.of(today);

        await pumpCalendarPage(tester, brightness: brightness);
        final l10n = tester.element(find.byType(CalendarPage)).l10n;
        expect(_cells(tester).every((cell) => cell.lunar != null), isTrue);
        expect(
          tester.widget<CalendarDayCell>(_todayCell).lunar?.date,
          lunar.date,
        );
        expect(
          tester.getSize(_todayCell).height,
          CalendarMonthGrid.lunarRowHeight,
        );
        expect(
          find.textContaining(l10n.calendarLunarDate(lunar.date)),
          findsOneWidget,
        );

        await pumpCalendarPage(
          tester,
          brightness: brightness,
          locale: const Locale('en'),
        );
        expect(_cells(tester).every((cell) => cell.lunar == null), isTrue);
        expect(tester.getSize(_todayCell).height, CalendarMonthGrid.rowHeight);
        expect(find.textContaining(lunar.date), findsNothing);
      });

      testWidgets('the sheet turns lunar dates on in English and persists', (
        tester,
      ) async {
        final settings = await pumpCalendarPage(
          tester,
          brightness: brightness,
          locale: const Locale('en'),
        );
        final l10n = tester.element(find.byType(CalendarPage)).l10n;

        await tester.tap(find.byTooltip(l10n.calendarDisplayOptionsTooltip));
        await tester.pumpAndSettle();
        // “农历与节假日”分组里农历在前、节假日在后，两组用同一套文案。
        final show = find.text(l10n.calendarLunarAlways).first;
        await tester.ensureVisible(show);
        await tester.pumpAndSettle();
        await tester.tap(show);
        await tester.pumpAndSettle();

        expect(_cells(tester).every((cell) => cell.lunar != null), isTrue);
        final saved = CalendarDisplayOptions.decode(
          settings.calendarDisplayOptionsRaw,
        );
        expect(saved.lunarMode, CalendarLunarMode.always);
        expect(saved.holidayMode, CalendarLunarMode.locale);
      });

      testWidgets('the sheet turns holidays on in English and persists', (
        tester,
      ) async {
        final settings = await pumpCalendarPage(
          tester,
          brightness: brightness,
          locale: const Locale('en'),
        );
        final l10n = tester.element(find.byType(CalendarPage)).l10n;

        await tester.tap(find.byTooltip(l10n.calendarDisplayOptionsTooltip));
        await tester.pumpAndSettle();
        expect(find.text(l10n.calendarOptionsHolidays), findsOneWidget);
        final show = find.text(l10n.calendarLunarAlways).last;
        await tester.ensureVisible(show);
        await tester.pumpAndSettle();
        await tester.tap(show);
        await tester.pumpAndSettle();

        final saved = CalendarDisplayOptions.decode(
          settings.calendarDisplayOptionsRaw,
        );
        expect(saved.holidayMode, CalendarLunarMode.always);
        expect(saved.lunarMode, CalendarLunarMode.locale);
        expect(_cells(tester).every((cell) => cell.lunar == null), isTrue);
      });

      testWidgets('"hide" removes lunar dates in Chinese', (tester) async {
        await pumpCalendarPage(
          tester,
          brightness: brightness,
          prefs: <String, Object>{
            _optionsKey: const CalendarDisplayOptions(
              lunarMode: CalendarLunarMode.never,
            ).encode(),
          },
        );

        expect(_cells(tester).every((cell) => cell.lunar == null), isTrue);
        expect(tester.getSize(_todayCell).height, CalendarMonthGrid.rowHeight);
        final l10n = tester.element(find.byType(CalendarPage)).l10n;
        expect(find.textContaining(l10n.calendarLunarDate('')), findsNothing);
      });

      testWidgets('lunar labels fit a 320dp screen with week numbers', (
        tester,
      ) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 9);
        final markers = <DiaryCalendarMarker>[
          for (var index = 0; index < 12; index++)
            DiaryCalendarMarker(
              diaryId: 'busy-$index',
              createdAt: today.add(Duration(minutes: index)),
              moodEmoji: '😀',
              wordCount: 900,
              cover: '/does/not/exist.jpg',
              weather: '晴',
              weatherIconCode: '100',
              tagColors: const <int>[0xFFE57373, 0xFF64B5F6, 0xFF81C784],
            ),
          DiaryCalendarMarker(
            diaryId: 'capsule',
            createdAt: today.subtract(const Duration(days: 1)),
            capsuleUnlockAt: today.add(const Duration(days: 30)),
          ),
        ];
        for (final scale in <double>[1, 1.3]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          for (final style in CalendarCellStyle.values) {
            await pumpCalendarPage(
              tester,
              brightness: brightness,
              width: 321.6,
              markers: markers,
              prefs: <String, Object>{
                _optionsKey: CalendarDisplayOptions(
                  cellStyle: style,
                  showWeekNumbers: true,
                  showWeatherBadge: true,
                  highlightWeekends: true,
                ).encode(),
              },
            );
            expect(tester.takeException(), isNull, reason: '$style x$scale');
            expect(
              tester.widget<CalendarDayCell>(_todayCell).lunar,
              isNotNull,
              reason: '$style x$scale',
            );
          }
        }
      });
    });
  }
}
