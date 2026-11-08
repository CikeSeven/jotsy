import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';

/// 分组标题：`titleSmall` w700 + 条数小胶囊（`surfaceContainerHigh` 底）。
///
/// - 逾期为 `error`，行尾可给“全部改到今天”（[onMoveOverdueToToday]）；
/// - “全部”视图里按清单分的组带清单图标（强调色）；
/// - 已完成（清单底部 / 今天已完成）可点按折叠，箭头随折叠旋转
///   （`fast` + effects，减少动画时直接到位）；
/// - 没有标题的一组（[TodoGroupKind.plain]）不画。
class TodoGroupHeader extends StatelessWidget {
  const TodoGroupHeader({
    super.key,
    required this.group,
    required this.today,
    this.list,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.onMoveOverdueToToday,
  });

  final TodoGroup group;
  final DateTime today;

  /// [TodoGroupKind.list] 的组所属清单；收集箱为 null。
  final TodoListRow? list;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  /// 逾期组行尾“全部改到今天”；null 时不显示。
  final VoidCallback? onMoveOverdueToToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = group.rows.length;
    final (String text, FaIconData? icon) = switch (group.kind) {
      TodoGroupKind.plain => ('', null),
      TodoGroupKind.overdue => (
        l10n.todoGroupOverdue,
        FontAwesomeIcons.triangleExclamation,
      ),
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
      TodoGroupKind.completed => (l10n.todoGroupCompletedTitle, null),
      TodoGroupKind.completedToday => (l10n.todoGroupCompletedToday, null),
      TodoGroupKind.completedDay => (
        TodoLabels.relativeDay(l10n, group.day!, today),
        null,
      ),
    };
    if (group.kind == TodoGroupKind.plain) return const SizedBox.shrink();
    final color = group.kind == TodoGroupKind.overdue
        ? scheme.error
        : scheme.onSurfaceVariant;
    final iconColor = group.kind == TodoGroupKind.list && list != null
        ? TodoListStyle.accentOf(list!.colorKey, scheme).onContainer
        : color;
    final style = AppPageBackdrop.onBackgroundTextStyle(
      context,
      theme.textTheme.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
    final toggle = onToggleCollapsed;
    final move = onMoveOverdueToToday;
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
            FaIcon(icon, size: 13, color: iconColor),
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
          const SizedBox(width: AppSpacing.s),
          _CountPill(count: count, color: color),
          if (toggle != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: FaIcon(FontAwesomeIcons.angleDown, size: 12, color: color),
            ),
          ],
        ],
      ),
    );
    final Widget header = toggle == null
        ? Semantics(header: true, child: content)
        : Semantics(
            header: true,
            button: true,
            expanded: !collapsed,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: toggle,
              child: content,
            ),
          );
    if (move == null) return header;
    // 标题与按钮按需分宽：长文案（英 / 俄）时按钮文字省略，不挤爆标题。
    return Row(
      children: <Widget>[
        Expanded(child: header),
        Flexible(
          child: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: move,
              child: Text(
                l10n.todoMoveOverdueToToday,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 分组标题旁的条数小胶囊。
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
