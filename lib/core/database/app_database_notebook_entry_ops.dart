part of 'app_database.dart';

/// 手动日记本的成员关系（`diary_notebooks`）读写。
///
/// 输入输出一律是业务 id（`notebookId` / `diaryId`），本地 id 只在这里换算。
/// 只有手动日记本有关联行：对智能、未知类型或不存在的日记本做成员操作抛
/// [ArgumentError]（合上的日记本照常接受）；认不出的日记 id 静默跳过。
/// 移除返回被删的关联行，撤销时经 [restoreNotebookMemberships] 原样写回。
/// [_replaceDiaryNotebooks] 供日记写入在同一事务里改写某篇日记所在的本子。
mixin _AppDatabaseNotebookEntryOps on _$AppDatabase, _AppDatabaseDiaryScopeSql {
  /// 把日记加进手动日记本，按 [diaryIds] 的顺序接在本子最后；已在本子里的与
  /// 不存在的日记跳过，返回实际加入的篇数。[chapterId] 已不是本子的章节时
  /// 落到“未分章”（章节可能刚在别处被删掉）。
  Future<int> addDiariesToNotebook(
    String notebookId,
    Iterable<String> diaryIds, {
    String? chapterId,
  }) {
    return transaction(() async {
      final notebook = await _requireManualNotebook(notebookId);
      final local = await _diaryLocalIds(diaryIds);
      final present = await _entryDiaryIds(notebook.id);
      final chapter = _validChapterId(notebook, chapterId);
      var position = await _nextEntryPosition(notebook.id);
      final now = DateTime.now();
      final rows = <DiaryNotebooksCompanion>[];
      for (final diaryId in diaryIds) {
        final id = local[diaryId];
        // present 同时记下本次已加入的，传入的重复 id 只加一次。
        if (id == null || !present.add(id)) continue;
        rows.add(
          DiaryNotebooksCompanion.insert(
            diaryId: id,
            notebookId: notebook.id,
            chapterId: Value(chapter),
            position: Value(position++),
            addedAt: now,
          ),
        );
      }
      await batch((batch) => batch.insertAll(diaryNotebooks, rows));
      return rows.length;
    });
  }

  /// 把日记移出手动日记本（日记本身不动），返回被删的关联行供撤销。
  Future<List<DiaryNotebookRow>> removeDiariesFromNotebook(
    String notebookId,
    Iterable<String> diaryIds,
  ) {
    return transaction(() async {
      final notebook = await _requireManualNotebook(notebookId);
      final local = (await _diaryLocalIds(diaryIds)).values.toList();
      final removed = <DiaryNotebookRow>[];
      for (final chunk in _chunked(local)) {
        Expression<bool> filter($DiaryNotebooksTable t) =>
            t.notebookId.equals(notebook.id) & t.diaryId.isIn(chunk);
        removed.addAll(await (select(diaryNotebooks)..where(filter)).get());
        await (delete(diaryNotebooks)..where(filter)).go();
      }
      return removed;
    });
  }

  /// 撤销移除：原样写回关联行（含章节、位置与加入时间）；日记或日记本已不
  /// 存在、或日记本已不是手动本的行丢弃，已存在的行保持不变。
  Future<void> restoreNotebookMemberships(List<DiaryNotebookRow> rows) {
    if (rows.isEmpty) return Future<void>.value();
    return transaction(() async {
      final diaryIds = await _existingDiaryLocalIds(
        rows.map((row) => row.diaryId),
      );
      final notebookRows = await (select(
        notebooks,
      )..where((t) => t.id.isIn(rows.map((row) => row.notebookId)))).get();
      final notebookIds = <int>{
        for (final notebook in notebookRows)
          if (notebook.acceptsManualEntries) notebook.id,
      };
      await batch((batch) {
        batch.insertAll(diaryNotebooks, <DiaryNotebookRow>[
          for (final row in rows)
            if (diaryIds.contains(row.diaryId) &&
                notebookIds.contains(row.notebookId))
              row,
        ], mode: InsertMode.insertOrIgnore);
      });
    });
  }

  /// 把日记从 [fromId] 移到 [toId]：一个事务里先移出再加入（接在目标本最后、
  /// 未分章）；已在目标本里的日记只从原本移出。两个 id 相同抛 [ArgumentError]。
  Future<void> moveDiariesBetweenNotebooks({
    required String fromId,
    required String toId,
    required Iterable<String> diaryIds,
  }) {
    if (fromId == toId) {
      throw ArgumentError.value(toId, 'toId', '不能移到同一个日记本');
    }
    final ids = diaryIds.toList();
    return transaction(() async {
      await _requireManualNotebook(toId);
      await removeDiariesFromNotebook(fromId, ids);
      await addDiariesToNotebook(toId, ids);
    });
  }

  /// 每篇日记所在的手动日记本（三态选择器用）：每个传入的 id 都有一项，不在
  /// 任何本子里（或日记不存在）时为空集合。
  Future<Map<String, Set<String>>> getNotebookIdsForDiaries(
    Iterable<String> diaryIds,
  ) async {
    final ids = diaryIds.toSet();
    final result = <String, Set<String>>{for (final id in ids) id: <String>{}};
    for (final chunk in _chunked(ids.toList())) {
      final rows = await _manualMembershipQuery(
        diaries.diaryId.isIn(chunk),
      ).get();
      for (final row in rows) {
        result[row.readTable(diaries).diaryId]!.add(
          row.readTable(notebooks).notebookId,
        );
      }
    }
    return result;
  }

  Future<Set<String>> getDiaryNotebookIds(String diaryId) async =>
      (await getNotebookIdsForDiaries(<String>[diaryId]))[diaryId]!;

  /// 单篇日记目前所在的手动日记本及对应章节（日记本业务 id → `chapter_id`，
  /// 未分章为 null）。用于编辑已有日记或单篇“收进日记本”回显各本当前章节。
  Future<Map<String, String?>> getDiaryNotebookMemberships(
    String diaryId,
  ) async {
    final query = _manualMembershipQuery(diaries.diaryId.equals(diaryId))
      ..orderBy(<OrderingTerm>[
        OrderingTerm.desc(notebooks.isPinned),
        OrderingTerm.asc(notebooks.sortOrder),
        OrderingTerm.asc(notebooks.id),
      ]);
    final rows = await query.get();
    return <String, String?>{
      for (final row in rows)
        row.readTable(notebooks).notebookId: row
            .readTable(diaryNotebooks)
            .chapterId,
    };
  }

  /// 包含这篇日记的手动日记本，按书架顺序（预览页的日记本胶囊用）。
  Stream<List<NotebookRow>> watchNotebooksOfDiary(String diaryId) {
    return _notebooksOfDiaryQuery(diaryId).watch().map(
      (rows) => <NotebookRow>[for (final row in rows) row.readTable(notebooks)],
    );
  }

  /// [watchNotebooksOfDiary] 的一次性读取。
  Future<List<NotebookRow>> getNotebooksOfDiary(String diaryId) async {
    final rows = await _notebooksOfDiaryQuery(diaryId).get();
    return <NotebookRow>[for (final row in rows) row.readTable(notebooks)];
  }

  JoinedSelectStatement<HasResultSet, dynamic> _notebooksOfDiaryQuery(
    String diaryId,
  ) {
    return _manualMembershipQuery(diaries.diaryId.equals(diaryId))
      ..orderBy(<OrderingTerm>[
        OrderingTerm.desc(notebooks.isPinned),
        OrderingTerm.asc(notebooks.sortOrder),
        OrderingTerm.asc(notebooks.id),
      ]);
  }

  /// 把本子里的这些日记放进 [chapterId]（null 为“未分章”），不改成书顺序；
  /// 章节已不存在时同样落到“未分章”。
  Future<void> setNotebookEntriesChapter(
    String notebookId,
    Iterable<String> diaryIds,
    String? chapterId,
  ) {
    return transaction(() async {
      final notebook = await _requireManualNotebook(notebookId);
      final chapter = _validChapterId(notebook, chapterId);
      final local = (await _diaryLocalIds(diaryIds)).values.toList();
      for (final chunk in _chunked(local)) {
        await (update(diaryNotebooks)..where(
              (t) => t.notebookId.equals(notebook.id) & t.diaryId.isIn(chunk),
            ))
            .write(DiaryNotebooksCompanion(chapterId: Value(chapter)));
      }
    });
  }

  /// 查询 [diaryIds] 在手动日记本 [notebookId] 中的当前章节：
  /// 只返回**已收录在本子里**的日记（业务 id → `chapter_id`，未分章为 null；
  /// 含归档日记）。不在本子里或不存在的日记不出现在结果里。
  Future<Map<String, String?>> getNotebookEntryChapters(
    String notebookId,
    Iterable<String> diaryIds,
  ) async {
    final notebook = await _requireManualNotebook(notebookId);
    final ids = diaryIds.toSet().toList();
    if (ids.isEmpty) return const <String, String?>{};
    final result = <String, String?>{};
    for (final chunk in _chunked(ids)) {
      final query =
          selectOnly(diaryNotebooks).join(<Join>[
              innerJoin(diaries, diaries.id.equalsExp(diaryNotebooks.diaryId)),
            ])
            ..addColumns(<Expression<Object>>[
              diaries.diaryId,
              diaryNotebooks.chapterId,
            ])
            ..where(
              diaryNotebooks.notebookId.equals(notebook.id) &
                  diaries.diaryId.isIn(chunk),
            );
      for (final row in await query.get()) {
        result[row.read(diaries.diaryId)!] = row.read(diaryNotebooks.chapterId);
      }
    }
    return result;
  }

  /// 按 [chaptersByDiaryId]（业务 id → 原 `chapter_id`）在同一事务里写回各篇
  /// 日记在手动日记本 [notebookId] 里的章节，不改成书顺序（撤销换章用）。
  /// 本子已删除或已不是手动本时静默返回；指向已不存在章节的落到“未分章”。
  Future<void> restoreNotebookEntryChapters(
    String notebookId,
    Map<String, String?> chaptersByDiaryId,
  ) {
    if (chaptersByDiaryId.isEmpty) return Future<void>.value();
    return transaction(() async {
      final notebook = await (select(
        notebooks,
      )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
      if (notebook == null || !notebook.acceptsManualEntries) return;
      final local = await _diaryLocalIds(chaptersByDiaryId.keys);
      final byChapter = <String?, List<int>>{};
      for (final entry in chaptersByDiaryId.entries) {
        final localId = local[entry.key];
        if (localId == null) continue;
        final chapter = _validChapterId(notebook, entry.value);
        byChapter.putIfAbsent(chapter, () => <int>[]).add(localId);
      }
      for (final entry in byChapter.entries) {
        for (final chunk in _chunked(entry.value)) {
          await (update(diaryNotebooks)..where(
                (t) => t.notebookId.equals(notebook.id) & t.diaryId.isIn(chunk),
              ))
              .write(DiaryNotebooksCompanion(chapterId: Value(entry.key)));
        }
      }
    });
  }

  /// 手动日记本 [notebookId] 里，[chapterIds] 中这些章节目前总共有多少条
  /// 成员行（含归档与回收站，判断撤销新建章节是否会让已有日记回到未分章用）。
  Future<int> countNotebookEntriesInChapters(
    String notebookId,
    Iterable<String> chapterIds,
  ) async {
    final ids = chapterIds.toSet().toList();
    if (ids.isEmpty) return 0;
    final notebook = await (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
    if (notebook == null || !notebook.acceptsManualEntries) return 0;
    var total = 0;
    final countExp = diaryNotebooks.diaryId.count();
    for (final chunk in _chunked(ids)) {
      final row =
          await (selectOnly(diaryNotebooks)
                ..addColumns(<Expression<Object>>[countExp])
                ..where(
                  diaryNotebooks.notebookId.equals(notebook.id) &
                      diaryNotebooks.chapterId.isIn(chunk),
                ))
              .getSingle();
      total += row.read(countExp) ?? 0;
    }
    return total;
  }

  /// 目录页保存手动排序：[ordered] 里的日记依次占位置 0..n-1 并改为各自的
  /// 章节；不在列表里的成员（例如排序途中别处新加入的）接在后面，保持原有
  /// 相对顺序、章节不变。不在本子里的日记与重复项忽略。
  Future<void> reorderNotebookEntries(
    String notebookId,
    List<({String diaryId, String? chapterId})> ordered,
  ) {
    return transaction(() async {
      final notebook = await _requireManualNotebook(notebookId);
      final local = await _diaryLocalIds(ordered.map((e) => e.diaryId));
      final rows = await _entriesInOrder(notebook.id);
      final byDiary = <int, DiaryNotebookRow>{
        for (final row in rows) row.diaryId: row,
      };
      final placed = <int>{};
      final next = <DiaryNotebookRow>[];
      for (final entry in ordered) {
        final id = local[entry.diaryId];
        final row = id == null ? null : byDiary[id];
        if (row == null || !placed.add(row.diaryId)) continue;
        next.add(
          row.copyWith(
            chapterId: Value(_validChapterId(notebook, entry.chapterId)),
          ),
        );
      }
      next.addAll(rows.where((row) => !placed.contains(row.diaryId)));
      for (var i = 0; i < next.length; i++) {
        final row = next[i];
        final before = byDiary[row.diaryId]!;
        if (before.position == i && before.chapterId == row.chapterId) continue;
        await (update(diaryNotebooks)..where(
              (t) =>
                  t.notebookId.equals(notebook.id) &
                  t.diaryId.equals(row.diaryId),
            ))
            .write(
              DiaryNotebooksCompanion(
                position: Value(i),
                chapterId: Value(row.chapterId),
              ),
            );
      }
    });
  }

  /// 首页列表口径下本子里每篇日记的章节：日记业务 id → `chapter_id`（未分章
  /// 或指向已删除章节时原样给出，读取方按章节列表判断）。
  ///
  /// 口径与 `DiaryNotebookScope` 一致：不算回收站与归档里的日记；普通本子不算
  /// 私密日记，私密本子算全部成员。章节胶囊的篇数与书序分隔行都由它派生，
  /// 只读两列，不随正文变化重新解码大字段。
  Stream<Map<String, String?>> watchNotebookEntryChapters(String notebookId) {
    final query = _notebookEntryColumnsQuery(notebookId, includeArchived: false)
      ..addColumns(<Expression<Object>>[
        diaries.diaryId,
        diaryNotebooks.chapterId,
      ]);
    return query.watch().map(
      (rows) => <String, String?>{
        for (final row in rows)
          row.read(diaries.diaryId)!: row.read(diaryNotebooks.chapterId),
      },
    );
  }

  /// 目录页：本子里的日记（含归档、不含回收站，私密规则同上）按成书位置排好，
  /// 只带目录行要显示的字段。
  Stream<List<NotebookContentsEntry>> watchNotebookContents(String notebookId) {
    return _notebookContentsQuery(
      notebookId,
    ).watch().map(_mapNotebookContentsRows);
  }

  /// [watchNotebookContents] 的一次性读取（导出成书按它确定章节与顺序）。
  Future<List<NotebookContentsEntry>> getNotebookContents(
    String notebookId,
  ) async {
    return _mapNotebookContentsRows(
      await _notebookContentsQuery(notebookId).get(),
    );
  }

  /// 导出成书（智能日记本）：[scope] 里全部未删除的日记 id，含归档与未解封
  /// 的胶囊（胶囊由导出链路跳过并计数提示），私密规则与列表范围一致；按发表
  /// 时间从旧到新——一本书从最早的一篇读起，不跟随列表的排序。
  Future<List<String>> getScopedDiaryIdsOldestFirst(
    DiaryListScope scope,
  ) async {
    final variables = <Variable<Object>>[];
    final sql = StringBuffer(
      'SELECT d.diary_id FROM diaries d\n${_diaryScopeJoinSql(scope)}'
      'WHERE d.is_deleted = 0\n',
    );
    _writeDiaryScopeFilter(sql, variables, scope);
    sql.writeln('ORDER BY d.created_at ASC, d.id ASC');
    final rows = await customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[diaries]),
    ).get();
    return <String>[for (final row in rows) row.read<String>('diary_id')];
  }

  JoinedSelectStatement<HasResultSet, dynamic> _notebookContentsQuery(
    String notebookId,
  ) {
    return _notebookEntryColumnsQuery(notebookId, includeArchived: true)
      ..addColumns(<Expression<Object>>[
        diaries.diaryId,
        diaries.title,
        diaries.createdAt,
        diaries.updatedAt,
        diaries.isArchived,
        diaries.capsuleLockedAt,
        diaries.capsuleUnlockAt,
        diaryNotebooks.chapterId,
        _notebookContentsLeadingText,
      ])
      ..orderBy(<OrderingTerm>[
        OrderingTerm.asc(diaryNotebooks.position),
        OrderingTerm.asc(diaryNotebooks.addedAt),
        OrderingTerm.asc(diaryNotebooks.diaryId),
      ]);
  }

  List<NotebookContentsEntry> _mapNotebookContentsRows(List<TypedResult> rows) {
    return List<NotebookContentsEntry>.unmodifiable(<NotebookContentsEntry>[
      for (final row in rows)
        NotebookContentsEntry(
          diaryId: row.read(diaries.diaryId)!,
          title: row.read(diaries.title) ?? '',
          createdAt: row.read(diaries.createdAt)!,
          updatedAt: row.read(diaries.updatedAt)!,
          isArchived: row.read(diaries.isArchived) ?? false,
          capsuleLockedAt: row.read(diaries.capsuleLockedAt),
          capsuleUnlockAt: row.read(diaries.capsuleUnlockAt),
          chapterId: row.read(diaryNotebooks.chapterId),
          leadingText: row.read(_notebookContentsLeadingText) ?? '',
        ),
    ]);
  }

  /// 目录行没写标题时拿正文第一行顶替（见 [NotebookContentsEntry.leadingText]），
  /// 这里只取正文开头一段：先去掉开头的空白与空行（只有图片的块在纯文本里
  /// 是空行），再截 [NotebookContentsEntry.leadingTextLength] 个字符。不取
  /// 整篇 `content_text`：目录、成书导出与统计页共用这个查询，大日记本每次
  /// 推送都会复制全部正文。
  static final Expression<String> _notebookContentsLeadingText =
      CustomExpression<String>(
        'substr(ltrim("diaries"."content_text", '
        'char(32, 9, 10, 13)), 1, ${NotebookContentsEntry.leadingTextLength})',
      );

  /// 目录页口径下的成员行（含归档、不含回收站，遵守私密规则），按成书位置排好；
  /// [chapterId] 非空时只取该章的成员。供目录整体转移到子日记本复用，保证搬运
  /// 集合与目录页展示完全一致。
  Future<List<DiaryNotebookRow>> _visibleContentsEntriesInOrder(
    String notebookId, {
    String? chapterId,
  }) async {
    final query =
        _notebookEntryColumnsQuery(
            notebookId,
            includeArchived: true,
            chapterId: chapterId,
          )
          ..addColumns(<Expression<Object>>[
            diaryNotebooks.diaryId,
            diaryNotebooks.notebookId,
            diaryNotebooks.chapterId,
            diaryNotebooks.position,
            diaryNotebooks.addedAt,
          ])
          ..orderBy(<OrderingTerm>[
            OrderingTerm.asc(diaryNotebooks.position),
            OrderingTerm.asc(diaryNotebooks.addedAt),
            OrderingTerm.asc(diaryNotebooks.diaryId),
          ]);
    final rows = await query.get();
    return <DiaryNotebookRow>[
      for (final row in rows)
        DiaryNotebookRow(
          diaryId: row.read(diaryNotebooks.diaryId)!,
          notebookId: row.read(diaryNotebooks.notebookId)!,
          chapterId: row.read(diaryNotebooks.chapterId),
          position: row.read(diaryNotebooks.position)!,
          addedAt: row.read(diaryNotebooks.addedAt)!,
        ),
    ];
  }

  /// 本子成员 × 日记 × 日记本的只取列查询（调用方再加列与排序）。
  JoinedSelectStatement<HasResultSet, dynamic> _notebookEntryColumnsQuery(
    String notebookId, {
    required bool includeArchived,
    String? chapterId,
  }) {
    final query = selectOnly(diaryNotebooks).join(<Join>[
      innerJoin(diaries, diaries.id.equalsExp(diaryNotebooks.diaryId)),
      innerJoin(notebooks, notebooks.id.equalsExp(diaryNotebooks.notebookId)),
    ]);
    var filter =
        notebooks.notebookId.equals(notebookId) &
        diaries.isDeleted.equals(false) &
        (CustomExpression<bool>(
              '"notebooks"."id" IN ($_privateNotebookIdsSql)',
            ) |
            CustomExpression<bool>(
              _privateDiaryExclusionSql('"diaries"."id"'),
            ));
    if (!includeArchived) {
      filter = filter & diaries.isArchived.equals(false);
    }
    if (chapterId != null) {
      filter = filter & diaryNotebooks.chapterId.equals(chapterId);
    }
    query.where(filter);
    return query;
  }

  /// 日记写入事务内调用：让本地 id 为 [localDiaryId] 的日记恰好在
  /// [notebookIds] 这些本子里。
  ///
  /// 仍选中的本子默认保留原关联行（章节、成书位置与加入时间都不变，否则编辑
  /// 一次日记就会把它挪到本子末尾、丢掉章节）；[updateExistingChapters] 为
  /// true 时按 [chapterIds] 更新仍在选中的本子的章节（位置与加入时间仍不变）。
  /// 取消选中的删除；新选中的接在该本最后，章节取 [chapterIds]（日记本业务
  /// id → 章节 id；没有或已不是那本的章节时为“未分章”）。智能、未知类型与
  /// 不存在的 id 静默忽略：编辑页拿到的列表可能来自过期的快照，为此让整次
  /// 保存失败不划算。
  Future<void> _replaceDiaryNotebooks(
    int localDiaryId,
    Set<String> notebookIds, {
    Map<String, String> chapterIds = const <String, String>{},
    bool updateExistingChapters = false,
  }) async {
    final targetRows = await _manualNotebooksByBusinessId(notebookIds);
    final targets = <int>[for (final row in targetRows) row.id];
    final existing = await (select(
      diaryNotebooks,
    )..where((t) => t.diaryId.equals(localDiaryId))).get();
    final kept = <int, DiaryNotebookRow>{};
    for (final row in existing) {
      if (targets.contains(row.notebookId)) {
        kept[row.notebookId] = row;
        continue;
      }
      await (delete(diaryNotebooks)..where(
            (t) =>
                t.diaryId.equals(localDiaryId) &
                t.notebookId.equals(row.notebookId),
          ))
          .go();
    }
    final now = DateTime.now();
    for (final notebook in targetRows) {
      final chapter = _validChapterId(
        notebook,
        chapterIds[notebook.notebookId],
      );
      final existingRow = kept[notebook.id];
      if (existingRow != null) {
        if (updateExistingChapters && existingRow.chapterId != chapter) {
          await (update(diaryNotebooks)..where(
                (t) =>
                    t.diaryId.equals(localDiaryId) &
                    t.notebookId.equals(notebook.id),
              ))
              .write(DiaryNotebooksCompanion(chapterId: Value(chapter)));
        }
        continue;
      }
      await into(diaryNotebooks).insert(
        DiaryNotebooksCompanion.insert(
          diaryId: localDiaryId,
          notebookId: notebook.id,
          chapterId: Value(chapter),
          position: Value(await _nextEntryPosition(notebook.id)),
          addedAt: now,
        ),
      );
    }
  }

  /// 按业务 id 取手动日记本；不存在或不接受手动成员时抛 [ArgumentError]。
  Future<NotebookRow> _requireManualNotebook(String notebookId) async {
    final row = await _requireNotebookRow(notebookId);
    if (!row.acceptsManualEntries) {
      throw ArgumentError.value(notebookId, 'notebookId', '只有手动日记本可以增删日记');
    }
    return row;
  }

  Future<NotebookRow> _requireNotebookRow(String notebookId) async {
    final row = await (select(
      notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError.value(notebookId, 'notebookId', '日记本不存在');
    }
    return row;
  }

  Future<List<NotebookRow>> _manualNotebooksByBusinessId(
    Iterable<String> notebookIds,
  ) async {
    final ids = notebookIds.toSet();
    if (ids.isEmpty) return const <NotebookRow>[];
    final rows = await (select(
      notebooks,
    )..where((t) => t.notebookId.isIn(ids))).get();
    final byId = <String, NotebookRow>{
      for (final row in rows)
        if (row.acceptsManualEntries) row.notebookId: row,
    };
    // 保持调用方给出的先后，新关联行的位置按这个顺序分配。
    return <NotebookRow>[for (final id in ids) ?byId[id]];
  }

  /// 本子里的关联行，按成书位置（同位置按加入时间、日记 id）排好。
  Future<List<DiaryNotebookRow>> _entriesInOrder(int localNotebookId) {
    return (select(diaryNotebooks)
          ..where((t) => t.notebookId.equals(localNotebookId))
          ..orderBy(<OrderClauseGenerator<$DiaryNotebooksTable>>[
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.addedAt),
            (t) => OrderingTerm.asc(t.diaryId),
          ]))
        .get();
  }

  Future<Set<int>> _entryDiaryIds(int localNotebookId) async {
    final query = selectOnly(diaryNotebooks)
      ..addColumns(<Expression<Object>>[diaryNotebooks.diaryId])
      ..where(diaryNotebooks.notebookId.equals(localNotebookId));
    return <int>{
      for (final row in await query.get()) row.read(diaryNotebooks.diaryId)!,
    };
  }

  Future<int> _nextEntryPosition(int localNotebookId) async {
    final maxPosition = diaryNotebooks.position.max();
    final row =
        await (selectOnly(diaryNotebooks)
              ..addColumns(<Expression<Object>>[maxPosition])
              ..where(diaryNotebooks.notebookId.equals(localNotebookId)))
            .getSingle();
    final current = row.read(maxPosition);
    return current == null ? 0 : current + 1;
  }

  /// 日记业务 id → 本地 id；不存在的日记不出现在结果里（含回收站里的）。
  Future<Map<String, int>> _diaryLocalIds(Iterable<String> diaryIds) async {
    final result = <String, int>{};
    for (final chunk in _chunked(diaryIds.toSet().toList())) {
      final query = selectOnly(diaries)
        ..addColumns(<Expression<Object>>[diaries.id, diaries.diaryId])
        ..where(diaries.diaryId.isIn(chunk));
      for (final row in await query.get()) {
        result[row.read(diaries.diaryId)!] = row.read(diaries.id)!;
      }
    }
    return result;
  }

  Future<Set<int>> _existingDiaryLocalIds(Iterable<int> localIds) async {
    final result = <int>{};
    for (final chunk in _chunked(localIds.toSet().toList())) {
      final query = selectOnly(diaries)
        ..addColumns(<Expression<Object>>[diaries.id])
        ..where(diaries.id.isIn(chunk));
      for (final row in await query.get()) {
        result.add(row.read(diaries.id)!);
      }
    }
    return result;
  }

  /// 日记 × 手动日记本的连接查询，[diaryFilter] 限定是哪些日记。
  JoinedSelectStatement<HasResultSet, dynamic> _manualMembershipQuery(
    Expression<bool> diaryFilter,
  ) {
    return select(notebooks).join(<Join>[
      innerJoin(
        diaryNotebooks,
        diaryNotebooks.notebookId.equalsExp(notebooks.id),
      ),
      innerJoin(diaries, diaries.id.equalsExp(diaryNotebooks.diaryId)),
    ])..where(notebooks.kind.equals(NotebookKind.manual.name) & diaryFilter);
  }
}

