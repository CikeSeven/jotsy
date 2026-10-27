import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_child_tile.dart';
import 'notebook_header_card.dart';

/// 首页日记本头部卡片里的子本条：小标题“子日记本”，下面一行横向滚动的
/// 直接子本（小封面 + 名称 + 篇数），末尾“＋ 新建子本”（只在
/// [NotebookView.canHaveChildren] 时）。
///
/// - 放在卡片的铺满插槽（`bleedExtras`）里、章节胶囊之上：滚出的格子消失在
///   卡片边缘，起止内容边距与卡片文字对齐；
/// - 子本列表只读 `notebookTreeProvider`（直接子本，书架顺序），篇数与书架
///   同一口径（`watchNotebookDisplayCount`，有子本的子本为汇总篇数）；
/// - 合上的子本照常列出、整格变淡；比当前这本更私密的子本（它的日记不在
///   这本的汇总里，进入要验证）在篇数旁带锁 / 隐藏图标；
/// - 点按经 [onOpen] 交给日记页进入（上锁的由它验证），“新建子本”经
///   [onCreate]；
/// - 新出现的子本（比如刚在这里新建的）横向展开淡入，首次构建时不播放。
class NotebookChildrenStrip extends ConsumerStatefulWidget {
  const NotebookChildrenStrip({
    super.key,
    required this.notebook,
    required this.onOpen,
    this.onCreate,
  });

  final NotebookView notebook;
  final ValueChanged<String> onOpen;

  /// “＋ 新建子本”；null 或这本不能再放子本时不显示。
  final VoidCallback? onCreate;

  @override
  ConsumerState<NotebookChildrenStrip> createState() =>
      _NotebookChildrenStripState();
}

class _NotebookChildrenStripState extends ConsumerState<NotebookChildrenStrip> {
  /// 上一次构建时已在条里的子本：之后新出现的才播放展开。null 为还没构建过。
  Set<String>? _known;

  @override
  void didUpdateWidget(covariant NotebookChildrenStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了一本（头部交叉淡入时复用到同一个 State 的情况）：重新起算。
    if (oldWidget.notebook.id != widget.notebook.id) _known = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notebook = widget.notebook;
    final children =
        ref.watch(notebookTreeProvider)?.childrenOf(notebook.id) ??
        const <NotebookView>[];
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final known = _known;
    _known = <String>{for (final child in children) child.id};
    final onCreate = notebook.canHaveChildren ? widget.onCreate : null;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NotebookHeaderCard.contentPadding,
            ),
            child: Text(
              l10n.notebookSubSectionTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          DesktopHorizontalScroll(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // 与章节胶囊同一排布：每格自带 end 间距，最后一格的并入右边距。
              padding: const EdgeInsetsDirectional.only(
                start: NotebookHeaderCard.contentPadding,
                end: NotebookHeaderCard.contentPadding - AppSpacing.s,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final child in children)
                      NotebookStripEntrance(
                        key: ValueKey<String>('notebook_child_${child.id}'),
                        appearing: known != null && !known.contains(child.id),
                        duration: duration,
                        child: NotebookChildTile(
                          notebook: child,
                          parentVisibility: notebook.effectiveVisibility,
                          count: watchNotebookDisplayCount(ref, child, counts),
                          onTap: () => widget.onOpen(child.id),
                        ),
                      ),
                    if (onCreate != null)
                      NotebookCreateChildTile(onTap: onCreate),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
