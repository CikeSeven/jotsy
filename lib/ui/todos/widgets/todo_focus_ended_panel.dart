import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_entrance.dart';
import '../models/todo_focus_run.dart';
import '../models/todo_focus_settings.dart';
import 'todo_focus_dial_painter.dart';
import 'todo_focus_journey.dart';
import 'todo_focus_task_card.dart';

/// 一段走完后的仪式感面板：12/10 瓣 M3E 饼干庆祝徽章 + 放射星点单次弹入 +
/// 成就摘要卡 + 分层下一步按钮。
///
/// 专注走完时主按钮是去休息，其下是“完成这条待办”（还没完成时）与“再专注一轮”；
/// 休息走完时主按钮是开始下一轮专注；最下面都是“结束”。
class TodoFocusEndedPanel extends StatelessWidget {
  const TodoFocusEndedPanel({
    super.key,
    required this.ended,
    required this.settings,
    required this.canComplete,
    required this.todaySeconds,
    required this.onBreak,
    required this.onNext,
    required this.onComplete,
    required this.onFinish,
  });

  final TodoFocusEnded ended;
  final TodoFocusSettings settings;

  /// 关联的待办还在、还没完成。
  final bool canComplete;
  final int todaySeconds;
  final VoidCallback onBreak;
  final VoidCallback onNext;
  final VoidCallback onComplete;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final focusDone = ended.phase == TodoFocusPhase.focus;
    final breakMinutes = ended.nextBreak(settings) == TodoFocusPhase.longBreak
        ? settings.longBreakMinutes
        : settings.shortBreakMinutes;
    final title = ended.title.trim();
    final tonal = AppGlassField.tonalButtonStyle(context);
    final primaryCtaStyle = FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 56),
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final secondaryOwnStyle = FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final secondaryTonalStyle =
        tonal?.merge(secondaryOwnStyle) ?? secondaryOwnStyle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: _CelebrationBadge(focusDone: focusDone)),
        const SizedBox(height: AppSpacing.xl),
        ExpressiveEntrance(
          child: Text(
            focusDone ? l10n.todoFocusDoneTitle : l10n.todoFocusBreakDoneTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        ExpressiveEntrance(
          glass: AppCardSurface.isGlass(context),
          child: AppCardSurface(
            borderRadius: BorderRadius.circular(AppRadii.card),
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title.isNotEmpty) ...<Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                ],
                Text(
                  focusDone
                      ? l10n.todoFocusDoneBody(ended.focusedSeconds ~/ 60)
                      : l10n.todoFocusBreakEndBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                TodoFocusRoundTrack(
                  total: settings.longBreakEvery,
                  currentRound: ended.round,
                  isBreak: !focusDone,
                  completedCurrent: focusDone,
                ),
                if (todaySeconds >= 60) ...<Widget>[
                  const SizedBox(height: AppSpacing.m),
                  TodoFocusTodayPill(todaySeconds: todaySeconds),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (focusDone) ...<Widget>[
          FilledButton.icon(
            style: primaryCtaStyle,
            onPressed: onBreak,
            icon: const FaIcon(FontAwesomeIcons.mugHot, size: 16),
            label: Text(l10n.todoFocusStartBreak(breakMinutes)),
          ),
          if (canComplete) ...<Widget>[
            const SizedBox(height: AppSpacing.s + 2),
            FilledButton.tonalIcon(
              style: secondaryTonalStyle,
              onPressed: () {
                unawaited(HapticFeedback.mediumImpact());
                onComplete();
              },
              icon: const FaIcon(FontAwesomeIcons.check, size: 16),
              label: Text(l10n.todoFocusCompleteTodo),
            ),
          ],
          const SizedBox(height: AppSpacing.s),
          TextButton(onPressed: onNext, child: Text(l10n.todoFocusAgain)),
        ] else
          FilledButton.icon(
            style: primaryCtaStyle,
            onPressed: onNext,
            icon: const FaIcon(FontAwesomeIcons.play, size: 16),
            label: Text(l10n.todoFocusStart(settings.focusMinutes)),
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          onPressed: onFinish,
          child: Text(l10n.todoFocusStop),
        ),
      ],
    );
  }
}

/// M3 Expressive 庆祝徽章：12/10 瓣有机饼干 + 一次性放射微点 + 弹性缩放图标。
class _CelebrationBadge extends StatelessWidget {
  const _CelebrationBadge({required this.focusDone});

  final bool focusDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outerColor = focusDone
        ? scheme.primaryContainer
        : scheme.tertiaryContainer;
    final coreColor = focusDone ? scheme.primary : scheme.tertiary;
    final iconColor = focusDone ? scheme.onPrimary : scheme.onTertiary;

    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
        curve: ExpressiveMotion.spatial,
        builder: (BuildContext context, double progress, Widget? child) {
          final clamped = progress.clamp(0.0, 1.0);
          return SizedBox.square(
            dimension: 136,
            child: CustomPaint(
              painter: _CelebrationBadgePainter(
                progress: clamped,
                scale: 0.72 + 0.28 * progress,
                outerColor: outerColor,
                coreColor: coreColor,
                lobes: focusDone ? 12 : 10,
              ),
              child: Center(
                child: Transform.scale(scale: progress, child: child),
              ),
            ),
          );
        },
        child: FaIcon(
          focusDone ? FontAwesomeIcons.check : FontAwesomeIcons.mugHot,
          size: 32,
          color: iconColor,
        ),
      ),
    );
  }
}

class _CelebrationBadgePainter extends CustomPainter {
  const _CelebrationBadgePainter({
    required this.progress,
    required this.scale,
    required this.outerColor,
    required this.coreColor,
    required this.lobes,
  });

  final double progress;
  final double scale;
  final Color outerColor;
  final Color coreColor;
  final int lobes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const dotCount = 8;
    final dotDist = size.shortestSide * (0.37 + 0.10 * progress);
    final dotRadius = 3.2 * (1 - 0.25 * progress);
    final dotPaint = Paint()
      ..color = coreColor.withValues(alpha: 0.34 * progress);
    for (var i = 0; i < dotCount; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / dotCount);
      canvas.drawCircle(
        Offset(
          center.dx + dotDist * math.cos(angle),
          center.dy + dotDist * math.sin(angle),
        ),
        i.isEven ? dotRadius : dotRadius * 0.72,
        dotPaint,
      );
    }

    final badgeExtent = 104.0 * scale;
    final badgeRect = Rect.fromCenter(
      center: center,
      width: badgeExtent,
      height: badgeExtent,
    );
    final path = focusScallopPath(
      badgeRect,
      lobes: lobes,
      amplitude: 0.068,
      rotation: (1 - progress) * 0.35,
    );
    canvas.drawPath(path, Paint()..color = outerColor);
    canvas.drawCircle(center, 33.0 * scale, Paint()..color = coreColor);
  }

  @override
  bool shouldRepaint(_CelebrationBadgePainter old) =>
      old.progress != progress ||
      old.scale != scale ||
      old.outerColor != outerColor ||
      old.coreColor != coreColor ||
      old.lobes != lobes;
}
