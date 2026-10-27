import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/form_width.dart';

/// 目录页章节标题行上的操作。
enum NotebookChapterAction { rename, moveUp, moveDown, delete }

/// 目录页的章节标题行：章节名（`titleMedium` w700 `primary`）+ 篇数，右侧
/// ⋮ 菜单（重命名 / 上移 / 下移 / 删除；在两端时不给上移或下移）。
/// [chapter] 为 null 时是“未分章”，没有菜单；它总在列表最后，空着时下方
/// 多一行“拖到这里移出章节”。标题行不能拖动。
class NotebookContentsChapterHeader extends StatelessWidget {
  const NotebookContentsChapterHeader({
    super.key,
    required this.chapter,
    required this.count,
    this.isFirst = false,
    this.isLast = false,
    this.onAction,
  });

  final NotebookChapter? chapter;
  final int count;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<NotebookChapterAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final chapter = this.chapter;
    final onAction = this.onAction;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Semantics(
                          header: true,
                          child: Text(
                            chapter?.title ?? l10n.notebookChapterUnassigned,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            // 章节标题行直接画在目录页背景上，有背景图时
                            // 加可读性兜底。
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
                      Text(
                        l10n.notebookEntryCount(count),
                        style: AppPageBackdrop.onBackgroundTextStyle(
                          context,
                          theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (chapter != null && onAction != null)
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
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
          // 空着的“未分章”是拖出章节的落点：提示一句，也给拖动留出落脚高度。
          if (chapter == null && count == 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(
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

/// 目录页的日记行：日期眉线（13sp w600 `onSurfaceVariant`，归档的带
/// `boxArchive` 小图标）、标题（`bodyLarge` w600，未写为“无标题”；未解封的
/// 胶囊只显示标题并带锁）。普通模式右侧是拖动手柄（[dragHandle]），多选模式
/// 左侧是勾选框、点按切换勾选。
class NotebookContentsEntryTile extends StatelessWidget {
  const NotebookContentsEntryTile({
    super.key,
    required this.dateLabel,
    required this.title,
    required this.archived,
    required this.sealed,
    required this.selecting,
    required this.selected,
    required this.onTap,
    this.dragHandle,
  });

  final String dateLabel;
  final String title;
  final bool archived;
  final bool sealed;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;

  /// 已包好 `ReorderableDragStartListener` 的手柄；多选时不显示。
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final eyebrowStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Row(
              children: <Widget>[
                AnimatedSize(
                  duration: ExpressiveMotion.durationNonZero(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: selecting
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.s,
                          ),
                          child: Checkbox(
                            value: selected,
                            onChanged: (_) => onTap(),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                dateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: eyebrowStyle,
                              ),
                            ),
                            if (archived) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs + 2),
                              Semantics(
                                label: l10n.notebookContentsArchived,
                                child: FaIcon(
                                  FontAwesomeIcons.boxArchive,
                                  size: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            if (sealed) ...<Widget>[
                              Semantics(
                                label: l10n.notebookContentsSealed,
                                child: FaIcon(
                                  FontAwesomeIcons.lock,
                                  size: 13,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs + 2),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (!selecting && dragHandle != null)
                  dragHandle!
                else
                  const SizedBox(width: AppSpacing.l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 目录页拖动手柄的外观：`gripLines`，留足 48dp 的触控区域。
class NotebookContentsDragGrip extends StatelessWidget {
  const NotebookContentsDragGrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.notebookContentsDragHandle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.l,
        ),
        child: FaIcon(
          FontAwesomeIcons.gripLines,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 没有章节时列表上方的提示条：“添加章节，把日记分成几部分”，点按即新建
/// 章节。
class NotebookContentsChapterHint extends StatelessWidget {
  const NotebookContentsChapterHint({super.key, required this.onAddChapter});

  final VoidCallback onAddChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAddChapter,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.folderPlus,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    context.l10n.notebookContentsNoChapterHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 多选时的底部操作栏：已选篇数 + “移到章节…”（有章节时）+ “从本日记本移出”。
class NotebookContentsSelectionBar extends StatelessWidget {
  const NotebookContentsSelectionBar({
    super.key,
    required this.count,
    required this.onMoveToChapter,
    required this.onRemove,
  });

  final int count;

  /// null 时不显示（本子没有章节）。
  final VoidCallback? onMoveToChapter;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final enabled = count > 0;
    final onMoveToChapter = this.onMoveToChapter;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: // 底色铺满整栏；宽窗口时内容收进居中的内容列（最宽 720）。
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: FormWidth.gutter(constraints.maxWidth),
                  vertical: AppSpacing.s,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s,
                      ),
                      child: Text(
                        l10n.notebookContentsSelectedCount(count),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: <Widget>[
                        if (onMoveToChapter != null)
                          TextButton.icon(
                            onPressed: enabled ? onMoveToChapter : null,
                            icon: const FaIcon(
                              FontAwesomeIcons.folderOpen,
                              size: 14,
                            ),
                            label: Text(l10n.notebookContentsMoveToChapter),
                          ),
                        TextButton.icon(
                          onPressed: enabled ? onRemove : null,
                          icon: const FaIcon(
                            FontAwesomeIcons.arrowRightFromBracket,
                            size: 14,
                          ),
                          label: Text(l10n.notebookRemoveFromCurrent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
