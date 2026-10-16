import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_month_stats.dart';

void main() {
  const moods = SettingsService.defaultMoodOptions;

  CalendarMonthStats statsFor(
    List<DiaryCalendarMarker> markers, {
    required DateTime month,
    required DateTime now,
  }) {
    return CalendarMonthStats.compute(
      CalendarDaySummary.groupByDay(markers, now: now, moodOptions: moods),
      month: month,
      now: now,
      moodOptions: moods,
    );
  }

  DiaryCalendarMarker entry(
    String id,
    DateTime createdAt, {
    String? mood,
    int chars = 0,
  }) {
    return DiaryCalendarMarker(
      diaryId: id,
      createdAt: createdAt,
      moodEmoji: mood,
      wordCount: chars,
    );
  }

  test('counts entries, days, length and the longest streak', () {
    final stats = statsFor(
      <DiaryCalendarMarker>[
        entry('a', DateTime(2026, 3, 1, 9), chars: 100),
        entry('b', DateTime(2026, 3, 2, 9), chars: 50),
        entry('c', DateTime(2026, 3, 2, 21), chars: 25),
        entry('d', DateTime(2026, 3, 3, 9)),
        entry('e', DateTime(2026, 3, 10, 9)),
        entry('f', DateTime(2026, 3, 11, 9)),
      ],
      month: DateTime(2026, 3),
      now: DateTime(2026, 4, 2),
    );

    expect(stats.entryCount, 6);
    expect(stats.recordedDays, 5);
    expect(stats.wordCount, 175);
    expect(stats.longestStreak, 3);
    // 过去的月份：分母为整月天数。
    expect(stats.elapsedDays, 31);
  });

  test('elapsed days stop at today and vanish for future months', () {
    final now = DateTime(2026, 3, 15, 10);
    expect(
      statsFor(const [], month: DateTime(2026, 3), now: now).elapsedDays,
      15,
    );
    final future = statsFor(const [], month: DateTime(2026, 5), now: now);
    expect(future.elapsedDays, isNull);
    expect(future.isEmpty, isTrue);
  });

  test('dominant mood is the most frequent, ties go to the latest', () {
    final now = DateTime(2026, 4, 1);
    final tie = statsFor(
      <DiaryCalendarMarker>[
        entry('a', DateTime(2026, 3, 1), mood: moods[2]),
        entry('b', DateTime(2026, 3, 2), mood: moods[7]),
      ],
      month: DateTime(2026, 3),
      now: now,
    );
    expect(tie.dominantMood, moods[7]);

    final frequent = statsFor(
      <DiaryCalendarMarker>[
        entry('a', DateTime(2026, 3, 1), mood: moods[2]),
        entry('b', DateTime(2026, 3, 1, 12), mood: moods[2]),
        entry('c', DateTime(2026, 3, 2), mood: moods[7]),
      ],
      month: DateTime(2026, 3),
      now: now,
    );
    expect(frequent.dominantMood, moods[2]);
  });

  test('days outside the month do not leak into the stats', () {
    final stats = statsFor(
      <DiaryCalendarMarker>[
        entry('feb', DateTime(2026, 2, 28)),
        entry('mar', DateTime(2026, 3, 1)),
      ],
      month: DateTime(2026, 3),
      now: DateTime(2026, 4, 1),
    );

    expect(stats.entryCount, 1);
    expect(stats.longestStreak, 1);
  });

  test('a year range counts elapsed days up to today', () {
    final now = DateTime(2026, 3, 2, 10);
    final markers = <DiaryCalendarMarker>[
      entry('jan', DateTime(2026, 1, 31)),
      entry('feb', DateTime(2026, 2, 1)),
    ];
    final stats = CalendarMonthStats.computeRange(
      CalendarDaySummary.groupByDay(markers, now: now, moodOptions: moods),
      start: DateTime(2026),
      end: DateTime(2027),
      now: now,
      moodOptions: moods,
    );

    // 1 月 31 天 + 2 月 28 天 + 3 月 2 日。
    expect(stats.elapsedDays, 31 + 28 + 2);
    expect(stats.recordedDays, 2);
    expect(stats.longestStreak, 2);
  });
}
