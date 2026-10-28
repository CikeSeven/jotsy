import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/app_features.dart';
import 'explore_module_id.dart';
import 'explore_module_options.dart';
import 'explore_option_spec.dart';

/// 卡片依赖的功能（设置 → 功能管理）；功能关闭时卡片不出现，编辑页里也
/// 显示为不可用。
enum ExploreModuleFeature { anniversaries, timeCapsules, notebooks, comments }

/// 一张卡片的登记信息：图标、分组、默认显隐与宽度、依赖的功能、是否跟随
/// 统计范围，以及它的选项。
///
/// [all] 的顺序就是默认布局的顺序，也是读取旧布局时补齐缺失卡片的顺序。
@immutable
class ExploreModuleSpec {
  const ExploreModuleSpec(
    this.id, {
    required this.group,
    required this.icon,
    this.visibleByDefault = false,
    this.halfByDefault = false,
    this.periodAware = false,
    this.feature,
    this.options = const <ExploreOptionSpec>[],
  });

  final ExploreModuleId id;
  final ExploreModuleGroup group;
  final FaIconData icon;
  final bool visibleByDefault;

  /// 宽度为“自动”时在宽窗口占一列（否则占整行）。
  final bool halfByDefault;

  /// 是否按页面顶部的统计范围取数据。
  final bool periodAware;
  final ExploreModuleFeature? feature;
  final List<ExploreOptionSpec> options;

  /// 在当前功能开关下是否可用。纪念日依附日历，读 `anniversariesEnabled`。
  bool isAvailable(AppFeatures features) => switch (feature) {
    null => true,
    ExploreModuleFeature.anniversaries => features.anniversariesEnabled,
    ExploreModuleFeature.timeCapsules => features.timeCapsules,
    ExploreModuleFeature.notebooks => features.notebooks,
    ExploreModuleFeature.comments => features.comments,
  };

  /// [span] 为“自动”时换算成这张卡的默认宽度。
  ExploreModuleSpan resolveSpan(ExploreModuleSpan span) =>
      span != ExploreModuleSpan.auto
      ? span
      : (halfByDefault ? ExploreModuleSpan.half : ExploreModuleSpan.full);

  static ExploreModuleSpec of(ExploreModuleId id) => _byId[id]!;

  static final Map<ExploreModuleId, ExploreModuleSpec> _byId =
      <ExploreModuleId, ExploreModuleSpec>{
        for (final spec in all) spec.id: spec,
      };

