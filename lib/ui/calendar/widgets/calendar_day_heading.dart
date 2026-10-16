import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/calendar_holiday_day.dart';
import '../viewmodels/calendar_lunar_day.dart';

/// 选中日期标题行：`10月15日 周三 [3 天前]` + 右侧当天篇数与字数；显示
/// 农历时下方再加一行“农历九月廿四 · 寒露”，逢法定节假日在行尾接上
/// “国庆节 · 休”或“调休上班”。
///
/// 输入：选中日期、当前时刻、当天已解封日记的篇数/字数、农历信息
/// [lunar] 与放假安排 [holiday]（不显示时为 null）；无副作用。
///
/// 日期与星期由 intl 按语言区域格式化（中文“10月15日 周三”、英文
/// “Oct 15 Wed”），不手写中英分支。换日时日期部分与下方内容一起交叉淡入；
/// 统计数字单独淡入，日记加载完成时只换数字、不让日期闪一下。
class CalendarDayHeading extends StatelessWidget {
  const CalendarDayHeading({
    super.key,
    required this.day,
    required this.now,
    required this.entryCount,
    required this.wordCount,
    this.lunar,
    this.holiday,
  });

  final DateTime day;
  final DateTime now;
  final int entryCount;
  final int wordCount;
  final CalendarLunarDay? lunar;
  final CalendarHolidayDay? holiday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final statsText = entryCount == 0
        ? ''
        : l10n.calendarDayStats(
            entryCount,
            NumberFormat.decimalPattern(l10n.localeName).format(wordCount),
          );
    // 日期本身不截断；星期与相对时间在窄屏、大字号下按需省略。统计数字
    // 很短，按内容宽度放在行尾，其余宽度都给日期一侧。
    return Row(
      children: <Widget>[
        Expanded(
          // 不显示农历但显示节假日时，第二行只在假日出现：高度随之过渡，
          // 下方内容不在换日的一帧里跳动。
          child: AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.fast,
            ),
            curve: ExpressiveMotion.effects,
            alignment: AlignmentDirectional.topStart,
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              layoutBuilder: _startAlignedLayout,
              child: Column(
                key: ValueKey<DateTime>(day),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        DateFormat.MMMd(l10n.localeName).format(day),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          DateFormat.E(l10n.localeName).format(day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _RelativeDayPill(day: day, now: now),
                      ),
                    ],
                  ),
                  ?_buildDetailLine(context),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: _endAlignedLayout,
          child: Padding(
            key: ValueKey<String>(statsText),
            padding: EdgeInsetsDirectional.only(
              start: statsText.isEmpty ? 0 : 8,
            ),
            child: Text(
              statsText,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 农历与节假日行：节日 tertiary、节气 primary，与日期格小字同一套颜色
  /// 语义；“休”同节日用 tertiary，“调休上班”用弱化色加粗。窄屏下按需
  /// 省略，不换行。不显示农历时只写节假日部分，假日名总是写出。
  Widget? _buildDetailLine(BuildContext context) {
    final lunar = this.lunar;
    final holiday = this.holiday;
    if (lunar == null && holiday == null) {
      return null;
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const emphasis = TextStyle(fontWeight: FontWeight.w600);
    final term = lunar?.term;
    final spans = <InlineSpan>[
      if (lunar != null) TextSpan(text: l10n.calendarLunarDate(lunar.date)),
      for (final festival in lunar?.festivals ?? const <String>[])
        TextSpan(
          text: festival,
          style: emphasis.copyWith(color: colorScheme.tertiary),
        ),
      if (term != null)
        TextSpan(
          text: term,
          style: emphasis.copyWith(color: colorScheme.primary),
        ),
      if (holiday != null) ...<InlineSpan>[
        if (holiday.headingName(lunar) case final name?)
          TextSpan(
            text: name,
            style: emphasis.copyWith(color: colorScheme.tertiary),
          ),
        holiday.isWork
            ? TextSpan(
                text: l10n.calendarHolidayMakeUpWorkday,
                style: emphasis.copyWith(color: colorScheme.onSurfaceVariant),
              )
            : TextSpan(
                text: l10n.calendarHolidayDayOff,
                style: emphasis.copyWith(color: colorScheme.tertiary),
              ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            for (var i = 0; i < spans.length; i++) ...<InlineSpan>[
              if (i > 0) const TextSpan(text: ' · '),
              spans[i],
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static Widget _startAlignedLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: <Widget>[...previousChildren, ?currentChild],
    );
  }

  static Widget _endAlignedLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: <Widget>[...previousChildren, ?currentChild],
    );
  }
}

/// 相对今天的小标签：今天 / 昨天 / 明天 / N 天前 / N 天后。按日历日期差
/// 计算（同为本地零点相减再四舍五入），跨夏令时的 23/25 小时日不会算错。
class _RelativeDayPill extends StatelessWidget {
  const _RelativeDayPill({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = DateUtils.dateOnly(now);
    final target = DateUtils.dateOnly(day);
    final diff = (target.difference(today).inHours / 24).round();
    final label = switch (diff) {
      0 => l10n.calendarRelativeToday,
      -1 => l10n.calendarRelativeYesterday,
      1 => l10n.calendarRelativeTomorrow,
      < 0 => l10n.calendarRelativeDaysAgo(-diff),
      _ => l10n.calendarRelativeDaysLater(diff),
    };
    final isToday = diff == 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday
                ? colorScheme.onTertiaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
