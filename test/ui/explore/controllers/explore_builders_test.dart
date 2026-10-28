import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/ui/explore/controllers/explore_data_builder.dart';
import 'package:node_diary/ui/explore/controllers/explore_life_builder.dart';
import 'package:node_diary/ui/explore/controllers/explore_page_controller.dart';
import 'package:node_diary/ui/explore/controllers/explore_series_builder.dart';
import 'package:node_diary/ui/explore/controllers/explore_stats_builder.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_module_data.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_module_options.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/viewmodels/explore_entry.dart';

void main() {
  final now = DateTime(2026, 10, 28, 15); // 周三
  final moods = SettingsService.defaultMoodOptions;
  final weights = SettingsService.buildMoodWeightMap(moods);
  final l10n = AppLocalizationsEn();
  var serial = 0;

  setUpAll(() => initializeDateFormatting('en'));

  ExploreDiaryOverview overview(
    DateTime created, {
    String text = '',
    String? mood,
    Object? energy,
    String? weather,
    String? weatherIcon,
    String? location,
    List<Tag> tags = const <Tag>[],
    String? cover,
    String? metadata,
    DateTime? updated,
    String? id,
  }) {
    serial += 1;
    return ExploreDiaryOverview(
      diaryId: id ?? 'd$serial',
      title: 't$serial',
      contentText: text,
      metadata:
          metadata ??
          jsonEncode(<String, Object?>{
            'context': <String, Object?>{
              'moodEmoji': ?mood,
              'energyLevel': ?energy,
              'weather': ?weather,
              'weatherIconCode': ?weatherIcon,
              'location': ?location,
            },
          }),
      createdAt: created,
      updatedAt: updated ?? created,
      tags: tags,
      cover: cover,
    );
  }

  List<ExploreEntry> entries(List<ExploreDiaryOverview> overviews) =>
      ExploreEntryCache().index(overviews).entries;

  group('ExploreEntryCache', () {
    test('parses metadata once and survives corrupt json', () {
      final cache = ExploreEntryCache();
      final first = overview(now, mood: '😊', energy: '4', text: 'hello world');
      final broken = overview(now, metadata: '{oops');
      final index = cache.index(<ExploreDiaryOverview>[first, broken]);
      expect(index.entries.first.mood, '😊');
      expect(index.entries.first.energy, 4);
      expect(index.entries.first.words, 2);
      expect(index.entries.last.mood, isNull);
      final again = cache.index(<ExploreDiaryOverview>[first]);
      expect(identical(again.entries.single, index.entries.first), isTrue);
    });
  });

  group('ExploreStatsBuilder', () {
    test('current streak survives an empty today and stops at gaps', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(DateTime(2026, 10, 27, 23)),
        overview(DateTime(2026, 10, 26, 8)),
        overview(DateTime(2026, 10, 24)),
      ]);
      final keys = <int>{for (final entry in list) entry.dayKey};
      expect(ExploreStatsBuilder.currentStreak(keys, now), 2);
      expect(
        ExploreStatsBuilder.currentStreak(keys, DateTime(2026, 10, 30)),
        0,
      );
      expect(
        ExploreStatsBuilder.longestStreak(<DateTime>[
          for (final entry in list) entry.day,
        ]),
        2,
      );
    });

    test('overview follows the period but streaks use every entry', () {
      const tag = Tag(id: 1, name: 'a', color: 1);
      final list = entries(<ExploreDiaryOverview>[
        overview(now, text: 'one two', tags: <Tag>[tag]),
        overview(DateTime(2026, 10, 27), text: 'three'),
        overview(DateTime(2026, 9, 30), text: 'four five six'),
      ]);
      final month = ExploreStatsBuilder.overview(
        list,
        range: explorePeriodRange(ExplorePeriod.month, now, firstWeekday: 1),
        now: now,
        photoCounts: <String, int>{list.first.diaryId: 2},
      );
      expect(month[ExploreMetric.entries], 2);
      expect(month[ExploreMetric.words], 3);
      expect(month[ExploreMetric.recordedDays], 2);
      expect(month[ExploreMetric.averageWords], 2);
      expect(month[ExploreMetric.photos], 2);
      expect(month[ExploreMetric.tags], 1);
      expect(month[ExploreMetric.span], 2);
      expect(month[ExploreMetric.currentStreak], 2);
      expect(month[ExploreMetric.todayWords], 2);
      final all = ExploreStatsBuilder.overview(list, range: null, now: now);
      expect(all[ExploreMetric.entries], 3);
      expect(all[ExploreMetric.photos], isNull);
      expect(all[ExploreMetric.span], 29);
    });

    test('recap compares with the previous period', () {
      const tag = Tag(id: 3, name: 'work', color: 3);
      final list = entries(<ExploreDiaryOverview>[
        overview(now, mood: '😊', tags: <Tag>[tag], text: 'a b'),
        overview(DateTime(2026, 10, 2), mood: '😊', tags: <Tag>[tag]),
        overview(DateTime(2026, 10, 2), mood: '😢'),
        overview(DateTime(2026, 9, 5), text: 'c'),
      ]);
      final recap = ExploreStatsBuilder.recap(
        list,
        period: ExplorePeriod.month,
        now: now,
        firstWeekday: DateTime.monday,
      );
      expect(recap.current.entries, 3);
      expect(recap.current.days, 2);
      expect(recap.current.words, 2);
      expect(recap.current.topMood, '😊');
      expect(recap.current.topTag?.name, 'work');
      expect(recap.previous.entries, 1);
    });

    test('milestones report the reached step and the next one', () {
      final list = entries(<ExploreDiaryOverview>[
        for (var i = 0; i < 12; i++) overview(DateTime(2024, 1, 1 + i)),
      ]);
      final result = ExploreStatsBuilder.milestones(
        list,
        kinds: ExploreMilestoneKind.values,
        now: now,
      );
      final byKind = {for (final m in result) m.kind: m};
      expect(byKind[ExploreMilestoneKind.entries]!.achieved, 10);
      expect(byKind[ExploreMilestoneKind.entries]!.next, 30);
      expect(
        byKind[ExploreMilestoneKind.entries]!.progress,
        closeTo(0.1, 1e-9),
      );
      expect(byKind[ExploreMilestoneKind.streak]!.value, 12);
      expect(byKind[ExploreMilestoneKind.streak]!.achieved, 7);
      expect(byKind[ExploreMilestoneKind.years]!.value, 2);
      expect(byKind[ExploreMilestoneKind.words]!.achieved, isNull);
    });

    test('mood share sorts by count or by mood', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(now, mood: moods.first),
        overview(now, mood: moods.first),
        overview(now, mood: moods.last),
      ]);
      final byCount = ExploreStatsBuilder.moodShare(
        list,
        sort: ExploreMoodSort.count,
        moodWeights: weights,
      );
      expect(byCount.first.emoji, moods.first);
      expect(byCount.first.percent, 67);
      final byMood = ExploreStatsBuilder.moodShare(
        list,
        sort: ExploreMoodSort.mood,
        moodWeights: weights,
      );
      expect(byMood.first.emoji, moods.last);
    });
  });

  group('ExploreSeriesBuilder', () {
    test('mood series averages weights and prefers day moods', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(now, mood: moods[0]),
        overview(now, mood: moods[9]),
        overview(DateTime(2026, 10, 27), mood: moods[0]),
      ]);
      final series = ExploreSeriesBuilder.moodSeries(
        list,
        now: now,
        days: 7,
        moodWeights: weights,
        dayMoods: <DateTime, DayMood>{DateTime(2026, 10, 27): DayMood.great},
      );
      expect(series, hasLength(7));
      expect(series.last.value, 5.5);
      expect(series[5].value, 10);
      expect(series.first.value, isNull);
      final energy = ExploreSeriesBuilder.energySeries(
        entries(<ExploreDiaryOverview>[overview(now, energy: 9)]),
        now: now,
        days: 7,
      );
      expect(energy.last.value, 5);
    });

    test('rhythm buckets months, weeks and days', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(now, text: 'a b c'),
        overview(DateTime(2026, 10, 26), text: 'a'),
        overview(DateTime(2026, 10, 25)),
        overview(DateTime(2025, 11, 1)),
        overview(DateTime(2025, 10, 31)),
      ]);
      final months = ExploreSeriesBuilder.rhythm(
        list,
        now: now,
        unit: ExploreRhythmUnit.month,
        metric: ExploreCountMetric.entries,
        firstWeekday: DateTime.monday,
      );
      expect(months, hasLength(12));
      expect(months.first.start, DateTime(2025, 11));
      expect(months.first.value, 1);
      expect(months.last.value, 3);
      final weeks = ExploreSeriesBuilder.rhythm(
        list,
        now: now,
        unit: ExploreRhythmUnit.week,
        metric: ExploreCountMetric.words,
        firstWeekday: DateTime.monday,
      );
      expect(weeks.last.start, DateTime(2026, 10, 26));
      expect(weeks.last.value, 4);
      expect(weeks[10].value, 0);
      final days = ExploreSeriesBuilder.rhythm(
        list,
        now: now,
        unit: ExploreRhythmUnit.day,
        metric: ExploreCountMetric.entries,
        firstWeekday: DateTime.monday,
      );
      expect(days, hasLength(30));
      expect(days.last.value, 1);
    });

    test('habits bucket by time slot and weekday order', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(DateTime(2026, 10, 28, 22)),
        overview(DateTime(2026, 10, 27, 22, 30)),
        overview(DateTime(2026, 10, 25, 7)),
      ]);
      final habits = ExploreSeriesBuilder.habits(
        list,
        metric: ExploreCountMetric.entries,
        firstWeekday: DateTime.sunday,
      );
      expect(habits.weekdayOrder.first, DateTime.sunday);
      expect(habits.topSlot, ExploreDaySlot.night);
      expect(habits.slots[ExploreDaySlot.morning.index], 1);
      expect(habits.weekdays.first, 1);
    });

    test('heatmap starts on the first weekday and keeps day order', () {
      final early = DateTime(2026, 10, 27, 8);
      final late = DateTime(2026, 10, 27, 21);
      final list = entries(<ExploreDiaryOverview>[
        overview(late, id: 'late', text: 'x y'),
        overview(early, id: 'early', mood: moods.last),
        overview(DateTime(2026, 1, 1)),
      ]);
      final heat = ExploreSeriesBuilder.heatmap(
        list,
        now: now,
        weeks: 12,
        firstWeekday: DateTime.monday,
        moodWeights: weights,
        dayMoods: <DateTime, DayMood>{DateTime(2026, 10, 20): DayMood.bad},
      );
      expect(heat.start, DateTime(2026, 8, 10));
      expect(heat.start.weekday, DateTime.monday);
      final day = heat.days[exploreDayKey(DateTime(2026, 10, 27))]!;
      expect(day.entries, 2);
      expect(day.words, 2);
      expect(day.diaryIds, <String>['early', 'late']);
      expect(day.moodWeight, 10);
      expect(
        heat.days[exploreDayKey(DateTime(2026, 10, 20))]!.dayMood,
        DayMood.bad,
      );
      expect(heat.days.length, 2);
    });
  });

  group('ExploreLifeBuilder and on this day', () {
    test('places and weather group, count and order', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(
          DateTime(2026, 10, 1),
          location: ' Home ',
          weatherIcon: '100',
          weather: 'Sunny',
        ),
        overview(
          DateTime(2026, 10, 2),
          location: 'Home',
          weatherIcon: '100',
          weather: 'Clear',
        ),
        overview(DateTime(2026, 10, 3), location: 'Office', weather: 'Fog'),
      ]);
      final places = ExploreLifeBuilder.places(list, limit: 5);
      expect(places.first.label, 'Home');
      expect(places.first.count, 2);
      expect(places.first.diaryIds, hasLength(2));
      final weather = ExploreLifeBuilder.weather(list);
      expect(weather.first.iconCode, '100');
      expect(weather.first.label, 'Clear');
      expect(weather.last.label, 'Fog');
    });

    test('random pool filters by age and cover and picks stably', () {
      final list = entries(<ExploreDiaryOverview>[
        overview(now),
        overview(DateTime(2025, 1, 1), cover: '/a.png'),
        overview(DateTime(2024, 1, 1)),
      ]);
      expect(
        ExploreLifeBuilder.randomPool(
          list,
          now: now,
          source: ExploreRandomSource.yearAgo,
          photosOnly: false,
        ),
        hasLength(2),
      );
      final covered = ExploreLifeBuilder.randomPool(
        list,
        now: now,
        source: ExploreRandomSource.all,
        photosOnly: true,
      );
      expect(covered.single.cover, '/a.png');
      expect(
        ExploreLifeBuilder.pick(list, 42),
        same(ExploreLifeBuilder.pick(list, 42)),
      );
      expect(ExploreLifeBuilder.pick(const <ExploreEntry>[], 1), isNull);
    });

    test('on this day supports exact, nearby and month matches', () {
      final diaries = <ExploreDiaryOverview>[
        overview(DateTime(2025, 10, 28)),
        overview(DateTime(2024, 10, 30)),
        overview(DateTime(2023, 10, 2)),
        overview(DateTime(2026, 10, 28)),
      ];
      const controller = ExplorePageController();
      int count(ExploreOnThisDayMatch match) => controller
          .pickOnThisDayList(diaries, now: now, l10n: l10n, match: match)
          .length;
      expect(count(ExploreOnThisDayMatch.sameDay), 1);
      expect(count(ExploreOnThisDayMatch.nearby), 2);
      expect(count(ExploreOnThisDayMatch.sameMonth), 3);
      final nearYearEnd = controller.pickOnThisDayList(
        <ExploreDiaryOverview>[overview(DateTime(2025, 1, 1))],
        now: DateTime(2026, 12, 30),
        l10n: l10n,
        match: ExploreOnThisDayMatch.nearby,
      );
      expect(nearYearEnd, hasLength(1));
      expect(
        controller
            .pickOnThisDayList(diaries, now: now, l10n: l10n, limit: 0)
            .length,
        0,
      );
    });
  });

  test('data builder only computes visible modules', () {
    final index = ExploreEntryCache().index(<ExploreDiaryOverview>[
      overview(now, text: 'hello', location: 'Park'),
    ]);
    final data = ExploreDataBuilder.build(
      ExploreDataRequest(
        index: index,
        layout: ExploreLayout.defaults,
        modules: <ExploreModuleId>{
          ExploreModuleId.overview,
          ExploreModuleId.places,
        },
        period: ExplorePeriod.week,
        now: now,
        firstWeekday: DateTime.monday,
        moodOptions: moods,
        l10n: l10n,
      ),
    );
    expect(data.totalEntries, 1);
    expect(data.overview?[ExploreMetric.entries], 1);
    expect(data.places?.single.label, 'Park');
    expect(data.heatmap, isNull);
    expect(data.greeting, isNull);
    expect(data.tags, isNull);
  });
}
