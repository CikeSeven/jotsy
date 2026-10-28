import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../notebooks/viewmodels/notebook_insights_data.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';
import '../viewmodels/explore_labels.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 数据看板：用户选的指标（有序，最多 9 个）排成网格，每格一个递增数字
/// （[ExploreStatTile]），同一行的格子之间用细竖线隔开（改版前的统计卡同款）。
///
/// 列数“自动”时：1~3 个指标排一行，4 个排两列，更多排三列；每列窄于 96 时
/// 少一列，窄屏上数字不被挤成省略号。标题行尾写当前统计范围。
class ExploreOverviewCard extends StatelessWidget {
  const ExploreOverviewCard({
    super.key,
    required this.config,
    required this.data,
    required this.period,
  });

  final ExploreModuleConfig config;
  final ExploreMetricValues data;
  final ExplorePeriod period;

  static FaIconData iconOf(ExploreMetric metric) => switch (metric) {
    ExploreMetric.entries => FontAwesomeIcons.bookOpen,
    ExploreMetric.words => FontAwesomeIcons.penNib,
    ExploreMetric.recordedDays => FontAwesomeIcons.calendarCheck,
    ExploreMetric.currentStreak => FontAwesomeIcons.fire,
    ExploreMetric.longestStreak => FontAwesomeIcons.medal,
    ExploreMetric.averageWords => FontAwesomeIcons.alignLeft,
    ExploreMetric.photos => FontAwesomeIcons.image,
    ExploreMetric.tags => FontAwesomeIcons.tags,
    ExploreMetric.span => FontAwesomeIcons.hourglassHalf,
    ExploreMetric.todayWords => FontAwesomeIcons.feather,
  };

  int _columns(int count, double width) {
    final chosen = config.count(ExploreOptions.overviewColumns);
    var columns = chosen != 0
        ? chosen
        : count <= 3
        ? count
        : count == 4
        ? 2
        : 3;
    while (columns > 1 && width / columns < 96) {
      columns -= 1;
    }
    return columns < 1 ? 1 : columns;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final metrics = config.multi(ExploreOptions.overviewMetrics);
    String number(int value) => look.formatNumber(value, l10n.localeName);
    String Function(int value) formatOf(ExploreMetric metric) {
      final first = data.first;
      return switch (metric) {
        ExploreMetric.currentStreak ||
        ExploreMetric.longestStreak => l10n.notebookInsightsDays,
        ExploreMetric.span =>
          first == null
              ? l10n.notebookInsightsDays
              : (int value) => notebookSpanDurationLabel(l10n, first, value),
        _ => number,
      };
    }

    final tiles = <Widget>[
      for (final metric in metrics)
        ExploreStatTile(
          icon: iconOf(metric),
          label: ExploreLabels.metric(l10n, metric),
          value: data[metric] ?? 0,
          format: formatOf(metric),
        ),
    ];
    // 数字递增期间只重绘本卡。
    return RepaintBoundary(
      child: ExploreCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.gaugeHigh,
              title: l10n.exploreModuleOverview,
              trailing: ExploreHeaderNote(ExploreLabels.period(l10n, period)),
            ),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final columns = _columns(tiles.length, constraints.maxWidth);
                return Column(
                  children: <Widget>[
                    for (
                      var start = 0;
                      start < tiles.length;
                      start += columns
                    ) ...<Widget>[
                      if (start > 0) const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          for (
                            var i = start;
                            i < start + columns;
                            i++
                          ) ...<Widget>[
                            if (i > start) _divider(colorScheme),
                            Expanded(
                              child: i < tiles.length
                                  ? tiles[i]
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}
