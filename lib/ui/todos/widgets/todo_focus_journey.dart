import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../models/todo_focus_run.dart';

/// 专注页顶部的阶段胶囊：图标 + 阶段文案，切换专注 / 休息时柔和补间语义底色。
class TodoFocusPhasePill extends StatelessWidget {
  const TodoFocusPhasePill({
    super.key,
    required this.phase,
    required this.round,
    required this.totalRounds,
    this.paused = false,
  });

  final TodoFocusPhase phase;
  final int round;
  final int totalRounds;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBreak = phase.isBreak;
    final label = switch (phase) {
      TodoFocusPhase.focus => l10n.todoFocusPhaseFocus(
        round.clamp(1, totalRounds),
        totalRounds,
      ),
      TodoFocusPhase.shortBreak => l10n.todoFocusPhaseShortBreak,
      TodoFocusPhase.longBreak => l10n.todoFocusPhaseLongBreak,
    };
    final icon = switch (phase) {
      TodoFocusPhase.focus => FontAwesomeIcons.fireFlameCurved,
      TodoFocusPhase.shortBreak => FontAwesomeIcons.mugHot,
      TodoFocusPhase.longBreak => FontAwesomeIcons.couch,
    };
    final background = paused
        ? scheme.surfaceContainerHighest
        : isBreak
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final foreground = paused
        ? scheme.onSurfaceVariant
        : isBreak
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return AnimatedContainer(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(icon, size: 13, color: foreground),
          const SizedBox(width: AppSpacing.s),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// M3 Expressive 番茄轮次旅程条：已完成为实心圆点，进行中的当前轮弹性伸展为
/// 30dp 胶囊，未开始为静默小点；末尾缀以一枚柔和长休标记。
class TodoFocusRoundTrack extends StatelessWidget {
  const TodoFocusRoundTrack({
    super.key,
    required this.total,
    required this.currentRound,
    required this.isBreak,
    this.completedCurrent = false,
    this.paused = false,
  });

  /// 一轮循环共几轮专注后长休。
  final int total;

  /// 当前处于第几轮（1-based）。
  final int currentRound;

  /// 当前是否正处于休息阶段。
  final bool isBreak;

  /// 当前轮是否刚刚全部完成（结束态用）。
  final bool completedCurrent;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final scheme = themeColorScheme(context);
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final activeIndex = (currentRound - 1).clamp(0, total - 1);
    final doneCount = isBreak || completedCurrent
        ? currentRound.clamp(0, total)
        : (currentRound - 1).clamp(0, total);
    final activeColor = paused
        ? scheme.outline
        : isBreak
        ? scheme.tertiary
        : scheme.primary;
    final activeTrack = isBreak
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < total; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            _RoundNode(
              duration: duration,
              isActive: !isBreak && !completedCurrent && i == activeIndex,
              isDone: i < doneCount,
              activeColor: activeColor,
              activeTrack: activeTrack,
              idleColor: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ],
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: duration,
            curve: ExpressiveMotion.effects,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isBreak
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FaIcon(
              FontAwesomeIcons.mugHot,
              size: 10,
              color: isBreak
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  static ColorScheme themeColorScheme(BuildContext context) =>
      Theme.of(context).colorScheme;
}

class _RoundNode extends StatelessWidget {
  const _RoundNode({
    required this.duration,
    required this.isActive,
    required this.isDone,
    required this.activeColor,
    required this.activeTrack,
    required this.idleColor,
  });

  final Duration duration;
  final bool isActive;
  final bool isDone;
  final Color activeColor;
  final Color activeTrack;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final width = isActive ? 28.0 : (isDone ? 10.0 : 8.0);
    final height = isActive ? 10.0 : (isDone ? 10.0 : 8.0);
    final color = isActive
        ? activeColor
        : isDone
        ? activeColor.withValues(alpha: 0.85)
        : idleColor;
    return AnimatedContainer(
      duration: duration,
      curve: ExpressiveMotion.spatial,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: isActive ? Border.all(color: activeTrack, width: 1.5) : null,
      ),
    );
  }
}
