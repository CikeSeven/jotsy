import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../pages/notebook_editor_page.dart';
import '../pages/notebooks_page.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_cover_tile.dart';
import '../widgets/notebook_shelf_grid.dart';
import '../widgets/notebooks_empty_state.dart';

/// 书架面板的选择结果：回到全部日记，或切到某一本。下滑或点遮罩关闭为 null。
sealed class NotebookShelfResult {
  const NotebookShelfResult();

  const factory NotebookShelfResult.selectAll() = NotebookShelfSelectAll;

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
/// 对应的一格高亮。
///
/// 面板只负责挑选；切换由调用方完成。面板内的删除带撤销提示条：面板盖住了
/// 页面底部，提示条显示在面板自己的 [ScaffoldMessenger] 里，撤销按钮才点得到。
Future<NotebookShelfResult?> showNotebookShelfSheet(
  BuildContext context, {
  String? currentNotebookId,
}) {
  return showModalBottomSheet<NotebookShelfResult>(
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
              ),
            ),
          ),
    ),
  );
}

/// 书架面板内容：标题行（“管理”进入管理页）、“全部日记”、置顶 / 我的日记本
/// / 智能日记本 / 已合上四组封面网格（空组不显示，“已合上”默认收起）。
class NotebookShelf extends ConsumerStatefulWidget {
  const NotebookShelf({
    super.key,
    required this.scrollController,
    this.currentNotebookId,
  });

  final ScrollController scrollController;
  final String? currentNotebookId;

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
            ListTile(
              selected: widget.currentNotebookId == null,
              selectedTileColor: theme.colorScheme.secondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: const FaIcon(FontAwesomeIcons.layerGroup, size: 18),
              title: Text(l10n.notebookAllDiaries),
              onTap: () => _select(const NotebookShelfResult.selectAll()),
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
  ) {
    final l10n = context.l10n;
    Widget tile(NotebookView notebook) => NotebookShelfTile(
      key: ValueKey<String>('notebook_shelf_${notebook.id}'),
      notebook: notebook,
      // 智能日记本的篇数由规则现算，接入前不显示。
      count: notebook.isManual ? counts[notebook.id] ?? 0 : null,
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
