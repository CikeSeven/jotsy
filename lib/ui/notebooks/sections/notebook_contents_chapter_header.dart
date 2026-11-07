import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';

/// 目录页章节标题行上的操作。
enum NotebookChapterAction { rename, moveUp, moveDown, delete }

/// 目录页的章节标题行：章节名（`titleMedium` w700 `primary`）+ 篇数 + 收起 /
/// 展开箭头，右侧 ⋮ 菜单（重命名 / 上移 / 下移 / 删除；在两端时不给上移或
/// 下移）与拖动手柄（与日记行的手柄在同一列）。
///
/// - 点按章节名一带收起 / 展开这一章的日记（[onToggle]；没有日记时为 null，
///   不显示箭头、点了也没反应）。箭头与管理页的子本按钮同一组：收起时向下
///   （点开）、展开时向上。
/// - [dragHandle] 为 null 时不能拖（“未分章”总在最后；多选时也不显示）。
/// - [chapter] 为 null 时是“未分章”，没有菜单；空着时下方多一行“拖到这里
///   移出章节”。
class NotebookContentsChapterHeader extends StatelessWidget {
  const NotebookContentsChapterHeader({
    super.key,
    required this.chapter,
    required this.count,
    this.isFirst = false,
    this.isLast = false,
    this.collapsed = false,
    this.onToggle,
    this.onAction,
    this.dragHandle,
  });

  final NotebookChapter? chapter;
  final int count;
  final bool isFirst;
  final bool isLast;

  /// 这一章是否收起着（只在 [onToggle] 不为 null 时显示）。
  final bool collapsed;
  final VoidCallback? onToggle;
  final ValueChanged<NotebookChapterAction>? onAction;

  /// 拖动手柄（`ReorderHandle`），由列表按下标包好。
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final chapter = this.chapter;
    final onAction = this.onAction;
    final dragHandle = this.dragHandle;
    final menu = chapter != null && onAction != null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.l,
        bottom: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ChapterTitle(
                    title: chapter?.title ?? l10n.notebookChapterUnassigned,
                    count: count,
                    collapsed: collapsed,
                    onToggle: onToggle,
                  ),
                ),
                if (menu)
                  ExpressiveMenuButton(
                    tooltip: l10n.notebookContentsChapterActions,
                    icon: const FaIcon(
                      FontAwesomeIcons.ellipsisVertical,
                      size: 18,
                    ),
                    items: <Widget>[
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(FontAwesomeIcons.pen),
                        onPressed: () => onAction(NotebookChapterAction.rename),
                        child: Text(l10n.notebookChapterRename),
                      ),
                      if (!isFirst)
                        ExpressiveMenuItem(
                          leadingIcon: const FaIcon(FontAwesomeIcons.arrowUp),
                          onPressed: () =>
                              onAction(NotebookChapterAction.moveUp),
                          child: Text(l10n.notebookChapterMoveUp),
                        ),
                      if (!isLast)
                        ExpressiveMenuItem(
                          leadingIcon: const FaIcon(FontAwesomeIcons.arrowDown),
                          onPressed: () =>
                              onAction(NotebookChapterAction.moveDown),
                          child: Text(l10n.notebookChapterMoveDown),
                        ),
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                        destructive: true,
                        onPressed: () => onAction(NotebookChapterAction.delete),
                        child: Text(l10n.commonDelete),
                      ),
                    ],
                  ),
                // 手柄与日记行的手柄同在最右一列；没有手柄时给菜单留出与
                // 以前相同的 4dp 右边距。
                dragHandle ?? const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
          // 空着的“未分章”是拖出章节的落点：提示一句，也给拖动留出落脚高度。
          if (chapter == null && count == 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.l,
                end: AppSpacing.l,
                bottom: AppSpacing.s,
              ),
              child: Text(
                l10n.notebookContentsUnassignedDropHint,
                style: AppPageBackdrop.onBackgroundTextStyle(
                  context,
                  theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 章节名 + 篇数 + 箭头；有 [onToggle] 时整块可点（水波纹圆角 16），读屏
/// 报“已展开 / 已收起”与点按的作用。
class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle({
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final onToggle = this.onToggle;
    // 章节标题行直接画在目录页背景上，有背景图时加可读性兜底。
    final countStyle = AppPageBackdrop.onBackgroundTextStyle(
      context,
      theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    // 与整行同高（至少 48），水波纹铺满这一行的标题区。
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.l,
          end: AppSpacing.s,
        ),
        child: Row(
          children: <Widget>[
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppPageBackdrop.onBackgroundTextStyle(
                    context,
                    theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(l10n.notebookEntryCount(count), style: countStyle),
            if (onToggle != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              AnimatedRotation(
                turns: collapsed ? 0 : 0.5,
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                curve: ExpressiveMotion.spatial,
                child: FaIcon(
                  FontAwesomeIcons.angleDown,
                  size: 12,
                  color: countStyle?.color ?? scheme.onSurfaceVariant,
                  shadows: countStyle?.shadows,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onToggle == null) return content;
    return Semantics(
      button: true,
      expanded: !collapsed,
      onTapHint: collapsed
          ? l10n.notebookChapterExpand
          : l10n.notebookChapterCollapse,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadii.input),
          child: content,
        ),
      ),
    );
  }
}
