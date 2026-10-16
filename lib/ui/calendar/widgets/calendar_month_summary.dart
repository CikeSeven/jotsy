import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/calendar_month_stats.dart';

/// 概览统计的时间段：决定无记录时的文案。
enum CalendarSummaryPeriod { month, year, range }

/// 日历卡片底部的概览条（月度、年度或所选日期范围）。
///
/// 输入：该时间段的 [CalendarMonthStats] 与可选的标题行 [header]（范围统计
/// 的起止日期与关闭按钮）；输出一行图标 + 数字。无副作用。
///
/// 只放数字不放单位：中英文单位长度差很多，320dp 宽的卡片里英文
/// “12 entries · 9/15 days · …”放不下。完整含义经 Tooltip（长按）与读屏
/// 标签给出。翻月或数据变化时整行短交叉淡入。
class CalendarMonthSummary extends StatelessWidget {
  const CalendarMonthSummary({
    super.key,
    required this.stats,
    required this.isFuture,
    this.period = CalendarSummaryPeriod.month,
    this.header,
  });

  final CalendarMonthStats stats;

  /// 整个时间段都在今天之后（显示“还没开始”而不是“没有日记”）。
  final bool isFuture;
  final CalendarSummaryPeriod period;
  final Widget? header;

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
            switch ((period, isFuture)) {
              (CalendarSummaryPeriod.month, false) => l10n.calendarSummaryEmpty,
              (CalendarSummaryPeriod.month, true) => l10n.calendarSummaryFuture,
              (CalendarSummaryPeriod.year, false) =>
                l10n.calendarSummaryEmptyYear,
              (CalendarSummaryPeriod.year, true) =>
                l10n.calendarSummaryFutureYear,
              (CalendarSummaryPeriod.range, false) =>
                l10n.calendarSummaryEmptyRange,
              (CalendarSummaryPeriod.range, true) =>
                l10n.calendarSummaryFutureRange,
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      // 各项按内容宽度排开、均分剩余空间：月视图与年视图的数字长短差很多
      // （“3” 与 “205/288”），固定等分会截断长的一项。大字号下放不下时
      // 换行而不是截断。
      content = SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.xs,
          children: _buildItems(context, l10n),
        ),
      );
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
          ?header,
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

  List<_CalendarSummaryItem> _buildItems(
    BuildContext context,
    AppLocalizations l10n,
  ) {
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
    return items;
  }
}

class _CalendarSummaryItem extends StatelessWidget {
  const _CalendarSummaryItem({
    required this.tooltip,
    this.icon,
    this.value,
    this.emoji,
  });

  static const double height = 28;

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
            mainAxisSize: MainAxisSize.min,
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
                Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
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
