import '../../calendar/models/calendar_display_enums.dart';
import 'explore_option_spec.dart';
import 'explore_period.dart';

// 各卡片选项的取值枚举与声明。持久化存的是枚举名，重命名等同于改存储格式。

/// 那年今日的匹配方式。
enum ExploreOnThisDayMatch { sameDay, nearby, sameMonth }

/// 回忆列表的样式。
enum ExploreMemoryStyle { carousel, list }

/// 随机回顾的抽取范围。
enum ExploreRandomSource { all, monthAgo, yearAgo }

/// 里程碑类别。
enum ExploreMilestoneKind { entries, words, streak, days, years }

/// 数据看板的指标。
enum ExploreMetric {
  entries,
  words,
  recordedDays,
  currentStreak,
  longestStreak,
  averageWords,
  photos,
  tags,
  span,
  todayWords,
}

/// 写作热力图的跨度。
enum ExploreHeatmapSpan { weeks12, weeks26, weeks52 }

/// 热力图格子的着色依据。
enum ExploreHeatBasis { entries, words, mood }

/// 写作节奏的粒度。
enum ExploreRhythmUnit { month, week, day }

/// 按篇数还是字数统计。
enum ExploreCountMetric { entries, words }

/// 趋势图的画法。
enum ExploreTrendChart { pixels, line, bars }

/// 心情分布的排序。
enum ExploreMoodSort { count, mood }

/// 标签卡的样式与排序。
enum ExploreTagStyle { cloud, ranking }

enum ExploreTagSort { manual, count, recent }

/// 媒体卡的样式。
enum ExploreMediaStyle { strip, grid, mosaic }

/// 天气卡的样式。
enum ExploreWeatherStyle { grid, ranking }

/// 日记本卡的排序。
enum ExploreNotebookSort { shelf, recent, entries }

/// 全部卡片选项的声明（键在同一张卡里唯一；同名键含义一致，编辑页按键取
/// 标题）。
abstract final class ExploreOptions {
  // 今日问候
  static const greetingLunar = ExploreChoiceOption<CalendarLunarMode>(
    'lunar',
    values: CalendarLunarMode.values,
    fallback: CalendarLunarMode.locale,
  );
  static const greetingPrompt = ExploreToggleOption('prompt', fallback: true);
  static const greetingWrite = ExploreToggleOption('write', fallback: true);

  // 那年今日
  static const onThisDayMatch = ExploreChoiceOption<ExploreOnThisDayMatch>(
    'match',
    values: ExploreOnThisDayMatch.values,
    fallback: ExploreOnThisDayMatch.sameDay,
  );
  static const onThisDayStyle = ExploreChoiceOption<ExploreMemoryStyle>(
    'style',
    values: ExploreMemoryStyle.values,
    fallback: ExploreMemoryStyle.carousel,
  );
  static const onThisDayCount = ExploreCountOption(
    'count',
    values: <int>[3, 6, 12],
    fallback: 12,
  );

  // 随机回顾
  static const randomSource = ExploreChoiceOption<ExploreRandomSource>(
    'source',
    values: ExploreRandomSource.values,
    fallback: ExploreRandomSource.all,
  );
  static const randomPhotosOnly = ExploreToggleOption(
    'photosOnly',
    fallback: false,
  );
  static const randomDaily = ExploreToggleOption('daily', fallback: true);

  // 周期回顾
  static const recapPeriod = ExploreChoiceOption<ExplorePeriod>(
    'period',
    values: <ExplorePeriod>[
      ExplorePeriod.week,
      ExplorePeriod.month,
      ExplorePeriod.year,
    ],
    fallback: ExplorePeriod.month,
  );
  static const recapCompare = ExploreToggleOption('compare', fallback: true);

  // 里程碑
  static const milestoneKinds = ExploreMultiOption<ExploreMilestoneKind>(
    'kinds',
    values: ExploreMilestoneKind.values,
    fallback: ExploreMilestoneKind.values,
    maxSelected: 5,
  );
  static const milestoneAchieved = ExploreToggleOption(
    'achieved',
    fallback: true,
  );

  // 数据看板
  static const overviewMetrics = ExploreMultiOption<ExploreMetric>(
    'metrics',
    values: ExploreMetric.values,
    fallback: <ExploreMetric>[
      ExploreMetric.entries,
      ExploreMetric.currentStreak,
      ExploreMetric.words,
    ],
    maxSelected: 9,
  );
  static const overviewColumns = ExploreCountOption(
    'columns',
    values: <int>[0, 2, 3],
    fallback: 0,
  );

