import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';

/// 分组标题：逾期为 `error`，其余 `onSurfaceVariant`；“全部”视图里按清单分
/// 的组带清单图标；清单底部的“已完成 N”可点按折叠。没有标题的一组
/// （[TodoGroupKind.plain]）不画。
class TodoGroupHeader extends StatelessWidget {
  const TodoGroupHeader({
    super.key,
    required this.group,
    required this.today,
    this.list,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final TodoGroup group;
  final DateTime today;

  /// [TodoGroupKind.list] 的组所属清单；收集箱为 null。
  final TodoListRow? list;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = group.rows.length;
    final (String text, FaIconData? icon) = switch (group.kind) {
      TodoGroupKind.plain => ('', null),
      TodoGroupKind.overdue => (l10n.todoGroupOverdue, null),
      TodoGroupKind.today => (l10n.todoGroupToday, null),
      TodoGroupKind.tomorrow => (l10n.todoGroupTomorrow, null),
      TodoGroupKind.nextDays => (l10n.todoGroupNextDays, null),
      TodoGroupKind.later => (l10n.todoGroupLater, null),
      TodoGroupKind.list => (
        list?.name ?? l10n.todoViewInbox,
        list == null
            ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
            : TodoListStyle.iconOfRow(list!),
      ),
      TodoGroupKind.completed => (l10n.todoGroupCompleted(count), null),
      TodoGroupKind.completedDay => (
        TodoLabels.relativeDay(l10n, group.day!, today),
        null,
      ),
    };
    if (group.kind == TodoGroupKind.plain) return const SizedBox.shrink();
    final color = group.kind == TodoGroupKind.overdue
        ? scheme.error
        : scheme.onSurfaceVariant;
    final style = AppPageBackdrop.onBackgroundTextStyle(
      context,
      theme.textTheme.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
    final showCount =
        group.kind != TodoGroupKind.completed &&
        group.kind != TodoGroupKind.completedDay;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.s,
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            FaIcon(icon, size: 13, color: color),
            const SizedBox(width: AppSpacing.s),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (showCount) ...<Widget>[
            const SizedBox(width: AppSpacing.s),
            Text('$count', style: style?.copyWith(fontWeight: FontWeight.w400)),
          ],
          if (onToggleCollapsed != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            FaIcon(
              collapsed
                  ? FontAwesomeIcons.angleRight
                  : FontAwesomeIcons.angleDown,
              size: 12,
              color: color,
            ),
          ],
        ],
      ),
    );
    final toggle = onToggleCollapsed;
    if (toggle == null) {
      return Semantics(header: true, child: content);
    }
    return Semantics(
      header: true,
      button: true,
      expanded: !collapsed,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: toggle,
        child: content,
      ),
    );
  }
}
