import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../pages/notebook_editor_page.dart';
import '../pages/notebooks_page.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_cover_tile.dart';
import '../widgets/notebook_shelf_grid.dart';
import '../widgets/notebook_switcher_chip.dart';
import '../widgets/notebooks_empty_state.dart';

/// 书架面板的选择结果：回到全部日记、切到“未收录”，或切到某一本。下滑或点
/// 遮罩关闭为 null。
sealed class NotebookShelfResult {
  const NotebookShelfResult();

  const factory NotebookShelfResult.selectAll() = NotebookShelfSelectAll;

  const factory NotebookShelfResult.selectUnfiled() =
      NotebookShelfSelectUnfiled;

  const factory NotebookShelfResult.selectNotebook(String notebookId) =
      NotebookShelfSelectNotebook;
}

final class NotebookShelfSelectAll extends NotebookShelfResult {
  const NotebookShelfSelectAll();

  @override
  bool operator ==(Object other) => other is NotebookShelfSelectAll;

  @override
  int get hashCode => (NotebookShelfSelectAll).hashCode;
}

final class NotebookShelfSelectUnfiled extends NotebookShelfResult {
  const NotebookShelfSelectUnfiled();

  @override
  bool operator ==(Object other) => other is NotebookShelfSelectUnfiled;

  @override
  int get hashCode => (NotebookShelfSelectUnfiled).hashCode;
}

final class NotebookShelfSelectNotebook extends NotebookShelfResult {
  const NotebookShelfSelectNotebook(this.notebookId);

  final String notebookId;

  @override
  bool operator ==(Object other) =>
      other is NotebookShelfSelectNotebook && other.notebookId == notebookId;

  @override
  int get hashCode => notebookId.hashCode;
}

/// 打开书架面板。[currentNotebookId] 为当前所在的日记本（null 为全部日记），
/// 对应的一格高亮；[unfiledSelected] 为当前在“未收录”里。
///
/// 面板只负责挑选；切换由调用方完成。面板内的删除带撤销提示条：面板盖住了
/// 页面底部，提示条显示在面板自己的 [ScaffoldMessenger] 里，撤销按钮才点得到。
Future<NotebookShelfResult?> showNotebookShelfSheet(
  BuildContext context, {
  String? currentNotebookId,
  bool unfiledSelected = false,
}) {
  return showAppModalBottomSheet<NotebookShelfResult>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      builder: (BuildContext context, ScrollController scrollController) =>
          ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: NotebookShelf(
                scrollController: scrollController,
                currentNotebookId: currentNotebookId,
                unfiledSelected: unfiledSelected,
              ),
            ),
          ),
    ),
  );
}

/// 书架面板内容：标题行（“管理”进入管理页）、“全部日记”与“未收录”（没有
/// 收进任何日记本的日记）两行（行尾为篇数）、置顶 / 我的日记本 / 智能日记本 /
/// 已合上四组封面网格（空组不显示，“已合上”默认收起）。
///
/// 只列顶层的本子（置顶除外，见 [NotebookShelfGroups]）：子本跟着上级，在
/// 上级的头部卡片里点进；有子本的封面画成叠放的样子。
class NotebookShelf extends ConsumerStatefulWidget {
  const NotebookShelf({
    super.key,
    required this.scrollController,
    this.currentNotebookId,
    this.unfiledSelected = false,
  });

  final ScrollController scrollController;
  final String? currentNotebookId;
  final bool unfiledSelected;

  @override
  ConsumerState<NotebookShelf> createState() => _NotebookShelfState();
}

class _NotebookShelfState extends ConsumerState<NotebookShelf> {
  bool _closedExpanded = false;

  void _select(NotebookShelfResult result) => Navigator.of(context).pop(result);

