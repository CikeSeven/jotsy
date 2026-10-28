import 'package:flutter/foundation.dart';

import 'explore_layout.dart';
import 'explore_module_config.dart';
import 'explore_module_id.dart';
import 'explore_module_options.dart';
import 'explore_module_spec.dart';

/// 内置布局。
///
/// 预设只决定卡片（顺序、显隐、选项）与是否显示统计范围条，套用时保留当前
/// 外观——外观有自己的标签页与重置，换一套卡片不该把调好的圆角、密度也换掉。
/// [balanced] 即默认布局。
enum ExplorePreset {
  balanced,
  minimal,
  dataLover,
  memories,
  everything;

  /// 套用到 [current]：换掉卡片与范围条，保留外观。
  ExploreLayout applyTo(ExploreLayout current) =>
      current.copyWith(entries: entries, showPeriodBar: showPeriodBar);

  bool get showPeriodBar => switch (this) {
    ExplorePreset.minimal || ExplorePreset.memories => false,
    _ => true,
  };

  List<ExploreLayoutEntry> get entries => _entries[this]!;

  /// [layout] 的卡片与范围条正好是哪套预设；都不是时为 null。
  static ExplorePreset? matching(ExploreLayout layout) {
    for (final preset in values) {
      if (layout.showPeriodBar == preset.showPeriodBar &&
          listEquals(layout.entries, preset.entries)) {
        return preset;
      }
    }
    return null;
  }

  static final Map<ExplorePreset, List<ExploreLayoutEntry>>
  _entries = <ExplorePreset, List<ExploreLayoutEntry>>{
    ExplorePreset.balanced: ExploreLayout.defaults.entries,
    ExplorePreset.minimal: _arrange(<ExploreModuleConfig>[
      _on(ExploreModuleId.greeting),
      _on(ExploreModuleId.onThisDay),
      _on(ExploreModuleId.overview),
      _on(ExploreModuleId.media),
    ]),
    ExplorePreset.dataLover: _arrange(<ExploreModuleConfig>[
      _on(ExploreModuleId.overview).withOption(
        ExploreOptions.overviewMetrics,
        <String>[
          for (final metric in <ExploreMetric>[
            ExploreMetric.entries,
            ExploreMetric.words,
            ExploreMetric.recordedDays,
            ExploreMetric.currentStreak,
            ExploreMetric.longestStreak,
            ExploreMetric.averageWords,
            ExploreMetric.photos,
            ExploreMetric.tags,
            ExploreMetric.span,
          ])
            metric.name,
        ],
      ),
      _on(ExploreModuleId.heatmap)
          .withOption(
            ExploreOptions.heatmapSpan,
            ExploreHeatmapSpan.weeks52.name,
          )
          .withOption(ExploreOptions.heatmapBasis, ExploreHeatBasis.words.name),
      _on(ExploreModuleId.rhythm),
      _on(ExploreModuleId.habits),
      _on(ExploreModuleId.moodTrend)
          .withOption(ExploreOptions.moodTrendDays, 90)
          .withOption(
            ExploreOptions.moodTrendChart,
            ExploreTrendChart.line.name,
          ),
      _on(ExploreModuleId.moodShare),
      _on(ExploreModuleId.energy)
          .withOption(ExploreOptions.energyDays, 14)
          .withOption(ExploreOptions.energyChart, ExploreTrendChart.line.name),
      _on(ExploreModuleId.tags)
          .withOption(ExploreOptions.tagsStyle, ExploreTagStyle.ranking.name)
          .withOption(ExploreOptions.tagsSort, ExploreTagSort.count.name),
      _on(ExploreModuleId.places).withOption(ExploreOptions.placesCount, 10),
      _on(ExploreModuleId.weather).withOption(
        ExploreOptions.weatherStyle,
        ExploreWeatherStyle.ranking.name,
      ),
    ]),
    ExplorePreset.memories: _arrange(<ExploreModuleConfig>[
      _on(ExploreModuleId.greeting),
      _on(ExploreModuleId.onThisDay)
          .withOption(
            ExploreOptions.onThisDayStyle,
            ExploreMemoryStyle.list.name,
          )
          .withOption(
            ExploreOptions.onThisDayMatch,
            ExploreOnThisDayMatch.nearby.name,
          ),
      _on(ExploreModuleId.randomMemory),
      _on(ExploreModuleId.recap),
      _on(ExploreModuleId.media)
          .withOption(ExploreOptions.mediaStyle, ExploreMediaStyle.mosaic.name)
          .withOption(ExploreOptions.mediaCount, 9),
      _on(ExploreModuleId.milestones),
      _on(ExploreModuleId.capsules),
      _on(ExploreModuleId.anniversaries),
      _on(ExploreModuleId.notebooks),
    ]),
    ExplorePreset.everything: <ExploreLayoutEntry>[
      for (final spec in ExploreModuleSpec.all) _on(spec.id),
    ],
  };

  static ExploreModuleConfig _on(ExploreModuleId id) =>
      ExploreModuleConfig(id, visible: true);

  /// [visible] 按给定顺序在前，其余卡片按登记顺序隐藏在后。
  static List<ExploreLayoutEntry> _arrange(List<ExploreModuleConfig> visible) {
    final ids = <ExploreModuleId>{for (final config in visible) config.id};
    return List<ExploreLayoutEntry>.unmodifiable(<ExploreLayoutEntry>[
      ...visible,
      for (final spec in ExploreModuleSpec.all)
        if (!ids.contains(spec.id))
          ExploreModuleConfig(spec.id, visible: false),
    ]);
  }
}
