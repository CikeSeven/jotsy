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