  // 写作热力图
  static const heatmapSpan = ExploreChoiceOption<ExploreHeatmapSpan>(
    'span',
    values: ExploreHeatmapSpan.values,
    fallback: ExploreHeatmapSpan.weeks26,
  );
  static const heatmapBasis = ExploreChoiceOption<ExploreHeatBasis>(
    'basis',
    values: ExploreHeatBasis.values,
    fallback: ExploreHeatBasis.entries,
  );
  static const heatmapWeekdays = ExploreToggleOption(
    'weekdays',
    fallback: true,
  );
  static const heatmapLegend = ExploreToggleOption('legend', fallback: true);

  // 写作节奏
  static const rhythmUnit = ExploreChoiceOption<ExploreRhythmUnit>(
    'unit',
    values: ExploreRhythmUnit.values,
    fallback: ExploreRhythmUnit.month,
  );
  static const rhythmMetric = ExploreChoiceOption<ExploreCountMetric>(
    'metric',
    values: ExploreCountMetric.values,
    fallback: ExploreCountMetric.entries,
  );

  // 写作习惯
  static const habitsTimeOfDay = ExploreToggleOption(
    'timeOfDay',
    fallback: true,
  );
  static const habitsWeekdays = ExploreToggleOption('weekdays', fallback: true);
  static const habitsMetric = ExploreChoiceOption<ExploreCountMetric>(
    'metric',
    values: ExploreCountMetric.values,
    fallback: ExploreCountMetric.entries,
  );

  // 心情趋势
  static const moodTrendDays = ExploreCountOption(
    'days',
    values: <int>[7, 30, 90],
    fallback: 30,
  );
  static const moodTrendChart = ExploreChoiceOption<ExploreTrendChart>(
    'chart',
    values: ExploreTrendChart.values,
    fallback: ExploreTrendChart.pixels,
  );
  static const moodTrendDayMoods = ExploreToggleOption(
    'dayMoods',
    fallback: true,
  );

  // 心情分布
  static const moodShareSort = ExploreChoiceOption<ExploreMoodSort>(
    'sort',
    values: ExploreMoodSort.values,
    fallback: ExploreMoodSort.count,
  );
  static const moodSharePercent = ExploreToggleOption(
    'percent',
    fallback: true,
  );

  // 精力趋势
  static const energyDays = ExploreCountOption(
    'days',
    values: <int>[7, 14, 30],
    fallback: 7,
  );
  static const energyChart = ExploreChoiceOption<ExploreTrendChart>(
    'chart',
    values: <ExploreTrendChart>[ExploreTrendChart.bars, ExploreTrendChart.line],
    fallback: ExploreTrendChart.bars,
  );

  // 标签
  static const tagsStyle = ExploreChoiceOption<ExploreTagStyle>(
    'style',
    values: ExploreTagStyle.values,
    fallback: ExploreTagStyle.cloud,
  );
  static const tagsSort = ExploreChoiceOption<ExploreTagSort>(
    'sort',
    values: ExploreTagSort.values,
    fallback: ExploreTagSort.manual,
  );
  static const tagsCount = ExploreCountOption(
    'count',
    values: <int>[10, 20, 0],
    fallback: 20,
  );

  // 媒体
  static const mediaStyle = ExploreChoiceOption<ExploreMediaStyle>(
    'style',
    values: ExploreMediaStyle.values,
    fallback: ExploreMediaStyle.strip,
  );
  static const mediaCount = ExploreCountOption(
    'count',
    values: <int>[5, 9, 12],
    fallback: 5,
  );
  static const mediaInline = ExploreToggleOption('inline', fallback: false);

  // 足迹
  static const placesCount = ExploreCountOption(
    'count',
    values: <int>[5, 10],
    fallback: 5,
  );

  // 天气
  static const weatherStyle = ExploreChoiceOption<ExploreWeatherStyle>(
    'style',
    values: ExploreWeatherStyle.values,
    fallback: ExploreWeatherStyle.grid,
  );

  // 纪念日
  static const anniversariesCount = ExploreCountOption(
    'count',
    values: <int>[1, 3, 5],
    fallback: 3,
  );

  // 时间胶囊
  static const capsulesRecent = ExploreToggleOption('recent', fallback: true);

  // 日记本
  static const notebooksSort = ExploreChoiceOption<ExploreNotebookSort>(
    'sort',
    values: ExploreNotebookSort.values,
    fallback: ExploreNotebookSort.shelf,
  );
  static const notebooksCount = ExploreCountOption(
    'count',
    values: <int>[4, 8, 0],
    fallback: 8,
  );
}
