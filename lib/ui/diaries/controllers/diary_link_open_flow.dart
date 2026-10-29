import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../notebooks/controllers/notebook_lock_flow.dart';
import '../../notebooks/controllers/notebook_navigation.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/providers/app_features_provider.dart';
import 'diary_open_flow.dart';

const Duration _hintDuration = Duration(seconds: 3);
const Duration _undoDuration = Duration(seconds: 4);

/// 点按日记链接（行内链接、卡片、反向链接）后打开目标，唯一出口。
///
/// 日记：
/// 1. 按 id 读一次本地库；查不到或在回收站 → 提示“不存在或已删除”；
/// 2. 在上锁的日记本里（任一所在的手动本生效可见性为 locked，层级取自书架
///    列表 [notebookTreeProvider]，书架没加载时只看本子自己）→ 先经 [authorizeNotebookEntry] 验证，
///    取消或失败则停在原处。链接本身可能来自一篇不私密的日记：按 id 直接
///    打开不经全局查询的私密过滤，这一步不能省；隐藏（不上锁）的本子不验证，
///    与在书架上进入它同一口径；
/// 3. 经 [openDiaryPage] 打开（未解封的胶囊照常进封存页）；在里面删除时
///    给撤销，撤销即从回收站恢复。
///
/// 日记本：日记本功能关闭时什么也不做（入口本应已隐藏）；书架上查不到 →
/// 提示；否则经 [openNotebookFromAnywhere]（自带上锁验证、回到首页）。
/// [fromEditor] 为 true（编辑态的正文）时不打开日记本：回到首页会关掉正在
/// 写的这一篇。
Future<void> openDiaryLinkTarget(
  BuildContext context,
  WidgetRef ref,
  DiaryLinkTarget target, {
  bool fromEditor = false,
}) async {
  switch (target.kind) {
    case DiaryLinkKind.diary:
      await _openDiary(context, ref, target.id);
    case DiaryLinkKind.notebook:
      if (fromEditor ||
          !ref.read(appFeaturesProvider.select((f) => f.notebooks))) {
        return;
      }
      final notebook = ref.read(notebookTreeProvider)?[target.id];
      if (notebook == null) {
        _hint(context, context.l10n.diaryLinkMissingNotebook);
        return;
      }
      await openNotebookFromAnywhere(context, ref, notebook);
  }
}

Future<void> _openDiary(
  BuildContext context,
  WidgetRef ref,
  String diaryId,
) async {
  // 撤销发生在页面返回之后，那时打开方可能已卸载、不能再用 ref：先取好库。
  final database = ref.read(appDatabaseProvider);
  final tree = ref.read(notebookTreeProvider);
  final detail = await database.getDiaryWithTagsByDiaryId(diaryId);
  if (!context.mounted) return;
  if (detail == null || detail.diary.isDeleted) {
    _hint(context, context.l10n.diaryLinkMissingDiary);
    return;
  }
  NotebookView? locked;
  for (final row in await database.getNotebooksOfDiary(diaryId)) {
    final notebook = tree?[row.notebookId] ?? NotebookView(row);
    if (notebookRequiresAuth(notebook)) {
      locked = notebook;
      break;
    }
  }
  if (!context.mounted) return;
  if (locked != null) {
    final allowed = await authorizeNotebookEntry(context, ref, locked);
    if (!allowed || !context.mounted) return;
  }
  final result = await openDiaryPage(
    context,
    ref,
    diaryId: diaryId,
    initialDetail: detail,
  );
  // 预览页里可能已滑到别的日记再删除：恢复的是结果里的那一篇。
  final deletedId = result?.diaryId;
  if (deletedId == null || !context.mounted) return;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(context.l10n.autoT0075),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(label: context.l10n.commonUndo, onPressed: () {}),
    ),
  );
  if (reason == SnackBarClosedReason.action) {
    await database.restoreDiary(deletedId, touchUpdatedAt: false);
  }
}

void _hint(BuildContext context, String message) {
  HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(message), duration: _hintDuration),
  );
}
