import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_holiday_day.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_cell_marks.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  // 10 月 1 日：国庆节（节日小字）、放假日。
  final day = DateTime(2026, 10, 1);
  final heart = find.byIcon(FontAwesomeIcons.solidHeart.data);

  Future<ColorScheme> pumpCell(
    WidgetTester tester, {
    CalendarDisplayOptions options = const CalendarDisplayOptions(),
    String? anniversary,
    bool lunar = true,
    CalendarHolidayDay? holiday,
    CalendarDaySummary? summary,
    String? image,
    bool isSelected = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 44,
            height: 60,
            child: CalendarDayCell(
              day: day,
              options: options,
              isToday: false,
              isSelected: isSelected,
              isOutside: false,
              isWeekend: false,
              summary: summary,
              image: image,
              lunar: lunar ? CalendarLunarDay.of(day) : null,
              holiday: holiday,
              anniversary: anniversary,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return Theme.of(tester.element(find.byType(CalendarDayCell))).colorScheme;
  }

  testWidgets('the anniversary name takes the lunar line over festivals', (
    tester,
  ) async {
    final colorScheme = await pumpCell(tester);
    expect(find.text('国庆节'), findsOneWidget);

    await pumpCell(tester, anniversary: '在一起');
    expect(find.text('在一起'), findsOneWidget);
    expect(find.text('国庆节'), findsNothing);
    expect(heart, findsNothing);
    final style = tester.widget<Text>(find.text('在一起')).style!;
    expect(style.color, colorScheme.tertiary);
    expect(style.fontWeight, FontWeight.w600);

    await pumpCell(tester, anniversary: '在一起', isSelected: true);
    expect(
      tester.widget<Text>(find.text('在一起')).style?.color,
      colorScheme.onPrimary,
    );
  });

  testWidgets('without lunar dates a heart marks the day', (tester) async {
    await pumpCell(tester, anniversary: '在一起', lunar: false);
    expect(find.text('在一起'), findsNothing);
    expect(heart, findsOneWidget);
    final mark = tester.getRect(heart);
    final number = tester.getRect(find.text('1'));
    expect(number.left - mark.right, inInclusiveRange(0, 3));
    expect(mark.overlaps(number), isFalse);
  });

  testWidgets('休 and the capsule lock outrank the heart', (tester) async {
    const rest = CalendarHolidayDay(name: '国庆节', isWork: false);
    await pumpCell(tester, anniversary: 'a', lunar: false, holiday: rest);
    expect(find.text('休'), findsOneWidget);
    expect(heart, findsNothing);

    final capsule = CalendarDaySummary.groupByDay(
      <DiaryCalendarMarker>[
        DiaryCalendarMarker(
          diaryId: 'capsule',
          createdAt: DateTime(2026, 10, 1, 8),
          capsuleUnlockAt: DateTime(2026, 12, 1),
        ),
      ],
      now: DateTime(2026, 10, 1, 12),
      moodOptions: SettingsService.defaultMoodOptions,
    )[day];
    await pumpCell(
      tester,
      anniversary: 'a',
      lunar: false,
      holiday: rest,
      summary: capsule,
    );
    expect(find.byIcon(FontAwesomeIcons.lock.data), findsOneWidget);
    expect(find.text('休'), findsNothing);
    expect(heart, findsNothing);
  });

  testWidgets('photo cells write the name inside the date backdrop', (
    tester,
  ) async {
    final summary = CalendarDaySummary.groupByDay(
      <DiaryCalendarMarker>[
        DiaryCalendarMarker(
          diaryId: 'photo',
          createdAt: DateTime(2026, 10, 1, 8),
          cover: 'https://example.invalid/cover.jpg',
        ),
      ],
      now: DateTime(2026, 10, 1, 12),
      moodOptions: SettingsService.defaultMoodOptions,
    )[day];
    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(cellStyle: CalendarCellStyle.photo),
      anniversary: '在一起',
      summary: summary,
      image: 'https://example.invalid/cover.jpg',
    );
    expect(find.text('在一起'), findsOneWidget);
  });

  test('long names are shortened to fit the cell', () {
    expect(CalendarCellSubtitle.shortTitle('  妈妈生日 '), '妈妈生日');
    expect(CalendarCellSubtitle.shortTitle('结婚纪念日'), '结婚纪…');
    expect(CalendarCellSubtitle.shortTitle('我们在一起的日子'), '我们在…');
    expect(CalendarCellSubtitle.shortTitle('Wedding'), 'Wedding');
    expect(CalendarCellSubtitle.shortTitle("Mom's birthday"), "Mom's…");
  });
}
