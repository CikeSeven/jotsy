import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../calendar/models/calendar_display_enums.dart';
import '../../../explore/models/explore_module_id.dart';
import '../../../explore/models/explore_module_options.dart';
import '../../../explore/models/explore_option_spec.dart';
import '../../../explore/models/explore_period.dart';
import '../../../explore/models/explore_presets.dart';
import '../../../explore/viewmodels/explore_labels.dart';
import '../../widgets/style_editor/style_preset_grid.dart';

/// 探索页自定义的文案：分组、宽度、选项标题与取值、内置布局。
abstract final class ExploreLayoutLabels {
  static String group(AppLocalizations l10n, ExploreModuleGroup group) =>
      switch (group) {
        ExploreModuleGroup.recall => l10n.exploreGroupRecall,
        ExploreModuleGroup.stats => l10n.exploreGroupStats,
        ExploreModuleGroup.life => l10n.exploreGroupLife,
        ExploreModuleGroup.linked => l10n.exploreGroupLinked,
      };

  static String span(AppLocalizations l10n, ExploreModuleSpan span) =>
      switch (span) {
        ExploreModuleSpan.auto => l10n.exploreValAuto,
        ExploreModuleSpan.full => l10n.exploreLayoutSpanFull,
        ExploreModuleSpan.half => l10n.exploreLayoutSpanHalf,
      };

  /// 选项标题。同名的键（如 count、style）含义一致，按键取；个别键在不同卡片
  /// 里说法不同（weekdays：热力图是星期标签、写作习惯是星期分布），按声明对象
  /// 区分。
  static String optionTitle(AppLocalizations l10n, ExploreOptionSpec option) {
    if (identical(option, ExploreOptions.heatmapWeekdays)) {
      return l10n.exploreOptWeekdayLabels;
    }
    if (identical(option, ExploreOptions.heatmapSpan)) {
      return l10n.exploreOptHeatmapSpan;
    }
    if (identical(option, ExploreOptions.habitsWeekdays)) {
      return l10n.exploreOptWeekdays;
    }
    return switch (option.key) {
      'lunar' => l10n.exploreOptLunar,
      'prompt' => l10n.exploreOptPrompt,
      'write' => l10n.exploreOptWrite,
      'match' => l10n.exploreOptMatch,
      'style' => l10n.exploreOptStyle,
      'count' => l10n.exploreOptCount,
      'source' => l10n.exploreOptSource,
      'photosOnly' => l10n.exploreOptPhotosOnly,
      'daily' => l10n.exploreOptDaily,
      'period' => l10n.exploreOptRecapPeriod,
      'compare' => l10n.exploreOptCompare,
      'kinds' => l10n.exploreOptKinds,
      'achieved' => l10n.exploreOptAchieved,
      'metrics' => l10n.exploreOptMetrics,
      'columns' => l10n.exploreOptColumns,
      'basis' => l10n.exploreOptBasis,
      'legend' => l10n.exploreOptLegend,
      'unit' => l10n.exploreOptUnit,
      'metric' => l10n.exploreOptMetric,
      'timeOfDay' => l10n.exploreOptTimeOfDay,
      'days' => l10n.exploreOptDays,
      'chart' => l10n.exploreOptChart,
      'dayMoods' => l10n.exploreOptDayMoods,
      'sort' => l10n.exploreOptSort,
      'percent' => l10n.exploreOptPercent,
      'inline' => l10n.exploreOptInline,
      'recent' => l10n.exploreOptRecent,
      _ => option.key,
    };
  }

