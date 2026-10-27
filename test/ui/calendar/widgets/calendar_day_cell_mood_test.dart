import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell_parts.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_mood_tile.dart';
import 'package:node_diary/ui/calendar/widgets/day_mood_face.dart';

/// 记了“这天的心情”的日期格：整格换成心情格，高亮改为外圈描边。
void main() {
  final day = DateTime(2026, 10, 1);

  CalendarDaySummary summaryWith(int entries) {
    return CalendarDaySummary.groupByDay(
      <DiaryCalendarMarker>[
        for (var i = 0; i < entries; i++)
          DiaryCalendarMarker(
            diaryId: 'd$i',
            createdAt: DateTime(2026, 10, 1, 8 + i),
          ),
      ],
      now: DateTime(2026, 10, 27),
      moodOptions: SettingsService.defaultMoodOptions,
    )[day]!;
  }

  Future<void> pumpCell(
    WidgetTester tester, {
    DayMood? mood = DayMood.good,
    CalendarDisplayOptions options = const CalendarDisplayOptions(),
    CalendarDaySummary? summary,
    bool isSelected = false,
    bool lunar = false,
    String? anniversary,
    double? highlightMaxWidth,
    Size size = const Size(49, 52),
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1E6586),
          brightness: brightness,
        ),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: CalendarDayCell(
                day: day,
                options: options,
                isToday: false,
                isSelected: isSelected,
                isOutside: false,
                isWeekend: false,
                summary: summary,
                lunar: lunar ? CalendarLunarDay.of(day) : null,
                anniversary: anniversary,
                dayMood: mood,
                highlightMaxWidth: highlightMaxWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color ringOf(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    return border.top.color;
  }

  for (final brightness in Brightness.values) {
    testWidgets('the whole cell turns into the mood (${brightness.name})', (
      tester,
    ) async {
      // 热力样式本来按篇数铺色，记了心情的日子仍整格画成心情。
      await pumpCell(
        tester,
        brightness: brightness,
        options: const CalendarDisplayOptions(
          cellStyle: CalendarCellStyle.heat,
        ),
        isSelected: true,
      );
      await tester.pumpAndSettle();
      final colorScheme = Theme.of(
        tester.element(find.byType(CalendarDayCell)),
      ).colorScheme;

      final tile = tester.widget<CalendarMoodTile>(
        find.byType(CalendarMoodTile),
      );
      expect(tile.colors, DayMoodColors.of(colorScheme, DayMood.good));
      expect(
        tester.widget<DayMoodFace>(find.byType(DayMoodFace)).mood,
        DayMood.good,
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('不错')), findsOneWidget);
      // 选中改为外圈 primary 描边，不再整格填 primary。
      expect(ringOf(tester), colorScheme.primary);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every mood has its own colors and face', (tester) async {
    final seen = <DayMoodColors>{};
    for (final mood in DayMood.values) {
      await pumpCell(tester, mood: mood);
      await tester.pumpAndSettle();
      seen.add(
        tester.widget<CalendarMoodTile>(find.byType(CalendarMoodTile)).colors,
      );
      expect(tester.widget<DayMoodFace>(find.byType(DayMoodFace)).mood, mood);
    }
    expect(seen, hasLength(DayMood.values.length));
  });

  testWidgets('a day without a mood keeps its usual look', (tester) async {
    await pumpCell(tester, mood: null, isSelected: true);
    expect(find.byType(CalendarMoodTile), findsNothing);
    final colorScheme = Theme.of(
      tester.element(find.byType(CalendarDayCell)),
    ).colorScheme;
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    expect((container.decoration! as BoxDecoration).color, colorScheme.primary);
  });

  testWidgets('written days get a dot, several entries a count', (
    tester,
  ) async {
    await pumpCell(tester, summary: summaryWith(1));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarCellCountMark), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CalendarMoodTile),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Container &&
              (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      ),
      findsOneWidget,
    );

    await pumpCell(tester, summary: summaryWith(3));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('phone cells drop the lunar line and mark anniversaries with '
      'a heart; wide cells keep the line', (tester) async {
    await pumpCell(
      tester,
      lunar: true,
      anniversary: '妈妈生日',
      size: const Size(49, 60),
    );
    await tester.pumpAndSettle();
    expect(find.text('妈妈生日'), findsNothing);
    expect(find.byIcon(FontAwesomeIcons.solidHeart.data), findsOneWidget);

    await pumpCell(
      tester,
      lunar: true,
      anniversary: '妈妈生日',
      size: const Size(100, 80),
      highlightMaxWidth: 64,
    );
    await tester.pumpAndSettle();
    expect(find.text('妈妈生日'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.solidHeart.data), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text still fits the small cell', (tester) async {
    await pumpCell(
      tester,
      lunar: true,
      size: const Size(36, 60),
      textScale: 2,
      summary: summaryWith(4),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DayMoodFace), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setting and clearing the mood cross-fades the content', (
    tester,
  ) async {
    await pumpCell(tester, mood: null);
    await pumpCell(tester, mood: DayMood.great);
    await tester.pump(const Duration(milliseconds: 60));
    // 过渡中新旧内容同时在树里，结束后只留心情格。
    expect(find.byType(CalendarMoodTile), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await pumpCell(tester, mood: null);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarMoodTile), findsNothing);
  });
}
