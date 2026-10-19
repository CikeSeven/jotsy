import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../controllers/notebooks_controller.dart';
import '../viewmodels/notebook_view.dart';

/// 书架上的全部日记本（置顶在前，再按手动顺序），实时跟随数据库。
///
/// 每行在这里解析一次成 [NotebookView]，组件不再自己解码 payload。
final notebooksProvider = StreamProvider<List<NotebookView>>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return database.watchNotebooks().map(
    (rows) => List<NotebookView>.unmodifiable(rows.map(NotebookView.new)),
  );
});

/// 普通日记本 id → 篇数（不算回收站与归档）。没有日记的本子不在表里，读取方
/// 按 0 处理；智能日记本的篇数由规则现算，暂不在这里。
final notebookEntryCountsProvider = StreamProvider<Map<String, int>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchManualNotebookEntryCounts();
});

/// 单个日记本，不存在（已删除）时为 null。
final notebookProvider = StreamProvider.autoDispose
    .family<NotebookView?, String>((Ref ref, String notebookId) {
      return ref
          .watch(appDatabaseProvider)
          .watchNotebook(notebookId)
          .map((row) => row == null ? null : NotebookView(row));
    });

/// 书架与管理页共用的日记本操作（置顶、合上、排序、删除与撤销、合并）。
final notebooksControllerProvider = Provider<NotebooksController>(
  (Ref ref) => NotebooksController(ref.watch(appDatabaseProvider)),
);
