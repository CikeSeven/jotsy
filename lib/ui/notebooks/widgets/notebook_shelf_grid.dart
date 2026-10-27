import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../sections/notebook_action_flows.dart';
import '../sections/notebook_action_sheets.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_tile.dart';
import 'notebook_stacked_cover.dart';

/// 书架网格的列数：窄屏（< 360dp）两列，否则每 180 一列、至少三列。
///
/// 书架面板最宽 640，在其中始终是三列；更宽的容器（宽窗口）才多放几列，
/// 封面不会被拉得过大。
int notebookShelfColumns(double width) =>
    width < 360 ? 2 : math.max(3, width ~/ 180);

/// 等宽网格：每行 [columns] 格、间距 12，最后一行不足时留空。用普通的行
/// 而不是 GridView：分组要能放进 AnimatedSize 里展开收起。
class NotebookShelfGrid extends StatelessWidget {
  const NotebookShelfGrid({
    super.key,
    required this.columns,
    required this.children,
  });

  static const double spacing = 12;

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: spacing));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < columns; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: spacing),
              Expanded(
                child: start + i < children.length
                    ? children[start + i]
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// 书架上的一本：点按选中，长按弹出编辑 / 置顶 / 合上 / 删除菜单（4 项单行
/// 动作，按 DESIGN.md §5.4 用锚定弹出菜单）。有子本时封面后面叠两层纸边
/// （[NotebookStackedCover]），点按照常进入（列表汇总子本）。
class NotebookShelfTile extends ConsumerWidget {
  const NotebookShelfTile({
    super.key,
    required this.notebook,
    required this.count,
    required this.selected,
    required this.onTap,
    this.childCount = 0,
  });

  final NotebookView notebook;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  /// 直接子本数（0 为没有子本，不画叠放）。
  final int childCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ExpressiveMenuAnchor(
      placement: ExpressiveMenuPlacement.start,
      menuChildren: <Widget>[
        for (final action in notebookQuickActions(notebook))
          ExpressiveMenuItem(
            leadingIcon: FaIcon(notebookActionIcon(action)),
            destructive: action == NotebookAction.delete,
            onPressed: () => unawaited(
              runNotebookAction(
                context,
                ref,
                notebook: notebook,
                action: action,
              ),
            ),
            child: Text(notebookActionLabel(l10n, action)),
          ),
      ],
      builder: (BuildContext context, ExpressiveMenuAnchorState menu, _) =>
          NotebookStackedCover(
            childCount: childCount,
            color: notebook.color,
            closed: notebook.isClosed,
            child: NotebookCoverTile.fromView(
              notebook,
              count: count,
              selected: selected,
              onTap: onTap,
              onLongPress: menu.open,
            ),
          ),
    );
  }
}

/// 书架面板的分组标题；[expanded] 非空时整行可点，右侧箭头指示展开状态。
class NotebookShelfSectionHeader extends StatelessWidget {
  const NotebookShelfSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.expanded,
    this.onToggle,
  });

  final FaIconData icon;
  final String label;
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expanded = this.expanded;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.m,
      ),
      child: Row(
        children: <Widget>[
          FaIcon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (expanded != null)
            FaIcon(
              expanded ? FontAwesomeIcons.angleUp : FontAwesomeIcons.angleDown,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    return Semantics(
      header: true,
      expanded: expanded,
      child: onToggle == null
          ? row
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: row,
            ),
    );
  }
}
