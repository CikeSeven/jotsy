import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../utils/tri_state_pick.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';

/// 目录页章节标题行上的操作。
enum NotebookChapterAction { rename, moveUp, moveDown, transferToChild, delete }

/// 目录页的章节标题行：章节名（`titleMedium` w700 `primary`）+ 篇数 + 收起 /
/// 展开箭头，右侧 ⋮ 菜单（重命名 / 上移 / 下移 / 移到子日记本 / 删除；在两端
/// 时不给上移或下移，不能转移到子本时不给“移到子日记本”）与拖动手柄（与日记行
/// 的手柄在同一列）。
///
/// - 点按章节名一带收起 / 展开这一章的日记（[onToggle]；没有日记时为 null，
///   不显示箭头、点了也没反应）；长按有日记的章节名直接进入多选并选中整章
///   （[onLongPress]）。箭头与管理页的子本按钮同一组：收起时向下（点开）、
///   展开时向上。
/// - 多选模式（[selecting]）下左侧滑出三态勾选框（与下方日记行的勾选框同列），
///   反映本章日记未选 / 部分选 / 全选状态；点按一键选中或取消选中整章
///   （[onSelectChapter]），空章节时禁用。
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
    this.canTransferToChild = false,
    this.selecting = false,
    this.selectionState = TriStatePick.none,
    this.onSelectChapter,
    this.onToggle,
    this.onLongPress,
    this.onAction,
    this.dragHandle,
  });

  final NotebookChapter? chapter;
  final int count;
  final bool isFirst;
  final bool isLast;

  /// 这一章是否收起着（只在 [onToggle] 不为 null 时显示）。
  final bool collapsed;

  /// 当前日记本是否支持把章节移到子日记本（最深叶子本为 false）。
  final bool canTransferToChild;

  /// 是否处于目录页多选模式：为 true 时左侧显示本章的三态勾选框。
  final bool selecting;

  /// 多选模式下本章日记的选中状态（全选 / 部分选中 / 未选中）。
  final TriStatePick selectionState;

  /// 点按左侧勾选框一键选中 / 取消选中本章所有日记；空章节时为 null（禁用）。
  final VoidCallback? onSelectChapter;
  final VoidCallback? onToggle;

  /// 长按章节标题区：普通模式进入多选并选中整章，多选模式切换整章勾选。
  final VoidCallback? onLongPress;
  final ValueChanged<NotebookChapterAction>? onAction;

  /// 拖动手柄（`ReorderHandle`），由列表按下标包好。
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final chapter = this.chapter;
    final title = chapter?.title ?? l10n.notebookChapterUnassigned;
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
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: <Widget>[
                  AnimatedSize(
                    duration: ExpressiveMotion.durationNonZero(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    curve: ExpressiveMotion.effects,
                    child: selecting
                        ? _ChapterSelectCheckbox(
                            title: title,
                            selectionState: selectionState,
                            onPressed: onSelectChapter,
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: _ChapterTitle(
                      title: title,
                      count: count,
                      collapsed: collapsed,
                      onToggle: onToggle,
                      onLongPress: onLongPress,
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
                          onPressed: () =>
                              onAction(NotebookChapterAction.rename),
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
                            leadingIcon: const FaIcon(
                              FontAwesomeIcons.arrowDown,
                            ),
                            onPressed: () =>
                                onAction(NotebookChapterAction.moveDown),
                            child: Text(l10n.notebookChapterMoveDown),
                          ),
                        if (canTransferToChild)
                          ExpressiveMenuItem(
                            leadingIcon: const FaIcon(
                              FontAwesomeIcons.folderTree,
                            ),
                            onPressed: () =>
                                onAction(NotebookChapterAction.transferToChild),
                            child: Text(l10n.notebookChapterTransferToChild),
                          ),
                        ExpressiveMenuItem(
                          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                          destructive: true,
                          onPressed: () =>
                              onAction(NotebookChapterAction.delete),
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
    required this.onLongPress,
  });

  final String title;
  final int count;
  final bool collapsed;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

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
    // 与整行同高（至少 48），水波纹铺满这一行的标题区。外层 Row 已自带
    // AppSpacing.s（8dp）起始边距，这里恒留水平 8dp，因此非多选时文字起点在
    // 16dp、多选时随勾选框同步滑至 72dp，均与下方日记行严格同列。
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
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
    if (onToggle == null && onLongPress == null) return content;
    return Semantics(
      button: onToggle != null,
      expanded: onToggle != null ? !collapsed : null,
      onTapHint: onToggle == null
          ? null
          : (collapsed
                ? l10n.notebookChapterExpand
                : l10n.notebookChapterCollapse),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadii.input),
          child: content,
        ),
      ),
    );
  }
}

/// 多选模式下章节标题行左侧的三态勾选框（未选 / 部分选 / 全选）。
///
/// 外侧行已有 `AppSpacing.s`（8dp）起始边距，这里再补 8dp 使勾选框落在距边缘
/// 16dp 处、总增量 56dp，与 `NotebookContentsEntryTile` 的勾选框和位移动画严格
/// 对齐。空章节时 [onPressed] 为 null，保持占位对齐并呈禁用态。
class _ChapterSelectCheckbox extends StatelessWidget {
  const _ChapterSelectCheckbox({
    required this.title,
    required this.selectionState,
    required this.onPressed,
  });

  final String title;
  final TriStatePick selectionState;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = selectionState == TriStatePick.all
        ? l10n.notebookChapterDeselectAll(title)
        : l10n.notebookChapterSelectAll(title);
    final checkbox = Checkbox(
      tristate: true,
      value: switch (selectionState) {
        TriStatePick.all => true,
        TriStatePick.some => null,
        TriStatePick.none => false,
      },
      semanticLabel: onPressed == null ? null : label,
      // 忽略 tristate 默认参数，固定按“未全选 → 全选、已全选 → 取消全选”切换。
      onChanged: onPressed == null ? null : (_) => onPressed!(),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.s),
      child: onPressed == null
          ? checkbox
          : Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: checkbox,
            ),
    );
  }
}
