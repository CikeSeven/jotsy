import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../settings/widgets/choice_sheet_parts.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/notebook_contents_controller.dart';
import '../controllers/notebook_lock_flow.dart';
import '../models/notebook_pick_selection.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_transfer_targets.dart';
import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_foldable_rows.dart';
import '../widgets/notebook_pick_row.dart';
import 'notebook_contents_transfer_dialog.dart';
import 'notebook_quick_create_dialog.dart';

/// 目录页“转移目录”流程（整份目录与单个章节共用）。
///
/// - 输入：当前手动日记本 [source]、目录页控制器 [controller]、预计转移的章节数
///   与日记篇数，以及可选的单个章节 [chapter]（为 null 表示整份目录）。
/// - 输出：无返回值；取消、身份验证未通过或写库失败时留在原处，不改动数据。
/// - 副作用：可在选择面板里于 [source] 下新建子日记本；目标处于不同上锁范围时
///   经 [authorizeNotebookEntry] 验证身份；确认后经 [controller.transfer] 在
///   单个事务里搬运章节与成员，弹出带撤销的提示条。
///
/// 目标可以是上级（父本、祖本）或子孙本：转到子本的内容能原路转回上级，提示条
/// 上的撤销则把两本精确还原到转移前。
Future<void> runNotebookContentsTransferFlow(
  BuildContext context,
  WidgetRef ref, {
  required NotebookView source,
  required NotebookContentsController controller,
  required int chapterCount,
  required int entryCount,
  NotebookChapter? chapter,
}) async {
  final target = await showNotebookTransferTargetSheet(
    context,
    source: source,
    chapter: chapter,
  );
  if (target == null || !context.mounted) return;
  final tree = ref.read(notebookTreeProvider);
  final bool needsAuth;
  if (tree == null) {
    needsAuth = notebookRequiresAuth(target);
  } else {
    // 刚在面板里新建的子本可能尚未经书架流推送回来：补进树里再按同一口径算
    // 上锁范围，避免继承当前本锁的新子本多问一次验证。往上级转属于“往上走”，
    // 同一口径下不再验证。
    final resolvedTree = tree[target.id] != null
        ? tree
        : NotebookTree(<NotebookRow>[
            ...tree.notebooks.map((NotebookView item) => item.row),
            target.row,
          ]);
    needsAuth = notebookSwitchRequiresAuth(
      resolvedTree,
      target,
      fromId: source.id,
    );
  }
  if (needsAuth) {
    final allowed = await authorizeNotebookEntry(context, ref, target);
    if (!allowed || !context.mounted) return;
  }
  final confirmed = await showNotebookContentsTransferDialog(
    context,
    source: source,
    target: target,
    chapterCount: chapterCount,
    entryCount: entryCount,
    chapter: chapter,
  );
  if (!confirmed || !context.mounted) return;
  final NotebookContentsTransfer transfer;
  try {
    transfer = await controller.transfer(
      targetId: target.id,
      chapterId: chapter?.id,
    );
  } catch (error) {
    debugPrint('Transferring notebook contents failed: $error');
    if (context.mounted) {
      showStyleEditorMessage(context, context.l10n.notebookActionFailed);
    }
    return;
  }
  if (!context.mounted) return;
  final l10n = context.l10n;
  final message = switch (NotebookTransferPrivacyChange.of(
    source: source,
    target: target,
    entryCount: transfer.entryCount,
  )) {
    NotebookTransferPrivacyChange.becomesPrivate =>
      l10n.notebookContentsTransferredPrivate(target.name),
    NotebookTransferPrivacyChange.becomesPublic =>
      l10n.notebookContentsTransferredPublic(target.name),
    NotebookTransferPrivacyChange.none =>
      chapter != null
          ? l10n.notebookChapterTransferred(chapter.title, target.name)
          : l10n.notebookContentsTransferred(target.name),
  };
  if (transfer.isEmpty) {
    showStyleEditorMessage(context, message);
    return;
  }
  // 带撤销的提示条开着时局域网同步不写入（撤销窗口），撤销写回的不会被同步
  // 刚写入的值覆盖，反之亦然。
  unawaited(
    showStyleEditorUndoSnackBar(
      context,
      message: message,
      onUndo: () => unawaited(_undoTransfer(context, controller, transfer)),
    ),
  );
}

