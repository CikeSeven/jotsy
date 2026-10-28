import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../models/explore_layout.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_id.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';
import '../viewmodels/explore_entry.dart';
import 'explore_life_builder.dart';
import 'explore_page_controller.dart';
import 'explore_series_builder.dart';
import 'explore_stats_builder.dart';

/// 一次聚合的输入。
///
/// 页面按这些输入的身份 / 值缓存结果（见 [ExploreDataBuilder.build] 的调用
/// 方）：概览流没有新推送、布局与范围没变、日期没变时重建页面不重算。
class ExploreDataRequest {
  const ExploreDataRequest({
    required this.index,
    required this.layout,
    required this.modules,
    required this.period,
    required this.now,
    required this.firstWeekday,
    required this.moodOptions,
    required this.l10n,
    this.orderedTagIds = const <int>[],
    this.dayMoods,
    this.photoCounts,
  });

  final ExploreEntryIndex index;
  final ExploreLayout layout;

  /// 要计算的卡片（可见且功能开启）。
  final Set<ExploreModuleId> modules;
  final ExplorePeriod period;
  final DateTime now;
  final int firstWeekday;
  final List<String> moodOptions;
  final AppLocalizations l10n;

  /// 标签管理里的顺序（标签卡按手动顺序时用）。
  final List<int> orderedTagIds;

  /// 这天的心情（日历长按记下的），按本地零点索引。
  final Map<DateTime, DayMood>? dayMoods;

  /// 日记 id → 图片数（数据看板选了“照片数”时才读），没读到时为 null。
  final Map<String, int>? photoCounts;
}

