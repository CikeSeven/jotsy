import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell_parts.dart';

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
    bool isWeekend = false,
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
              isWeekend: isWeekend,
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
      options: const CalendarDisplayOptions(cellStyle: CalendarCellStyle.tags),
      summary: summary,
    );
    expect(find.text('2'), findsOneWidget);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(
        cellStyle: CalendarCellStyle.tags,
        showCountBadge: false,
      ),
      summary: summary,
    );
    expect(find.text('2'), findsNothing);
  });

  testWidgets('one mark per entry makes the count badge redundant', (
    tester,
  ) async {
    const dots = CalendarDisplayOptions(cellStyle: CalendarCellStyle.dot);
    await pumpCell(
      tester,
      options: dots,
      summary: summaryOf(<DiaryCalendarMarker>[entry(8), entry(9)]),
    );
    expect(find.byType(CalendarCellCountMark), findsNothing);

    // 超过 3 个记号的上限时仍要标出篇数。
    await pumpCell(
      tester,
      options: dots,
      summary: summaryOf(<DiaryCalendarMarker>[
        for (var hour = 8; hour < 12; hour++) entry(hour),
      ]),
    );
    expect(find.text('4'), findsOneWidget);

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(
        moodAggregation: CalendarMoodAggregation.each,
      ),
      summary: summaryOf(<DiaryCalendarMarker>[
        entry(8, mood: moods[1]),
        entry(9, mood: moods[8]),
      ]),
    );
    expect(find.byType(CalendarCellCountMark), findsNothing);

    // 照片样式没有照片时退回圆点，同样不重复标篇数。
    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(cellStyle: CalendarCellStyle.photo),
      summary: summaryOf(<DiaryCalendarMarker>[entry(8), entry(9)]),
    );
    expect(find.byType(CalendarCellCountMark), findsNothing);
  });

  testWidgets('the count sits beside its day number without covering it', (
    tester,
  ) async {
    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(cellStyle: CalendarCellStyle.tags),
      summary: summaryOf(<DiaryCalendarMarker>[entry(8), entry(9)]),
    );

    final number = tester.getRect(find.text('12'));
    final mark = tester.getRect(find.byType(CalendarCellCountMark));
    // 上标：在数字右侧紧贴、略高于数字，且不遮挡数字。
    expect(mark.overlaps(number), isFalse);
    expect(mark.left - number.right, inInclusiveRange(0, 3));
    expect(mark.top, lessThan(number.top + 1));
  });

  testWidgets('weekend shading gives weekend cells a neutral tile', (
    tester,
  ) async {
    Color? outerFill() {
      final outer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      return (outer.decoration! as BoxDecoration).color;
    }

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(highlightWeekends: true),
      isWeekend: true,
    );
    final colorScheme = Theme.of(
      tester.element(find.byType(CalendarDayCell)),
    ).colorScheme;
    expect(outerFill(), CalendarDayCell.weekendColor(colorScheme));

    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(),
      isWeekend: true,
    );
    expect(outerFill()!.a, 0);

    // 选中仍以 primary 填充为准。
    await pumpCell(
      tester,
      options: const CalendarDisplayOptions(highlightWeekends: true),
      isWeekend: true,
      isSelected: true,
    );
    await tester.pumpAndSettle();
    expect(outerFill(), colorScheme.primary);
  });

  testWidgets('heat cells keep their data color on weekends', (tester) async {
    const options = CalendarDisplayOptions(
      cellStyle: CalendarCellStyle.heat,
      highlightWeekends: true,
    );
    List<Color?> fills() => tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((container) => (container.decoration as BoxDecoration?)?.color)
        .toList();

    await pumpCell(tester, options: options, isWeekend: true);
    final colorScheme = Theme.of(
      tester.element(find.byType(CalendarDayCell)),
    ).colorScheme;
    expect(fills(), contains(CalendarDayCell.weekendColor(colorScheme)));

    await pumpCell(
      tester,
      options: options,
      isWeekend: true,
      summary: summaryOf(<DiaryCalendarMarker>[entry(8)]),
    );
    expect(fills(), contains(CalendarDayCell.heatColorFor(colorScheme, 1)));
    expect(fills(), isNot(contains(CalendarDayCell.weekendColor(colorScheme))));
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
