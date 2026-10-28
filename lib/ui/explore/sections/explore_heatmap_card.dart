import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../calendar/widgets/calendar_year_palette.dart';
import '../../widgets/mood_band_palette.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../widgets/charts/explore_heatmap_grid.dart';
import '../widgets/charts/explore_reveal.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 写作热力图卡：按周排布的每日格子（[ExploreHeatmapGrid]）与图例。
///
/// 着色依据：篇数（1~4 篇及以上四档）或字数（<200 / <600 / <1500 / 其余，
/// 与日历热力同一档位），颜色为强调色的四档不透明度；心情依据与日历年视图
/// 一致——“这天的心情”优先，否则按当天日记的平均心情分段着色（
/// [MoodBandPalette]），写了日记但没选心情用浅 secondary。点按有日记的格子按
/// 发表先后翻看那天的日记。
class ExploreHeatmapCard extends StatelessWidget {
  const ExploreHeatmapCard({
    super.key,
    required this.config,
    required this.data,
    required this.moodOptions,
  });

  final ExploreModuleConfig config;
  final ExploreHeatmapData data;
  final List<String> moodOptions;

  static const List<double> _alphas = <double>[0.3, 0.5, 0.72, 1];

  static int levelOf(ExploreHeatDay day, ExploreHeatBasis basis) {
    if (day.entries == 0) return 0;
    return switch (basis) {
      ExploreHeatBasis.words => switch (day.words) {
        < 200 => 1,
        < 600 => 2,
        < 1500 => 3,
        _ => 4,
      },
      _ => day.entries.clamp(1, 4),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final actions = ExploreActionsScope.of(context);
    final accent = look.accentOf(scheme);
    final basis = config.choice(ExploreOptions.heatmapBasis);
    final empty = CalendarYearPalette.emptyColor(scheme);
    Color colorOf(ExploreHeatDay? day) {
      if (day == null) return empty;
      if (basis == ExploreHeatBasis.mood) {
        final dayMood = day.dayMood;
        if (dayMood != null) {
          return MoodBandPalette.color(scheme, dayMood.index);
        }
        if (day.entries == 0) return empty;
        final weight = day.moodWeight;
        if (weight == null) return CalendarYearPalette.noMoodColor(scheme);
        return MoodBandPalette.color(
          scheme,
          MoodBandPalette.bandForWeight(weight.round()),
        );
      }
      final level = levelOf(day, basis);
      return level == 0 ? empty : accent.withValues(alpha: _alphas[level - 1]);
    }

    final writtenDays = data.days.values.where((day) => day.entries > 0).length;
    final summary = l10n.exploreHeatmapSummary(writtenDays, data.weeks);
    final dateFormat = l10n.formatFullDate;
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.tableCells,
              title: l10n.exploreModuleHeatmap,
            ),
            ExploreHeatmapGrid(
              data: data,
              colorOf: colorOf,
              emptyColor: empty,
              todayColor: accent,
              reveal: reveal,
              showWeekdays: config.toggle(ExploreOptions.heatmapWeekdays),
              summary: summary,
              describe: (DateTime date, ExploreHeatDay? day) =>
                  day == null || day.entries == 0
                  ? l10n.exploreHeatmapDayEmpty(dateFormat(date))
                  : l10n.exploreHeatmapDay(
                      dateFormat(date),
                      day.entries,
                      look.formatNumber(day.words, l10n.localeName),
                    ),
              onDayTap: (ExploreHeatDay day) =>
                  actions.openDiary(day.diaryIds.first, sequence: day.diaryIds),
            ),
            if (config.toggle(ExploreOptions.heatmapLegend)) ...<Widget>[
              const SizedBox(height: 8),
              _Legend(
                colors: basis == ExploreHeatBasis.mood
                    ? <Color>[
                        for (var band = 0; band < 5; band++)
                          MoodBandPalette.color(scheme, band),
                      ]
                    : <Color>[
                        empty,
                        for (final alpha in _alphas)
                          accent.withValues(alpha: alpha),
                      ],
                low: basis == ExploreHeatBasis.mood
                    ? _moodEmoji(MoodBandPalette.bandWeights.first)
                    : l10n.exploreHeatmapLess,
                high: basis == ExploreHeatBasis.mood
                    ? _moodEmoji(MoodBandPalette.bandWeights.last)
                    : l10n.exploreHeatmapMore,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _moodEmoji(int weight) =>
      moodOptions.length >= weight ? moodOptions[weight - 1] : '';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors, required this.low, required this.high});

  final List<Color> colors;
  final String low;
  final String high;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(low, style: style),
          const SizedBox(width: 6),
          for (final color in colors)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: 6),
          Text(high, style: style),
        ],
      ),
    );
  }
}
