import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../models/calendar_range_selection.dart';

/// 范围统计的标题行：起止日期与天数，右侧为退出范围选择的按钮；尚未选定
/// 终点时提示“点按另一天作为终点”。
///
/// 输入：当前范围、当前时刻与退出回调；无副作用。首尾跨年或不在今年时
/// 日期带上年份，否则只写月日，窄屏上一行放得下。
class CalendarRangeHeader extends StatelessWidget {
  const CalendarRangeHeader({
    super.key,
    required this.range,
    required this.now,
    required this.onExit,
  });

  final CalendarRangeSelection range;
  final DateTime now;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final first = range.first;
    final last = range.last;
    final withYear = first.year != last.year || first.year != now.year;
    final format = withYear
        ? DateFormat.yMMMd(l10n.localeName)
        : DateFormat.MMMd(l10n.localeName);
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
