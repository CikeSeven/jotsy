import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import 'calendar_day_cell.dart';

/// 日历卡片内部共用的 0.6dp 细分隔线：星期栏与日期网格之间、日期网格与概览条
/// 之间各放一条，明暗透明度与卡片微边框保持同一档次。
class CalendarPanelDivider extends StatelessWidget {
  const CalendarPanelDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 0.6,
      color: colorScheme.outlineVariant.withValues(
        alpha: colorScheme.brightness == Brightness.light ? 0.35 : 0.18,
      ),
    );
  }
}

/// 日历卡片顶部的星期栏与底部分隔线。
///
/// 输入：每周起始日 [firstWeekday]、是否高亮周末 [highlightWeekends]、周数列
/// 预留宽 [leadingSpace] 与宽窗口下的高亮宽度上限 [highlightMaxWidth]；无副作用。
///
/// 独立画在 `TableCalendar` 之外，翻月左右滑时星期与分隔线保持静止，并保证
/// 分隔线与底部概览条的分隔线左右对齐（均内缩 8dp、上下各留 4dp）。
class CalendarWeekdayBar extends StatelessWidget {
  const CalendarWeekdayBar({
    super.key,
    required this.firstWeekday,
    required this.highlightWeekends,
    this.leadingSpace = 0,
    this.highlightMaxWidth,
  });

  /// 每周第一天（`DateTime.monday` … `DateTime.sunday`）。
  final int firstWeekday;
  final bool highlightWeekends;

  /// 显示周数时为左侧周数列留出的等宽空位，使 7 列星期与下方日期格对齐。
  final double leadingSpace;

  /// 宽窗口下周末色带的最大宽度（含外侧 4dp 留白）；手机上为 null。
  final double? highlightMaxWidth;

  /// 2024-01-01 为周一（`DateTime.monday == 1`），加偏移即可得到该星期的样例日期。
  static DateTime _sampleDay(int weekday) => DateTime.utc(2024, 1, weekday);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final maxWidth = highlightMaxWidth;

    Widget buildWeekday(int offset) {
      final day = _sampleDay(firstWeekday + offset);
      // 独立窄星期（ccccc）：中文“一…日”、英文“M…S”，
      // 由 intl 语言数据提供，新增语言无需改代码。
      final label = DateFormat('ccccc', l10n.localeName).format(day);
      final shaded =
          highlightWeekends &&
          (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday);
      // 周末着色时星期栏的“六、日”也铺同样的灰底，与下方日期格连成一条竖向色带；
      // 宽窗口下与日期格高亮同宽居中。
      final band = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: shaded ? CalendarDayCell.weekendColor(colorScheme) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: textTheme.bodySmall?.copyWith(
                  color: shaded
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
      if (maxWidth == null) {
        return band;
      }
      // 不能复用 CalendarDayCell.limitWidth（内部 SizedBox.expand 需要有界高度）；
      // 这里只限制宽度，高度随字体与系统文字缩放自然展开。
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: band),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (leadingSpace > 0) SizedBox(width: leadingSpace),
            for (var i = 0; i < DateTime.daysPerWeek; i++)
              Expanded(child: buildWeekday(i)),
          ],
        ),
        // 与底部概览条（CalendarMonthSummary）对称：左右内缩 8、上下各 4。
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: CalendarPanelDivider(),
        ),
      ],
    );
  }
}
