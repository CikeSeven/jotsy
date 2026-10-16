import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';

void main() {
  final now = DateTime(2026, 3, 15, 12);
  const moods = SettingsService.defaultMoodOptions;

  Map<DateTime, CalendarDaySummary> group(List<DiaryCalendarMarker> markers) {
    return CalendarDaySummary.groupByDay(markers, now: now, moodOptions: moods);
  }

  test('markers are bucketed by local date and summed', () {
    final summaries = group(<DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'a',
        createdAt: DateTime(2026, 3, 3, 0, 5),
        wordCount: 120,
      ),
      DiaryCalendarMarker(
        diaryId: 'b',
        createdAt: DateTime(2026, 3, 3, 23, 50),
        wordCount: 30,
      ),
      DiaryCalendarMarker(diaryId: 'c', createdAt: DateTime(2026, 3, 4, 9)),
    ]);

    final third = summaries[DateTime(2026, 3, 3)]!;
    expect(third.entryCount, 2);
    expect(third.wordCount, 150);
    expect(third.diaryIds, <String>['a', 'b']);
    expect(summaries[DateTime(2026, 3, 4)]!.entryCount, 1);
  });

  test('sealed capsules only raise the lock flag', () {
    final day = DateTime(2026, 3, 20, 8);
    final summary = group(<DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'capsule',
        createdAt: day,
        moodEmoji: '😭',
        wordCount: 999,
        cover: '/secret.jpg',
        capsuleUnlockAt: day,
        tagColors: const <int>[0xFFFF0000],
      ),
    ])[DateTime(2026, 3, 20)]!;

    expect(summary.hasLockedCapsule, isTrue);
    expect(summary.hasEntries, isFalse);
    expect(summary.wordCount, 0);
    expect(summary.moods, isEmpty);
    expect(summary.explicitCover, isNull);
    expect(summary.tagColors, isEmpty);
  });

  test('moods keep every entry in order and average to the nearest slot', () {
    final summary = group(<DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'a',
        createdAt: DateTime(2026, 3, 5, 8),
        moodEmoji: moods[0],
      ),
      DiaryCalendarMarker(diaryId: 'b', createdAt: DateTime(2026, 3, 5, 9)),
      DiaryCalendarMarker(
        diaryId: 'c',
        createdAt: DateTime(2026, 3, 5, 10),
        moodEmoji: moods[9],
      ),
    ])[DateTime(2026, 3, 5)]!;

    expect(summary.moods, <String>[moods[0], moods[9]]);
    // 权重 (1 + 10) / 2 = 5.5，四舍五入到第 6 档。
    expect(summary.averageMood, moods[5]);
  });

  test('tag colors are de-duplicated and capped at three', () {
    final summary = group(<DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'a',
        createdAt: DateTime(2026, 3, 5, 8),
        tagColors: const <int>[1, 2],
      ),
      DiaryCalendarMarker(
        diaryId: 'b',
        createdAt: DateTime(2026, 3, 5, 9),
        tagColors: const <int>[2, 3, 4],
      ),
    ])[DateTime(2026, 3, 5)]!;

    expect(summary.tagColors, <int>[1, 2, 3]);
  });

  test('an explicit cover wins over an earlier inline photo', () {
    final summary = group(<DiaryCalendarMarker>[
      DiaryCalendarMarker(
        diaryId: 'inline',
        createdAt: DateTime(2026, 3, 5, 8),
      ),
      DiaryCalendarMarker(
        diaryId: 'covered',
        createdAt: DateTime(2026, 3, 5, 9),
        cover: '/cover.jpg',
      ),
    ])[DateTime(2026, 3, 5)]!;

    expect(
      summary.representativeImage(<String, String>{'inline': '/inline.jpg'}),
      '/cover.jpg',
    );

    final withoutCover = group(<DiaryCalendarMarker>[
      DiaryCalendarMarker(diaryId: 'a', createdAt: DateTime(2026, 3, 6, 8)),
      DiaryCalendarMarker(diaryId: 'b', createdAt: DateTime(2026, 3, 6, 9)),
    ])[DateTime(2026, 3, 6)]!;
    expect(
      withoutCover.representativeImage(<String, String>{'b': '/b.jpg'}),
      '/b.jpg',
    );
    expect(withoutCover.representativeImage(const <String, String>{}), isNull);
  });

  test('heat levels use fixed thresholds', () {
    CalendarDaySummary dayWith(int entries, int chars) {
      return group(<DiaryCalendarMarker>[
        for (var index = 0; index < entries; index++)
          DiaryCalendarMarker(
            diaryId: 'd$index',
            createdAt: DateTime(2026, 3, 8, 8 + index),
            wordCount: index == 0 ? chars : 0,
          ),
      ])[DateTime(2026, 3, 8)]!;
    }

    expect(dayWith(1, 0).heatLevel(CalendarHeatBasis.entries), 1);
    expect(dayWith(6, 0).heatLevel(CalendarHeatBasis.entries), 4);
    expect(dayWith(1, 199).heatLevel(CalendarHeatBasis.words), 1);
    expect(dayWith(1, 200).heatLevel(CalendarHeatBasis.words), 2);
    expect(dayWith(1, 600).heatLevel(CalendarHeatBasis.words), 3);
    expect(dayWith(1, 1500).heatLevel(CalendarHeatBasis.words), 4);
  });
}
