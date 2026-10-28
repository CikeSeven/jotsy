import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/settings_service.dart';
import '../../widgets/mood_band_palette.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../widgets/charts/explore_axis_labels.dart';
import '../widgets/charts/explore_column_chart.dart';
import '../widgets/charts/explore_line_chart.dart';
import '../widgets/charts/explore_reveal.dart';
import '../widgets/charts/explore_share_bars.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 心情一档（1~10）的颜色：十档合并成五段（[MoodBandPalette]），与日历年
/// 视图、日记卡片的心情色同源；没有数据为浅表面色。
Color exploreMoodColor(ColorScheme scheme, double? weight) {
  if (weight == null) {
    return scheme.surfaceContainerHighest.withValues(
      alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.6,
    );
  }
  return MoodBandPalette.color(
    scheme,
    MoodBandPalette.bandForWeight(weight.round()),
  );
}

/// 心情趋势：最近 7 / 30 / 90 天每天的平均心情，画成像素格（7 天时每格写
/// 当天的心情 emoji）、折线或柱状；标题行尾写平均心情。
class ExploreMoodTrendCard extends StatelessWidget {
  const ExploreMoodTrendCard({
    super.key,
    required this.config,
    required this.series,
    required this.moodOptions,
  });

  final ExploreModuleConfig config;
  final List<ExploreDayValue> series;
  final List<String> moodOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final chart = config.choice(ExploreOptions.moodTrendChart);
    final values = <double>[
      for (final day in series)
        if (day.value != null) day.value!,
    ];
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    String emojiOf(double weight) =>
        SettingsService.moodForWeight(weight.round(), moodOptions);
    final labels = exploreDayAxisLabels(<DateTime>[
      for (final day in series) day.day,
    ], l10n.localeName);
    return RepaintBoundary(
      child: ExploreCard(
        child: ExploreReveal(
          enabled: look.animations,
          builder: (BuildContext context, double reveal) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExploreCardHeader(
                icon: FontAwesomeIcons.chartLine,
                title: l10n.exploreModuleMoodTrend,
                trailing: ExploreHeaderNote(
                  average == null
                      ? l10n.exploreLastDays(series.length)
                      : l10n.exploreMoodAverage(emojiOf(average)),
                ),
              ),
              if (values.isEmpty)
                ExploreInlineHint(message: l10n.exploreMoodTrendEmpty)
              else
                switch (chart) {
                  ExploreTrendChart.line => ExploreLineChart(
                    values: <double?>[for (final day in series) day.value],
                    min: 1,
                    max: 10,
                    reveal: reveal,
                    color: look.accentOf(scheme).withValues(alpha: 0.55),
                    pointColor: (double value) =>
                        exploreMoodColor(scheme, value),
                  ),
                  ExploreTrendChart.bars => ExploreColumnChart(
                    reveal: reveal,
                    showValues: false,
                    height: 64,
                    maxValue: 10,
                    columns: <ExploreColumn>[
                      for (var i = 0; i < series.length; i++)
                        ExploreColumn(
                          value: series[i].value ?? 0,
                          color: exploreMoodColor(scheme, series[i].value),
                          label: labels[i],
                        ),
                    ],
                  ),
                  ExploreTrendChart.pixels => _MoodPixels(
                    series: series,
                    reveal: reveal,
                    emojiOf: emojiOf,
                    labels: labels,
                  ),
                },
            ],
          ),
        ),
      ),
    );
  }
}

/// 像素格：7 天时每天一格（写心情 emoji 与星期），更长时为一排排小方格。
class _MoodPixels extends StatelessWidget {
  const _MoodPixels({
    required this.series,
    required this.reveal,
    required this.emojiOf,
    required this.labels,
  });

  final List<ExploreDayValue> series;
  final double reveal;
  final String Function(double weight) emojiOf;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = exploreMoodColor(scheme, null);
    Color colorAt(int index) => Color.lerp(
      empty,
      exploreMoodColor(scheme, series[index].value),
      ExploreReveal.staggered(reveal, index, series.length),
    )!;
    if (series.length <= 7) {
      final labelStyle = Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
      return Row(
        children: <Widget>[
          for (var i = 0; i < series.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorAt(i),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: series[i].value == null
                            ? null
                            : FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    emojiOf(series[i].value!),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], maxLines: 1, style: labelStyle),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    final size = series.length > 45 ? 9.0 : 15.0;
    return Wrap(
      spacing: series.length > 45 ? 3 : 6,
      runSpacing: series.length > 45 ? 3 : 6,
      children: <Widget>[
        for (var i = 0; i < series.length; i++)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorAt(i),
              borderRadius: BorderRadius.circular(size / 3),
            ),
          ),
      ],
    );
  }
}

/// 心情分布：每种用过的心情一行横条（与日记本统计页同一组件），按次数或
/// 心情高低排序，可只写次数不写百分比。跟随统计范围。
class ExploreMoodShareCard extends StatelessWidget {
  const ExploreMoodShareCard({
    super.key,
    required this.config,
    required this.shares,
  });

  final ExploreModuleConfig config;
  final List<ExploreMoodShare> shares;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final percent = config.toggle(ExploreOptions.moodSharePercent);
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.faceSmile,
              title: l10n.exploreModuleMoodShare,
            ),
            if (shares.isEmpty)
              ExploreInlineHint(message: l10n.exploreMoodShareEmpty)
            else
              ExploreShareBars(
                reveal: reveal,
                color: look.accentOf(scheme),
                rows: <ExploreShareRow>[
                  for (final mood in shares)
                    ExploreShareRow(
                      leading: Text(
                        mood.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      count: mood.count,
                      share: mood.share,
                      trailing: percent
                          ? l10n.notebookInsightsMoodShare(
                              mood.count,
                              mood.percent,
                            )
                          : l10n.exploreUnitEntries(mood.count),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 精力趋势：最近 7 / 14 / 30 天每天的平均精力（1~5），柱状或折线；标题
/// 行尾写平均值。
class ExploreEnergyCard extends StatelessWidget {
  const ExploreEnergyCard({
    super.key,
    required this.config,
    required this.series,
  });

  final ExploreModuleConfig config;
  final List<ExploreDayValue> series;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final chart = config.choice(ExploreOptions.energyChart);
    final values = <double>[
      for (final day in series)
        if (day.value != null) day.value!,
    ];
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final labels = exploreDayAxisLabels(<DateTime>[
      for (final day in series) day.day,
    ], l10n.localeName);
    final decimal = NumberFormat('0.0', l10n.localeName);
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.bolt,
              title: l10n.exploreModuleEnergy,
              trailing: ExploreHeaderNote(
                average == null
                    ? l10n.exploreLastDays(series.length)
                    : l10n.exploreEnergyAverage(decimal.format(average)),
              ),
            ),
            if (values.isEmpty)
              ExploreInlineHint(message: l10n.exploreEnergyEmpty)
            else if (chart == ExploreTrendChart.line)
              ExploreLineChart(
                values: <double?>[for (final day in series) day.value],
                min: 1,
                max: 5,
                reveal: reveal,
                color: look.accentOf(scheme),
                height: 72,
              )
            else
              ExploreColumnChart(
                reveal: reveal,
                height: 44,
                showValues: false,
                maxValue: 5,
                color: look.accentOf(scheme),
                columns: <ExploreColumn>[
                  for (var i = 0; i < series.length; i++)
                    ExploreColumn(
                      value: series[i].value ?? 0,
                      label: labels[i],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