Future<void> _undoTransfer(
  BuildContext context,
  NotebookContentsController controller,
  NotebookContentsTransfer transfer,
) async {
  try {
    await controller.undoTransfer(transfer);
  } catch (error) {
    debugPrint('Undoing notebook contents transfer failed: $error');
    if (context.mounted) {
      showStyleEditorMessage(context, context.l10n.notebookActionFailed);
    }
  }
}

/// 挑选目标日记本的底部面板：有上级时分“上级日记本 / 子日记本”两组，列出
/// [source] 未合上的手动上级与手动子孙（树序缩进、可收起展开）；还能建子本
/// 时在子本一组顶部提供“＋ 新建子日记本”，建完直接返回新子本。
Future<NotebookView?> showNotebookTransferTargetSheet(
  BuildContext context, {
  required NotebookView source,
  NotebookChapter? chapter,
}) {
  return showAppModalBottomSheet<NotebookView>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext _) =>
        _NotebookTransferTargetSheet(source: source, chapter: chapter),
  );
}

class _NotebookTransferTargetSheet extends ConsumerWidget {
  const _NotebookTransferTargetSheet({required this.source, this.chapter});

  final NotebookView source;
  final NotebookChapter? chapter;

  Future<void> _createChild(BuildContext context, WidgetRef ref) async {
    final newId = await showQuickCreateNotebookDialog(
      context,
      parentId: source.id,
    );
    if (newId == null || !context.mounted) return;
    final row = await ref.read(appDatabaseProvider).getNotebook(newId);
    if (row == null || !context.mounted) return;
    final created = NotebookView(
      row,
      parentId: source.id,
      depth: source.depth + 1,
      effectiveVisibility: source.effectiveVisibility,
    );
    Navigator.of(context).pop(created);
  }

  Widget _rows(
    BuildContext context,
    WidgetRef ref,
    List<NotebookTreeRow> rows,
    Map<String, int> counts,
  ) {
    return NotebookFoldableRows(
      rows: rows,
      itemBuilder: (context, row, toggle) {
        final notebook = row.notebook;
        return NotebookPickRow(
          key: ValueKey<String>('notebook_transfer_target_${notebook.id}'),
          notebook: notebook,
          state: NotebookPickState.none,
          count: watchNotebookDisplayCount(ref, notebook, counts),
          showCheck: false,
          indent: row.indent,
          toggle: toggle,
          onTap: () => Navigator.of(context).pop(notebook),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tree = ref.watch(notebookTreeProvider);
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final targets = tree == null
        ? const NotebookTransferTargets(
            ancestors: <NotebookTreeRow>[],
            descendants: <NotebookTreeRow>[],
          )
        : NotebookTransferTargets.of(tree, source.id);
    final canCreate = source.canHaveChildren;
    // 没有上级时只有子本一组，不加分组标题（与只能转到子本时一样）。
    final grouped = targets.ancestors.isNotEmpty;
    final title = chapter == null
        ? l10n.notebookContentsTransferSheetTitle
        : l10n.notebookChapterTransferSheetTitle(chapter!.title);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.m,
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                children: <Widget>[
                  if (grouped) ...<Widget>[
                    ChoiceSheetSectionHeader(
                      icon: FontAwesomeIcons.arrowTurnUp,
                      label: l10n.notebookParentLabel,
                    ),
                    _rows(context, ref, targets.ancestors, counts),
                    if (canCreate || targets.descendants.isNotEmpty)
                      ChoiceSheetSectionHeader(
                        icon: FontAwesomeIcons.arrowTurnDown,
                        label: l10n.notebookSubSectionTitle,
                      ),
                  ],
                  if (canCreate)
                    NotebookPickCreateRow(
                      key: const ValueKey<String>(
                        'notebook_transfer_create_child',
                      ),
                      label: l10n.notebookSubCreate,
                      onTap: () => _createChild(context, ref),
                    ),
                  if (targets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.l,
                      ),
                      child: Text(
                        l10n.notebookContentsTransferEmptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else if (targets.descendants.isNotEmpty)
                    _rows(context, ref, targets.descendants, counts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
