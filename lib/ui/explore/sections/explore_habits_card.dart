import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../viewmodels/explore_labels.dart';
import '../widgets/charts/explore_column_chart.dart';
import '../widgets/charts/explore_reveal.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 写作习惯：一句结论（最常在哪个时段写、星期几写得最多），下面是时段与
/// 星期两张小柱状图（各自可关）。跟随统计范围。
class ExploreHabitsCard extends StatelessWidget {
  const ExploreHabitsCard({
    super.key,
    required this.config,
    required this.data,
  });

  final ExploreModuleConfig config;
  final ExploreHabitsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final showSlots = config.toggle(ExploreOptions.habitsTimeOfDay);
    final showWeekdays = config.toggle(ExploreOptions.habitsWeekdays);
    final topSlot = data.topSlot;
    final topWeekday = data.topWeekday;
    final weekdayFormat = DateFormat.E(l10n.localeName);
    // 2026-06-01 是周一：加 (weekday - 1) 天得到任意星期几的一个日期。
    String weekdayName(int weekday) =>
        weekdayFormat.format(DateTime(2026, 6, weekday));
    final insight = <String>[
      if (topSlot != null)
        l10n.exploreHabitsTopSlot(ExploreLabels.slot(l10n, topSlot)),
      if (topWeekday != null)
        l10n.exploreHabitsTopWeekday(weekdayName(topWeekday)),
    ].join(' · ');
    final caption = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.clock,
              title: l10n.exploreModuleHabits,
            ),
            if (insight.isEmpty)
              ExploreInlineHint(message: l10n.explorePeriodEmpty)
            else ...<Widget>[
              Text(
                insight,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showSlots) ...<Widget>[
                const SizedBox(height: 12),
                Text(l10n.exploreHabitsTimeOfDay, style: caption),
                const SizedBox(height: 4),
                ExploreColumnChart(
                  reveal: reveal,
                  height: 56,
                  color: look.accentOf(scheme),
                  columns: <ExploreColumn>[
                    for (final slot in ExploreDaySlot.values)
                      ExploreColumn(
                        value: data.slots[slot.index],
                        label: ExploreLabels.slot(l10n, slot),
                      ),
                  ],
                ),
              ],
              if (showWeekdays) ...<Widget>[
                const SizedBox(height: 12),
                Text(l10n.exploreHabitsWeekdays, style: caption),
                const SizedBox(height: 4),
                ExploreColumnChart(
                  reveal: reveal,
                  height: 56,
                  color: look.accentOf(scheme),
                  columns: <ExploreColumn>[
                    for (var i = 0; i < 7; i++)
                      ExploreColumn(
                        value: data.weekdays[i],
                        label: weekdayName(data.weekdayOrder[i]),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
