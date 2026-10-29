part of 'app_database.dart';

/// 局域网同步的顺序列表写入（规格 docs/lan_sync.md §6、§4.6 第 4 条）：书架、
/// 我的模板与手动日记本的书序。
///
/// - 输入：业务 id 列表（计划给出的最终顺序）；
/// - 副作用：把位置列重写为 0..n-1，只改有变化的行。
///
/// 规则：列表里的项按列表顺序；列表里没有的现有项（只在有写入被跳过时才会
/// 出现）按原来的相对顺序接在末尾；列表里有、库里没有的 id 忽略。“原来的
/// 相对顺序”与规范化读取的口径相同（`syncShelfOrder` / `syncTemplateOrder` /
/// `syncBookOrder`），写完之后两端再读出来就没有平手。
///
/// 与 `app_database_sync_writes.dart` 一样不各自开事务，由调用方放进同一个
/// 事务。
mixin _AppDatabaseSyncOrder on _$AppDatabase {
  /// 书架：全部日记本按 `sort_order`、同值按本地 id。
  Future<void> syncReorderShelf(List<String> ids) async {
    final rows = await customSelect(
      'SELECT id, notebook_id AS bid, sort_order AS pos FROM notebooks '
      'ORDER BY sort_order, id',
    ).get();
    await _syncRenumber(
      rows,
      ids,
      (localId, position) =>
          (update(notebooks)..where((t) => t.id.equals(localId))).write(
            NotebooksCompanion(sortOrder: Value(position)),
          ),
    );
  }

  /// 我的模板：只排用户模板（`builtin.*` 按内置顺序显示、不在列表里，位置
  /// 原样不动），按 `sort_order`、同值按本地 id。
  Future<void> syncReorderTemplates(List<String> ids) async {
    final rows = await customSelect(
      'SELECT id, template_id AS bid, sort_order AS pos FROM diary_templates '
      "WHERE template_id NOT LIKE '$builtInDiaryTemplateIdPrefix%' "
      'ORDER BY sort_order, id',
    ).get();
    await _syncRenumber(
      rows,
      ids,
      (localId, position) =>
          (update(diaryTemplates)..where((t) => t.id.equals(localId))).write(
            DiaryTemplatesCompanion(sortOrder: Value(position)),
          ),
    );
  }

  /// 书序：一本日记本的成员按 `position`、`added_at`、日记本地 id；日记已不在
  /// 的悬空关联行不参与（它们本来就不进清单）。日记本不存在时什么都不做。
  Future<void> syncReorderBook(String notebookId, List<String> ids) async {
    final notebook = await customSelect(
      'SELECT id FROM notebooks WHERE notebook_id = ?',
      variables: <Variable<Object>>[Variable.withString(notebookId)],
    ).getSingleOrNull();
    if (notebook == null) return;
    final notebookLocalId = _syncInt(notebook.data['id']);
    final rows = await customSelect(
      'SELECT dn.diary_id AS id, d.diary_id AS bid, dn.position AS pos '
      'FROM diary_notebooks dn JOIN diaries d ON d.id = dn.diary_id '
      'WHERE dn.notebook_id = ? ORDER BY dn.position, dn.added_at, dn.diary_id',
      variables: <Variable<Object>>[Variable.withInt(notebookLocalId)],
    ).get();
    await _syncRenumber(
      rows,
      ids,
      (diaryLocalId, position) =>
          (update(diaryNotebooks)..where(
                (t) =>
                    t.diaryId.equals(diaryLocalId) &
                    t.notebookId.equals(notebookLocalId),
              ))
              .write(DiaryNotebooksCompanion(position: Value(position))),
    );
  }

  /// [rows] 已按原顺序排好，列为 `id`（本地 id）、`bid`（业务 id）、`pos`。
  Future<void> _syncRenumber(
    List<QueryRow> rows,
    List<String> ids,
    Future<int> Function(int localId, int position) write,
  ) async {
    final byBusinessId = <String, QueryRow>{
      for (final row in rows) row.data['bid'] as String: row,
    };
    final ordered = <QueryRow>[];
    final placed = <String>{};
    for (final id in ids) {
      final row = byBusinessId[id];
      if (row != null && placed.add(id)) ordered.add(row);
    }
    for (final row in rows) {
      if (placed.add(row.data['bid'] as String)) ordered.add(row);
    }
    for (var position = 0; position < ordered.length; position++) {
      final row = ordered[position];
      if (_syncInt(row.data['pos']) == position) continue;
      await write(_syncInt(row.data['id']), position);
    }
  }
}
