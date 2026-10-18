import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../../core/services/diary_media_cleanup_service.dart';

/// 草稿箱的删除与撤销；不构建 UI，提示与确认由页面负责。
///
/// 删除是硬删除：先读出整行再删，撤销时经 [restore] 原样写回（含本地 id 与
/// 编辑时间，回到列表原位置）。媒体回收必须等撤销窗口结束、确定不撤销后
/// 才执行（[releaseMedia]）：只被这份草稿引用、且早于宽限期的图片会被立即
/// 回收，撤销回来的草稿就会指向已删除的文件。
class DiaryDraftsController {
  DiaryDraftsController({required this.database, required this.mediaCleanup});

  final AppDatabase database;
  final DiaryMediaCleanupService mediaCleanup;

  /// 删除 [draftIds]，返回被删的行（供撤销）；已不存在的 id 忽略。
  ///
  /// 读出与删除在同一事务里：中间若有编辑页补存，撤销拿回的就是删除那一刻
  /// 的内容。
  Future<List<DiaryDraftRow>> delete(Iterable<String> draftIds) {
    final ids = draftIds.toSet();
    return database.transaction(() async {
      final rows = await (database.select(
        database.diaryDrafts,
      )..where((t) => t.draftId.isIn(ids))).get();
      await database.deleteDiaryDrafts(ids);
      return rows;
    });
  }

  Future<void> restore(List<DiaryDraftRow> rows) =>
      database.restoreDiaryDrafts(rows);

  /// 撤销窗口结束且未撤销：在后台按引用回收只被这些草稿用到的媒体。
  void releaseMedia() => unawaited(mediaCleanup.sweep());
}
