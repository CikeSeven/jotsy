import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../viewmodels/anniversary_countdown.dart';
import 'anniversary_labels.dart';

/// 详情页的卡片表面：与列表卡片同一套（24dp 圆角、卡片表面、0.8dp 微边框、
/// 静止阴影）。
class AnniversaryDetailSurface extends StatelessWidget {
  const AnniversaryDetailSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 玻璃时为内容玻璃（共用页面背景读取、无背景图不模糊）；经典分支不变。
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      return SizedBox(
        width: double.infinity,
        child: AppGlassSurface(
          component: AppGlassComponent.cards,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
          shadow: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: child,
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: child,
    );
  }
}

/// 详情页顶部的倒数卡：一句话 + 大号天数 + 下一次的日期。
///
/// 还没到：“还有 / 12 / 天”；就是今天：“今天是第 N 周年”（tertiary）；
/// 已过去的倒数日：“已经 / 15 / 天”。重复的纪念日另起一行写从首次算起
/// 已经多少天；当年没有那一天而顺延时注明。
class AnniversaryHeroCard extends StatelessWidget {
  const AnniversaryHeroCard({
    super.key,
    required this.row,
    required this.countdown,
  });

  final Anniversary row;
  final AnniversaryCountdown countdown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final next = countdown.next;
    final rule = countdown.rule;
    final phase = countdown.phase;
    final headline = switch (phase) {
      AnniversaryPhase.today when rule.repeats && next!.ordinal > 0 =>
        l10n.anniversaryTodayOrdinal(next.ordinal),
      AnniversaryPhase.today => l10n.anniversaryIsToday,
      AnniversaryPhase.upcoming => l10n.anniversaryDaysLeft(
        countdown.daysUntilNext!,
      ),
      AnniversaryPhase.past => l10n.anniversaryDaysSince(
        countdown.daysSinceBase,
      ),
    };
    final details = <String>[
      if (next != null && phase != AnniversaryPhase.today)
        '${l10n.anniversaryDetailNext} · '
            '${DateFormat.yMMMEd(l10n.localeName).format(next.date)}'
            '${rule.repeats && next.ordinal > 0 ? ' · ${l10n.anniversaryOrdinal(next.ordinal)}' : ''}',
      if (rule.repeats && countdown.daysSinceBase > 0)
        l10n.anniversaryDaysSince(countdown.daysSinceBase),
    ];
    return AnniversaryDetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            row.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              headline,
              maxLines: 1,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: phase == AnniversaryPhase.today
                    ? colorScheme.tertiary
                    : colorScheme.primary,
              ),
            ),
          ),
          for (final line in details)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (next != null && next.adjusted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Text(
                l10n.anniversaryAdjustedNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 详情页的信息卡：开始于（农历规则附农历日期）、重复规则、备注。
class AnniversaryInfoCard extends StatelessWidget {
  const AnniversaryInfoCard({
    super.key,
    required this.row,
    required this.countdown,
  });

  final Anniversary row;
  final AnniversaryCountdown countdown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rule = countdown.rule;
    final base = rule.base;
    final lunar = rule.lunar;
    final start = DateFormat.yMMMEd(l10n.localeName).format(base);
    final note = row.note.trim();
    return AnniversaryDetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InfoRow(
            label: l10n.anniversaryDetailStart,
            value: lunar == null
                ? start
                : '$start\n${l10n.calendarLunarDate(CalendarLunarDay.of(base).date)}',
          ),
          _InfoRow(
            label: l10n.anniversaryFieldRepeat,
            value: AnniversaryLabels.ruleName(l10n, rule.recurrence),
          ),
          if (note.isNotEmpty)
            _InfoRow(label: l10n.anniversaryFieldNote, value: note),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
