import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/calendar_month_stats.dart';

/// 日历卡片底部的月度概览条。
///
/// 输入：当前翻到的月份的 [CalendarMonthStats]；输出一行图标 + 数字。无
/// 副作用。
///
/// 只放数字不放单位：中英文单位长度差很多，320dp 宽的卡片里英文
/// “12 entries · 9/15 days · …”放不下。完整含义经 Tooltip（长按）与读屏
/// 标签给出。翻月或数据变化时整行短交叉淡入。
class CalendarMonthSummary extends StatelessWidget {
  const CalendarMonthSummary({
    super.key,
    required this.stats,
    required this.isFutureMonth,
  });

  final CalendarMonthStats stats;
  final bool isFutureMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Widget content;
    if (stats.isEmpty) {
      content = SizedBox(
        height: _CalendarSummaryItem.height,
        child: Center(
          child: Text(
            isFutureMonth
                ? l10n.calendarSummaryFuture
                : l10n.calendarSummaryEmpty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      content = Row(children: _buildItems(context, l10n));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.s,
        AppSpacing.xs,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Divider(
            height: 1,
            thickness: 0.6,
            color: colorScheme.outlineVariant.withValues(
              alpha: colorScheme.brightness == Brightness.light ? 0.35 : 0.18,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            child: KeyedSubtree(key: ValueKey<Object>(stats), child: content),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context, AppLocalizations l10n) {
    final compact = NumberFormat.compact(locale: l10n.localeName);
    final decimal = NumberFormat.decimalPattern(l10n.localeName);
    final elapsed = stats.elapsedDays;
    final mood = stats.dominantMood;
    final items = <_CalendarSummaryItem>[
      _CalendarSummaryItem(
        icon: FontAwesomeIcons.bookOpen,
        value: '${stats.entryCount}',
        tooltip: l10n.calendarSummaryEntries(stats.entryCount),
      ),
      _CalendarSummaryItem(
        // “已记录/已过去”在年视图下是两个三位数，多分一份宽度。
        flex: 3,
        icon: FontAwesomeIcons.calendarCheck,
        value: elapsed == null
            ? '${stats.recordedDays}'
            : '${stats.recordedDays}/$elapsed',
        tooltip: elapsed == null
            ? l10n.calendarSummaryDaysNoTotal(stats.recordedDays)
            : l10n.calendarSummaryDays(stats.recordedDays, elapsed),
      ),
      _CalendarSummaryItem(
        icon: FontAwesomeIcons.penNib,
        value: compact.format(stats.charCount),
        tooltip: l10n.calendarSummaryChars(decimal.format(stats.charCount)),
      ),
      if (mood != null)
        _CalendarSummaryItem(
          emoji: mood,
          tooltip: l10n.calendarSummaryMood(mood),
        ),
      _CalendarSummaryItem(
        icon: FontAwesomeIcons.fire,
        value: '${stats.longestStreak}',
        tooltip: l10n.calendarSummaryStreak(stats.longestStreak),
      ),
    ];
    return <Widget>[
      for (final item in items) Expanded(flex: item.flex, child: item),
    ];
  }
}

class _CalendarSummaryItem extends StatelessWidget {
  const _CalendarSummaryItem({
    required this.tooltip,
    this.flex = 2,
    this.icon,
    this.value,
    this.emoji,
  });

  static const double height = 28;

  /// 在概览行里所占的宽度份数。
  final int flex;

  final FaIconData? icon;
  final String? value;
  final String? emoji;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = this.icon;
    final value = this.value;
    final emoji = this.emoji;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null)
                FaIcon(icon, size: 11, color: colorScheme.primary),
              if (emoji != null)
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 14, height: 1),
                  textScaler: TextScaler.noScaling,
                ),
              if (value != null) ...<Widget>[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
