part of 'app_database.dart';

/// 多篇日记的状态批量写入：首页多选的置顶、归档、删除与它们的撤销。
///
/// 为什么不逐篇调用 [_AppDatabaseDiaryWrites.archiveDiary] 等单篇写入：
/// 首页全选会把还没分页加载的日记一并选中，可能有几千篇。逐篇写入时每条
/// UPDATE 都各自提交、各自通知一次数据流，首页分页（含正文）、时间轴、
/// 探索等订阅会被反复重查，界面明显卡顿。这里在一个事务里按 500 个一批
/// （`IN (…)` 的绑定变量上限）写完，提交后只通知一次；任一批失败则整体
/// 回滚，调用方不必再逐篇回退。
///
/// 口径与单篇写入一致：都不改 `updatedAt`（只做整理，撤销后排序不变）；
/// 软删除同时清掉归档标记，恢复回到未归档、未删除。
mixin _AppDatabaseDiaryBatchWrites on _$AppDatabase {
  /// 批量置顶（[pinned] 为 true）或取消置顶。
  Future<void> setDiariesPinned(
    Iterable<String> diaryIds, {
    required bool pinned,
  }) => _updateDiariesByIds(
    diaryIds,
    DiariesCompanion(isPinned: Value<bool>(pinned)),
  );

  /// 批量归档（[archived] 为 true）或取消归档。
  Future<void> setDiariesArchived(
    Iterable<String> diaryIds, {
    required bool archived,
  }) => _updateDiariesByIds(
    diaryIds,
    DiariesCompanion(
      isArchived: Value<bool>(archived),
      archivedAt: Value<DateTime?>(archived ? DateTime.now() : null),
    ),
  );

  /// 批量软删除（进回收站，不动标签与日记本关联，见单篇的 softDeleteDiary）。
  Future<void> softDeleteDiaries(Iterable<String> diaryIds) =>
      _updateDiariesByIds(
        diaryIds,
        DiariesCompanion(
          isArchived: const Value<bool>(false),
          archivedAt: const Value<DateTime?>(null),
          isDeleted: const Value<bool>(true),
          deletedAt: Value<DateTime?>(DateTime.now()),
        ),
      );

  /// 批量从回收站恢复（撤销 [softDeleteDiaries]）。
  Future<void> restoreDiaries(Iterable<String> diaryIds) => _updateDiariesByIds(
    diaryIds,
    const DiariesCompanion(
      isArchived: Value<bool>(false),
      archivedAt: Value<DateTime?>(null),
      isDeleted: Value<bool>(false),
      deletedAt: Value<DateTime?>(null),
    ),
  );

  Future<void> _updateDiariesByIds(
    Iterable<String> diaryIds,
    DiariesCompanion values,
  ) async {
    final ids = diaryIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    await transaction(() async {
      for (final chunk in _chunked(ids)) {
        await (update(
          diaries,
        )..where((Diaries t) => t.diaryId.isIn(chunk))).write(values);
      }
    });
  }
}
