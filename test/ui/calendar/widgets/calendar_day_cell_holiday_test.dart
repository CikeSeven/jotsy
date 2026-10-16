import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_holiday_day.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/widgets/qweather_icon.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  const rest = CalendarHolidayDay(name: '国庆节', isWork: false);
  const work = CalendarHolidayDay(name: '国庆节', isWork: true);
  final day = DateTime(2026, 10, 1);

  CalendarDaySummary summaryOf(DiaryCalendarMarker marker) {
    return CalendarDaySummary.groupByDay(
      <DiaryCalendarMarker>[marker],
      now: DateTime(2026, 10, 1, 12),
      moodOptions: SettingsService.defaultMoodOptions,
    )[day]!;
  }

  Future<ColorScheme> pumpCell(
    WidgetTester tester, {
    CalendarDisplayOptions options = const CalendarDisplayOptions(),
    CalendarHolidayDay? holiday,
    CalendarDaySummary? summary,
    bool isSelected = false,
    bool isWeekend = false,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: expressiveTestTheme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 40,
            height: 52,
            child: CalendarDayCell(
              day: day,
              options: options,
              isToday: false,
              isSelected: isSelected,
              isOutside: false,
              isWeekend: isWeekend,
              summary: summary,
              holiday: holiday,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return Theme.of(tester.element(find.byType(CalendarDayCell))).colorScheme;
  }

  Color? outerFill(WidgetTester tester) {
    final outer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    return (outer.decoration! as BoxDecoration).color;
  }

  for (final brightness in Brightness.values) {
    testWidgets('休 and 班 sit at the top left of the number '
        '(${brightness.name})', (tester) async {
      final colorScheme = await pumpCell(
        tester,
        holiday: rest,
        brightness: brightness,
      );
      final mark = tester.getRect(find.text('休'));
      final number = tester.getRect(find.text('1'));
      expect(number.left - mark.right, inInclusiveRange(0, 3));
      expect(mark.top, lessThan(number.top));
      expect(mark.overlaps(number), isFalse);
      expect(
        tester.widget<Text>(find.text('休')).style?.color,
        colorScheme.tertiary,
      );

      await pumpCell(tester, holiday: work, brightness: brightness);
      expect(find.text('班'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('班')).style?.color,
        colorScheme.onSurfaceVariant,
      );

      await pumpCell(
        tester,
        holiday: rest,
        isSelected: true,
        brightness: brightness,
      );
      expect(
        tester.widget<Text>(find.text('休')).style?.color,
        colorScheme.onPrimary,
      );
    });
  }

  testWidgets('the capsule lock outranks 休, and 休 outranks the weather', (
    tester,
  ) async {
    await pumpCell(
      tester,
      holiday: rest,
      summary: summaryOf(
        DiaryCalendarMarker(
          diaryId: 'capsule',
          createdAt: DateTime(2026, 10, 1, 8),
          capsuleUnlockAt: DateTime(2026, 12, 1),
        ),
      ),
    );
    expect(find.byIcon(FontAwesomeIcons.lock.data), findsOneWidget);
    expect(find.text('休'), findsNothing);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(showWeatherBadge: true),
      holiday: rest,
      summary: summaryOf(
        DiaryCalendarMarker(
          diaryId: 'sunny',
          createdAt: DateTime(2026, 10, 1, 8),
          weather: '晴',
          weatherIconCode: '100',
        ),
      ),
    );
    expect(find.text('休'), findsOneWidget);
    expect(find.byType(QWeatherIcon), findsNothing);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(showWeatherBadge: true),
      summary: summaryOf(
        DiaryCalendarMarker(
          diaryId: 'sunny',
          createdAt: DateTime(2026, 10, 1, 8),
          weather: '晴',
          weatherIconCode: '100',
        ),
      ),
    );
    expect(find.byType(QWeatherIcon), findsOneWidget);
  });

  testWidgets('weekend shading follows days off rather than weekdays', (
    tester,
  ) async {
    const options = CalendarDisplayOptions(highlightWeekends: true);
    // 周四放假：着色。
    final colorScheme = await pumpCell(tester, options: options, holiday: rest);
    expect(outerFill(tester), CalendarDayCell.weekendColor(colorScheme));

    // 调休上班的周六：不着色。
    await pumpCell(tester, options: options, holiday: work, isWeekend: true);
    expect(outerFill(tester)!.a, 0);

    // 普通周末照旧着色，关闭周末着色时放假日也不着色。
    await pumpCell(tester, options: options, isWeekend: true);
    expect(outerFill(tester), CalendarDayCell.weekendColor(colorScheme));
    await pumpCell(tester, holiday: rest);
    expect(outerFill(tester)!.a, 0);
  });

  testWidgets('heat cells write 休 in the cell foreground once filled', (
    tester,
  ) async {
    const options = CalendarDisplayOptions(cellStyle: CalendarCellStyle.heat);
    final colorScheme = await pumpCell(tester, options: options, holiday: rest);
    Color? markColor() => tester.widget<Text>(find.text('休')).style?.color;
    expect(markColor(), colorScheme.tertiary);

    // 有数据的热力格底色是 primary 色阶，tertiary 字会撞色，改用前景色。
    await pumpCell(
      tester,
      options: options,
      holiday: rest,
      summary: summaryOf(
        DiaryCalendarMarker(
          diaryId: 'heat',
          createdAt: DateTime(2026, 10, 1, 8),
          charCount: 2000,
        ),
      ),
    );
    expect(markColor(), anyOf(colorScheme.onPrimary, colorScheme.onSurface));
  });
}
