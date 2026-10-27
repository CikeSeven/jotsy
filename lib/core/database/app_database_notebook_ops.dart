part of 'app_database.dart';

/// 日记本本身的读写：书架列表、增改、排序、删除与撤销、合并。
///
/// 输入输出一律是业务 id（`notebookId`）；不存在的 id 抛 [ArgumentError]。
/// 删除返回 [NotebookDeletion] 快照，撤销经 [restoreNotebookDeletion] 原子写回。
/// 成员关系的增删见 `_AppDatabaseNotebookEntryOps`，嵌套（上级、层级修复）见
/// `_AppDatabaseNotebookTreeOps`。
mixin _AppDatabaseNotebookOps
    on
        _$AppDatabase,
        _AppDatabaseNotebookEntryOps,
        _AppDatabaseNotebookTreeOps {
  /// 书架上的全部日记本：置顶的在前，再按手动顺序，同序按本地 id 保证稳定。
  Stream<List<NotebookRow>> watchNotebooks() {
    return (select(notebooks)..orderBy(_notebookShelfOrder)).watch();
  }

  Future<List<NotebookRow>> getNotebooks() {
    return (select(notebooks)..orderBy(_notebookShelfOrder)).get();
  }

  Future<NotebookRow?> getNotebook(String notebookId) {
    return (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
  }

  Stream<NotebookRow?> watchNotebook(String notebookId) {
    return (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).watchSingleOrNull();
  }

  /// 手动日记本 id → 篇数，口径与本子里的日记列表（`DiaryNotebookScope`）
  /// 一致：不算回收站与归档里的日记；普通本子不算私密日记（同时在某本私密
  /// 本子里的），否则书架上的篇数会透露私密日记的存在、也与列表对不上；私密
  /// 本子（含随上级私密的）自己算全部成员。只算本子自己收录的，不含子本。没有这类日记的本子（含全部智能本）不在结果里，读取
  /// 方按 0 处理。
  Stream<Map<String, int>> watchManualNotebookEntryCounts() {
    return customSelect(
      '''
SELECT n.notebook_id AS notebook_id, COUNT(*) AS entry_count
FROM diary_notebooks dn
INNER JOIN notebooks n ON n.id = dn.notebook_id
INNER JOIN diaries d ON d.id = dn.diary_id
WHERE n.kind = ? AND d.is_deleted = 0 AND d.is_archived = 0
  AND (n.id IN ($_privateNotebookIdsSql)
    OR ${_privateDiaryExclusionSql('d.id')})
GROUP BY n.notebook_id
''',
      variables: <Variable<Object>>[Variable<String>(NotebookKind.manual.name)],
      readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
        notebooks,
        diaryNotebooks,
        diaries,
      },
    ).watch().map(
      (rows) => <String, int>{
        for (final row in rows)
          row.read<String>('notebook_id'): row.read<int>('entry_count'),
      },
    );
  }

  /// 新建日记本并返回业务 id，排在书架最后。名称去首尾空白后须为 1–60 个
  /// 字符，否则抛 [ArgumentError]。智能日记本一律存成 normal（见表注释）。
  /// [parentId] 为上级日记本（null 为顶层），不合法时同样抛 [ArgumentError]
  /// （见 [NotebookHierarchy.problemFor]）。
  Future<String> createNotebook({
    required String name,
    NotebookKind kind = NotebookKind.manual,
    NotebookVisibility visibility = NotebookVisibility.normal,
    NotebookPayload payload = NotebookPayload.defaults,
    String? parentId,
  }) {
    final normalizedName = _normalizeNotebookName(name);
    return transaction(() async {
      if (parentId != null) {
        _checkNotebookParent(await notebookHierarchy(), null, parentId);
      }
      final id = _newBusinessUuid();
      final now = DateTime.now();
      await into(notebooks).insert(
        NotebooksCompanion.insert(
          notebookId: id,
          name: normalizedName,
          kind: Value(kind.name),
          visibility: Value(
            kind == NotebookKind.manual
                ? visibility.name
                : NotebookVisibility.normal.name,
          ),
          payload: Value(payload.encode()),
          parentId: Value(parentId),
          sortOrder: Value(await _nextNotebookSortOrder()),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    });
  }

  /// 修改日记本，传 null 的项保持不变，并刷新 `updatedAt`。
  ///
  /// 非手动日记本的可见性一律写成 normal。传入 [payload] 时，本子里指向已不在
  /// 章节列表中的 `chapter_id` 在同一事务里清空，这些日记回到“未分章”。
  /// [parentId] 给出时（`Value(null)` 为移到顶层）同一事务里经
  /// [moveNotebook] 改上级，不合法时整次修改都不写入。
  Future<void> updateNotebook(
    String notebookId, {
    String? name,
    NotebookVisibility? visibility,
    NotebookPayload? payload,
    bool? isPinned,
    bool? isClosed,
    Value<String?> parentId = const Value<String?>.absent(),
  }) {
    final normalizedName = name == null ? null : _normalizeNotebookName(name);
    return transaction(() async {
      if (parentId.present) {
        await moveNotebook(notebookId, parentId.value);
      }
      final row = await _requireNotebookRow(notebookId);
      final nextVisibility = row.acceptsManualEntries
          ? visibility
          : NotebookVisibility.normal;
      await (update(notebooks)..where((t) => t.id.equals(row.id))).write(
        NotebooksCompanion(
          name: Value.absentIfNull(normalizedName),
          visibility: Value.absentIfNull(nextVisibility?.name),
          payload: Value.absentIfNull(payload?.encode()),
          isPinned: Value.absentIfNull(isPinned),
          isClosed: Value.absentIfNull(isClosed),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (payload != null) {
        final chapterIds = payload.chapterIds;
        await (update(diaryNotebooks)..where(
              (t) =>
                  t.notebookId.equals(row.id) &
                  t.chapterId.isNotNull() &
                  t.chapterId.isNotIn(chapterIds),
            ))
            .write(const DiaryNotebooksCompanion(chapterId: Value(null)));
      }
    });
  }

  /// 按 [orderedNotebookIds] 的先后重写书架顺序 0..n-1；不在列表里的日记本
  /// （例如拖动途中经备份合并新增的）接在后面，保持原有相对顺序。置顶仍优先
  /// 于手动顺序。
  Future<void> reorderNotebooks(List<String> orderedNotebookIds) {
    return transaction(() async {
      final rows = await (select(
        notebooks,
      )..orderBy(_notebookManualOrder)).get();
      final position = <String, int>{
        for (var i = 0; i < orderedNotebookIds.length; i++)
          orderedNotebookIds[i]: i,
      };
      // List.sort 不保证稳定：同为“不在列表里”的行按原有顺序决出先后。
      final original = <int, int>{
        for (var i = 0; i < rows.length; i++) rows[i].id: i,
      };
      final sorted = rows.toList()
        ..sort((a, b) {
          final pa = position[a.notebookId] ?? orderedNotebookIds.length;
          final pb = position[b.notebookId] ?? orderedNotebookIds.length;
          if (pa != pb) return pa.compareTo(pb);
          return original[a.id]!.compareTo(original[b.id]!);
        });
      for (var i = 0; i < sorted.length; i++) {
        if (sorted[i].sortOrder == i) continue;
        await (update(notebooks)..where((t) => t.id.equals(sorted[i].id)))
            .write(NotebooksCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// 删除日记本（硬删除）并返回撤销所需的快照，一个事务内完成。
  ///
  /// 子本不删，整棵子树提到这本的上级下（顶层的就到顶层）。默认只删本子与
  /// 关联行，日记本身不动；[trashDiaries] 为 true 时把本子里
  /// 尚未删除的日记一并移进回收站（语义同 `softDeleteDiary`：标记删除并取消
  /// 归档；不刷新 `updatedAt`，撤销后列表顺序不变）。智能日记本没有关联行，
  /// 不会删除任何日记；随之进回收站的只有本子自己收录的，不含子本里的。
  Future<NotebookDeletion> deleteNotebook(
    String notebookId, {
    bool trashDiaries = false,
  }) {
    return transaction(() async {
      final row = await _requireNotebookRow(notebookId);
      final entries = await _entriesInOrder(row.id);
      final trashed = <String>[];
      final archivedAt = <String, DateTime?>{};
      if (trashDiaries && entries.isNotEmpty) {
        final memberQuery = selectOnly(diaryNotebooks)
          ..addColumns(<Expression<Object>>[diaryNotebooks.diaryId])
          ..where(diaryNotebooks.notebookId.equals(row.id));
        Expression<bool> live($DiariesTable t) =>
            t.isDeleted.equals(false) & t.id.isInQuery(memberQuery);
        for (final diary in await (select(diaries)..where(live)).get()) {
          trashed.add(diary.diaryId);
          if (diary.isArchived) archivedAt[diary.diaryId] = diary.archivedAt;
        }
        await (update(diaries)..where(live)).write(
          DiariesCompanion(
            isArchived: const Value(false),
            archivedAt: const Value(null),
            isDeleted: const Value(true),
            deletedAt: Value(DateTime.now()),
          ),
        );
      }
      final children = await _liftNotebookChildren(row);
      await (delete(
        diaryNotebooks,
      )..where((t) => t.notebookId.equals(row.id))).go();
      await (delete(notebooks)..where((t) => t.id.equals(row.id))).go();
      return NotebookDeletion._(
        Map<String, DateTime?>.unmodifiable(archivedAt),
        notebook: row,
        entries: List<DiaryNotebookRow>.unmodifiable(entries),
        trashedDiaryIds: List<String>.unmodifiable(trashed),
        childIds: List<String>.unmodifiable(children),
      );
    });
  }

  /// 撤销 [deleteNotebook]，一个事务内完成。
  ///
  /// 日记本按原本地 id 写回：`notebooks.id` 是 AUTOINCREMENT，删掉的 id 不会
  /// 被新行复用，写回不会撞上别的本子，快照里的关联行也就仍然指得对。日记已
  /// 被彻底删除的关联行丢弃；随本子移进回收站的日记若仍在回收站则恢复，原来
  /// 归档的回到归档（不刷新 `updatedAt`）。已被用户另行恢复或彻底删除的不动。
  /// 删除时提上去的子本挪回来（撤销窗口里被另行移动过的不动）；上级在此期间
  /// 被删掉的，修复层级时回到顶层。
  Future<void> restoreNotebookDeletion(NotebookDeletion deletion) {
    return transaction(() async {
      await into(
        notebooks,
      ).insert(deletion.notebook, mode: InsertMode.insertOrReplace);
      final existing = await _existingDiaryLocalIds(
        deletion.entries.map((row) => row.diaryId),
      );
      await batch((batch) {
        batch.insertAll(diaryNotebooks, <DiaryNotebookRow>[
          for (final row in deletion.entries)
            if (existing.contains(row.diaryId)) row,
        ], mode: InsertMode.insertOrIgnore);
      });
      for (final diaryId in deletion.trashedDiaryIds) {
        final wasArchived = deletion._archivedBeforeTrash.containsKey(diaryId);
        await (update(diaries)..where(
              (t) => t.diaryId.equals(diaryId) & t.isDeleted.equals(true),
            ))
            .write(
              DiariesCompanion(
                isDeleted: const Value(false),
                deletedAt: const Value(null),
                isArchived: Value(wasArchived),
                archivedAt: Value(deletion._archivedBeforeTrash[diaryId]),
              ),
            );
      }
      await _restoreNotebookChildren(
        deletion.notebook.notebookId,
        deletion.notebook.parentId,
        deletion.childIds,
      );
    });
  }

  /// 把手动日记本 [sourceId] 并入 [targetId] 后删除 [sourceId]，一个事务内完成。
  ///
  /// 目标本里已有的日记跳过；搬过去的按原成书顺序接在目标本最后、未分章
  /// （两本的章节互不相干），保留加入时间。[sourceId] 的子本改挂到目标本下
  /// （超出层数的回到顶层）。任一方不是手动本或两者相同时抛 [ArgumentError]。
  Future<void> mergeNotebook({
    required String sourceId,
    required String targetId,
  }) {
    if (sourceId == targetId) {
      throw ArgumentError.value(targetId, 'targetId', '不能并入自己');
    }
    return transaction(() async {
      final source = await _requireManualNotebook(sourceId);
      final target = await _requireManualNotebook(targetId);
      final present = await _entryDiaryIds(target.id);
      var position = await _nextEntryPosition(target.id);
      final moved = <DiaryNotebooksCompanion>[
        for (final row in await _entriesInOrder(source.id))
          if (!present.contains(row.diaryId))
            DiaryNotebooksCompanion.insert(
              diaryId: row.diaryId,
              notebookId: target.id,
              position: Value(position++),
              addedAt: row.addedAt,
            ),
      ];
      await batch((batch) => batch.insertAll(diaryNotebooks, moved));
      await _moveChildrenForMerge(source, target);
      await (delete(
        diaryNotebooks,
      )..where((t) => t.notebookId.equals(source.id))).go();
      await (delete(notebooks)..where((t) => t.id.equals(source.id))).go();
      await repairNotebookHierarchy();
    });
  }

  /// 把智能日记本转为普通日记本，一个事务内完成：类型改为手动、payload 去掉
  /// 规则，并按 [diaryIds] 的顺序把这些日记收进来（未分章）。
  ///
  /// [diaryIds] 由调用方按转换前的规则现算（`getActiveDiaryIds` + 智能范围，
  /// 只含未归档、未删除、非私密的日记）；不存在的 id 与重复 id 跳过。本子不是
  /// 智能日记本时抛 [ArgumentError]，不改动任何数据。返回收进的篇数。
  Future<int> convertSmartNotebookToManual(
    String notebookId,
    List<String> diaryIds,
  ) {
    return transaction(() async {
      final row = await _requireNotebookRow(notebookId);
      if (row.kind != NotebookKind.smart.name) {
        throw ArgumentError.value(notebookId, 'notebookId', '不是智能日记本');
      }
      await (update(notebooks)..where((t) => t.id.equals(row.id))).write(
        NotebooksCompanion(
          kind: Value(NotebookKind.manual.name),
          visibility: Value(NotebookVisibility.normal.name),
          payload: Value(row.parsedPayload.copyWith(clearRules: true).encode()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final local = await _diaryLocalIds(diaryIds);
      // 智能本没有关联行；仍按已有成员去重，防御不一致的旧数据。
      final present = await _entryDiaryIds(row.id);
      var position = await _nextEntryPosition(row.id);
      final now = DateTime.now();
      final rows = <DiaryNotebooksCompanion>[
        for (final diaryId in diaryIds)
          if (local[diaryId] case final id? when present.add(id))
            DiaryNotebooksCompanion.insert(
              diaryId: id,
              notebookId: row.id,
              position: Value(position++),
              addedAt: now,
            ),
      ];
      await batch((batch) => batch.insertAll(diaryNotebooks, rows));
      return rows.length;
    });
  }

  String _normalizeNotebookName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 60) {
      throw ArgumentError.value(name, 'name', '日记本名称须为 1–60 个字符');
    }
    return normalized;
  }

  static final List<OrderClauseGenerator<$NotebooksTable>> _notebookShelfOrder =
      <OrderClauseGenerator<$NotebooksTable>>[
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.id),
      ];

  /// 不看置顶的手动顺序：重排只改 `sort_order`，置顶本的手动位置也要保留。
  static final List<OrderClauseGenerator<$NotebooksTable>>
  _notebookManualOrder = <OrderClauseGenerator<$NotebooksTable>>[
    (t) => OrderingTerm.asc(t.sortOrder),
    (t) => OrderingTerm.asc(t.id),
  ];
}

/// [AppDatabase.deleteNotebook] 的撤销快照：被删的日记本行、它的全部关联行，
/// 以及随它移进回收站的日记业务 id。只由删除产生，原样交给
/// [AppDatabase.restoreNotebookDeletion]。
@immutable
class NotebookDeletion {
  // 私有字段用位置参数：命名参数不能直接初始化私有字段（新语法 drift 的
  // 代码生成器还解析不了）。
  const NotebookDeletion._(
    this._archivedBeforeTrash, {
    required this.notebook,
    required this.entries,
    required this.trashedDiaryIds,
    this.childIds = const <String>[],
  });

  final NotebookRow notebook;

  /// 被删的关联行，按成书顺序。
  final List<DiaryNotebookRow> entries;

  /// 随本子移进回收站的日记（`trashDiaries: true` 时才有）。
  final List<String> trashedDiaryIds;

  /// 删除时提到上一层的直接子本，撤销时挪回来。
  final List<String> childIds;

  /// 移进回收站前处于归档的日记 → 原归档时间，撤销时放回归档。
  final Map<String, DateTime?> _archivedBeforeTrash;
}
