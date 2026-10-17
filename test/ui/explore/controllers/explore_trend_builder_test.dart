import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/explore/controllers/explore_content_extractor.dart';
import 'package:node_diary/ui/explore/controllers/explore_trend_builder.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);
  final moods = SettingsService.defaultMoodOptions;

  ExploreDiaryOverview entry({
    DateTime? at,
    Object? mood,
    Object? energy,
    String? metadata,
  }) => ExploreDiaryOverview(
    diaryId: 'trend-${at ?? now}-$mood-$energy',
    title: '',
    contentText: '',
    metadata:
        metadata ??
        jsonEncode({
          'context': {'moodEmoji': mood, 'energyLevel': energy},
        }),
    createdAt: at ?? now,
    updatedAt: at ?? now,
    tags: [],
  );

  test('averages each metric independently and preserves empty days', () {
    final trends = const ExploreTrendBuilder().build(
      [
        entry(mood: moods.first, energy: 2),
        entry(
          at: DateTime(2026, 10, 17, 23, 59),
          mood: moods.last,
          energy: '4',
        ),
        entry(energy: 3),
        entry(mood: moods.last, energy: 'invalid'),
        entry(at: DateTime(2026, 10, 16), energy: 1.5),
      ],
      now: now,
      moodOptions: moods,
    );
    expect(trends.moodWeights30, hasLength(30));
    expect(trends.energyValues7, hasLength(7));
    expect(trends.moodWeights30.take(29), everyElement(isNull));
    expect(trends.moodWeights30.last, (1 + 5 + 5) / 3);
    expect(trends.energyValues7.take(5), everyElement(isNull));
    expect(trends.energyValues7[5], 1.5);
    expect(trends.energyValues7.last, 3);
  });

  test('parses only the exact 30-day window and each related entry once', () {
    final extractor = _CountingExtractor();
    final trends = ExploreTrendBuilder(extractor: extractor).build(
      [
        entry(at: DateTime(2026, 9, 17, 23, 59), mood: moods.first, energy: 1),
        entry(at: DateTime(2026, 9, 18), mood: moods.first, energy: 1),
        entry(at: DateTime(2026, 10, 10, 23, 59), mood: moods.last, energy: 5),
        entry(at: DateTime(2026, 10, 11), mood: moods.last, energy: 4),
        entry(at: now.toUtc(), mood: moods.first, energy: 2),
        entry(at: DateTime(2026, 10, 18), mood: moods.last, energy: 5),
      ],
      now: now,
      moodOptions: moods,
    );
    expect(extractor.reads, 4);
    expect(trends.moodWeights30.first, 1);
    expect(trends.moodWeights30.last, 1);
    expect(trends.energyValues7.first, 4);
    expect(trends.energyValues7.last, 2);
    expect(trends.energyValues7.whereType<double>(), [4, 2]);
  });

  test('corrupt and incomplete metadata keep both series empty', () {
    final trends = const ExploreTrendBuilder().build(
      [
        for (final metadata in [
          '{broken',
          '[]',
          '{}',
          '{"context":null}',
          '{"context":{"moodEmoji":"unknown","energyLevel":{}}}',
        ])
          entry(metadata: metadata),
      ],
      now: now,
      moodOptions: moods,
    );
    expect(trends.moodWeights30, everyElement(isNull));
    expect(trends.energyValues7, everyElement(isNull));
    final empty = const ExploreTrendBuilder().build(
      [],
      now: now,
      moodOptions: moods,
    );
    expect(empty.moodWeights30, trends.moodWeights30);
    expect(empty.energyValues7, trends.energyValues7);
  });

  test(
    'custom symbols and legacy default aliases share the original scores',
    () {
      final custom = ['custom-low', ...moods.skip(1).take(8), 'custom-high'];
      for (final mood in [...moods, ...custom]) {
        final trends = const ExploreTrendBuilder().build(
          [entry(mood: ' $mood ')],
          now: now,
          moodOptions: custom,
        );
        expect(
          trends.moodWeights30.last,
          SettingsService.moodScore(mood, custom),
        );
      }
    },
  );
}

class _CountingExtractor extends ExploreContentExtractor {
  int reads = 0;

  @override
  Map<String, dynamic>? parseContext(String metadata) {
    reads += 1;
    return super.parseContext(metadata);
  }
}
