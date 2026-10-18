part of 'app_database.dart';

/// 草稿箱读写。
///
/// 输入：编辑页整理好的草稿 JSON 与标题、纯文本镜像；输出：drift watch 流与
/// 草稿业务 id。删除是硬删除——草稿没有回收站，撤销由调用方持有被删的整行、
/// 经 [restoreDiaryDrafts] 原样写回。
mixin _AppDatabaseDraftOps on _$AppDatabase {
  /// 全部草稿：最近编辑的在前；同一时刻按本地 id 倒序，保证顺序稳定。
  Stream<List<DiaryDraftRow>> watchDiaryDrafts() {
    return (select(diaryDrafts)..orderBy(_draftOrder)).watch();
  }

  /// 最近编辑的 [limit] 份草稿，供新建入口的草稿选择面板一次性读取。
  Future<List<DiaryDraftRow>> getRecentDiaryDrafts(int limit) {
    return (select(diaryDrafts)
          ..orderBy(_draftOrder)
          ..limit(limit))
        .get();
  }

  Stream<int> watchDiaryDraftCount() {
    final count = diaryDrafts.id.count();
    return (selectOnly(diaryDrafts)..addColumns(<Expression<Object>>[count]))
        .map((row) => row.read(count)!)
        .watchSingle();
  }

  Future<int> countDiaryDrafts() async {
    final count = diaryDrafts.id.count();
    final row = await (selectOnly(
      diaryDrafts,
    )..addColumns(<Expression<Object>>[count])).getSingle();
    return row.read(count)!;
  }

  Future<DiaryDraftRow?> getDiaryDraft(String draftId) {
    return (select(
      diaryDrafts,
    )..where((t) => t.draftId.equals(draftId))).getSingleOrNull();
  }

  /// 写入一份草稿并返回它的业务 id。
  ///
  /// [draftId] 为 null 时新建；不为 null 时按它更新，行已不存在（例如在别处
  /// 被删）则以同一 id 重新插入，编辑页手里的内容不会因此丢失。`createdAt`
  /// 只在插入时写，之后只刷新内容与 `updatedAt`。
  Future<String> saveDiaryDraft({
    String? draftId,
    required String title,
    required String contentText,
    required String payload,
    DateTime? now,
  }) async {
    final id = draftId ?? _newBusinessUuid();
    final timestamp = now ?? DateTime.now();
    await into(diaryDrafts).insert(
      DiaryDraftsCompanion.insert(
        draftId: id,
        title: Value(title),
        contentText: Value(contentText),
        payload: payload,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      onConflict: DoUpdate(
        (_) => DiaryDraftsCompanion(
          title: Value(title),
          contentText: Value(contentText),
          payload: Value(payload),
          updatedAt: Value(timestamp),
        ),
        target: <Column<Object>>[diaryDrafts.draftId],
      ),
    );
    return id;
  }

  Future<void> deleteDiaryDrafts(Iterable<String> draftIds) async {
    final ids = draftIds.toSet();
    if (ids.isEmpty) return;
    await (delete(diaryDrafts)..where((t) => t.draftId.isIn(ids))).go();
  }

  /// 撤销删除：把调用方持有的整行原样写回（含本地 id 与时间戳），列表里回到
  /// 原来的位置。
  Future<void> restoreDiaryDrafts(Iterable<DiaryDraftRow> rows) async {
    await batch((batch) {
      batch.insertAll(
        diaryDrafts,
        rows.map((row) => row.toCompanion(false)),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  static final List<OrderClauseGenerator<$DiaryDraftsTable>> _draftOrder =
      <OrderClauseGenerator<$DiaryDraftsTable>>[
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ];
}
