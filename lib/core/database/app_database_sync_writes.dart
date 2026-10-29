part of 'app_database.dart';

/// 局域网同步的数据库写入（规格 docs/lan_sync.md §6；读取见
/// `app_database_sync_ops.dart`）。
///
/// - 输入：同步层由规范记录还原出的列值（各表的 Companion，业务 id；标签按
///   名称）；
/// - 输出：无（成员关系写入返回是否写成）；
/// - 副作用：按原值写各表、删除时手动清理关联行。
///
/// 约定：
/// - 这里的方法**不各自开事务**，由调用方（`SyncApplier`）把一侧计划的全部
///   写入放进同一个事务：任一条失败整批回滚。复用的 [hardDeleteDiary] /
///   [deleteTag] 自带的事务在外层事务里是保存点，不影响这一点；
/// - 不调用 UI 写库函数（它们会改写 `updatedAt`、取消归档 / 删除标记），列值
///   原样落库；也不调用 `deleteNotebook` / `mergeNotebook`：它们的子本上提会
///   覆盖另一台设备上的移动，层级以计划里精确的 `parentId` 为准；
/// - 删除的关联清理与现有删除路径一致：日记复用 [hardDeleteDiary]（标签关联、
///   成员关系、留言、纪念日关联），标签复用 [deleteTag]（标签关联），日记本
///   清掉成员关系；模板删除不动日记本定义（规格 §6）。
mixin _AppDatabaseSyncWrites
    on _$AppDatabase, _AppDatabaseTagOps, _AppDatabaseDiaryWrites {
  /// 按业务 id 插入或按原值更新一篇日记，再按名称重写它的标签关联。
  ///
  /// 标签按名称精确匹配（不去空白：规范名就是库里的原名）；没有的以
  /// [newTagColor] 新建，颜色随后由同一计划里 `tag:` 记录的写入定下。已有
  /// 标签的颜色从不在这里改动。
  Future<void> syncWriteDiary(
    DiariesCompanion row,
    Iterable<String> tagNames, {
    required int newTagColor,
  }) async {
    final existing = await _syncDiaryLocalId(row.diaryId.value);
    final localId = existing ?? await into(diaries).insert(row);
    if (existing != null) {
      await (update(diaries)..where((t) => t.id.equals(existing))).write(row);
    }
    final tagIds = <int>{};
    for (final name in tagNames) {
      // 空名不可能来自规范记录（标签表要求至少 1 个字符），防御性跳过。
      if (name.isEmpty) continue;
      tagIds.add(await _syncTagIdFor(name, newTagColor));
    }
    await _replaceDiaryTags(localId, tagIds.toList());
  }

  /// 彻底删除日记，清理范围与 [hardDeleteDiary] 相同（就是它）。
  Future<void> syncDeleteDiary(String diaryId) => hardDeleteDiary(diaryId);

  /// 标签原地改名：本地 id 不变（编辑器与 `tagOrderRaw` 持有本地 id），颜色
  /// 设为计划给出的值。返回是否找到了旧名。
  Future<bool> syncRenameTag({
    required String from,
    required String to,
    required int color,
  }) async {
    final count = await (update(tags)..where((t) => t.name.equals(from))).write(
      TagsCompanion(name: Value(to), color: Value(color)),
    );
    return count > 0;
  }

  /// 按名称插入标签或改写颜色。
  Future<void> syncWriteTag(String name, int color) async {
    final existing = await (select(
      tags,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing == null) {
      await into(tags).insert(TagsCompanion.insert(name: name, color: color));
    } else if (existing.color != color) {
      await (update(tags)..where((t) => t.id.equals(existing.id))).write(
        TagsCompanion(color: Value(color)),
      );
    }
  }

  /// 删除标签与它的关联（[deleteTag]）。
  Future<void> syncDeleteTag(String name) async {
    final existing = await (select(
      tags,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) await deleteTag(existing.id);
  }

  /// 按业务 id 插入或按原值更新日记本（`parent_id` 精确取自 [row]）。
  ///
  /// 新行的书架位置放在最后，随后由 orderList `shelf` 的写入重排。智能本
  /// 改成手动本时先清掉它残留的关联行：智能本的关联行不进清单，留着会在
  /// 写入后凭空变成成员，与计划不符（规格 §4.6 第 5 条）。
  Future<void> syncWriteNotebook(NotebooksCompanion row) async {
    final existing =
        await (select(notebooks)
              ..where((t) => t.notebookId.equals(row.notebookId.value)))
            .getSingleOrNull();
    if (existing == null) {
      final order = await _syncNextValue('notebooks', 'sort_order');
      await into(notebooks).insert(row.copyWith(sortOrder: Value(order)));
      return;
    }
    if (!existing.acceptsManualEntries &&
        row.kind.value == NotebookKind.manual.name) {
      await (delete(
        diaryNotebooks,
      )..where((t) => t.notebookId.equals(existing.id))).go();
    }
    await (update(
      notebooks,
    )..where((t) => t.id.equals(existing.id))).write(row);
  }

  /// 删除日记本与它的关联行；子本不提升（它们的 `parentId` 由计划给出）。
  Future<void> syncDeleteNotebook(String notebookId) async {
    final existing = await (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
    if (existing == null) return;
    await (delete(
      diaryNotebooks,
    )..where((t) => t.notebookId.equals(existing.id))).go();
    await (delete(notebooks)..where((t) => t.id.equals(existing.id))).go();
  }

  /// 写入一条成员关系（新行排在书末，随后由 `book:` 列表重排）。
  ///
  /// 日记或日记本不存在（它的写入被跳过）、或日记本不是手动本时不写并返回
  /// false：智能本从不写关联行。
  Future<bool> syncWriteMembership({
    required String notebookId,
    required String diaryId,
    required String? chapterId,
    required DateTime addedAt,
  }) async {
    final diary = await _syncDiaryLocalId(diaryId);
    final notebook = await (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
    if (diary == null || notebook == null || !notebook.acceptsManualEntries) {
      return false;
    }
    final existing =
        await (select(diaryNotebooks)..where(
              (t) => t.diaryId.equals(diary) & t.notebookId.equals(notebook.id),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (update(diaryNotebooks)..where(
            (t) => t.diaryId.equals(diary) & t.notebookId.equals(notebook.id),
          ))
          .write(
            DiaryNotebooksCompanion(
              chapterId: Value(chapterId),
              addedAt: Value(addedAt),
            ),
          );
      return true;
    }
    final position = await _syncNextValue(
      'diary_notebooks',
      'position',
      where: 'notebook_id = ${notebook.id}',
    );
    await into(diaryNotebooks).insert(
      DiaryNotebooksCompanion.insert(
        diaryId: diary,
        notebookId: notebook.id,
        chapterId: Value(chapterId),
        position: Value(position),
        addedAt: addedAt,
      ),
    );
    return true;
  }

  Future<void> syncDeleteMembership({
    required String notebookId,
    required String diaryId,
  }) async {
    final diary = await _syncDiaryLocalId(diaryId);
    final notebook = await (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
    if (diary == null || notebook == null) return;
    await (delete(diaryNotebooks)..where(
          (t) => t.diaryId.equals(diary) & t.notebookId.equals(notebook.id),
        ))
        .go();
  }

  Future<void> syncWriteComment(DiaryCommentsCompanion row) async {
    final count = await (update(
      diaryComments,
    )..where((t) => t.commentId.equals(row.commentId.value))).write(row);
    if (count == 0) await into(diaryComments).insert(row);
  }

  Future<void> syncDeleteComment(String commentId) =>
      (delete(diaryComments)..where((t) => t.commentId.equals(commentId))).go();

  /// 新模板排在最后，随后由 orderList `templates` 的写入重排（内置模板不在
  /// 列表里，位置不影响显示）。
  Future<void> syncWriteTemplate(DiaryTemplatesCompanion row) async {
    final count = await (update(
      diaryTemplates,
    )..where((t) => t.templateId.equals(row.templateId.value))).write(row);
    if (count > 0) return;
    final order = await _syncNextValue('diary_templates', 'sort_order');
    await into(diaryTemplates).insert(row.copyWith(sortOrder: Value(order)));
  }

  /// 只删模板这一行：指向它的日记本默认模板保持原样（应用读取时找不到即
  /// 回落，规格 §6）。
  Future<void> syncDeleteTemplate(String templateId) => (delete(
    diaryTemplates,
  )..where((t) => t.templateId.equals(templateId))).go();

  Future<void> syncWriteAnniversary(AnniversariesCompanion row) async {
    final count =
        await (update(anniversaries)
              ..where((t) => t.anniversaryId.equals(row.anniversaryId.value)))
            .write(row);
    if (count == 0) await into(anniversaries).insert(row);
  }

  Future<void> syncDeleteAnniversary(String anniversaryId) => (delete(
    anniversaries,
  )..where((t) => t.anniversaryId.equals(anniversaryId))).go();

  Future<void> syncWriteDayMood(DayMoodsCompanion row) =>
      into(dayMoods).insertOnConflictUpdate(row);

  Future<void> syncDeleteDayMood(String day) =>
      (delete(dayMoods)..where((t) => t.day.equals(day))).go();

  Future<int?> _syncDiaryLocalId(String diaryId) async {
    final row = await customSelect(
      'SELECT id FROM diaries WHERE diary_id = ?',
      variables: <Variable<Object>>[Variable.withString(diaryId)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{diaries},
    ).getSingleOrNull();
    return row == null ? null : _syncInt(row.data['id']);
  }

  /// 按名称取标签 id，没有就以 [color] 新建。
  Future<int> _syncTagIdFor(String name, int color) async {
    final existing = await (select(
      tags,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(tags).insert(TagsCompanion.insert(name: name, color: color));
  }

  /// `MAX(column) + 1`（空表为 0）。[table] / [column] / [where] 只来自本文件
  /// 的常量与整数本地 id，不拼接外部输入。
  Future<int> _syncNextValue(
    String table,
    String column, {
    String? where,
  }) async {
    final row = await customSelect(
      'SELECT MAX($column) AS m FROM $table'
      '${where == null ? '' : ' WHERE $where'}',
    ).getSingle();
    final max = row.data['m'];
    return max == null ? 0 : _syncInt(max) + 1;
  }
}
