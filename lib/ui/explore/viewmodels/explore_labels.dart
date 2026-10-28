import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_module_data.dart';
import '../models/explore_module_id.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';

/// 探索页的展示文案（页面、卡片与编辑页共用），保证各处说法一致。
abstract final class ExploreLabels {
  static String moduleName(AppLocalizations l10n, ExploreModuleId id) =>
      switch (id) {
        ExploreModuleId.greeting => l10n.exploreModuleGreeting,
        ExploreModuleId.onThisDay => l10n.exploreModuleOnThisDay,
        ExploreModuleId.randomMemory => l10n.exploreModuleRandomMemory,
        ExploreModuleId.recap => l10n.exploreModuleRecap,
        ExploreModuleId.milestones => l10n.exploreModuleMilestones,
        ExploreModuleId.overview => l10n.exploreModuleOverview,
        ExploreModuleId.heatmap => l10n.exploreModuleHeatmap,
        ExploreModuleId.rhythm => l10n.exploreModuleRhythm,
        ExploreModuleId.habits => l10n.exploreModuleHabits,
        ExploreModuleId.moodTrend => l10n.exploreModuleMoodTrend,
        ExploreModuleId.moodShare => l10n.exploreModuleMoodShare,
        ExploreModuleId.energy => l10n.exploreModuleEnergy,
        ExploreModuleId.tags => l10n.exploreModuleTags,
        ExploreModuleId.media => l10n.exploreModuleMedia,
        ExploreModuleId.places => l10n.exploreModulePlaces,
        ExploreModuleId.weather => l10n.exploreModuleWeather,
        ExploreModuleId.anniversaries => l10n.exploreModuleAnniversaries,
        ExploreModuleId.capsules => l10n.exploreModuleCapsules,
        ExploreModuleId.notebooks => l10n.exploreModuleNotebooks,
        ExploreModuleId.drafts => l10n.exploreModuleDrafts,
        ExploreModuleId.comments => l10n.exploreModuleComments,
      };

  static String moduleDescription(AppLocalizations l10n, ExploreModuleId id) =>
      switch (id) {
        ExploreModuleId.greeting => l10n.exploreModuleGreetingDesc,
        ExploreModuleId.onThisDay => l10n.exploreModuleOnThisDayDesc,
        ExploreModuleId.randomMemory => l10n.exploreModuleRandomMemoryDesc,
        ExploreModuleId.recap => l10n.exploreModuleRecapDesc,
        ExploreModuleId.milestones => l10n.exploreModuleMilestonesDesc,
        ExploreModuleId.overview => l10n.exploreModuleOverviewDesc,
        ExploreModuleId.heatmap => l10n.exploreModuleHeatmapDesc,
        ExploreModuleId.rhythm => l10n.exploreModuleRhythmDesc,
        ExploreModuleId.habits => l10n.exploreModuleHabitsDesc,
        ExploreModuleId.moodTrend => l10n.exploreModuleMoodTrendDesc,
        ExploreModuleId.moodShare => l10n.exploreModuleMoodShareDesc,
        ExploreModuleId.energy => l10n.exploreModuleEnergyDesc,
        ExploreModuleId.tags => l10n.exploreModuleTagsDesc,
        ExploreModuleId.media => l10n.exploreModuleMediaDesc,
        ExploreModuleId.places => l10n.exploreModulePlacesDesc,
        ExploreModuleId.weather => l10n.exploreModuleWeatherDesc,
        ExploreModuleId.anniversaries => l10n.exploreModuleAnniversariesDesc,
        ExploreModuleId.capsules => l10n.exploreModuleCapsulesDesc,
        ExploreModuleId.notebooks => l10n.exploreModuleNotebooksDesc,
        ExploreModuleId.drafts => l10n.exploreModuleDraftsDesc,
        ExploreModuleId.comments => l10n.exploreModuleCommentsDesc,
      };

  static String period(AppLocalizations l10n, ExplorePeriod period) =>
      switch (period) {
        ExplorePeriod.week => l10n.explorePeriodWeek,
        ExplorePeriod.month => l10n.explorePeriodMonth,
        ExplorePeriod.year => l10n.explorePeriodYear,
        ExplorePeriod.all => l10n.explorePeriodAll,
      };

  static String metric(AppLocalizations l10n, ExploreMetric metric) =>
      switch (metric) {
        ExploreMetric.entries => l10n.exploreMetricEntries,
        ExploreMetric.words => l10n.exploreMetricWords,
        ExploreMetric.recordedDays => l10n.exploreMetricRecordedDays,
        ExploreMetric.currentStreak => l10n.exploreMetricCurrentStreak,
        ExploreMetric.longestStreak => l10n.exploreMetricLongestStreak,
        ExploreMetric.averageWords => l10n.exploreMetricAverageWords,
        ExploreMetric.photos => l10n.exploreMetricPhotos,
        ExploreMetric.tags => l10n.exploreMetricTags,
        ExploreMetric.span => l10n.exploreMetricSpan,
        ExploreMetric.todayWords => l10n.exploreMetricTodayWords,
      };

  static String milestone(AppLocalizations l10n, ExploreMilestoneKind kind) =>
      switch (kind) {
        ExploreMilestoneKind.entries => l10n.exploreMilestoneEntries,
        ExploreMilestoneKind.words => l10n.exploreMilestoneWords,
        ExploreMilestoneKind.streak => l10n.exploreMilestoneStreak,
        ExploreMilestoneKind.days => l10n.exploreMilestoneDays,
        ExploreMilestoneKind.years => l10n.exploreMilestoneYears,
      };

  static String slot(AppLocalizations l10n, ExploreDaySlot slot) =>
      switch (slot) {
        ExploreDaySlot.lateNight => l10n.exploreSlotLateNight,
        ExploreDaySlot.morning => l10n.exploreSlotMorning,
        ExploreDaySlot.forenoon => l10n.exploreSlotForenoon,
        ExploreDaySlot.afternoon => l10n.exploreSlotAfternoon,
        ExploreDaySlot.evening => l10n.exploreSlotEvening,
        ExploreDaySlot.night => l10n.exploreSlotNight,
      };

  /// 按时段的问候：5–11 早上、11–13 中午、13–18 下午、18–23 晚上，其余夜深。
  static String greeting(AppLocalizations l10n, int hour) {
    if (hour >= 5 && hour < 11) return l10n.exploreGreetingMorning;
    if (hour >= 11 && hour < 13) return l10n.exploreGreetingNoon;
    if (hour >= 13 && hour < 18) return l10n.exploreGreetingAfternoon;
    if (hour >= 18 && hour < 23) return l10n.exploreGreetingEvening;
    return l10n.exploreGreetingNight;
  }

  /// 每日写作提示（按一年中的第几天轮换）。
  static List<String> prompts(AppLocalizations l10n) => <String>[
    l10n.autoT0049,
    l10n.autoT0050,
    l10n.autoT0051,
    l10n.autoT0196,
    l10n.explorePrompt01,
    l10n.explorePrompt02,
    l10n.explorePrompt03,
    l10n.explorePrompt04,
    l10n.explorePrompt05,
    l10n.explorePrompt06,
    l10n.explorePrompt07,
    l10n.explorePrompt08,
    l10n.explorePrompt09,
    l10n.explorePrompt10,
    l10n.explorePrompt11,
    l10n.explorePrompt12,
    l10n.explorePrompt13,
    l10n.explorePrompt14,
    l10n.explorePrompt15,
    l10n.explorePrompt16,
    l10n.explorePrompt17,
    l10n.explorePrompt18,
    l10n.explorePrompt19,
    l10n.explorePrompt20,
  ];
}