/// 探索页整页聚合：按可见的卡片调用各聚合器，未显示的卡片不计算。
///
/// 统计范围（[ExploreDataRequest.period]）只作用于登记了 `periodAware` 的
/// 卡片（数据看板、标签、写作习惯、心情分布、足迹、天气）；其余卡片有自己的
/// 时间窗口（热力图跨度、趋势天数等）。纯计算，无副作用。
abstract final class ExploreDataBuilder {
  static ExploreData build(ExploreDataRequest request) {
    final all = request.index.entries;
    final layout = request.layout;
    final modules = request.modules;
    final now = request.now;
    final range = explorePeriodRange(
      request.period,
      now,
      firstWeekday: request.firstWeekday,
    );
    final scoped = ExploreStatsBuilder.inRange(all, range);
    final moodWeights = SettingsService.buildMoodWeightMap(request.moodOptions);
    bool shows(ExploreModuleId id) => modules.contains(id);

    final onThisDay = layout.module(ExploreModuleId.onThisDay);
    final random = layout.module(ExploreModuleId.randomMemory);
    final recap = layout.module(ExploreModuleId.recap);
    final milestones = layout.module(ExploreModuleId.milestones);
    final heatmap = layout.module(ExploreModuleId.heatmap);
    final rhythm = layout.module(ExploreModuleId.rhythm);
    final habits = layout.module(ExploreModuleId.habits);
    final moodTrend = layout.module(ExploreModuleId.moodTrend);
    final moodShare = layout.module(ExploreModuleId.moodShare);
    final energy = layout.module(ExploreModuleId.energy);
    final tags = layout.module(ExploreModuleId.tags);
    final media = layout.module(ExploreModuleId.media);
    final places = layout.module(ExploreModuleId.places);

    return ExploreData(
      totalEntries: all.length,
      greeting: shows(ExploreModuleId.greeting)
          ? ExploreStatsBuilder.greeting(all, now)
          : null,
      onThisDay: shows(ExploreModuleId.onThisDay)
          ? const ExplorePageController().pickOnThisDayList(
              <ExploreDiaryOverview>[for (final entry in all) entry.source],
              now: now,
              l10n: request.l10n,
              match: onThisDay.choice(ExploreOptions.onThisDayMatch),
              limit: onThisDay.count(ExploreOptions.onThisDayCount),
            )
          : null,
      randomPool: shows(ExploreModuleId.randomMemory)
          ? ExploreLifeBuilder.randomPool(
              all,
              now: now,
              source: random.choice(ExploreOptions.randomSource),
              photosOnly: random.toggle(ExploreOptions.randomPhotosOnly),
            )
          : null,
      recap: shows(ExploreModuleId.recap)
          ? ExploreStatsBuilder.recap(
              all,
              period: recap.choice(ExploreOptions.recapPeriod),
              now: now,
              firstWeekday: request.firstWeekday,
            )
          : null,
      milestones: shows(ExploreModuleId.milestones)
          ? ExploreStatsBuilder.milestones(
              all,
              kinds: milestones.multi(ExploreOptions.milestoneKinds),
              now: now,
            )
          : null,
      overview: shows(ExploreModuleId.overview)
          ? ExploreStatsBuilder.overview(
              all,
              range: range,
              now: now,
              photoCounts: request.photoCounts,
            )
          : null,
      heatmap: shows(ExploreModuleId.heatmap)
          ? ExploreSeriesBuilder.heatmap(
              all,
              now: now,
              weeks: switch (heatmap.choice(ExploreOptions.heatmapSpan)) {
                ExploreHeatmapSpan.weeks12 => 12,
                ExploreHeatmapSpan.weeks26 => 26,
                ExploreHeatmapSpan.weeks52 => 52,
              },
              firstWeekday: request.firstWeekday,
              moodWeights: moodWeights,
              dayMoods: request.dayMoods,
            )
          : null,
      rhythm: shows(ExploreModuleId.rhythm)
          ? ExploreSeriesBuilder.rhythm(
              all,
              now: now,
              unit: rhythm.choice(ExploreOptions.rhythmUnit),
              metric: rhythm.choice(ExploreOptions.rhythmMetric),
              firstWeekday: request.firstWeekday,
            )
          : null,
      habits: shows(ExploreModuleId.habits)
          ? ExploreSeriesBuilder.habits(
              scoped,
              metric: habits.choice(ExploreOptions.habitsMetric),
              firstWeekday: request.firstWeekday,
            )
          : null,
      moodTrend: shows(ExploreModuleId.moodTrend)
          ? ExploreSeriesBuilder.moodSeries(
              all,
              now: now,
              days: moodTrend.count(ExploreOptions.moodTrendDays),
              moodWeights: moodWeights,
              dayMoods: moodTrend.toggle(ExploreOptions.moodTrendDayMoods)
                  ? request.dayMoods
                  : null,
            )
          : null,
      moodShare: shows(ExploreModuleId.moodShare)
          ? ExploreStatsBuilder.moodShare(
              scoped,
              sort: moodShare.choice(ExploreOptions.moodShareSort),
              moodWeights: moodWeights,
            )
          : null,
      energy: shows(ExploreModuleId.energy)
          ? ExploreSeriesBuilder.energySeries(
              all,
              now: now,
              days: energy.count(ExploreOptions.energyDays),
            )
          : null,
      tags: shows(ExploreModuleId.tags)
          ? ExploreLifeBuilder.tags(
              scoped,
              sort: tags.choice(ExploreOptions.tagsSort),
              limit: tags.count(ExploreOptions.tagsCount),
              orderedTagIds: request.orderedTagIds,
            )
          : null,
      media: shows(ExploreModuleId.media)
          ? ExploreLifeBuilder.covers(
              all,
              limit: media.count(ExploreOptions.mediaCount),
            )
          : null,
      places: shows(ExploreModuleId.places)
          ? ExploreLifeBuilder.places(
              scoped,
              limit: places.count(ExploreOptions.placesCount),
            )
          : null,
      weather: shows(ExploreModuleId.weather)
          ? ExploreLifeBuilder.weather(scoped)
          : null,
      recentCapsules: shows(ExploreModuleId.capsules)
          ? ExploreLifeBuilder.recentCapsules(all, now: now)
          : null,
    );
  }
}
