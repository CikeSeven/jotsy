import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/viewmodels/publish_panel_summary.dart';
import 'package:node_diary/ui/notebooks/models/notebook_pick_selection.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_quick_create_dialog.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_capsule.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_pick_row.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import 'publish_panel_tile.dart';

/// 面板主页的“日记本”行：最多两枚日记本胶囊，其余以 +N 汇总；没选时显示
/// “不收进日记本”。点按进入日记本子页。只随草稿里的日记本重建。
class PublishNotebookTile extends StatelessWidget {
  const PublishNotebookTile({
    super.key,
    required this.draft,
    required this.notebooks,
    required this.onOpen,
  });

  static const int _maxVisible = 2;

  final DiaryMetaDraftController draft;

  /// 书架上的日记本（含合上的：编辑已在合上本子里的日记时仍要显示它）。
  final List<NotebookView> notebooks;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ValueListenableSelector<DiaryMetaDraft, Set<String>>(
      valueListenable: draft,
      selector: (value) => value.notebookIds,
      builder: (context, _, _) {
        final selected = publishSelectedNotebooks(draft.value, notebooks);
        final more = selected.length - _maxVisible;
        return PublishPanelTile(
          onTap: onOpen,
          child: Row(
            children: <Widget>[
              Text(
                l10n.notebookTitle,
                style: PublishPanelTile.titleStyle(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: selected.isEmpty
                    ? Text(
                        l10n.notebookPublishNone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      )
                    // 窄屏时换行而不是横向滚动（与标签行一致）。
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          for (final notebook in selected.take(_maxVisible))
                            NotebookCapsule(
                              notebook: notebook,
                              maxNameWidth: 96,
                            ),
                          if (more > 0)
                            Text(
                              '+$more',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            ],
          ),
        );
      },
    );
  }
}

/// 面板的日记本子页：顶部“＋ 新建日记本”，下面是可收进的日记本（没合上的
/// 普通日记本，按书架顺序）的勾选列表；已选中的合上的本子也列出来，可以
/// 取消。勾选直接写进草稿。
///
/// 三态：加载中 / 列表 / 没有日记本时的说明（仍可新建）。篇数在这里订阅：
/// 子页只在打开时构建，面板主页不随日记写入重查篇数。
class PublishNotebookPickerPage extends ConsumerWidget {
  const PublishNotebookPickerPage({
    super.key,
    required this.draft,
    required this.notebooks,
  });

  final DiaryMetaDraftController draft;

  /// 书架上的日记本；null 为还在读取。
  final List<NotebookView>? notebooks;

  Future<void> _create(BuildContext context) async {
    final id = await showQuickCreateNotebookDialog(context);
    if (id == null) return;
    draft.setNotebookSelected(id, true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = notebooks;
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ValueListenableSelector<DiaryMetaDraft, Set<String>>(
        valueListenable: draft,
        selector: (value) => value.notebookIds,
        builder: (context, selectedIds, _) {
          final rows = all == null
              ? null
              : <NotebookView>[
                  for (final notebook in all)
                    if (notebook.isManual &&
                        (!notebook.isClosed ||
                            selectedIds.contains(notebook.id)))
                      notebook,
                ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              NotebookPickCreateRow(onTap: () => unawaited(_create(context))),
              if (rows == null)
                const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: ExpressiveLoadingIndicator(),
                  ),
                )
              else if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.notebookPickerEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                for (final notebook in rows)
                  NotebookPickRow(
                    key: ValueKey<String>('publish_notebook_${notebook.id}'),
                    notebook: notebook,
                    count: counts[notebook.id] ?? 0,
                    state: selectedIds.contains(notebook.id)
                        ? NotebookPickState.all
                        : NotebookPickState.none,
                    onTap: () => draft.setNotebookSelected(
                      notebook.id,
                      !selectedIds.contains(notebook.id),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
