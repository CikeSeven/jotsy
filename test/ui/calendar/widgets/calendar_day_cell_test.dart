import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';

void main() {
  const moods = SettingsService.defaultMoodOptions;
  final day = DateTime(2026, 3, 12);

  CalendarDaySummary summaryOf(List<DiaryCalendarMarker> markers) {
    return CalendarDaySummary.groupByDay(
      markers,
      now: DateTime(2026, 3, 15),
      moodOptions: moods,
    )[day]!;
  }

  DiaryCalendarMarker entry(int hour, {String? mood, int chars = 0}) {
    return DiaryCalendarMarker(
      diaryId: 'd$hour',
      createdAt: DateTime(2026, 3, 12, hour),
      moodEmoji: mood,
      charCount: chars,
    );
  }

  Future<void> pumpCell(
    WidgetTester tester, {
    required CalendarDisplayOptions options,
    CalendarDaySummary? summary,
    bool isSelected = false,
    bool isToday = false,
    String? image,
    Brightness brightness = Brightness.light,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1E6586),
          brightness: brightness,
        ),
        home: Center(
          child: SizedBox(
            width: 40,
            height: 52,
            child: CalendarDayCell(
              day: day,
              options: options,
              isToday: isToday,
              isSelected: isSelected,
              isOutside: false,
              isWeekend: false,
              summary: summary,
              image: image,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('mood style shows the average or every entry', (tester) async {
    final summary = summaryOf(<DiaryCalendarMarker>[
      entry(8, mood: moods[0]),
      entry(9, mood: moods[9]),
    ]);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(),
      summary: summary,
    );
    expect(find.text(moods[5]), findsOneWidget);
    expect(find.text(moods[0]), findsNothing);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(
        moodAggregation: CalendarMoodAggregation.each,
      ),
      summary: summary,
    );
    expect(find.text(moods[0]), findsOneWidget);
    expect(find.text(moods[9]), findsOneWidget);
  });

  testWidgets('count badge follows its switch', (tester) async {
    final summary = summaryOf(<DiaryCalendarMarker>[entry(8), entry(9)]);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(cellStyle: CalendarCellStyle.dot),
      summary: summary,
    );
    expect(find.text('2'), findsOneWidget);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(
        cellStyle: CalendarCellStyle.dot,
        showCountBadge: false,
      ),
      summary: summary,
    );
    expect(find.text('2'), findsNothing);
  });

  testWidgets('a sealed capsule shows only the lock', (tester) async {
    final summary = summaryOf(<DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'capsule',
        createdAt: DateTime(2026, 3, 12, 8),
        moodEmoji: moods[9],
        capsuleUnlockAt: DateTime(2026, 3, 30),
      ),
    ]);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(),
      summary: summary,
    );

    expect(find.byIcon(FontAwesomeIcons.lock.data), findsOneWidget);
    expect(find.text(moods[9]), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('heat cells tint by level with readable numbers '
        '(${brightness.name})', (tester) async {
      final summary = summaryOf(<DiaryCalendarMarker>[entry(8, chars: 900)]);

      await pumpCell(
        tester,
        options: const CalendarDisplayOptions(
          cellStyle: CalendarCellStyle.heat,
          heatBasis: CalendarHeatBasis.words,
        ),
        summary: summary,
        brightness: brightness,
      );

      final colorScheme = Theme.of(
        tester.element(find.byType(CalendarDayCell)),
      ).colorScheme;
      final expected = CalendarDayCell.heatColorFor(colorScheme, 3);
      final tinted = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((container) => (container.decoration as BoxDecoration?)?.color)
          .contains(expected);
      expect(tinted, isTrue);

      final number = tester.widget<Text>(find.text('12'));
      expect(
        number.style?.color,
        anyOf(colorScheme.onPrimary, colorScheme.onSurface),
      );
    });
  }

  testWidgets('photo style falls back to dots when the day has no photo', (
    tester,
  ) async {
    final summary = summaryOf(<DiaryCalendarMarker>[entry(8)]);
    const options = CalendarDisplayOptions(cellStyle: CalendarCellStyle.photo);

    await pumpCell(tester, options: options, summary: summary);
    expect(find.byType(Image), findsNothing);

    await pumpCell(
      tester,
      options: options,
      summary: summary,
      image: '/does/not/exist.jpg',
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('selection keeps the same rounded shape in every style', (
    tester,
  ) async {
    for (final style in CalendarCellStyle.values) {
      await pumpCell(
        tester,
        options: CalendarDisplayOptions(cellStyle: style),
        summary: summaryOf(<DiaryCalendarMarker>[entry(8)]),
        isSelected: true,
      );
      await tester.pumpAndSettle();
      final outer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = outer.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(14),
        reason: '$style',
      );
      expect(decoration.shape, BoxShape.rectangle, reason: '$style');
    }
  });
}
