import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/todo_check_box.dart';
import '../viewmodels/todo_focus_format.dart';
import '../viewmodels/todo_priority_colors.dart';
import 'todo_progress_ring.dart';

/// 专注页关联待办的上下文工作卡：展示待办标题、优先级标、累计专注时长与
/// 可在专注途中就地勾选的子步骤清单。
///
/// - 窄屏默认折叠步骤（显示下一条待办步骤预览，点按展开全部）；
/// - 宽屏双栏时传入 [alwaysExpandSteps] 为 true，直接平铺完整步骤工作台；
/// - 卡片外壳统一经 [AppCardSurface]，经典与玻璃材质自动适配。
class TodoFocusTaskCard extends StatefulWidget {
  const TodoFocusTaskCard({
    super.key,
    required this.title,
    required this.todo,
    required this.focusSeconds,
    required this.onToggleStep,
    this.onOpenDetail,
    this.alwaysExpandSteps = false,
  });

  /// 开始专注时的标题快照（待办被删除后仍有文字可看）。
  final String title;

  /// 实时待办行；未关联或已删除时为 null。
  final TodoRow? todo;

  /// 这条待办历史累计专注秒数。
  final int focusSeconds;

  /// 就地切换子步骤完成态。
  final void Function(String stepId, bool done) onToggleStep;

  /// 打开待办详情底部面板；不打断专注。
  final VoidCallback? onOpenDetail;

  /// 宽屏右栏常驻展开步骤列表。
  final bool alwaysExpandSteps;

  @override
  State<TodoFocusTaskCard> createState() => _TodoFocusTaskCardState();
}

class _TodoFocusTaskCardState extends State<TodoFocusTaskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final todo = widget.todo;
    final displayTitle = (todo?.title ?? widget.title).trim();
    if (displayTitle.isEmpty) return const SizedBox.shrink();

    final steps = todo == null
        ? const <TodoStep>[]
        : decodeTodoSteps(todo.steps);
    final doneSteps = steps.where((TodoStep s) => s.done).length;
    final completed = todo?.completedAt != null;
    final priority = todo == null
        ? TodoPriority.none
        : TodoPriority.of(todo.priority);
    final priorityColors = TodoPriorityColors.of(scheme, priority);
    final showSteps =
        steps.isNotEmpty && (widget.alwaysExpandSteps || _expanded);

    final badgeBg = completed
        ? scheme.primaryContainer
        : priorityColors?.tint ??
              scheme.primaryContainer.withValues(alpha: 0.7);
    final badgeFg = completed
        ? scheme.onPrimaryContainer
        : priorityColors?.accent ?? scheme.onPrimaryContainer;
    final badgeIcon = completed
        ? FontAwesomeIcons.check
        : priority != TodoPriority.none
        ? FontAwesomeIcons.flag
        : FontAwesomeIcons.listCheck;

    final nextStep = steps.cast<TodoStep?>().firstWhere(
      (TodoStep? s) => s != null && !s.done,
      orElse: () => null,
    );

    return AppCardSurface(
      borderRadius: BorderRadius.circular(AppRadii.card),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: steps.isNotEmpty && !widget.alwaysExpandSteps
                ? () => setState(() => _expanded = !_expanded)
                : widget.onOpenDetail,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: FaIcon(badgeIcon, size: 15, color: badgeFg),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: completed
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (widget.focusSeconds >= 60 ||
                            steps.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: AppSpacing.m,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              if (widget.focusSeconds >= 60)
                                _MetaChip(
                                  icon: FontAwesomeIcons.stopwatch,
                                  label: l10n.todoFocusTotal(
                                    TodoFocusFormat.duration(
                                      l10n,
                                      widget.focusSeconds,
                                    ),
                                  ),
                                ),
                              if (steps.isNotEmpty)
                                _MetaChip(
                                  icon: FontAwesomeIcons.listCheck,
                                  label: l10n.todoStepsTitleProgress(
                                    doneSteps,
                                    steps.length,
                                  ),
                                  accent: doneSteps == steps.length
                                      ? scheme.primary
                                      : null,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.onOpenDetail != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.todoFocusOpenTodoDetails,
                      onPressed: widget.onOpenDetail,
                      icon: FaIcon(
                        FontAwesomeIcons.arrowUpRightFromSquare,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (steps.isNotEmpty && !widget.alwaysExpandSteps)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      curve: ExpressiveMotion.effects,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FaIcon(
                          FontAwesomeIcons.angleDown,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (steps.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.m),
            TodoProgressBar(
              fraction: doneSteps / steps.length,
              color: scheme.primary,
              track: scheme.surfaceContainerHighest,
              height: 5,
            ),
          ],
          AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.spatial,
            alignment: AlignmentDirectional.topCenter,
            child: showSteps
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final step in steps)
                          _FocusStepRow(
                            step: step,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              widget.onToggleStep(step.id, !step.done);
                            },
                          ),
                      ],
                    ),
                  )
                : (!widget.alwaysExpandSteps && nextStep != null)
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s),
                    child: _FocusStepRow(
                      step: nextStep,
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        widget.onToggleStep(nextStep.id, !nextStep.done);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.accent});

  final FaIconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FaIcon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: accent != null ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FocusStepRow extends StatelessWidget {
  const _FocusStepRow({required this.step, required this.onTap});

  final TodoStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      checked: step.done,
      button: true,
      label: step.title,
      hint: step.done ? l10n.todoMarkUndone : l10n.todoMarkDone,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: <Widget>[
                TodoCheckBoxVisual(checked: step.done, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: step.done
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      decoration: step.done ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 今日已专注的轻盈徽章；不足 1 分钟时不占位。
class TodoFocusTodayPill extends StatelessWidget {
  const TodoFocusTodayPill({super.key, required this.todaySeconds});

  final int todaySeconds;

  @override
  Widget build(BuildContext context) {
    if (todaySeconds < 60) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final field = AppGlassField.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: field?.fill ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: field?.border == null
            ? null
            : Border.fromBorderSide(field!.border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(FontAwesomeIcons.solidClock, size: 12, color: scheme.primary),
          const SizedBox(width: 7),
          Text(
            l10n.todoFocusTodayTotal(
              TodoFocusFormat.duration(l10n, todaySeconds),
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
