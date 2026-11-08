import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../explore/widgets/charts/explore_column_chart.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../viewmodels/storage_growth.dart';

/// 总览页“媒体增长”：按日记日期每年（或近 12 个月每月）新增多少媒体的
/// 柱状图（与探索页同一个柱状图组件），新增最多的一根用实色、其余半透明，
/// 下面一句话写出最多的是哪一段、多大。按年时柱顶写大小，按月柱太窄只画柱。
/// 全为 0 时不出现。
class StorageGrowthCard extends StatelessWidget {
  const StorageGrowthCard({super.key, required this.series});

  final StorageGrowthSeries series;

  @override
  Widget build(BuildContext context) {
    final peak = series.peakIndex;
    if (peak == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = l10n.localeName;
    final points = series.points;
    String label(DateTime start) =>
        series.yearly ? '${start.year}' : DateFormat.MMM(locale).format(start);
    String? sublabel(int index) {
      if (series.yearly) return null;
      final start = points[index].start;
      return index == 0 || start.month == 1
          ? DateFormat.y(locale).format(start)
          : null;
    }

    final period = series.yearly
        ? DateFormat.y(locale).format(points[peak].start)
        : DateFormat.yMMM(locale).format(points[peak].start);
    return SettingsCardGroup(
      title: l10n.storageMgmtGrowthTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                series.yearly
                    ? l10n.storageMgmtGrowthByYear
                    : l10n.storageMgmtGrowthByMonth,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              ExploreReveal(
                builder: (BuildContext context, double reveal) =>
                    ExploreColumnChart(
                      reveal: reveal,
                      height: 96,
                      showValues: series.yearly,
                      semanticsLabel: l10n.storageMgmtGrowthPeak(
                        period,
                        l10n.formatByteSize(points[peak].bytes),
                      ),
                      columns: [
                        for (var i = 0; i < points.length; i++)
                          ExploreColumn(
                            value: points[i].bytes,
                            label: label(points[i].start),
                            sublabel: sublabel(i),
                            valueLabel: points[i].bytes > 0
                                ? l10n.formatByteSize(points[i].bytes)
                                : '',
                            color: i == peak
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.45),
                          ),
                      ],
                    ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.storageMgmtGrowthPeak(
                  period,
                  l10n.formatByteSize(points[peak].bytes),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
