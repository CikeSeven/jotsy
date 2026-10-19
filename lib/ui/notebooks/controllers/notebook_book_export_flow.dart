import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/controllers/diary_export_flow.dart';
import '../../diaries/export/diary_export_book.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../models/notebook_export_book.dart';
import '../models/notebook_scope_resolver.dart';
import '../viewmodels/notebook_view.dart';

/// 导出成书的素材：书的结构与按书序排好的日记详情。
typedef NotebookBookExportSource = ({
  DiaryExportBook book,
  List<DiaryWithTags> diaries,
});

/// 读出一本日记本的全部日记（含归档，不含回收站），按书序排好。
///
/// - 普通日记本：经 `getNotebookContents` 取成员与章节（私密规则与目录页
///   一致），再按 [notebookExportBook] 分章排序；
/// - 智能日记本：规则范围内的日记按发表时间从旧到新
///   （`getScopedDiaryIdsOldestFirst`），不分章。
///
/// 详情逐篇按 id 读取（与首页多选导出相同）；读取途中被删掉的日记跳过。
Future<NotebookBookExportSource> loadNotebookBookExport(
  AppDatabase database,
  NotebookView notebook,
) async {
  final DiaryExportBook book;
  if (notebook.isSmart) {
    final ids = await database.getScopedDiaryIdsOldestFirst(
      resolveNotebookScope(notebook),
    );
    book = smartNotebookExportBook(notebook, ids);
  } else {
    book = notebookExportBook(
      notebook,
      await database.getNotebookContents(notebook.id),
    );
  }
  final diaries = <DiaryWithTags>[];
  for (final id in book.diaryIds) {
    final detail = await database.getDiaryWithTagsByDiaryId(id);
    if (detail != null && !detail.diary.isDeleted) {
      diaries.add(detail);
    }
  }
  return (book: book, diaries: diaries);
}

/// 日记本头部 ⋮ 菜单“导出成书”：读出全书（等待超过 150ms 时显示等待遮罩），
/// 交给共用导出流程 `runDiaryExportFlow`（面板挑选格式与“书籍结构”，控制器
/// 生成文件）。普通与智能日记本都可用；加锁的日记本只能在已解锁的范围里
/// 走到这里（头部卡片只在那时出现），这里不再验证。提示统一经
/// `HomeHintVisibilityScope`。
Future<void> exportNotebookAsBook(
  BuildContext context,
  WidgetRef ref,
  NotebookView notebook,
) async {
  final l10n = context.l10n;
  void showHint(String message) {
    if (!context.mounted) {
      return;
    }
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  final database = ref.read(appDatabaseProvider);
  final NotebookBookExportSource source;
  try {
    source = await runWithActionLoadingOverlay(
      context,
      label: l10n.commonLoading,
      task: () => loadNotebookBookExport(database, notebook),
    );
  } catch (error) {
    debugPrint('Loading notebook for book export failed: $error');
    showHint(l10n.previewExportFailed('$error'));
    return;
  }
  if (!context.mounted) {
    return;
  }
  await runDiaryExportFlow(
    context,
    ref,
    diaries: source.diaries,
    book: source.book,
    showHint: showHint,
  );
}