  Future<void> _create() =>
      Navigator.of(context).push(NotebookEditorPage.route());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notebooks = ref.watch(notebooksProvider).value;
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final tree = ref.watch(notebookTreeProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = notebookShelfColumns(constraints.maxWidth);
        return ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.xs,
                    ),
                    child: Text(
                      l10n.notebookTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotebooksPage(),
                    ),
                  ),
                  child: Text(l10n.notebookManage),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            _ScopeTile(
              scope: DiaryListScope.all,
              icon: FontAwesomeIcons.layerGroup,
              title: l10n.notebookAllDiaries,
              selected:
                  widget.currentNotebookId == null && !widget.unfiledSelected,
              onTap: () => _select(const NotebookShelfResult.selectAll()),
            ),
            const SizedBox(height: AppSpacing.xs),
            _ScopeTile(
              scope: DiaryListScope.unfiled,
              icon: NotebookSwitcherChip.unfiledIcon,
              title: l10n.notebookUnfiled,
              selected: widget.unfiledSelected,
              onTap: () => _select(const NotebookShelfResult.selectUnfiled()),
            ),
            if (notebooks == null)
              const SizedBox(height: 160, child: DelayedLoadingIndicator())
            else if (notebooks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxl),
                child: NotebooksEmptyState(onCreate: _create),
              )
            else
              ..._sections(
                context,
                NotebookShelfGroups(notebooks),
                counts,
                columns,
                tree,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _sections(
    BuildContext context,
    NotebookShelfGroups groups,
    Map<String, int> counts,
    int columns,
    NotebookTree? tree,
  ) {
    final l10n = context.l10n;
    Widget tile(NotebookView notebook) => NotebookShelfTile(
      key: ValueKey<String>('notebook_shelf_${notebook.id}'),
      notebook: notebook,
      childCount: tree?.childrenOf(notebook.id).length ?? 0,
      // 智能日记本的篇数由规则现算（算出之前不显示）。
      count: watchNotebookDisplayCount(ref, notebook, counts),
      selected: notebook.id == widget.currentNotebookId,
      onTap: () => _select(NotebookShelfResult.selectNotebook(notebook.id)),
    );
    Widget grid(List<Widget> children) =>
        NotebookShelfGrid(columns: columns, children: children);
    return <Widget>[
      if (groups.pinned.isNotEmpty) ...<Widget>[
        NotebookShelfSectionHeader(
          icon: FontAwesomeIcons.thumbtack,
          label: l10n.notebookSectionPinned,
        ),
        grid(groups.pinned.map(tile).toList()),
      ],
      NotebookShelfSectionHeader(
        icon: FontAwesomeIcons.book,
        label: l10n.notebookSectionMine,
      ),
      grid(<Widget>[
        ...groups.shelfManual.map(tile),
        NotebookCoverTile.create(onTap: () => unawaited(_create())),
      ]),
      if (groups.shelfSmart.isNotEmpty) ...<Widget>[
        NotebookShelfSectionHeader(
          icon: FontAwesomeIcons.wandMagicSparkles,
          label: l10n.notebookSectionSmart,
        ),
        grid(groups.shelfSmart.map(tile).toList()),
      ],
      if (groups.closed.isNotEmpty) ...<Widget>[
        NotebookShelfSectionHeader(
          icon: FontAwesomeIcons.boxArchive,
          label: l10n.notebookSectionClosed,
          expanded: _closedExpanded,
          onToggle: () => setState(() => _closedExpanded = !_closedExpanded),
        ),
        AnimatedSize(
          // AnimatedSize 不能接受 0 时长（见 ExpressiveMotion.durationNonZero）。
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: _closedExpanded
              ? grid(groups.closed.map(tile).toList())
              : const SizedBox(width: double.infinity),
        ),
      ],
    ];
  }
}

/// 书架顶部的“全部日记”与“未收录”两行，行尾为范围内的篇数（未删除、未归档，
/// 与首页列表同一口径：私密日记不计入，也就不透露私密本子里有多少篇；算出
/// 之前不显示）。
class _ScopeTile extends ConsumerWidget {
  const _ScopeTile({
    required this.scope,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final DiaryListScope scope;
  final FaIconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final count = ref.watch(notebookScopeCountProvider(scope)).value;
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: FaIcon(icon, size: 18),
      title: Text(title),
      trailing: count == null
          ? null
          : Text(
              l10n.notebookEntryCount(count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
    );
  }
}
