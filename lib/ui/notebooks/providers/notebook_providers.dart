import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
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

/// 范围内（未删除、未归档）的篇数：日记本头部卡片的篇数，与首页列表一致。
final notebookScopeCountProvider = StreamProvider.autoDispose
    .family<int, DiaryListScope>(
      (Ref ref, DiaryListScope scope) =>
          ref.watch(appDatabaseProvider).watchScopedDiaryCount(scope),
    );

/// 范围内未归档日记的轻量概览（不含富文本正文与未解封的胶囊）：头部卡片
/// 统计字数与时间跨度。
final notebookScopeOverviewsProvider = StreamProvider.autoDispose
    .family<List<ExploreDiaryOverview>, DiaryListScope>(
      (Ref ref, DiaryListScope scope) => ref
          .watch(appDatabaseProvider)
          .watchExploreDiaryOverviews(scope: scope, includeArchived: false),
    );

/// 私密日记（在隐藏 / 上锁的普通日记本里）的业务 id，含回收站里的：回收站与
/// 纪念日据此把它们显示为占位，而不是“已删除”。
final privateDiaryIdsProvider = StreamProvider.autoDispose<Set<String>>(
  (Ref ref) => ref.watch(appDatabaseProvider).watchPrivateDiaryIds(),
);

/// 包含这篇日记的普通日记本（按书架顺序）：预览页的日记本胶囊与“收进日记本”
/// 的说明。
///
/// 一次性读取而不是订阅：这条查询连着日记表，订阅会在每次写日记（预览页
/// 勾选待办）时重查。改动收录的地方（预览页“收进日记本”）写完后
/// invalidate；预览页每次打开都重新读取。
final diaryNotebooksProvider = FutureProvider.autoDispose
    .family<List<NotebookView>, String>((Ref ref, String diaryId) async {
      final rows = await ref
          .watch(appDatabaseProvider)
          .getNotebooksOfDiary(diaryId);
      return List<NotebookView>.unmodifiable(rows.map(NotebookView.new));
    });
