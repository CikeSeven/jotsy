import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_id.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';
import '../controllers/explore_module_actions.dart';
import 'explore_greeting_card.dart';
import 'explore_habits_card.dart';
import 'explore_heatmap_card.dart';
import 'explore_life_cards.dart';
import 'explore_linked_cards.dart';
import 'explore_media_card.dart';
import 'explore_memory_card.dart';
import 'explore_milestones_card.dart';
import 'explore_mood_cards.dart';
import 'explore_overview_card.dart';
import 'explore_random_card.dart';
import 'explore_recap_card.dart';
import 'explore_rhythm_card.dart';

/// 按卡片设置与聚合数据建出一张卡片（探索页与自定义页的预览共用）。
///
/// 数据没算（这张卡不在可见集合里）时返回 null。动作一律经
/// `ExploreActionsScope` 取，这里不接任何回调。
Widget? buildExploreModule(
  BuildContext context, {
  required ExploreModuleConfig config,
  required ExploreData data,
  required DateTime now,
  required ExplorePeriod period,
  required List<String> moodOptions,
}) {
  switch (config.id) {
    case ExploreModuleId.greeting:
      final greeting = data.greeting;
      return greeting == null
          ? null
          : ExploreGreetingCard(config: config, data: greeting, now: now);
    case ExploreModuleId.onThisDay:
      final items = data.onThisDay;
      if (items == null) return null;
      return Builder(
        builder: (BuildContext context) {
          final actions = ExploreActionsScope.of(context);
          return ExploreMemoryCard(
            items: items,
            style: config.choice(ExploreOptions.onThisDayStyle),
            emptyMessage: context.l10n.exploreOnThisDayEmpty,
            onOpenDiary: (String diaryId) => actions.openDiary(
              diaryId,
              sequence: <String>[for (final item in items) item.diaryId],
            ),
            onCreateToday: actions.createDiary,
          );
        },
      );
    case ExploreModuleId.randomMemory:
      final pool = data.randomPool;
      return pool == null
          ? null
          : ExploreRandomCard(config: config, pool: pool, now: now);
    case ExploreModuleId.recap:
      final recap = data.recap;
      return recap == null
          ? null
          : ExploreRecapCard(config: config, data: recap);
    case ExploreModuleId.milestones:
      final milestones = data.milestones;
      return milestones == null
          ? null
          : ExploreMilestonesCard(config: config, milestones: milestones);
    case ExploreModuleId.overview:
      final overview = data.overview;
      return overview == null
          ? null
          : ExploreOverviewCard(config: config, data: overview, period: period);
    case ExploreModuleId.heatmap:
      final heatmap = data.heatmap;
      return heatmap == null
          ? null
          : ExploreHeatmapCard(
              config: config,
              data: heatmap,
              moodOptions: moodOptions,
            );
    case ExploreModuleId.rhythm:
      final bars = data.rhythm;
      return bars == null
          ? null
          : ExploreRhythmCard(config: config, bars: bars);
    case ExploreModuleId.habits:
      final habits = data.habits;
      return habits == null
          ? null
          : ExploreHabitsCard(config: config, data: habits);
    case ExploreModuleId.moodTrend:
      final series = data.moodTrend;
      return series == null
          ? null
          : ExploreMoodTrendCard(
              config: config,
              series: series,
              moodOptions: moodOptions,
            );
    case ExploreModuleId.moodShare:
      final shares = data.moodShare;
      return shares == null
          ? null
          : ExploreMoodShareCard(config: config, shares: shares);
    case ExploreModuleId.energy:
      final series = data.energy;
      return series == null
          ? null
          : ExploreEnergyCard(config: config, series: series);
    case ExploreModuleId.tags:
      final tags = data.tags;
      return tags == null ? null : ExploreTagsCard(config: config, tags: tags);
    case ExploreModuleId.media:
      final covers = data.media;
      return covers == null
          ? null
          : ExploreMediaCard(config: config, covers: covers);
    case ExploreModuleId.places:
      final places = data.places;
      return places == null ? null : ExplorePlacesCard(places: places);
    case ExploreModuleId.weather:
      final groups = data.weather;
      return groups == null
          ? null
          : ExploreWeatherCard(config: config, groups: groups);
    case ExploreModuleId.anniversaries:
      return ExploreAnniversariesCard(config: config, now: now);
    case ExploreModuleId.capsules:
      final recent = data.recentCapsules;
      return recent == null
          ? null
          : ExploreCapsulesCard(config: config, recent: recent, now: now);
    case ExploreModuleId.notebooks:
      return ExploreNotebooksCard(config: config);
    case ExploreModuleId.drafts:
      return const ExploreDraftsCard();
  }
}
