import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../widgets/charts/explore_axis_labels.dart';
import '../widgets/charts/explore_column_chart.dart';
import '../widgets/charts/explore_reveal.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 写作节奏：最近 12 个月 / 12 周 / 30 天每段的篇数或字数柱状图。月份粒度
/// 在 1 月（与第一根）柱下写年份；30 天时柱顶不写数字，太挤。
class ExploreRhythmCard extends StatelessWidget {
  const ExploreRhythmCard({
    super.key,
    required this.config,
    required this.bars,
  });

  final ExploreModuleConfig config;
  final List<ExploreRhythmBar> bars;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final unit = config.choice(ExploreOptions.rhythmUnit);
    final metric = config.choice(ExploreOptions.rhythmMetric);
    final total = bars.fold<int>(0, (sum, bar) => sum + bar.value);
    final monthFormat = DateFormat.MMM(l10n.localeName);
    final weekFormat = DateFormat.Md(l10n.localeName);
    final dayLabels = unit == ExploreRhythmUnit.day
        ? exploreDayAxisLabels(<DateTime>[
            for (final bar in bars) bar.start,
          ], l10n.localeName)
        : null;
    String number(int value) => look.formatNumber(value, l10n.localeName);
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.chartColumn,
              title: l10n.exploreModuleRhythm,
              trailing: ExploreHeaderNote(
                metric == ExploreCountMetric.words
                    ? l10n.exploreTotalWords(number(total))
                    : l10n.exploreTotalEntries(total),
              ),
            ),
            ExploreColumnChart(
              reveal: reveal,
              color: look.accentOf(scheme),
              showValues: unit != ExploreRhythmUnit.day,
              columns: <ExploreColumn>[
                for (var i = 0; i < bars.length; i++)
                  ExploreColumn(
                    value: bars[i].value,
                    valueLabel: bars[i].value > 0
                        ? (metric == ExploreCountMetric.words
                              ? NumberFormat.compact(
                                  locale: l10n.localeName,
                                ).format(bars[i].value)
                              : '${bars[i].value}')
                        : '',
                    label: switch (unit) {
                      ExploreRhythmUnit.month => monthFormat.format(
                        bars[i].start,
                      ),
                      ExploreRhythmUnit.week => weekFormat.format(
                        bars[i].start,
                      ),
                      ExploreRhythmUnit.day => dayLabels![i],
                    },
                    sublabel: unit == ExploreRhythmUnit.month
                        ? (i == 0 || bars[i].start.month == 1
                              ? '${bars[i].start.year}'
                              : '')
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
