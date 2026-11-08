import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/page_header.dart';
import '../../widgets/select_all_button.dart';
import '../controllers/todo_batch_actions.dart';
import '../controllers/todo_page_selection.dart';
import '../widgets/todo_due_sheet.dart';
import '../widgets/todo_labels.dart';

/// 多选时的页头：标题“已选 N”，右侧全选 / 取消全选与退出（`xmark`）。
/// 与 [PageHeader] 同一底（实色 / 玻璃随首页顶栏）。
class TodoSelectionHeader extends StatelessWidget {
  const TodoSelectionHeader({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onToggleAll,
    required this.onClose,
    this.contentMaxWidth,
  });

  final int count;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final VoidCallback onClose;
  final double? contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageHeader(
      title: l10n.todoSelectedCount(count),
      contentMaxWidth: contentMaxWidth,
      actions: <Widget>[
        SelectAllButton(allSelected: allSelected, onPressed: onToggleAll),
        IconButton(
          tooltip: l10n.todoSelectionExit,
          onPressed: onClose,
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
        ),
      ],
    );
  }
}

/// 多选时浮在列表底部的操作栏（卡片表面、带投影、自下滑入）：完成、日期、
/// 清单、优先级（4 项弹出菜单）、删除（error）。没有选中时各按钮停用。
class TodoSelectionActionBar extends StatelessWidget {
  const TodoSelectionActionBar({
    super.key,
    required this.enabled,
    required this.onComplete,
    required this.onDue,
    required this.onList,
    required this.onPriority,
    required this.onDelete,
  });

  final bool enabled;
  final VoidCallback onComplete;
  final VoidCallback onDue;
  final VoidCallback onList;
  final ValueChanged<TodoPriority> onPriority;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ExpressiveEntrance(
      offset: const Offset(0, 0.4),
      glass: AppCardSurface.isGlass(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppEffects.softShadow(scheme),
        ),
        child: AppCardSurface(
          shadow: false,
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              _BarAction(
                icon: FontAwesomeIcons.circleCheck,
                label: l10n.todoBatchActionComplete,
                onPressed: enabled ? onComplete : null,
              ),
              _BarAction(
                icon: FontAwesomeIcons.calendar,
                label: l10n.todoFieldDue,
                onPressed: enabled ? onDue : null,
              ),
              _BarAction(
                icon: FontAwesomeIcons.folderOpen,
                label: l10n.todoFieldList,
                onPressed: enabled ? onList : null,
              ),
              Expanded(
                child: ExpressiveMenuAnchor(
                  menuChildren: <Widget>[
                    for (final priority in TodoPriority.values.reversed)
                      ExpressiveMenuItem(
                        leadingIcon: FaIcon(
                          FontAwesomeIcons.solidFlag,
                          color:
                              TodoLabels.priorityColor(scheme, priority) ??
                              scheme.onSurfaceVariant,
                        ),
                        onPressed: () => onPriority(priority),
                        child: Text(TodoLabels.priority(l10n, priority)),
                      ),
                  ],
                  builder:
                      (
                        BuildContext context,
                        ExpressiveMenuAnchorState menu,
                        Widget? _,
                      ) => _BarAction(
                        icon: FontAwesomeIcons.flag,
                        label: l10n.todoFieldPriority,
                        expand: false,
                        onPressed: enabled ? menu.toggle : null,
                      ),
                ),
              ),
              _BarAction(
                icon: FontAwesomeIcons.trashCan,
                label: l10n.commonDelete,
                color: scheme.error,
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.expand = true,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final tint = enabled
        ? (color ?? scheme.onSurface)
        : scheme.onSurface.withValues(alpha: 0.38);
    final button = InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(icon, size: 17, color: tint),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    final child = Semantics(button: true, enabled: enabled, child: button);
    return expand ? Expanded(child: child) : child;
  }
}

/// 多选操作栏接上批量流程：各操作作用于 [rows] 里被选中的，写完退出多选。
Widget buildTodoSelectionActionBar(
  BuildContext context,
  WidgetRef ref, {
  required TodoPageSelection selection,
  required List<TodoRow> rows,
  required DateTime today,
}) {
  final selected = selection.selectedRows(rows);
  final database = ref.read(appDatabaseProvider);
  List<String> ids() => <String>[for (final row in selected) row.todoId];

  Future<void> run(Future<void> Function() action) async {
    selection.clear();
    await action();
  }

  return TodoSelectionActionBar(
    enabled: selected.isNotEmpty,
    onComplete: () =>
        unawaited(run(() => completeTodosWithUndo(context, database, ids()))),
    onDue: () => unawaited(() async {
      final choice = await showTodoDueSheet(
        context,
        date: null,
        minute: null,
        today: today,
      );
      if (choice == null || !context.mounted) return;
      await run(
        () => setTodosDueWithUndo(
          context,
          database,
          selected,
          date: choice.date,
          minute: choice.minute,
        ),
      );
    }()),
    onList: () => unawaited(() async {
      final picked = <TodoRow>[...selected];
      selection.clear();
      await todoMoveRowsToList(context, ref, picked);
    }()),
    onPriority: (TodoPriority priority) => unawaited(
      run(() => setTodosPriorityWithUndo(context, database, ids(), priority)),
    ),
    onDelete: () =>
        unawaited(run(() => deleteTodosWithUndo(context, database, ids()))),
  );
}