  /// 单选 / 多选的取值名称。
  static String value(AppLocalizations l10n, Enum value) => switch (value) {
    CalendarLunarMode.locale => l10n.exploreValFollowLanguage,
    CalendarLunarMode.always => l10n.exploreValShow,
    CalendarLunarMode.never => l10n.exploreValHide,
    ExploreOnThisDayMatch.sameDay => l10n.exploreValSameDay,
    ExploreOnThisDayMatch.nearby => l10n.exploreValNearby,
    ExploreOnThisDayMatch.sameMonth => l10n.exploreValSameMonth,
    ExploreMemoryStyle.carousel => l10n.exploreValCarousel,
    ExploreMemoryStyle.list => l10n.exploreValList,
    ExploreRandomSource.all => l10n.exploreValAll,
    ExploreRandomSource.monthAgo => l10n.exploreValMonthAgo,
    ExploreRandomSource.yearAgo => l10n.exploreValYearAgo,
    final ExplorePeriod period => ExploreLabels.period(l10n, period),
    final ExploreMilestoneKind kind => ExploreLabels.milestone(l10n, kind),
    final ExploreMetric metric => ExploreLabels.metric(l10n, metric),
    ExploreHeatmapSpan.weeks12 => l10n.exploreValWeeks12,
    ExploreHeatmapSpan.weeks26 => l10n.exploreValHalfYear,
    ExploreHeatmapSpan.weeks52 => l10n.exploreValYear,
    ExploreHeatBasis.entries ||
    ExploreCountMetric.entries => l10n.exploreValEntries,
    ExploreHeatBasis.words || ExploreCountMetric.words => l10n.exploreValWords,
    ExploreHeatBasis.mood => l10n.exploreValMood,
    ExploreRhythmUnit.month => l10n.exploreValByMonth,
    ExploreRhythmUnit.week => l10n.exploreValByWeek,
    ExploreRhythmUnit.day => l10n.exploreValByDay,
    ExploreTrendChart.pixels => l10n.exploreValPixels,
    ExploreTrendChart.line => l10n.exploreValLine,
    ExploreTrendChart.bars => l10n.exploreValBars,
    ExploreMoodSort.count || ExploreTagSort.count => l10n.exploreValByCount,
    ExploreMoodSort.mood => l10n.exploreValByMood,
    ExploreTagStyle.cloud => l10n.autoT0069,
    ExploreTagStyle.ranking ||
    ExploreWeatherStyle.ranking => l10n.exploreValRanking,
    ExploreTagSort.manual => l10n.exploreValManual,
    ExploreTagSort.recent => l10n.exploreValRecent,
    ExploreMediaStyle.strip => l10n.exploreValStrip,
    ExploreMediaStyle.grid => l10n.exploreValGrid,
    ExploreMediaStyle.mosaic => l10n.exploreValMosaic,
    ExploreWeatherStyle.grid => l10n.exploreValIcons,
    ExploreNotebookSort.shelf => l10n.exploreValShelf,
    ExploreNotebookSort.recent => l10n.exploreValUpdated,
    ExploreNotebookSort.entries => l10n.exploreValByEntries,
    _ => value.name,
  };

  /// 数量选项的取值：0 为“全部”（列数为“自动”），天数写“N 天”，列数写
  /// “N 列”，其余写数字。
  static String count(
    AppLocalizations l10n,
    ExploreCountOption option,
    int value,
  ) {
    if (identical(option, ExploreOptions.overviewColumns)) {
      return value == 0 ? l10n.exploreValAuto : l10n.exploreValColumns(value);
    }
    if (value == 0) return l10n.exploreValAll;
    if (option.key == 'days') return l10n.notebookInsightsDays(value);
    return '$value';
  }

  static List<StylePresetOption<ExplorePreset>> presets(
    AppLocalizations l10n,
  ) => <StylePresetOption<ExplorePreset>>[
    StylePresetOption<ExplorePreset>(
      id: ExplorePreset.balanced,
      icon: FontAwesomeIcons.compass,
      name: l10n.explorePresetBalanced,
      description: l10n.explorePresetBalancedDesc,
    ),
    StylePresetOption<ExplorePreset>(
      id: ExplorePreset.minimal,
      icon: FontAwesomeIcons.feather,
      name: l10n.explorePresetMinimal,
      description: l10n.explorePresetMinimalDesc,
    ),
    StylePresetOption<ExplorePreset>(
      id: ExplorePreset.dataLover,
      icon: FontAwesomeIcons.chartPie,
      name: l10n.explorePresetDataLover,
      description: l10n.explorePresetDataLoverDesc,
    ),
    StylePresetOption<ExplorePreset>(
      id: ExplorePreset.memories,
      icon: FontAwesomeIcons.clockRotateLeft,
      name: l10n.explorePresetMemories,
      description: l10n.explorePresetMemoriesDesc,
    ),
    StylePresetOption<ExplorePreset>(
      id: ExplorePreset.everything,
      icon: FontAwesomeIcons.tableCellsLarge,
      name: l10n.explorePresetEverything,
      description: l10n.explorePresetEverythingDesc,
    ),
  ];
}
