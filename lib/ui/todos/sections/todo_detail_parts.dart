import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../widgets/todo_check_box.dart';
import '../widgets/todo_bare_input.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_progress_ring.dart';

/// 待办详情（[TodoDetailBody] 所在的 `todo_detail_body.dart`）的几块版式：
/// 头部、步骤 / 备注卡片与创建 / 完成时间。只负责排版，写库与状态都在
/// 详情内容里。

/// 头部：28dp 方框（勾选完成）+ `titleLarge` w700 标题输入框 + “更多”。
class TodoDetailHeader extends StatelessWidget {
  const TodoDetailHeader({
    super.key,
    required this.row,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onToggle,
    required this.onDelete,
    required this.onDuplicate,
  });

  final TodoRow row;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = row.completedAt != null;
    final priority = TodoPriority.of(row.priority);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          checked: done,
          button: true,
          label: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onToggle,
            radius: 24,
            child: SizedBox(
              width: 44,
              height: 52,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TodoCheckBoxVisual(
                  checked: done,
                  size: 28,
                  accent: TodoLabels.priorityColor(scheme, priority),
                  onAccent: TodoLabels.priorityOnColor(scheme, priority),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (_) => onChanged(),
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
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.copy),
              onPressed: onDuplicate,
              child: Text(l10n.todoDuplicate),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
              destructive: true,
              onPressed: onDelete,
              child: Text(l10n.todoDelete),
            ),
          ],
        ),
      ],
    );
  }
}

/// 步骤与备注的卡片：小标题（可带细进度条）+ 内容，`surfaceContainerLow`
/// 底、16 圆角（面板与详情栏本身已是卡片表面，里面不再叠投影与描边）。
class TodoDetailSectionCard extends StatelessWidget {
  const TodoDetailSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.progress,
  });

  final String title;
  final double? progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.m,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
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

/// 创建 / 完成时间。
class TodoDetailFooter extends StatelessWidget {
  const TodoDetailFooter({super.key, required this.row});

  final TodoRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final completedAt = row.completedAt;
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
      ],
    );
  }
}
