import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../models/todo_focus_run.dart';
import '../models/todo_focus_settings.dart';
import 'todo_focus_dial.dart';

/// 正在计时的一段：阶段胶囊、大圆环、待办标题、轮数圆点与操作行（结束 ·
/// 暂停 / 继续 · 加 5 分钟；休息时右边换成跳过休息）。
class TodoFocusRunPanel extends StatelessWidget {
  const TodoFocusRunPanel({
    super.key,
    required this.run,
    required this.settings,
    required this.now,
    required this.dialSize,
    required this.onPause,
    required this.onResume,
    required this.onExtend,
    required this.onStop,
    required this.onSkipBreak,
  });

  final TodoFocusRun run;
  final TodoFocusSettings settings;
  final DateTime Function() now;
  final double dialSize;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onExtend;
  final VoidCallback onStop;
  final VoidCallback onSkipBreak;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = settings.longBreakEvery;
    final phase = switch (run.phase) {
      TodoFocusPhase.focus => l10n.todoFocusPhaseFocus(
        run.round.clamp(1, total),
        total,
      ),
      TodoFocusPhase.shortBreak => l10n.todoFocusPhaseShortBreak,
      TodoFocusPhase.longBreak => l10n.todoFocusPhaseLongBreak,
    };
    final title = run.title.trim();
    final tonal = AppGlassField.tonalButtonStyle(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PhaseChip(label: phase, isBreak: run.phase.isBreak),
        const SizedBox(height: AppSpacing.xl),
        TodoFocusDial(run: run, now: now, size: dialSize),
        const SizedBox(height: AppSpacing.xl),
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: AppSpacing.m),
        _RoundDots(
          total: total,
          done: run.phase.isBreak ? run.round : run.round - 1,
          color: scheme.primary,
          track: scheme.outlineVariant,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton.filledTonal(
              style: tonal,
              iconSize: 20,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              tooltip: l10n.todoFocusStop,
              onPressed: onStop,
              icon: const FaIcon(FontAwesomeIcons.stop),
            ),
            const SizedBox(width: AppSpacing.xl),
            SizedBox.square(
              dimension: 80,
              child: IconButton.filled(
                iconSize: 28,
                tooltip: run.paused
                    ? l10n.todoFocusResume
                    : l10n.todoFocusPause,
                onPressed: run.paused ? onResume : onPause,
                icon: ExpressiveIconSwap(
                  switchKey: run.paused,
                  child: FaIcon(
                    run.paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            if (run.phase.isBreak)
              IconButton.filledTonal(
                style: tonal,
                iconSize: 20,
                constraints: const BoxConstraints.tightFor(
                  width: 56,
                  height: 56,
                ),
                tooltip: l10n.todoFocusSkipBreak,
                onPressed: onSkipBreak,
                icon: const FaIcon(FontAwesomeIcons.forwardStep),
              )
            else
              IconButton.filledTonal(
                style: tonal,
                iconSize: 20,
                constraints: const BoxConstraints.tightFor(
                  width: 56,
                  height: 56,
                ),
                tooltip: l10n.todoFocusExtend,
                onPressed: onExtend,
                icon: const FaIcon(FontAwesomeIcons.plus),
              ),
          ],
        ),
      ],
    );
  }
}

/// 一段走完了：对勾徽章 + 标题与说明 + 下一步按钮。专注走完时主按钮是去
/// 休息，下面是“完成这条待办”（还没完成时）与“再专注一轮”；休息走完时
/// 主按钮是开始下一轮专注。最下面都是“结束”。
class TodoFocusEndedPanel extends StatelessWidget {
  const TodoFocusEndedPanel({
    super.key,
    required this.ended,
    required this.settings,
    required this.canComplete,
    required this.onBreak,
    required this.onNext,
    required this.onComplete,
    required this.onFinish,
  });

  final TodoFocusEnded ended;
  final TodoFocusSettings settings;

  /// 关联的待办还在、还没完成。
  final bool canComplete;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: ExpressiveEntrance(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: focusDone
                    ? scheme.primaryContainer
                    : scheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: FaIcon(
                focusDone ? FontAwesomeIcons.check : FontAwesomeIcons.mugHot,
                size: 36,
                color: focusDone
                    ? scheme.onPrimaryContainer
                    : scheme.onTertiaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          focusDone ? l10n.todoFocusDoneTitle : l10n.todoFocusBreakDoneTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          focusDone
              ? <String>[
                  if (title.isNotEmpty) title,
                  l10n.todoFocusDoneBody(ended.focusedSeconds ~/ 60),
                ].join(' · ')
              : l10n.todoFocusBreakEndBody,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (focusDone) ...<Widget>[
          FilledButton.icon(
            onPressed: onBreak,
            icon: const FaIcon(FontAwesomeIcons.mugHot, size: 16),
            label: Text(l10n.todoFocusStartBreak(breakMinutes)),
          ),
          if (canComplete) ...<Widget>[
            const SizedBox(height: AppSpacing.s),
            FilledButton.tonalIcon(
              style: tonal,
              onPressed: onComplete,
              icon: const FaIcon(FontAwesomeIcons.check, size: 16),
              label: Text(l10n.todoFocusCompleteTodo),
            ),
          ],
          const SizedBox(height: AppSpacing.s),
          TextButton(onPressed: onNext, child: Text(l10n.todoFocusAgain)),
        ] else
          FilledButton.icon(
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

/// 阶段胶囊：专注 `secondaryContainer`，休息 `tertiaryContainer`，换阶段时
/// 底色补间。
class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.isBreak});

  final String label;
  final bool isBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m + 2,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: isBreak ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: isBreak
              ? scheme.onTertiaryContainer
              : scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 一轮循环里的进度：[total] 个圆点，前 [done] 个实心。
class _RoundDots extends StatelessWidget {
  const _RoundDots({
    required this.total,
    required this.done,
    required this.color,
    required this.track,
  });

  final int total;
  final int done;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? color : track,
              ),
            ),
        ],
      ),
    );
  }
}
