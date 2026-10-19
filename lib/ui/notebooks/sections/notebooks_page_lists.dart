import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/list_item_presence.dart';
import '../viewmodels/notebook_labels.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_cover_tile.dart';

/// 管理页的一个分组：按住左侧手柄拖动排序，点按编辑，行尾“更多”打开操作
/// 面板。删除时这一行先收起（[collapsing]），撤销后从 0 高度展开
/// （[appearing]），进出都经 [ListItemPresence]。
class NotebooksSectionSliver extends StatelessWidget {
  const NotebooksSectionSliver({
    super.key,
    required this.notebooks,
    required this.counts,
    required this.collapsing,
    required this.appearing,
    required this.onTap,
    required this.onMore,
    required this.onReorder,
  });

  final List<NotebookView> notebooks;
  final Map<String, int> counts;
  final Set<String> collapsing;
  final Set<String> appearing;
  final ValueChanged<NotebookView> onTap;
  final ValueChanged<NotebookView> onMore;

  /// onReorderItem 语义：[newIndex] 已按移除 [oldIndex] 后的列表修正。
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      sliver: SliverReorderableList(
        itemCount: notebooks.length,
        onReorderItem: onReorder,
        // 拿起条目即生效的瞬间给一次触觉：手柄是立即拖动，不经过长按。
        onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
        proxyDecorator: _liftProxy,
        itemBuilder: (BuildContext context, int index) {
          final notebook = notebooks[index];
          return ListItemPresence(
            key: ValueKey<String>('notebook_row_${notebook.id}'),
            visible: !collapsing.contains(notebook.id),
            appearing: appearing.contains(notebook.id),
            duration: duration,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: NotebookManageRow(
                notebook: notebook,
                count: notebook.isManual ? counts[notebook.id] ?? 0 : null,
                index: index,
                onTap: () => onTap(notebook),
                onMore: () => onMore(notebook),
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

/// 管理页的一行：拖动手柄、小封面、名称与状态摘要（“23 篇 · 置顶”）、更多。
class NotebookManageRow extends StatelessWidget {
  const NotebookManageRow({
    super.key,
    required this.notebook,
    required this.count,
    required this.index,
    required this.onTap,
    required this.onMore,
  });

  final NotebookView notebook;
  final int? count;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = notebookRowSubtitle(l10n, notebook, count);
    return Material(
      color: ExpressiveSurfaces.cardColor(scheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        side: ExpressiveSurfaces.cardBorderSide(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
              NotebookCoverTile.mini(
                icon: notebook.icon,
                color: notebook.color,
                coverPath: notebook.coverPath,
                closed: notebook.isClosed,
              ),
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
      ),
    );
  }
}
