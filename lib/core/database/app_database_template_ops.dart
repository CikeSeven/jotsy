part of 'app_database.dart';

/// 日记模板读写。
///
/// 输入：模板模型整理好的 payload JSON 与名称镜像；输出：drift watch 流与模板
/// 业务 id。删除是硬删除，撤销由调用方持有被删的整行、经
/// [restoreDiaryTemplates] 原样写回。
mixin _AppDatabaseTemplateOps on _$AppDatabase {
  /// 全部用户模板：按手动排序，同序时按本地 id，保证顺序稳定。
  Stream<List<DiaryTemplateRow>> watchDiaryTemplates() {
    return (select(diaryTemplates)..orderBy(_templateOrder)).watch();
  }

  Future<List<DiaryTemplateRow>> getDiaryTemplates() {
    return (select(diaryTemplates)..orderBy(_templateOrder)).get();
  }

  Future<DiaryTemplateRow?> getDiaryTemplate(String templateId) {
    return (select(
      diaryTemplates,
    )..where((t) => t.templateId.equals(templateId))).getSingleOrNull();
  }

  Future<int> countDiaryTemplates() async {
    final count = diaryTemplates.id.count();
    final row = await (selectOnly(
      diaryTemplates,
    )..addColumns(<Expression<Object>>[count])).getSingle();
    return row.read(count)!;
  }

  /// 写入一个模板并返回它的业务 id。
  ///
  /// [templateId] 为 null 时新建，排在现有模板之后；不为 null 时按它更新，
  /// 只刷新名称、payload 与 `updatedAt`，手动排序与创建时间保持不变。行已
  /// 不存在（例如编辑途中经备份恢复被替换）时以同一 id 重新插入到最后。
  Future<String> saveDiaryTemplate({
    String? templateId,
    required String name,
    required String payload,
    DateTime? now,
  }) {
    return transaction(() async {
      final id = templateId ?? _newBusinessUuid();
      final timestamp = now ?? DateTime.now();
      final nextOrder = await _nextTemplateSortOrder();
      await into(diaryTemplates).insert(
        DiaryTemplatesCompanion.insert(
          templateId: id,
          name: Value(name),
          payload: payload,
          sortOrder: Value(nextOrder),
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
        onConflict: DoUpdate(
          (_) => DiaryTemplatesCompanion(
            name: Value(name),
            payload: Value(payload),
            updatedAt: Value(timestamp),
          ),
          target: <Column<Object>>[diaryTemplates.templateId],
        ),
      );
      return id;
    });
  }

  Future<void> deleteDiaryTemplates(Iterable<String> templateIds) async {
    final ids = templateIds.toSet();
    if (ids.isEmpty) return;
    await (delete(diaryTemplates)..where((t) => t.templateId.isIn(ids))).go();
  }

  /// 撤销删除：把调用方持有的整行原样写回（含本地 id、排序与时间戳），列表
  /// 里回到原来的位置。
  Future<void> restoreDiaryTemplates(Iterable<DiaryTemplateRow> rows) async {
    await batch((batch) {
      batch.insertAll(
        diaryTemplates,
        rows.map((row) => row.toCompanion(false)),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// 按 [orderedIds] 的先后重写手动排序；不在列表里的模板（例如拖动途中经
  /// 备份合并新增的）接在后面，保持原有相对顺序。
  Future<void> reorderDiaryTemplates(List<String> orderedIds) {
    return transaction(() async {
      final rows = await getDiaryTemplates();
      final position = <String, int>{
        for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
      };
      // List.sort 不保证稳定：同为“不在列表里”的行按原有顺序（rows 的下标）
      // 决出先后。
      final original = <String, int>{
        for (var i = 0; i < rows.length; i++) rows[i].templateId: i,
      };
      final sorted = rows.toList()
        ..sort((a, b) {
          final pa = position[a.templateId] ?? orderedIds.length;
          final pb = position[b.templateId] ?? orderedIds.length;
          if (pa != pb) return pa.compareTo(pb);
          return original[a.templateId]!.compareTo(original[b.templateId]!);
        });
      for (var i = 0; i < sorted.length; i++) {
        if (sorted[i].sortOrder == i) continue;
        await (update(diaryTemplates)..where((t) => t.id.equals(sorted[i].id)))
            .write(DiaryTemplatesCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<int> _nextTemplateSortOrder() async {
    final maxOrder = diaryTemplates.sortOrder.max();
    final row = await (selectOnly(
      diaryTemplates,
    )..addColumns(<Expression<Object>>[maxOrder])).getSingle();
    final current = row.read(maxOrder);
    return current == null ? 0 : current + 1;
  }

  static final List<OrderClauseGenerator<$DiaryTemplatesTable>> _templateOrder =
      <OrderClauseGenerator<$DiaryTemplatesTable>>[
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.id),
      ];
}
