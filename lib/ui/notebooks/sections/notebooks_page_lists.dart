import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../widgets/list_item_presence.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_labels.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_cover_tile.dart';

/// 管理页的一个分组：按住左侧手柄（或长按整行）拖动排序，点按编辑，行尾
/// “更多”打开操作面板。删除时这一行先收起（[collapsing]），撤销后从 0 高度
/// 展开（[appearing]），进出都经 [ListItemPresence]。
///
/// 行按树序排列（[rows]，见 `notebookSubtreeRows`）：子本紧跟在上级下面，
/// 每深一层向内缩进 [notebookTreeIndentStep]；层级变化（上级被删、子本提上来）时缩进
/// 经 [AnimatedPadding] 补间。拖动只在同一上级的兄弟之间换顺序，由页面按
/// 落点换算（`notebookSiblingOrderAfterDrag`）。
///
/// 收起：有子本的行尾多一个展开 / 收起按钮（[collapsed] 为收起了的本子）。
/// 被收起的子孙（[folded]）仍留在列表里、只经 [ListItemPresence] 收到 0 高度
/// 并让出焦点：行的下标因此不随收起变化，拖动的落点换算照旧按整组树序。
class NotebooksSectionSliver extends StatelessWidget {
  const NotebooksSectionSliver({
    super.key,
    required this.rows,
    required this.counts,
    required this.childCounts,
    required this.collapsing,
    required this.appearing,
    required this.collapsed,
    required this.folded,
    required this.onTap,
    required this.onMore,
    required this.onToggle,
    required this.onReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
  });

  final List<NotebookTreeRow> rows;
  final Map<String, int> counts;

  /// 每本的直接子本数；没有子本的不在表里。
  final Map<String, int> childCounts;
  final Set<String> collapsing;
  final Set<String> appearing;
  final Set<String> collapsed;
  final Set<String> folded;
  final ValueChanged<NotebookView> onTap;
  final ValueChanged<NotebookView> onMore;
  final ValueChanged<NotebookView> onToggle;

  /// onReorderItem 语义：[newIndex] 已按移除 [oldIndex] 后的列表修正。
  final void Function(int oldIndex, int newIndex) onReorder;

  /// 拿起第 index 行（页面借此把被拖的父本的子本收进来）。
  final ValueChanged<int> onReorderStart;

  /// 松手，参数为未修正的插入位置（`SliverReorderableList.onReorderEnd`）。
  final ValueChanged<int> onReorderEnd;

  @override
  Widget build(BuildContext context) {
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.cards);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      sliver: SliverReorderableList(
        itemCount: rows.length,
        onReorderItem: onReorder,
        // 拿起条目即生效的瞬间给一次触觉（手柄立即拖动，整行在长按之后）。
        onReorderStart: (int index) {
          unawaited(HapticFeedback.mediumImpact());
          onReorderStart(index);
        },
        onReorderEnd: onReorderEnd,
        proxyDecorator: _liftProxy,
        itemBuilder: (BuildContext context, int index) {
          final row = rows[index];
          final notebook = row.notebook;
          final hidden = folded.contains(notebook.id);
          final childCount = childCounts[notebook.id] ?? 0;
          return ListItemPresence(
            key: ValueKey<String>('notebook_row_${notebook.id}'),
            visible: !collapsing.contains(notebook.id) && !hidden,
            appearing: appearing.contains(notebook.id),
            duration: duration,
            glass: glass,
            child: ExcludeFocus(
              excluding: hidden,
              child: AnimatedPadding(
                duration: duration,
                curve: ExpressiveMotion.effects,
                padding: EdgeInsetsDirectional.only(
                  start: row.indent * notebookTreeIndentStep,
                  bottom: AppSpacing.s,
                ),
                // 智能日记本的篇数由规则现算，只让这一行订阅它的计数。
                child: Consumer(
                  builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                      NotebookManageRow(
                        notebook: notebook,
                        count: watchNotebookDisplayCount(ref, notebook, counts),
                        childCount: childCount,
                        expanded: !collapsed.contains(notebook.id),
                        index: index,
                        onTap: () => onTap(notebook),
                        onMore: () => onMore(notebook),
                        onToggle: childCount == 0
                            ? null
                            : () => onToggle(notebook),
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 拖起时只轻微放大，不另加卡片：行本身就是带描边的卡片。
  static Widget _liftProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale: 1 + 0.02 * ExpressiveMotion.effects.transform(animation.value),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// 管理页的一行：拖动手柄、小封面、名称与状态摘要（“23 篇 · 2 本子本 ·
/// 置顶”）、有子本时的展开 / 收起、更多。
///
/// 手柄按住即拖；小封面与名称一块长按后拖动（[ReorderableDelayedDragStartListener]，
/// 短按仍是编辑）。两个拖动入口互不嵌套：同一次按下若同时交给两个识别器，
/// 列表只记得后一个，立即拖动会和长按抢同一个指针。行尾的按钮不在长按区里，
/// 长按它们照常显示提示。
class NotebookManageRow extends StatelessWidget {
  const NotebookManageRow({
    super.key,
    required this.notebook,
    required this.count,
    required this.index,
    required this.onTap,
    required this.onMore,
    this.childCount = 0,
    this.expanded = true,
    this.onToggle,
  });

  final NotebookView notebook;
  final int? count;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMore;

  /// 直接子本数，摘要里显示；0 时不显示。
  final int childCount;

  /// 子本是否展开着（只在 [onToggle] 不为 null 时有意义）。
  final bool expanded;

  /// 展开 / 收起子本；没有子本时为 null，不显示按钮。
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = notebookRowSubtitle(
      l10n,
      notebook,
      count,
      childCount: childCount,
    );
    final toggle = onToggle;
    final body = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Row(
          children: <Widget>[
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: l10n.notebookDragHandle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.l,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.gripLines,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: Row(
                  children: <Widget>[
                    NotebookCoverTile.miniFromView(notebook),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            notebook.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (toggle != null)
              IconButton(
                key: ValueKey<String>('notebook_toggle_${notebook.id}'),
                tooltip: expanded
                    ? l10n.notebookSubCollapse
                    : l10n.notebookSubExpand,
                onPressed: toggle,
                // 与书架“已合上”同一组图标：收起时向下（点开），展开时向上。
                icon: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.spatial,
                  child: FaIcon(
                    FontAwesomeIcons.angleDown,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            IconButton(
              tooltip: l10n.notebookMoreActions,
              onPressed: onMore,
              icon: FaIcon(
                FontAwesomeIcons.ellipsisVertical,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
    // 玻璃时为内容玻璃（共用页面背景读取、无背景图不模糊）；经典分支保持
    // 原样。经典行没有投影，玻璃也不画。
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.input)),
        child: body,
      );
    }
    return Material(
      color: ExpressiveSurfaces.cardColor(scheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        side: ExpressiveSurfaces.cardBorderSide(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }
}
