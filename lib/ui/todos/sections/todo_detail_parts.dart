import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../viewmodels/todo_priority_colors.dart';
import '../widgets/todo_bare_input.dart';
import '../widgets/todo_complete_motion.dart';
import '../widgets/todo_progress_ring.dart';
import '../widgets/todo_tile_check.dart';

/// 待办详情（[TodoDetailBody] 所在的 `todo_detail_body.dart`）的几块版式：
/// 头部、步骤 / 备注卡片与创建 / 完成时间。只负责排版，写库与状态都在
/// 详情内容里。

/// 头部：28dp 方框（勾选完成，按优先级着色同列表行）+ `titleLarge` w700
/// 标题输入框 + “更多”。
///
/// 勾选未完成的这条时演勾选三拍的前两拍（按下压小、弹起、对勾描出，节拍
/// 见 `TodoCompleteMotion`，轻震一次），播完才交给 [onToggle] 写库；取消
/// 勾选直接交出。减少动画时直接交出。
class TodoDetailHeader extends StatefulWidget {
  const TodoDetailHeader({
    super.key,
    required this.row,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onToggle,
    required this.onDelete,
    required this.onDuplicate,
    this.onFocus,
  });

  final TodoRow row;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  /// “开始专注”；null 时不出现（专注计时关着，或这条已完成）。
  final VoidCallback? onFocus;

  @override
  State<TodoDetailHeader> createState() => _TodoDetailHeaderState();
}

class _TodoDetailHeaderState extends State<TodoDetailHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _check = AnimationController(
    vsync: this,
    value: widget.row.completedAt != null ? 1 : 0,
  );
  bool _checking = false;

  bool get _done => widget.row.completedAt != null;

  @override
  void didUpdateWidget(TodoDetailHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.row.completedAt != null) != _done ||
        oldWidget.row.todoId != widget.row.todoId) {
      _checking = false;
      _check.value = _done ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_checking) return;
    if (_done) {
      widget.onToggle();
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    final duration = ExpressiveMotion.duration(
      context,
      TodoCompleteMotion.check,
    );
    if (duration == Duration.zero) {
      widget.onToggle();
      return;
    }
    setState(() => _checking = true);
    await _check.animateTo(1, duration: duration, curve: Curves.linear);
    if (!mounted || !_checking) return;
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = widget.row;
    final done = _done;
    final priority = TodoPriorityColors.of(
      scheme,
      TodoPriority.of(row.priority),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 44,
          height: 52,
          child: TodoTileCheckButton(
            check: _check,
            checked: done || _checking,
            enabled: true,
            accent: priority?.accent,
            onAccent: priority?.onAccent,
            tint: priority?.tint,
            semanticsLabel: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
            onTap: () => unawaited(_toggle()),
            size: 28,
            alignment: AlignmentDirectional.centerStart,
          ),
        ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: (_) => widget.onChanged(),
            maxLength: 500,
            minLines: 1,
            maxLines: null,
            textInputAction: TextInputAction.done,
            contextMenuBuilder: appTextContextMenuBuilder,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: done ? scheme.onSurfaceVariant : null,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: scheme.onSurfaceVariant,
            ),
            decoration: todoBareInputDecoration(
              hintText: l10n.todoQuickAddHint,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        ExpressiveMenuButton(
          tooltip: l10n.todoMore,
          icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 18),
          items: <Widget>[
            if (widget.onFocus case final onFocus?)
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.stopwatch),
                onPressed: onFocus,
                child: Text(l10n.todoFocusAction),
              ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.copy),
              onPressed: widget.onDuplicate,
              child: Text(l10n.todoDuplicate),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
              destructive: true,
              onPressed: widget.onDelete,
              child: Text(l10n.todoDelete),
            ),
          ],
        ),
      ],
    );
  }
}

/// 步骤与备注的卡片：小标题（可带细进度条，行尾可放 [trailing]）+ 内容，
/// `surfaceContainerLow` 底、16 圆角（面板与详情栏本身已是卡片表面，里面
/// 不再叠投影与描边）。
class TodoDetailSectionCard extends StatelessWidget {
  const TodoDetailSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.progress,
    this.trailing,
  });

  final String title;
  final double? progress;
  final Widget child;

  /// 小标题行尾的按钮（步骤卡的“AI 拆解”）。按钮的 48dp 触控区比小标题
  /// 高：有它时卡片上边距收窄，小标题仍落在原来的位置附近。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final trailing = this.trailing;
    final heading = Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: trailing == null ? AppSpacing.m : 0,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (trailing == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: heading,
              )
            else
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.l,
                  end: AppSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: heading),
                    trailing,
                  ],
                ),
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  0,
                ),
                child: TodoProgressBar(
                  fraction: progress,
                  color: scheme.primary,
                  track: scheme.surfaceContainerHighest,
                  height: 4,
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 创建 / 完成时间，截止日往后推过时再写推迟了几次，专注过时写累计专注。
class TodoDetailFooter extends StatelessWidget {
  const TodoDetailFooter({super.key, required this.row, this.focusTotal});

  final TodoRow row;

  /// 写好的累计专注时长；null 时不写（没专注过，或专注计时关着）。
  final String? focusTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final completedAt = row.completedAt;
    final postponed = todoPostponeCount(row);
    return Column(
      children: <Widget>[
        Text(
          l10n.todoCreatedAt(l10n.formatDateTimeMinute(row.createdAt)),
          style: style,
          textAlign: TextAlign.center,
        ),
        if (completedAt != null)
          Text(
            l10n.todoCompletedAt(l10n.formatDateTimeMinute(completedAt)),
            style: style,
            textAlign: TextAlign.center,
          ),
        if (postponed > 0)
          Text(
            l10n.todoPostponedCount(postponed),
            style: style,
            textAlign: TextAlign.center,
          ),
        if (focusTotal case final total?)
          Text(
            l10n.todoFocusTotal(total),
            style: style,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
