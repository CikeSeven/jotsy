part of 'app_database.dart';

/// 目录页的“转移目录”：把手动日记本的整份目录或单个章节转移到同一棵树里的
/// 手动上级（父本、祖本）或手动子孙本，以及转移后的撤销。
///
/// - 输入：源本与目标本的业务 id，可选的单个章节 id。
/// - 输出：[NotebookContentsTransfer]，既是界面要显示的章节数 / 篇数，也是
///   [undoNotebookContentsTransfer] 原样写回所需的快照。
/// - 副作用：一个事务里改写两本 payload 的章节列表与两本的 `diary_notebooks`
///   行；日记本身不动。
///
/// 允许往上转：子本的内容可以原路转回上级，转错了也能还原（#349）。
mixin _AppDatabaseNotebookTransferOps
    on
        _$AppDatabase,
        _AppDatabaseDiaryScopeSql,
        _AppDatabaseNotebookEntryOps,
        _AppDatabaseNotebookTreeOps {
  /// 把手动日记本 [sourceId] 的整个目录（[chapterId] 为 null）或单个章节
  /// （[chapterId] 非空）整体转移到 [targetId]，一个事务内完成。[targetId]
  /// 须是 [sourceId] 的手动上级或手动子孙。
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
  /// 两者相同、任一方不存在或非手动本、目标既不是源本上级也不是源本子孙，或
  /// 指定的 [chapterId] 不存在时抛 [ArgumentError]，不改动任何数据。
  Future<NotebookContentsTransfer> transferNotebookContents({
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
      if (!hierarchy.ancestorsOf(sourceId).contains(targetId) &&
          !hierarchy.descendantsOf(sourceId).contains(targetId)) {
        throw ArgumentError.value(targetId, 'targetId', '目标不是当前日记本的上级或子日记本');
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
      final undo = NotebookContentsTransfer._(
        source.id,
        target.id,
        movingChapters.isEmpty
            ? null
            : List<NotebookChapter>.unmodifiable(sourcePayload.chapters),
        movingChapters.isEmpty
            ? null
            : List<NotebookChapter>.unmodifiable(targetPayload.chapters),
        chapterCount: movingChapters.length,
        entryCount: visibleEntries.length,
      );
      if (movingChapters.isEmpty && visibleEntries.isEmpty) return undo;

      // 整份转移按成书顺序（先各章、后未分章）重排，单章本身已是章内顺序。
      final orderedEntries = chapterId == null
          ? _entriesInBookOrder(sourcePayload.chapters, visibleEntries)
          : visibleEntries;

      if (movingChapters.isNotEmpty) {
        final now = DateTime.now();
        await _writeNotebookChapters(
          source.id,
          sourcePayload.copyWith(chapters: remainingSourceChapters),
          now,
        );
        await _writeNotebookChapters(
          target.id,
          targetPayload.copyWith(
            chapters: <NotebookChapter>[
              ...targetPayload.chapters,
              ...appendedChapters,
            ],
          ),
          now,
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
          undo._sourceRowsBefore.add(row);
          final mappedChapter = row.chapterId == null
              ? null
              : chapterIdMap[row.chapterId];
          final existing = targetExisting[row.diaryId];
          if (existing == null) {
            undo._insertedTargetDiaryIds.add(row.diaryId);
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
            undo._targetEntryChaptersBefore[row.diaryId] = existing.chapterId;
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
        Expression<bool> dangling($DiaryNotebooksTable t) =>
            t.notebookId.equals(source.id) &
            t.chapterId.isNotNull() &
            t.chapterId.isNotIn(remainingIds);
        // 先记下原样再清：撤销时连章节归属一起写回。
        undo._sourceRowsBefore.addAll(
          await (select(diaryNotebooks)..where(dangling)).get(),
        );
        await (update(diaryNotebooks)..where(dangling)).write(
          const DiaryNotebooksCompanion(chapterId: Value(null)),
        );
      }
      return undo;
    });
  }

  /// 撤销 [transferNotebookContents]，一个事务内完成：两本的章节列表写回转移前
  /// 的样子（payload 其他字段取最新值），删掉搬进目标本的关联行、改回目标本
  /// 原有日记的章节，源本的关联行原样写回（含章节、位置与加入时间）。
  ///
  /// 只在提示条的撤销窗口里调用（局域网同步此时不写入），所以不检查期间的
  /// 改动；已不存在或已不是手动本的日记本跳过，已被彻底删除的日记不写回。
  Future<void> undoNotebookContentsTransfer(NotebookContentsTransfer transfer) {
    if (transfer.isEmpty) return Future<void>.value();
    return transaction(() async {
      final rows =
          await (select(notebooks)..where(
                (t) => t.id.isIn(<int>[
                  transfer._sourceLocalId,
                  transfer._targetLocalId,
                ]),
              ))
              .get();
      final manual = <int, NotebookRow>{
        for (final row in rows)
          if (row.acceptsManualEntries) row.id: row,
      };
      final source = manual[transfer._sourceLocalId];
      final target = manual[transfer._targetLocalId];

      final now = DateTime.now();
      final sourceChapters = transfer._sourceChaptersBefore;
      if (source != null && sourceChapters != null) {
        await _writeNotebookChapters(
          source.id,
          source.parsedPayload.copyWith(chapters: sourceChapters),
          now,
        );
      }
      final targetChapters = transfer._targetChaptersBefore;
      if (target != null && targetChapters != null) {
        await _writeNotebookChapters(
          target.id,
          target.parsedPayload.copyWith(chapters: targetChapters),
          now,
        );
      }

      if (target != null) {
        for (final chunk in _chunked(transfer._insertedTargetDiaryIds)) {
          await (delete(diaryNotebooks)..where(
                (t) => t.notebookId.equals(target.id) & t.diaryId.isIn(chunk),
              ))
              .go();
        }
        final byChapter = <String?, List<int>>{};
        for (final entry in transfer._targetEntryChaptersBefore.entries) {
          byChapter.putIfAbsent(entry.value, () => <int>[]).add(entry.key);
        }
        for (final entry in byChapter.entries) {
          for (final chunk in _chunked(entry.value)) {
            await (update(diaryNotebooks)..where(
                  (t) => t.notebookId.equals(target.id) & t.diaryId.isIn(chunk),
                ))
                .write(DiaryNotebooksCompanion(chapterId: Value(entry.key)));
          }
        }
      }

      if (source != null && transfer._sourceRowsBefore.isNotEmpty) {
        final existing = await _existingDiaryLocalIds(
          transfer._sourceRowsBefore.map((row) => row.diaryId),
        );
        await batch((batch) {
          batch.insertAll(diaryNotebooks, <DiaryNotebookRow>[
            for (final row in transfer._sourceRowsBefore)
              if (existing.contains(row.diaryId)) row,
          ], mode: InsertMode.insertOrReplace);
        });
      }
    });
  }

  Future<void> _writeNotebookChapters(
    int localNotebookId,
    NotebookPayload payload,
    DateTime now,
  ) {
    return (update(
      notebooks,
    )..where((t) => t.id.equals(localNotebookId))).write(
      NotebooksCompanion(
        payload: Value(payload.encode()),
        updatedAt: Value(now),
      ),
    );
  }
}

/// [AppDatabase.transferNotebookContents] 的结果与撤销快照：转移了几个章节、
/// 几篇日记，以及原样写回所需的转移前状态。只由转移产生，原样交给
/// [AppDatabase.undoNotebookContentsTransfer]。
///
/// 快照里是本地 id：撤销窗口只有几秒，两本日记本都还在原地（`notebooks.id`
/// 是 AUTOINCREMENT，删掉的也不会被复用）。
class NotebookContentsTransfer {
  // 私有字段用位置参数：命名参数不能直接初始化私有字段（新语法 drift 的
  // 代码生成器还解析不了，同 `NotebookDeletion`）。三个集合在转移事务里逐步
  // 填好。
  NotebookContentsTransfer._(
    this._sourceLocalId,
    this._targetLocalId,
    this._sourceChaptersBefore,
    this._targetChaptersBefore, {
    required this.chapterCount,
    required this.entryCount,
  });

  /// 转移到目标本的章节数。
  final int chapterCount;

  /// 从源本转移出的日记篇数。
  final int entryCount;

  final int _sourceLocalId;
  final int _targetLocalId;

  /// 转移前两本的章节列表；没有章节移动时为 null（两本的章节都没改）。
  final List<NotebookChapter>? _sourceChaptersBefore;
  final List<NotebookChapter>? _targetChaptersBefore;

  /// 源本被删掉或被清空章节的关联行，转移前的原样。
  final List<DiaryNotebookRow> _sourceRowsBefore = <DiaryNotebookRow>[];

  /// 新插进目标本的日记（本地 id）。
  final List<int> _insertedTargetDiaryIds = <int>[];

  /// 原本就在目标本、被归入搬来章节的日记（本地 id）→ 原来的章节 id。
  final Map<int, String?> _targetEntryChaptersBefore = <int, String?>{};

  /// 什么都没改（空目录）时撤销无事可做。
  bool get isEmpty =>
      _sourceChaptersBefore == null && _sourceRowsBefore.isEmpty;
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
