import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../sections/notebook_action_sheets.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_chapter_chips.dart';
import 'notebook_goal_row.dart';
import 'notebook_header_actions.dart';
import 'notebook_header_card.dart';

/// 首页标签栏与列表之间的日记本头部：进入日记本时卡片从 0 高度展开并淡入，
/// 回到全部日记时反向收起，列表随之平滑移动而不是一帧跳开（DESIGN §4.3
/// “内容插入与移除”）。随列表一起滚走。
///
/// 在两本之间切换时新旧卡片交叉淡入，高度差同样经 [AnimatedSize] 过渡。
class NotebookHeaderSliver extends StatelessWidget {
  const NotebookHeaderSliver({
    super.key,
    required this.notebook,
    required this.onAction,
    this.onExportBook,
    this.horizontalMargin = AppSpacing.l,
    this.onAddDiaries,
    this.onOpenContents,
    this.onOpenInsights,
    this.selectedChapterId,
    this.unassignedChapterOnly = false,
    this.onSelectChapter,
  });

  /// 当前日记本；null（全部日记）时收起为 0 高度。
  final NotebookView? notebook;
  final ValueChanged<NotebookAction> onAction;

  /// 头部菜单“导出成书”（见 `exportNotebookAsBook`）。
  final VoidCallback? onExportBook;

  /// 卡片左右外边距，与下方日记卡片的侧边距一致（见 [NotebookHeaderCard]）。
  final double horizontalMargin;

  /// “添加日记”（从已有日记挑选）；只对普通日记本显示，null 时不显示。
  final VoidCallback? onAddDiaries;

  /// “目录”；只对普通日记本显示，null 时不显示。
  final VoidCallback? onOpenContents;

  /// “统计”；普通与智能日记本都显示，null 时不显示。
  final VoidCallback? onOpenInsights;

  /// 首页当前的章节筛选（章节胶囊的选中态）。
  final String? selectedChapterId;
  final bool unassignedChapterOnly;

  /// 点章节胶囊；null 时不显示胶囊行。胶囊行只在有章节的普通日记本里出现。
  final void Function({String? chapterId, bool unassigned})? onSelectChapter;

  @override
  Widget build(BuildContext context) {
    final current = notebook;
    return SliverToBoxAdapter(
      child: AnimatedSize(
        // AnimatedSize 不接受 0 时长（见 ExpressiveMotion.durationNonZero）。
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: (Widget? currentChild, List<Widget> previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, ?currentChild],
          ),
          child: current == null
              ? const SizedBox(
                  key: ValueKey<String>('notebook_header_none'),
                  width: double.infinity,
                )
              : NotebookHeaderCard(
                  key: ValueKey<String>('notebook_header_${current.id}'),
                  notebook: current,
                  onAction: onAction,
                  onExportBook: onExportBook,
                  horizontalMargin: horizontalMargin,
                  extras: <Widget>[
                    // 写作目标（只有设了目标的普通日记本）：点按打开编辑页。
                    if (current.isManual && current.payload.goal != null)
                      NotebookGoalRow(
                        notebook: current,
                        onTap: () => onAction(NotebookAction.edit),
                      ),
                    if (onOpenInsights != null ||
                        (current.isManual &&
                            (onAddDiaries != null || onOpenContents != null)))
                      NotebookHeaderActions(
                        onAddDiaries: current.isManual ? onAddDiaries : null,
                        onOpenContents: current.isManual
                            ? onOpenContents
                            : null,
                        onOpenInsights: onOpenInsights,
                      ),
                  ],
                  // 章节胶囊放在最下方，紧挨着它筛选的列表；横向滚动区铺到
                  // 卡片边缘。
                  bleedExtras: <Widget>[
                    if (current.isManual &&
                        current.payload.chapters.isNotEmpty &&
                        onSelectChapter != null)
                      NotebookChapterChips(
                        notebook: current,
                        selectedChapterId: selectedChapterId,
                        unassignedOnly: unassignedChapterOnly,
                        onSelect: onSelectChapter!,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 日记本里还没有日记时列表位置的空状态（沿用日记页空状态的排布）。
///
/// 普通日记本给两个入口：“写第一篇”（直接写进这本）与“从已有日记挑选”；
/// 智能日记本按规则收录，只有说明文字。
class NotebookEmptyState extends StatelessWidget {
  const NotebookEmptyState({super.key, this.onWriteFirst, this.onPickExisting});

  /// “写第一篇”；与 [onPickExisting] 都为 null 时只显示文字（智能日记本）。
  final VoidCallback? onWriteFirst;
  final VoidCallback? onPickExisting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onWriteFirst = this.onWriteFirst;
    final onPickExisting = this.onPickExisting;
    final hasActions = onWriteFirst != null || onPickExisting != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(FontAwesomeIcons.bookOpen, size: 38, color: scheme.secondary),
          const SizedBox(height: AppSpacing.m),
          Text(
            l10n.notebookEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            hasActions
                ? l10n.notebookEmptyManualHint
                : l10n.notebookEmptyCreateHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (hasActions) ...<Widget>[
            const SizedBox(height: AppSpacing.l),
            // 窄屏或大字号时两个按钮放不下一行就折到下一行，不横向溢出。
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: <Widget>[
                if (onWriteFirst != null)
                  FilledButton.tonalIcon(
                    onPressed: onWriteFirst,
                    icon: const FaIcon(FontAwesomeIcons.penNib, size: 14),
                    label: Text(l10n.notebookEmptyWriteFirst),
                  ),
                if (onPickExisting != null)
                  OutlinedButton.icon(
                    onPressed: onPickExisting,
                    icon: const FaIcon(FontAwesomeIcons.listCheck, size: 14),
                    label: Text(l10n.notebookEmptyPickExisting),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
