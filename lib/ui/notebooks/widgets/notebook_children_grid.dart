import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_children_layout.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_child_tile.dart';
import 'notebook_children_toggle_tile.dart';
import 'notebook_header_card.dart';

/// 首页日记本头部卡片里的子本网格：标题行“子日记本 N”（右侧“＋ 新建子本”，
/// 只在 [NotebookView.canHaveChildren] 时），下面按宽度分列的直接子本
/// （小封面 + 名称 + 篇数）。子本多时不必横向翻找：一眼看到前两行，其余
/// 折叠在“还有 N 本”里。
///
/// - 排布与折叠只经 [NotebookChildrenLayout]（按网格实际可用宽度，手机两列）；
///   展开状态只在内存 `notebookChildrenExpandedProvider`（按日记本记，进了
///   子本再回来仍保持），不加设置键；
/// - 放在卡片的铺满插槽（`bleedExtras`）里、章节胶囊之上，左右与卡片文字对齐；
/// - 子本列表只读 `notebookTreeProvider`（直接子本，书架顺序），篇数与书架
///   同一口径（`watchNotebookDisplayCount`，有子本的子本为汇总篇数）；
/// - 合上的子本照常列出、整格变淡；比当前这本更私密的子本（它的日记不在
///   这本的汇总里，进入要验证）在篇数旁带锁 / 隐藏图标；
/// - 点按经 [onOpen] 交给日记页进入（上锁的由它验证），“新建子本”经
///   [onCreate]；
/// - 新出现的格子（刚在这里新建的子本、展开后露出来的子本、互换的“还有 N 本 /
///   收起”）淡入放大，首次构建时不播放；高度变化由头部外层的 AnimatedSize
///   过渡。
class NotebookChildrenGrid extends ConsumerStatefulWidget {
  const NotebookChildrenGrid({
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
  ConsumerState<NotebookChildrenGrid> createState() =>
      _NotebookChildrenGridState();
}

/// “还有 N 本 / 收起”格在 [_NotebookChildrenGridState._known] 里的身份。
enum _ToggleCellId { more, less }

class _NotebookChildrenGridState extends ConsumerState<NotebookChildrenGrid> {
  /// 上一次构建时网格里已有的格子（子本 id 与 [_ToggleCellId]）：之后新出现的
  /// 才播放出现动画。null 为还没构建过。
  Set<Object>? _known;

  @override
  void didUpdateWidget(covariant NotebookChildrenGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了一本（头部交叉淡入时复用到同一个 State 的情况）：重新起算。
    if (oldWidget.notebook.id != widget.notebook.id) _known = null;
  }

  @override
  Widget build(BuildContext context) {
    final notebook = widget.notebook;
    final children =
        ref.watch(notebookTreeProvider)?.childrenOf(notebook.id) ??
        const <NotebookView>[];
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    // 篇数须在 build 里订阅（不能放进下面的 LayoutBuilder）；折叠起来的子本
    // 一并订阅，展开时篇数已经就绪、格子不跳。
    final childCounts = <String, int?>{
      for (final child in children)
        child.id: watchNotebookDisplayCount(ref, child, counts),
    };
    final expanded = ref.watch(
      notebookChildrenExpandedProvider.select(
        (Set<String> ids) => ids.contains(notebook.id),
      ),
    );
    final onCreate = notebook.canHaveChildren ? widget.onCreate : null;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    void toggle() =>
        ref.read(notebookChildrenExpandedProvider.notifier).toggle(notebook.id);
    return Padding(
      // 标题行带着按钮高 36、文字上下各留 10：上边距只补 2，与上方内容仍隔
      // 约 12。
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            // 有“新建子本”时文字按钮的内边距伸进卡片右边距，按钮文字与
            // 卡片内容右缘对齐。
            padding: EdgeInsetsDirectional.only(
              start: NotebookHeaderCard.contentPadding,
              end: onCreate == null
                  ? NotebookHeaderCard.contentPadding
                  : NotebookHeaderCard.contentPadding - AppSpacing.s,
            ),
            child: _TitleRow(count: children.length, onCreate: onCreate),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NotebookHeaderCard.contentPadding,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final layout = NotebookChildrenLayout.of(
                  width: constraints.maxWidth,
                  count: children.length,
                  expanded: expanded,
                );
                final known = _known;
                final cells = <Widget>[];
                final ids = <Object>{};
                void addCell(Object id, Widget child) {
                  ids.add(id);
                  cells.add(
                    NotebookChildEntrance(
                      key: ValueKey<Object>(id),
                      appearing: known != null && !known.contains(id),
                      duration: duration,
                      child: child,
                    ),
                  );
                }

                for (final child in children.take(layout.shown)) {
                  addCell(
                    child.id,
                    NotebookChildTile(
                      notebook: child,
                      parentVisibility: notebook.effectiveVisibility,
                      count: childCounts[child.id],
                      onTap: () => widget.onOpen(child.id),
                    ),
                  );
                }
                if (layout.collapsible && !expanded) {
                  addCell(
                    _ToggleCellId.more,
                    NotebookChildrenMoreTile(
                      hidden: children.skip(layout.shown).toList(),
                      // 约 150dp 以下的格子（窄手机）只叠两张，给文字让出宽度。
                      maxCovers: layout.cellWidth < 150 ? 2 : 3,
                      onTap: toggle,
                    ),
                  );
                } else if (layout.collapsible) {
                  addCell(
                    _ToggleCellId.less,
                    NotebookChildrenLessTile(onTap: toggle),
                  );
                }
                _known = ids;
                return _GridRows(columns: layout.columns, cells: cells);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 标题行：“子日记本” + 直接子本数，右侧“＋ 新建子本”。
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.count, required this.onCreate});

  final int count;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    final onCreate = this.onCreate;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: <Widget>[
          // 标题与数字占满按钮左边的空间（不用 Spacer：与 Flexible 平分
          // 剩余宽度会把按钮挤到中间）。
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    l10n.notebookSubSectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: titleStyle?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
          if (onCreate != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: onCreate,
              icon: const FaIcon(FontAwesomeIcons.plus, size: 11),
              label: Text(l10n.notebookSubCreateShort),
            ),
        ],
      ),
    );
  }
}

/// 按行排好的格子：每行等宽分 [columns] 格、同一行按最高的一格拉齐
/// （大字号时名称两行的子本格会比“收起”格高），末行不满时留空。
class _GridRows extends StatelessWidget {
  const _GridRows({required this.columns, required this.cells});

  final int columns;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    const gap = NotebookChildrenLayout.gap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var start = 0; start < cells.length; start += columns) ...<Widget>[
          if (start > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < columns; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: start + i < cells.length
                        ? cells[start + i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
