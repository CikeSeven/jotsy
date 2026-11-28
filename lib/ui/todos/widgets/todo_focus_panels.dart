import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../models/todo_focus_run.dart';
import '../models/todo_focus_settings.dart';
import 'todo_focus_controls.dart';
import 'todo_focus_dial.dart';
import 'todo_focus_journey.dart';
import 'todo_focus_task_card.dart';

/// 正在计时的一段舞台：阶段胶囊 + 轮次旅程 → M3E 动态波形表盘 → 形变操控栏。
///
/// 窄屏下由页面或本组件在下方承接任务工作卡；宽屏双栏时本组件专注左栏舞台，
/// 右栏独立放 [TodoFocusTaskCard]。
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
    this.taskCard,
    this.todaySeconds = 0,
    this.zenMode = false,
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

  /// 窄屏模式下叠在操控栏下方的任务卡；宽屏双栏放右栏时传 null。
  final Widget? taskCard;
  final int todaySeconds;
  final bool zenMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TodoFocusPhasePill(
          phase: run.phase,
          round: run.round,
          totalRounds: settings.longBreakEvery,
          paused: run.paused,
        ),
        const SizedBox(height: AppSpacing.m),
        TodoFocusRoundTrack(
          total: settings.longBreakEvery,
          currentRound: run.round,
          isBreak: run.phase.isBreak,
          paused: run.paused,
        ),
        const SizedBox(height: AppSpacing.xl),
        TodoFocusDial(run: run, now: now, size: dialSize),
        const SizedBox(height: AppSpacing.xxl),
        TodoFocusControls(
          run: run,
          onPause: onPause,
          onResume: onResume,
          onExtend: onExtend,
          onStop: onStop,
          onSkipBreak: onSkipBreak,
        ),
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.spatial,
          alignment: AlignmentDirectional.topCenter,
          child: zenMode
              ? const SizedBox.shrink()
              : taskCard != null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: taskCard!,
                )
              : todaySeconds >= 60
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: TodoFocusTodayPill(todaySeconds: todaySeconds),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 空闲准备台：有机静态表盘预览 + 快捷时长胶囊条 + 关联待办选择器 + 主开始按钮 +
/// 节奏摘要与今日统计。
class TodoFocusIdlePanel extends StatelessWidget {
  const TodoFocusIdlePanel({
    super.key,
    required this.settings,
    required this.now,
    required this.dialSize,
    required this.selectedTodo,
    required this.todaySeconds,
    required this.onSelectMinutes,
    required this.onPickTodo,
    required this.onOpenRhythm,
    required this.onStart,
  });

  final TodoFocusSettings settings;
  final DateTime Function() now;
  final double dialSize;
  final TodoRow? selectedTodo;
  final int todaySeconds;
  final ValueChanged<int> onSelectMinutes;
  final VoidCallback onPickTodo;
  final VoidCallback onOpenRhythm;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glassField = AppGlassField.of(context);
    final todo = selectedTodo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: TodoFocusPreviewDial(
            minutes: settings.focusMinutes,
            now: now(),
            size: dialSize,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _DurationPresetStrip(
          selectedMinutes: settings.focusMinutes,
          glassField: glassField,
          onSelect: (int m) {
            unawaited(HapticFeedback.selectionClick());
            onSelectMinutes(m);
          },
        ),
        const SizedBox(height: AppSpacing.l),
        AppCardSurface(
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onPickTodo,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m + 2,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: todo != null
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: FaIcon(
                      todo != null
                          ? FontAwesomeIcons.listCheck
                          : FontAwesomeIcons.stopwatch,
                      size: 14,
                      color: todo != null
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          todo?.title ?? l10n.todoFocusFreeSession,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.todoFocusPickTodo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FaIcon(
                    FontAwesomeIcons.angleRight,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              onStart();
            },
            icon: const FaIcon(FontAwesomeIcons.play, size: 16),
            label: Text(l10n.todoFocusStart(settings.focusMinutes)),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: onOpenRhythm,
            icon: const FaIcon(FontAwesomeIcons.sliders, size: 12),
            label: Text(
              l10n.todoFocusRhythmSummary(
                settings.focusMinutes,
                settings.shortBreakMinutes,
                settings.longBreakEvery,
              ),
            ),
          ),
        ),
        if (todaySeconds >= 60) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Center(child: TodoFocusTodayPill(todaySeconds: todaySeconds)),
        ],
      ],
    );
  }
}

class _DurationPresetStrip extends StatelessWidget {
  const _DurationPresetStrip({
    required this.selectedMinutes,
    required this.glassField,
    required this.onSelect,
  });

  final int selectedMinutes;
  final AppGlassField? glassField;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: DesktopHorizontalScroll(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final minutes in TodoFocusSettings.focusChoices)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _PresetChip(
                    label: l10n.todoFocusMinutes(minutes),
                    selected: minutes == selectedMinutes,
                    glassField: glassField,
                    theme: theme,
                    scheme: scheme,
                    onTap: () => onSelect(minutes),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.glassField,
    required this.theme,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppGlassField? glassField;
  final ThemeData theme;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? null : glassField?.border;
    return AnimatedContainer(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary
            : glassField?.fill ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(selected ? 999 : 14),
        border: border == null ? null : Border.fromBorderSide(border),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(selected ? 999 : 14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
