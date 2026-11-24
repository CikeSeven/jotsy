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

  /// 把手动日记本 [sourceId] 的整个目录（[chapterId] 为 null）或单个章节
  /// （[chapterId] 非空）整体转移到它的手动子孙日记本 [targetId]，一个事务内完成。
  ///
  /// - 章节：移出的章节接在目标本现有章节之后；若目标本已有同 id 章节，为移入
  ///   章节生成新 id 并同步更新对应日记的 `chapter_id`。
  /// - 日记：按目录页口径（含归档、不含回收站，遵守私密规则）取可见成员，按原
  ///   成书顺序（各章按章节先后、章内按 position，最后未分章）接在目标本末尾，
  ///   保留章节归属与加入时间，并从源本移出。已在目标本里的日记只从源本移出；
  ///   若它在目标本原本未分章而源本里有章节，一并归入搬入后的该章，否则保留
  ///   目标本原有章节。
  /// - 源本残留的悬空 `chapter_id`（如回收站或普通本不可见的私密日记）在同一
  ///   事务里清成未分章。
  ///
  /// 两者相同、任一方不存在或非手动本、目标不是源本子孙，或指定的 [chapterId]
  /// 不存在时抛 [ArgumentError]，不改动任何数据。
  Future<NotebookContentsTransferResult> transferNotebookContentsToChild({
    required String sourceId,
    required String targetId,
    String? chapterId,
  }) async {
    if (sourceId == targetId) {
      throw ArgumentError.value(targetId, 'targetId', '不能转移到同一个日记本');
    }
    return transaction(() async {
      final source = await _requireManualNotebook(sourceId);
      final target = await _requireManualNotebook(targetId);
      final hierarchy = await notebookHierarchy();
      if (!hierarchy.descendantsOf(sourceId).contains(targetId)) {
        throw ArgumentError.value(targetId, 'targetId', '目标不是当前日记本的子日记本');
      }
      final sourcePayload = source.parsedPayload;
      final targetPayload = target.parsedPayload;

      final List<NotebookChapter> movingChapters;
      final List<NotebookChapter> remainingSourceChapters;
      if (chapterId == null) {
        movingChapters = sourcePayload.chapters;
        remainingSourceChapters = const <NotebookChapter>[];
      } else {
        NotebookChapter? found;
        final remaining = <NotebookChapter>[];
        for (final chapter in sourcePayload.chapters) {
          if (chapter.id == chapterId) {
            found = chapter;
          } else {
            remaining.add(chapter);
          }
        }
        if (found == null) {
          throw ArgumentError.value(chapterId, 'chapterId', '章节不存在');
        }
        movingChapters = <NotebookChapter>[found];
        remainingSourceChapters = remaining;
      }

      // 为移入目标本的章节分配最终 id（不与目标本已有章节撞车时保持原 id）。
      final targetValidChaptersBefore = targetPayload.chapterIds;
      final usedIds = <String>{...targetValidChaptersBefore};
      final chapterIdMap = <String, String>{};
      final appendedChapters = <NotebookChapter>[];
      for (final chapter in movingChapters) {
        var nextId = chapter.id;
        while (!usedIds.add(nextId)) {
          nextId = NotebookChapter.newId();
        }
        chapterIdMap[chapter.id] = nextId;
        appendedChapters.add(
          nextId == chapter.id
              ? chapter
              : NotebookChapter(id: nextId, title: chapter.title),
        );
      }

      final visibleEntries = await _visibleContentsEntriesInOrder(
        sourceId,
        chapterId: chapterId,
      );
      if (movingChapters.isEmpty && visibleEntries.isEmpty) {
        return const NotebookContentsTransferResult(
          chapterCount: 0,
          entryCount: 0,
        );
      }

      // 整份转移按成书顺序（先各章、后未分章）重排，单章本身已是章内顺序。
      final orderedEntries = chapterId == null
          ? _entriesInBookOrder(sourcePayload.chapters, visibleEntries)
          : visibleEntries;

      if (movingChapters.isNotEmpty) {
        final now = DateTime.now();
        final nextSourcePayload = sourcePayload.copyWith(
          chapters: remainingSourceChapters,
        );
        final nextTargetPayload = targetPayload.copyWith(
          chapters: <NotebookChapter>[
            ...targetPayload.chapters,
            ...appendedChapters,
          ],
        );
        await (update(notebooks)..where((t) => t.id.equals(source.id))).write(
          NotebooksCompanion(
            payload: Value(nextSourcePayload.encode()),
            updatedAt: Value(now),
          ),
        );
        await (update(notebooks)..where((t) => t.id.equals(target.id))).write(
          NotebooksCompanion(
            payload: Value(nextTargetPayload.encode()),
            updatedAt: Value(now),
          ),
        );
      }

      if (orderedEntries.isNotEmpty) {
        final targetExisting = <int, DiaryNotebookRow>{
          for (final row in await _entriesInOrder(target.id)) row.diaryId: row,
        };
        var position = await _nextEntryPosition(target.id);
        final inserted = <DiaryNotebooksCompanion>[];
        final updatedChapters = <String, List<int>>{};
        final movedLocalIds = <int>[];
        for (final row in orderedEntries) {
          movedLocalIds.add(row.diaryId);
          final mappedChapter = row.chapterId == null
              ? null
              : chapterIdMap[row.chapterId];
          final existing = targetExisting[row.diaryId];
          if (existing == null) {
            inserted.add(
              DiaryNotebooksCompanion.insert(
                diaryId: row.diaryId,
                notebookId: target.id,
                chapterId: Value(mappedChapter),
                position: Value(position++),
                addedAt: row.addedAt,
              ),
            );
          } else if (mappedChapter != null &&
              (existing.chapterId == null ||
                  !targetValidChaptersBefore.contains(existing.chapterId))) {
            // 日记原本就在目标本里且未分章：归入刚搬来的章节，不打乱目标本原有位置。
            updatedChapters
                .putIfAbsent(mappedChapter, () => <int>[])
                .add(row.diaryId);
          }
        }
        if (inserted.isNotEmpty) {
          await batch((batch) => batch.insertAll(diaryNotebooks, inserted));
        }
        for (final entry in updatedChapters.entries) {
          for (final chunk in _chunked(entry.value)) {
            await (update(diaryNotebooks)..where(
                  (t) => t.notebookId.equals(target.id) & t.diaryId.isIn(chunk),
                ))
                .write(DiaryNotebooksCompanion(chapterId: Value(entry.key)));
          }
        }
        for (final chunk in _chunked(movedLocalIds)) {
          await (delete(diaryNotebooks)..where(
                (t) => t.notebookId.equals(source.id) & t.diaryId.isIn(chunk),
              ))
              .go();
        }
      }

      if (movingChapters.isNotEmpty) {
        final remainingIds = <String>{
          for (final chapter in remainingSourceChapters) chapter.id,
        };
        await (update(diaryNotebooks)..where(
              (t) =>
                  t.notebookId.equals(source.id) &
                  t.chapterId.isNotNull() &
                  t.chapterId.isNotIn(remainingIds),
            ))
            .write(const DiaryNotebooksCompanion(chapterId: Value(null)));
      }

      return NotebookContentsTransferResult(
        chapterCount: movingChapters.length,
        entryCount: orderedEntries.length,
      );
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

  /// 删除手动日记本 [notebookId] 中的若干章节（[chapterIds]），同一事务里把
  /// 原本属于这些章节的日记移回“未分章”，并返回完整快照供
  /// [restoreNotebookChaptersDeletion] 撤销。
  ///
  /// 本子不存在、不是手动本或没有任何有效可删章节时抛 [ArgumentError]。
  Future<NotebookChaptersDeletion> deleteNotebookChaptersWithSnapshot(
    String notebookId,
    Iterable<String> chapterIds,
  ) {
    return transaction(() async {
      final row = await _requireManualNotebook(notebookId);
      final payload = row.parsedPayload;
      final before = payload.chapters;
      final existing = payload.chapterIds;
      final deleting = <String>{
        for (final id in chapterIds)
          if (existing.contains(id)) id,
      };
      if (deleting.isEmpty) {
        throw ArgumentError.value(chapterIds, 'chapterIds', '没有可删除的章节');
      }
      final cleared = <String, String>{};
      for (final chunk in _chunked(deleting.toList())) {
        final query =
            selectOnly(diaryNotebooks).join(<Join>[
                innerJoin(
                  diaries,
                  diaries.id.equalsExp(diaryNotebooks.diaryId),
                ),
              ])
              ..addColumns(<Expression<Object>>[
                diaries.diaryId,
                diaryNotebooks.chapterId,
              ])
              ..where(
                diaryNotebooks.notebookId.equals(row.id) &
                    diaryNotebooks.chapterId.isIn(chunk),
              );
        for (final entry in await query.get()) {
          final chapterId = entry.read(diaryNotebooks.chapterId);
          if (chapterId != null) {
            cleared[entry.read(diaries.diaryId)!] = chapterId;
          }
        }
      }
      final after = <NotebookChapter>[
        for (final chapter in before)
          if (!deleting.contains(chapter.id)) chapter,
      ];
      final afterPayload = payload.copyWith(chapters: after);
      await (update(notebooks)..where((t) => t.id.equals(row.id))).write(
        NotebooksCompanion(
          payload: Value(afterPayload.encode()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (update(diaryNotebooks)..where(
            (t) =>
                t.notebookId.equals(row.id) &
                t.chapterId.isNotNull() &
                t.chapterId.isNotIn(afterPayload.chapterIds),
          ))
          .write(const DiaryNotebooksCompanion(chapterId: Value(null)));
      return NotebookChaptersDeletion(
        notebookId: notebookId,
        beforeChapters: List<NotebookChapter>.unmodifiable(before),
        afterChapters: List<NotebookChapter>.unmodifiable(after),
        clearedEntries: Map<String, String>.unmodifiable(cleared),
      );
    });
  }

  /// 撤销 [deleteNotebookChaptersWithSnapshot]：写回原章节列表（保留其他
  /// payload 字段的最新值），并恢复当时回到“未分章”的日记归属。
  ///
  /// 若删除之后章节列表又被改过且 [force] 为 false，抛 [StateError]；
  /// 非强制时只恢复目前仍为“未分章”的日记，不覆盖期间已被重新分章的条目。
  Future<void> restoreNotebookChaptersDeletion(
    NotebookChaptersDeletion deletion, {
    bool force = false,
  }) {
    return transaction(() async {
      final row = await getNotebook(deletion.notebookId);
      if (row == null || !row.acceptsManualEntries) return;
      final current = row.parsedPayload;
      if (!force &&
          !_sameNotebookChapters(current.chapters, deletion.afterChapters)) {
        throw StateError('章节列表在删除后已发生变化');
      }
      await (update(notebooks)..where((t) => t.id.equals(row.id))).write(
        NotebooksCompanion(
          payload: Value(
            current.copyWith(chapters: deletion.beforeChapters).encode(),
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (deletion.clearedEntries.isEmpty) return;
      final validIds = <String>{
        for (final chapter in deletion.beforeChapters) chapter.id,
      };
      final local = await _diaryLocalIds(deletion.clearedEntries.keys);
      final byChapter = <String, List<int>>{};
      for (final entry in deletion.clearedEntries.entries) {
        final localId = local[entry.key];
        if (localId == null || !validIds.contains(entry.value)) continue;
        byChapter.putIfAbsent(entry.value, () => <int>[]).add(localId);
      }
      for (final entry in byChapter.entries) {
        for (final chunk in _chunked(entry.value)) {
          await (update(diaryNotebooks)..where((t) {
                var filter =
                    t.notebookId.equals(row.id) & t.diaryId.isIn(chunk);
                if (!force) {
                  filter = filter & t.chapterId.isNull();
                }
                return filter;
              }))
              .write(DiaryNotebooksCompanion(chapterId: Value(entry.key)));
        }
      }
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

/// [AppDatabase.deleteNotebookChaptersWithSnapshot] 的撤销快照：删除前后的
/// 章节列表，以及当时被清空章节归属的日记业务 id → 原章节 id。
@immutable
class NotebookChaptersDeletion {
  const NotebookChaptersDeletion({
    required this.notebookId,
    required this.beforeChapters,
    required this.afterChapters,
    required this.clearedEntries,
  });

  final String notebookId;
  final List<NotebookChapter> beforeChapters;
  final List<NotebookChapter> afterChapters;
  final Map<String, String> clearedEntries;

  Map<String, Object?> toJson() => <String, Object?>{
    'notebookId': notebookId,
    'before': _encodeChapters(beforeChapters),
    'after': _encodeChapters(afterChapters),
    if (clearedEntries.isNotEmpty) 'cleared': clearedEntries,
  };

  factory NotebookChaptersDeletion.fromJson(Map<String, Object?> json) {
    final rawCleared = json['cleared'];
    final cleared = <String, String>{};
    if (rawCleared is Map) {
      for (final entry in rawCleared.entries) {
        if (entry.key is String && entry.value is String) {
          cleared[entry.key as String] = entry.value as String;
        }
      }
    }
    return NotebookChaptersDeletion(
      notebookId: json['notebookId']! as String,
      beforeChapters: _decodeChapters(json['before']),
      afterChapters: _decodeChapters(json['after']),
      clearedEntries: Map<String, String>.unmodifiable(cleared),
    );
  }

  static List<Map<String, String>> _encodeChapters(
    List<NotebookChapter> chapters,
  ) => <Map<String, String>>[
    for (final chapter in chapters)
      <String, String>{'id': chapter.id, 'title': chapter.title},
  ];

  static List<NotebookChapter> _decodeChapters(Object? raw) {
    if (raw is! List) return const <NotebookChapter>[];
    return List<NotebookChapter>.unmodifiable(<NotebookChapter>[
      for (final item in raw)
        if (item is Map && item['id'] is String && item['title'] is String)
          ?NotebookChapter.tryCreate(
            id: item['id'] as String,
            title: item['title'] as String,
          ),
    ]);
  }
}

/// [AppDatabase.transferNotebookContentsToChild] 的结果。
@immutable
class NotebookContentsTransferResult {
  const NotebookContentsTransferResult({
    required this.chapterCount,
    required this.entryCount,
  });

  /// 转移到目标子日记本的章节数。
  final int chapterCount;

  /// 从源日记本转移出的日记篇数。
  final int entryCount;
}

List<DiaryNotebookRow> _entriesInBookOrder(
  List<NotebookChapter> chapters,
  List<DiaryNotebookRow> entries,
) {
  final validIds = <String>{for (final chapter in chapters) chapter.id};
  final byChapter = <String?, List<DiaryNotebookRow>>{};
  for (final row in entries) {
    final key = row.chapterId != null && validIds.contains(row.chapterId)
        ? row.chapterId
        : null;
    byChapter.putIfAbsent(key, () => <DiaryNotebookRow>[]).add(row);
  }
  return <DiaryNotebookRow>[
    for (final chapter in chapters) ...?byChapter[chapter.id],
    ...?byChapter[null],
  ];
}

bool _sameNotebookChapters(List<NotebookChapter> a, List<NotebookChapter> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
