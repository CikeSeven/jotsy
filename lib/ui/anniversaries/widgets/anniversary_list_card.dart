import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../viewmodels/anniversary_countdown.dart';

/// 纪念日列表里的一张卡片：左侧名称与下一次的日期，右侧大号天数。
///
/// 右侧固定 88dp，数字按宽度等比缩小（上万天也放得下），等宽数字让上下
/// 卡片的位数对齐；当天显示 tertiary 色的“今天”。置顶以名称旁的小胶囊表示，
/// 不加竖条或彩色边（DESIGN.md §5.1）。
class AnniversaryListCard extends StatelessWidget {
  const AnniversaryListCard({
    super.key,
    required this.row,
    required this.countdown,
    required this.onTap,
  });

  final Anniversary row;
  final AnniversaryCountdown countdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadii.card);
    final next = countdown.next;
    final rule = countdown.rule;
    final date = next?.date ?? rule.base;
    final dateLine = rule.repeats
        ? '${DateFormat.MMMEd(l10n.localeName).format(date)} · '
              '${next != null && next.ordinal > 0 ? l10n.anniversaryOrdinal(next.ordinal) : l10n.anniversaryBaseDay}'
        : DateFormat.yMMMEd(l10n.localeName).format(date);
    final lunarLine = rule.lunar == null
        ? null
        : l10n.calendarLunarDate(CalendarLunarDay.of(date).date);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    // 经典分支与原来的 Container + Material 写法逐像素一致；玻璃时为内容
    // 玻璃。
    return AppCardSurface(
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m + 2,
            AppSpacing.l,
            AppSpacing.m + 2,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (row.isPinned) ...<Widget>[
                          const SizedBox(width: AppSpacing.s),
                          _PinnedCapsule(label: l10n.anniversaryPinnedBadge),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
                    ),
                    if (lunarLine != null)
                      Text(
                        lunarLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              SizedBox(width: 88, child: _DayCount(countdown: countdown)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCount extends StatelessWidget {
  const _DayCount({required this.countdown});

  final AnniversaryCountdown countdown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final phase = countdown.phase;
    final days = switch (phase) {
      AnniversaryPhase.upcoming => countdown.daysUntilNext!,
      AnniversaryPhase.past => countdown.daysSinceBase,
      AnniversaryPhase.today => 0,
    };
    final big = phase == AnniversaryPhase.today
        ? l10n.calendarRelativeToday
        : NumberFormat.decimalPattern(l10n.localeName).format(days);
    final caption = switch (phase) {
      AnniversaryPhase.upcoming => l10n.anniversaryDaysToGo(days),
      AnniversaryPhase.past => l10n.anniversaryDaysAgo(days),
      AnniversaryPhase.today => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            big,
            maxLines: 1,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: phase == AnniversaryPhase.today
                  ? colorScheme.tertiary
                  : colorScheme.primary,
            ),
          ),
        ),
        if (caption != null)
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _PinnedCapsule extends StatelessWidget {
  const _PinnedCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
