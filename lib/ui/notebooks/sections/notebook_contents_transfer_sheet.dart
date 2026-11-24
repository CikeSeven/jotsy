import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/notebook_contents_controller.dart';
import '../controllers/notebook_lock_flow.dart';
import '../models/notebook_pick_selection.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_foldable_rows.dart';
import '../widgets/notebook_pick_row.dart';
import 'notebook_quick_create_dialog.dart';

/// 目录页“转移到子日记本”流程（整份目录与单个章节共用）。
///
/// - 输入：当前手动日记本 [source]、目录页控制器 [controller]、预计转移的章节数
///   与日记篇数，以及可选的单个章节 [chapter]（为 null 表示整份目录）。
/// - 输出：无返回值；取消、身份验证未通过或写库失败时留在原处，不改动数据。
/// - 副作用：可在选择面板里于 [source] 下新建子日记本；目标处于不同上锁范围时
///   经 [authorizeNotebookEntry] 验证身份；确认后经 [controller.transferToChild]
///   在单个事务里搬运章节与成员并弹出提示条。

/// 当前日记本 [sourceId] 下面可以接收目录转移的候选子日记本：所有未合上的手动
/// 子孙本，按 [notebookTreeRows] 树序缩进（直接子本缩进 0、孙子本缩进 1）。
List<NotebookTreeRow> notebookChildTransferCandidates(
  NotebookTree tree,
  String sourceId,
) {
  final descendants = <String>{
    for (final child in tree.descendantsOf(sourceId)) child.id,
  };
  if (descendants.isEmpty) return const <NotebookTreeRow>[];
  return notebookTreeRows(
    tree,
    include: (NotebookView notebook) =>
        descendants.contains(notebook.id) &&
        notebook.isManual &&
        !notebook.isClosed,
  );
}

/// 当前手动日记本是否支持在目录页发起“转移到子日记本”：还能新建子本，或已经
/// 有可接收转移的手动子孙本（第 3 层最深叶子本两者都不满足，入口隐藏）。
bool canTransferNotebookContentsToChild(
  NotebookView notebook,
  NotebookTree? tree,
) {
  if (!notebook.isManual) return false;
  if (notebook.canHaveChildren) return true;
  if (tree == null) return false;
  return notebookChildTransferCandidates(tree, notebook.id).isNotEmpty;
}

/// 执行“转移到子日记本”完整流程：挑选子日记本（或当场新建子本）→ 目标位于
/// 不同上锁范围时验证身份 → 确认转移内容与私密影响 → 原子写库并提示。
Future<void> runNotebookContentsTransferFlow(
  BuildContext context,
  WidgetRef ref, {
  required NotebookView source,
  required NotebookContentsController controller,
  required int chapterCount,
  required int entryCount,
  NotebookChapter? chapter,
}) async {
  final target = await showNotebookChildTargetSheet(
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
    // 上锁范围，避免继承当前本锁的新子本多问一次验证。
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
  final NotebookContentsTransferResult result;
  try {
    result = await controller.transferToChild(
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
  final becamePrivate =
      !source.isPrivate && target.isPrivate && result.entryCount > 0;
  final message = becamePrivate
      ? l10n.notebookContentsTransferredPrivate(target.name)
      : chapter != null
      ? l10n.notebookChapterTransferred(chapter.title, target.name)
      : l10n.notebookContentsTransferred(target.name);
  showStyleEditorMessage(context, message);
}

/// 挑选目标子日记本的底部面板：列出 [source] 下所有未合上的手动子孙本（树序
/// 缩进、可收起展开），还能建子本时顶部提供“＋ 新建子日记本”直接建完返回。
Future<NotebookView?> showNotebookChildTargetSheet(
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
        _NotebookChildTargetSheet(source: source, chapter: chapter),
  );
}

class _NotebookChildTargetSheet extends ConsumerWidget {
  const _NotebookChildTargetSheet({required this.source, this.chapter});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tree = ref.watch(notebookTreeProvider);
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final candidates = tree == null
        ? const <NotebookTreeRow>[]
        : notebookChildTransferCandidates(tree, source.id);
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
                  if (source.canHaveChildren)
                    NotebookPickCreateRow(
                      key: const ValueKey<String>(
                        'notebook_transfer_create_child',
                      ),
                      label: l10n.notebookSubCreate,
                      onTap: () => _createChild(context, ref),
                    ),
                  if (candidates.isEmpty)
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
                  else
                    NotebookFoldableRows(
                      rows: candidates,
                      itemBuilder: (context, row, toggle) {
                        final notebook = row.notebook;
                        return NotebookPickRow(
                          key: ValueKey<String>(
                            'notebook_transfer_target_${notebook.id}',
                          ),
                          notebook: notebook,
                          state: NotebookPickState.none,
                          count: watchNotebookDisplayCount(
                            ref,
                            notebook,
                            counts,
                          ),
                          showCheck: false,
                          indent: row.indent,
                          toggle: toggle,
                          onTap: () => Navigator.of(context).pop(notebook),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 转移确认框：写明即将搬运的章节数、日记篇数与目标子本；从普通本转入私密
/// 子本且含日记时附带私密可见性说明。确认键为主色（不删除任何日记）。
Future<bool> showNotebookContentsTransferDialog(
  BuildContext context, {
  required NotebookView source,
  required NotebookView target,
  required int chapterCount,
  required int entryCount,
  NotebookChapter? chapter,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      final message = _confirmMessage(
        l10n,
        sourceName: source.name,
        targetName: target.name,
        chapterCount: chapterCount,
        entryCount: entryCount,
        chapter: chapter,
      );
      final showPrivateNote =
          !source.isPrivate && target.isPrivate && entryCount > 0;
      return AlertDialog(
        title: Text(l10n.notebookContentsTransferConfirmTitle),
        content: showPrivateNote
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(message),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    l10n.notebookContentsTransferPrivateNote(target.name),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Text(message),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.notebookContentsTransferAction),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

String _confirmMessage(
  AppLocalizations l10n, {
  required String sourceName,
  required String targetName,
  required int chapterCount,
  required int entryCount,
  required NotebookChapter? chapter,
}) {
  if (chapter != null) {
    return entryCount > 0
        ? l10n.notebookChapterTransferConfirm(
            chapter.title,
            entryCount,
            sourceName,
            targetName,
          )
        : l10n.notebookChapterTransferConfirmEmpty(
            chapter.title,
            sourceName,
            targetName,
          );
  }
  if (chapterCount > 0 && entryCount > 0) {
    return l10n.notebookContentsTransferConfirmAll(
      sourceName,
      chapterCount,
      entryCount,
      targetName,
    );
  }
  if (chapterCount > 0) {
    return l10n.notebookContentsTransferConfirmChaptersOnly(
      sourceName,
      chapterCount,
      targetName,
    );
  }
  return l10n.notebookContentsTransferConfirmEntriesOnly(
    sourceName,
    entryCount,
    targetName,
  );
}
