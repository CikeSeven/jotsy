import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/expressive_button_group.dart';
import '../models/explore_period.dart';
import '../viewmodels/explore_labels.dart';

/// 探索页顶部的统计范围条：本周 / 本月 / 今年 / 全部。只影响跟随统计范围的
/// 卡片（数据看板、标签、写作习惯、心情分布、足迹、天气），选中即保存。
class ExplorePeriodBar extends StatelessWidget {
  const ExplorePeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ExplorePeriod period;
  final ValueChanged<ExplorePeriod>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveButtonGroup<ExplorePeriod>(
      minSegmentWidth: 72,
      segments: <ButtonSegment<ExplorePeriod>>[
        for (final value in ExplorePeriod.values)
          ButtonSegment<ExplorePeriod>(
            value: value,
            // 四段在窄屏上各约 90dp：长标签（This month）整体缩小、不折行。
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(ExploreLabels.period(l10n, value), maxLines: 1),
            ),
          ),
      ],
      selected: <ExplorePeriod>{period},
      onSelectionChanged: onChanged == null
          ? null
          : (Set<ExplorePeriod> next) => onChanged!(next.single),
    );
  }
}
