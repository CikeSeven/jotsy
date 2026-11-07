import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/form_width.dart';
import '../../widgets/reorder_handle.dart';

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

  /// 拖动手柄（[ReorderHandle]）；多选时不显示。
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

/// 没有章节时列表上方的提示条：“添加章节，把日记分成几部分”，点按即新建
/// 章节。
class NotebookContentsChapterHint extends StatelessWidget {
  const NotebookContentsChapterHint({super.key, required this.onAddChapter});

  final VoidCallback onAddChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 玻璃时为半透明底色 + 玻璃描边；经典时 side 为 none，与只给
    // borderRadius 的形状一致。
    final glassField = AppGlassField.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Material(
        color: glassField?.fill ?? scheme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: glassField?.border ?? BorderSide.none,
        ),
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