  /// 全部卡片，按默认布局的顺序。
  static const List<ExploreModuleSpec> all = <ExploreModuleSpec>[
    ExploreModuleSpec(
      ExploreModuleId.greeting,
      group: ExploreModuleGroup.recall,
      icon: FontAwesomeIcons.sun,
      visibleByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.greetingLunar,
        ExploreOptions.greetingPrompt,
        ExploreOptions.greetingWrite,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.drafts,
      group: ExploreModuleGroup.linked,
      icon: FontAwesomeIcons.filePen,
      visibleByDefault: true,
      halfByDefault: true,
    ),
    ExploreModuleSpec(
      ExploreModuleId.overview,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.gaugeHigh,
      visibleByDefault: true,
      periodAware: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.overviewMetrics,
        ExploreOptions.overviewColumns,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.onThisDay,
      group: ExploreModuleGroup.recall,
      icon: FontAwesomeIcons.clockRotateLeft,
      visibleByDefault: true,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.onThisDayMatch,
        ExploreOptions.onThisDayStyle,
        ExploreOptions.onThisDayCount,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.moodTrend,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.chartLine,
      visibleByDefault: true,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.moodTrendDays,
        ExploreOptions.moodTrendChart,
        ExploreOptions.moodTrendDayMoods,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.heatmap,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.tableCells,
      visibleByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.heatmapSpan,
        ExploreOptions.heatmapBasis,
        ExploreOptions.heatmapWeekdays,
        ExploreOptions.heatmapLegend,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.randomMemory,
      group: ExploreModuleGroup.recall,
      icon: FontAwesomeIcons.shuffle,
      visibleByDefault: true,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.randomSource,
        ExploreOptions.randomPhotosOnly,
        ExploreOptions.randomDaily,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.anniversaries,
      group: ExploreModuleGroup.linked,
      icon: FontAwesomeIcons.heart,
      visibleByDefault: true,
      halfByDefault: true,
      feature: ExploreModuleFeature.anniversaries,
      options: <ExploreOptionSpec>[ExploreOptions.anniversariesCount],
    ),
    ExploreModuleSpec(
      ExploreModuleId.capsules,
      group: ExploreModuleGroup.linked,
      icon: FontAwesomeIcons.hourglassHalf,
      visibleByDefault: true,
      halfByDefault: true,
      feature: ExploreModuleFeature.timeCapsules,
      options: <ExploreOptionSpec>[ExploreOptions.capsulesRecent],
    ),
    ExploreModuleSpec(
      ExploreModuleId.tags,
      group: ExploreModuleGroup.life,
      icon: FontAwesomeIcons.tags,
      visibleByDefault: true,
      periodAware: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.tagsStyle,
        ExploreOptions.tagsSort,
        ExploreOptions.tagsCount,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.media,
      group: ExploreModuleGroup.life,
      icon: FontAwesomeIcons.images,
      visibleByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.mediaStyle,
        ExploreOptions.mediaCount,
        ExploreOptions.mediaInline,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.recap,
      group: ExploreModuleGroup.recall,
      icon: FontAwesomeIcons.calendarCheck,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.recapPeriod,
        ExploreOptions.recapCompare,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.milestones,
      group: ExploreModuleGroup.recall,
      icon: FontAwesomeIcons.trophy,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.milestoneKinds,
        ExploreOptions.milestoneAchieved,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.rhythm,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.chartColumn,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.rhythmUnit,
        ExploreOptions.rhythmMetric,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.habits,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.clock,
      halfByDefault: true,
      periodAware: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.habitsTimeOfDay,
        ExploreOptions.habitsWeekdays,
        ExploreOptions.habitsMetric,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.moodShare,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.faceSmile,
      halfByDefault: true,
      periodAware: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.moodShareSort,
        ExploreOptions.moodSharePercent,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.energy,
      group: ExploreModuleGroup.stats,
      icon: FontAwesomeIcons.bolt,
      halfByDefault: true,
      options: <ExploreOptionSpec>[
        ExploreOptions.energyDays,
        ExploreOptions.energyChart,
      ],
    ),
    ExploreModuleSpec(
      ExploreModuleId.places,
      group: ExploreModuleGroup.life,
      icon: FontAwesomeIcons.locationDot,
      halfByDefault: true,
      periodAware: true,
      options: <ExploreOptionSpec>[ExploreOptions.placesCount],
    ),
    ExploreModuleSpec(
      ExploreModuleId.weather,
      group: ExploreModuleGroup.life,
      icon: FontAwesomeIcons.cloudSun,
      halfByDefault: true,
      periodAware: true,
      options: <ExploreOptionSpec>[ExploreOptions.weatherStyle],
    ),
    ExploreModuleSpec(
      ExploreModuleId.notebooks,
      group: ExploreModuleGroup.linked,
      icon: FontAwesomeIcons.book,
      feature: ExploreModuleFeature.notebooks,
      options: <ExploreOptionSpec>[
        ExploreOptions.notebooksSort,
        ExploreOptions.notebooksCount,
      ],
    ),
    // 留言是后加的功能：登记在最后，老布局读取时它按默认显示补到末尾（功能
    // 默认关闭，开启前不会出现）。归“关联”：数据来自留言这项独立功能（自己的
    // 表、可在功能管理里关闭），与纪念日、时间胶囊、日记本同一类。
    ExploreModuleSpec(
      ExploreModuleId.comments,
      group: ExploreModuleGroup.linked,
      icon: FontAwesomeIcons.comment,
      visibleByDefault: true,
      halfByDefault: true,
      feature: ExploreModuleFeature.comments,
      options: <ExploreOptionSpec>[ExploreOptions.commentsCount],
    ),
  ];
}
