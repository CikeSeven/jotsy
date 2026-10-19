import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../utils/date_range_format.dart';
import '../models/calendar_range_selection.dart';

/// 范围统计的标题行：起止日期与天数，右侧为“存为日记本”与退出范围选择的
/// 按钮；尚未选定终点时提示“点按另一天作为终点”（此时没有“存为日记本”）。
///
/// 输入：当前范围、当前时刻、退出回调与可选的存为日记本回调；无副作用。首尾跨年或不在今年时
/// 日期带上年份，否则只写月日，窄屏上一行放得下。
class CalendarRangeHeader extends StatelessWidget {
  const CalendarRangeHeader({
    super.key,
    required this.range,
    required this.now,
    required this.onExit,
    this.onSaveAsNotebook,
  });

  final CalendarRangeSelection range;
  final DateTime now;
  final VoidCallback onExit;

  /// 把这段日期存为日记本；null 时不显示按钮。只在首尾都选定后出现。
  final VoidCallback? onSaveAsNotebook;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final first = range.first;
    final last = range.last;
    final format = dateRangeEndpointFormat(
      l10n.localeName,
      first: first,
      last: last,
      now: now,
    );
    final title = range.isComplete
        ? l10n.calendarRangeTitle(
            format.format(first),
            format.format(last),
            range.dayCount,
          )
        : l10n.calendarRangePickEnd(format.format(range.start));
    return Row(
      children: <Widget>[
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: range.isComplete
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (range.isComplete && onSaveAsNotebook != null)
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: onSaveAsNotebook,
            child: Text(l10n.notebookSaveRange),
          ),
        IconButton(
          tooltip: l10n.calendarRangeExit,
          visualDensity: VisualDensity.compact,
          onPressed: onExit,
          icon: FaIcon(
            FontAwesomeIcons.xmark,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
