import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../../core/services/diary_media_cleanup_service.dart';

/// 回收站的恢复与彻底删除；不构建 UI，确认、提示与收起动画由页面负责。
///
/// 两种操作都逐篇提交、单篇失败不打断其余的，返回失败的 id，页面据此让
/// 这些条目重新展开、保持勾选以便重试。
class RecycleBinController {
  RecycleBinController({required this.database, required this.mediaCleanup});

  final AppDatabase database;
  final DiaryMediaCleanupService mediaCleanup;

  /// 恢复 [diaryIds]：不改编辑时间，日记回到原来的排序位置与日记本。
  Future<List<String>> restore(List<String> diaryIds) => _eachDiary(
    diaryIds,
    (diaryId) => database.restoreDiary(diaryId, touchUpdatedAt: false),
  );

  /// 彻底删除 [diaryIds]。只删记录：正文媒体可能被别的日记或草稿复用，
  /// 至少删掉一篇时在后台按引用回收，不阻塞删除结果提示。
  Future<List<String>> purge(List<String> diaryIds) async {
    final failedIds = await _eachDiary(diaryIds, database.hardDeleteDiary);
    if (failedIds.length < diaryIds.length) {
      unawaited(mediaCleanup.sweep());
    }
    return failedIds;
  }

  Future<List<String>> _eachDiary(
    List<String> diaryIds,
    Future<void> Function(String diaryId) run,
  ) async {
    final failedIds = <String>[];
    for (final diaryId in diaryIds) {
      try {
        await run(diaryId);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }
    return failedIds;
  }
}
