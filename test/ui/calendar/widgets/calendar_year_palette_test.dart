import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_year_palette.dart';

void main() {
  const moods = SettingsService.defaultMoodOptions;
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1E6586));
  final day = DateTime(2026, 3, 5);

  CalendarDaySummary dayWith(List<String?> dayMoods) {
    return CalendarDaySummary.groupByDay(
      <DiaryCalendarMarker>[
        for (var index = 0; index < dayMoods.length; index++)
          DiaryCalendarMarker(
            diaryId: 'p$index',
            createdAt: DateTime(2026, 3, 5, 8 + index),
            moodEmoji: dayMoods[index],
          ),
      ],
      now: DateTime(2026, 4, 1),
      moodOptions: moods,
    )[day]!;
  }

  test('ten mood slots fold into five bands from low to high', () {
    for (var weight = 1; weight <= 10; weight++) {
      expect(
        CalendarYearPalette.pixelColor(
          colorScheme,
          dayWith(<String?>[moods[weight - 1]]),
          CalendarYearBasis.mood,
        ),
        CalendarYearPalette.moodBandColor(colorScheme, (weight - 1) ~/ 2),
        reason: 'weight $weight',
      );
    }
  });

  test('written days without a mood differ from empty days', () {
    final noMood = CalendarYearPalette.pixelColor(
      colorScheme,
      dayWith(<String?>[null]),
      CalendarYearBasis.mood,
    );
    final empty = CalendarYearPalette.pixelColor(
      colorScheme,
      null,
      CalendarYearBasis.mood,
    );

    expect(noMood, CalendarYearPalette.noMoodColor(colorScheme));
    expect(empty, CalendarYearPalette.emptyColor(colorScheme));
    expect(noMood, isNot(empty));
  });

  test('a mood set for the day wins over the diaries in the mood view', () {
    // 日记平均是最低一段，这天记的是“超棒”：按这天的心情着色。
    final written = dayWith(<String?>[moods.first]);
    for (final mood in DayMood.values) {
      expect(
        CalendarYearPalette.pixelColor(
          colorScheme,
          written,
          CalendarYearBasis.mood,
          dayMood: mood,
        ),
        CalendarYearPalette.moodBandColor(colorScheme, mood.index),
        reason: mood.name,
      );
    }
    // 没写日记的日子也按记下的心情着色。
    expect(
      CalendarYearPalette.pixelColor(
        colorScheme,
        null,
        CalendarYearBasis.mood,
        dayMood: DayMood.great,
      ),
      CalendarYearPalette.moodBandColor(colorScheme, 4),
    );
    // 按篇数着色时不看心情。
    expect(
      CalendarYearPalette.pixelColor(
        colorScheme,
        null,
        CalendarYearBasis.entries,
        dayMood: DayMood.great,
      ),
      CalendarYearPalette.emptyColor(colorScheme),
    );
  });

  test('entry counts use the heat steps', () {
    expect(
      CalendarYearPalette.pixelColor(
        colorScheme,
        dayWith(<String?>[null, null]),
        CalendarYearBasis.entries,
      ),
      CalendarYearPalette.heatColor(colorScheme, 2),
    );
  });
}