/// 章节 id 仍在本子的章节列表里才保留，否则归“未分章”。
String? _validChapterId(NotebookRow notebook, String? chapterId) {
  if (chapterId == null) return null;
  return notebook.parsedPayload.chapterIds.contains(chapterId)
      ? chapterId
      : null;
}

/// 拆成小批，避免 `IN (…)` 的绑定变量超过 SQLite 上限（旧版本为 999）。
Iterable<List<T>> _chunked<T>(List<T> items, [int size = 500]) sync* {
  for (var start = 0; start < items.length; start += size) {
    yield items.sublist(start, min(start + size, items.length));
  }
}

/// 目录页的一行日记（[AppDatabase.watchNotebookContents]）。
@immutable
class NotebookContentsEntry {
  const NotebookContentsEntry({
    required this.diaryId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.chapterId,
    this.capsuleLockedAt,
    this.capsuleUnlockAt,
    this.leadingText = '',
  });

  /// [leadingText] 最多取的字符数：够日记卡片标题行的上限（240）再留些余量
  /// 给开头的全角空格等 SQL 没去掉的空白行。
  static const int leadingTextLength = 512;

  final String diaryId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final DateTime? capsuleLockedAt;
  final DateTime? capsuleUnlockAt;

  /// 原始 `chapter_id`；不在章节列表里时算“未分章”。
  final String? chapterId;

  /// 正文纯文本的开头一段（去掉了开头的空白与空行，最多 [leadingTextLength]
  /// 个字符），只够没写标题时取第一行顶替标题；不是完整正文。
  final String leadingText;
}
