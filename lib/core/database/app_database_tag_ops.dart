part of 'app_database.dart';

/// 一次批量改标签（[_AppDatabaseTagOps.applyDiaryTagBatch]）的撤销信息。
///
/// [before] 为本次真正改动过的日记（业务 id）原来的标签 id（升序），[add] /
/// [remove] 为本次实际加上 / 去掉的标签：撤销时只把这次加上的去掉、去掉的
/// 放回，结果与 [before] 逐一相等，又不会抹掉撤销窗口里别处对其他标签的
/// 改动。本次没有任何改动时 [isEmpty]。
@immutable
class DiaryTagBatchUndo {
  const DiaryTagBatchUndo({
    this.before = const <String, List<int>>{},
    this.add = const <int>{},
    this.remove = const <int>{},
  });

  final Map<String, List<int>> before;
  final Set<int> add;
  final Set<int> remove;

  bool get isEmpty => before.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'before': before,
    'add': add.toList(),
    'remove': remove.toList(),
  };

  static DiaryTagBatchUndo fromJson(Map<String, Object?> json) {
    List<int> ints(Object? raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is int) item,
    ];
    final before = json['before'];
    return DiaryTagBatchUndo(
      before: <String, List<int>>{
        if (before is Map)
          for (final entry in before.entries) '${entry.key}': ints(entry.value),
      },
      add: ints(json['add']).toSet(),
      remove: ints(json['remove']).toSet(),
    );
  }
}

/// 删掉的一个标签：标签本身与当时用着它的日记（本地 id）。撤销时原样放回
/// （见 `restoreTagDeletion`）。
class TagDeletion {
  const TagDeletion({required this.tag, required this.diaryIds});

  final Tag tag;
  final List<int> diaryIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'tag': tag.toJson(),
    'diaries': diaryIds,
  };

  static TagDeletion fromJson(Map<String, Object?> json) => TagDeletion(
    tag: Tag.fromJson((json['tag']! as Map).cast<String, dynamic>()),
    diaryIds: [
      for (final id in json['diaries']! as List)
        if (id is int) id,
    ],
  );
}

/// 一次标签合并的撤销记录：删掉的来源标签与合并时新挂上目标标签的日记。
class TagMerge {
  const TagMerge({
    required this.targetId,
    required this.sources,
    required this.addedTargetDiaryIds,
  });

  final int targetId;
  final List<TagDeletion> sources;
  final List<int> addedTargetDiaryIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'target': targetId,
    'sources': [for (final source in sources) source.toJson()],
    'added': addedTargetDiaryIds,
  };

  static TagMerge fromJson(Map<String, Object?> json) => TagMerge(
    targetId: json['target']! as int,
    sources: [
      for (final source in json['sources']! as List)
        TagDeletion.fromJson((source as Map).cast<String, Object?>()),
    ],
    addedTargetDiaryIds: [
      for (final id in json['added']! as List)
        if (id is int) id,
    ],
  );
}

/// 标签相关数据访问实现。
///
/// 这部分负责标签本身的增删查，以及多选日记的批量加减标签（只改
/// `diary_tags`，不碰日记行）；不处理日记正文与归档语义。
mixin _AppDatabaseTagOps on _$AppDatabase {
  /// 按名称升序实时监听全部标签。
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy(<OrderingTerm Function(Tags)>[
          (Tags t) => OrderingTerm.asc(t.name),
        ]))
        .watch();
  }

  /// 创建标签。
  ///
  /// 若同名标签已存在，则复用已有标签并同步更新颜色，避免重复记录。
  Future<int> createTag({required String name, required int color}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('标签名不能为空');
    }

    final existing = await (select(
      tags,
    )..where((Tags t) => t.name.equals(normalizedName))).getSingleOrNull();
    if (existing != null) {
      if (existing.color != color) {
        await (update(tags)..where((Tags t) => t.id.equals(existing.id))).write(
          TagsCompanion(color: Value<int>(color)),
        );
      }
      return existing.id;
    }

    return into(
      tags,
    ).insert(TagsCompanion.insert(name: normalizedName, color: color));
  }

  /// 更新标签信息。
  ///
  /// 约束：
  /// - 标签名不能为空；
  /// - 不允许与其他标签重名。
  Future<void> updateTag({
    required int tagId,
    required String name,
    required int color,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('标签名不能为空');
    }

    final duplicate = await (select(
      tags,
    )..where((Tags t) => t.name.equals(normalizedName))).getSingleOrNull();
    if (duplicate != null && duplicate.id != tagId) {
      throw const FormatException('已存在同名标签');
    }

    await (update(tags)..where((Tags t) => t.id.equals(tagId))).write(
      TagsCompanion(
        name: Value<String>(normalizedName),
        color: Value<int>(color),
      ),
    );
  }

  /// 按名称取得一组标签的 id，缺失的才新建。
  ///
  /// 与 [createTag] 不同，已存在的同名标签**不改颜色**：模板与模板码只带
  /// 标签名和建议色，套用时不能悄悄改掉用户自己设好的标签颜色。名称先去首尾
  /// 空白，空名与超过 40 个字符的名称跳过（与 `tags` 表约束一致）。
  ///
  /// 返回名称（去空白后）到 id 的映射，以及本次新建的 id——撤销套用时只回收
  /// 这些新建且仍未被任何日记使用的标签。
  Future<({Map<String, int> ids, Set<int> created})> ensureTagsByName(
    Iterable<({String name, int color})> refs,
  ) {
    return transaction(() async {
      final ids = <String, int>{};
      final created = <int>{};
      for (final ref in refs) {
        final name = ref.name.trim();
        if (name.isEmpty || name.length > 40 || ids.containsKey(name)) {
          continue;
        }
        final existing = await (select(
          tags,
        )..where((Tags t) => t.name.equals(name))).getSingleOrNull();
        if (existing != null) {
          ids[name] = existing.id;
          continue;
        }
        final id = await into(
          tags,
        ).insert(TagsCompanion.insert(name: name, color: ref.color));
        ids[name] = id;
        created.add(id);
      }
      return (ids: ids, created: created);
    });
  }

  /// 删除 [tagIds] 中没有任何日记引用的标签；仍被日记使用的保持不动。
  Future<void> deleteTagsIfUnused(Set<int> tagIds) async {
    if (tagIds.isEmpty) return;
    await (delete(tags)..where(
          (Tags t) =>
              t.id.isIn(tagIds) &
              notExistsQuery(
                select(diaryTags)
                  ..where((DiaryTags link) => link.tagId.equalsExp(t.id)),
              ),
        ))
        .go();
  }

  /// 每篇日记（业务 id）现有的标签 id：每个传入的 id 都有一项，没有标签
  /// （或日记不存在）时为空集合。多选的标签面板据此算出各标签的三态。
  Future<Map<String, Set<int>>> getTagIdsForDiaries(
    Iterable<String> diaryIds,
  ) async {
    final ids = diaryIds.toSet();
    final result = <String, Set<int>>{for (final id in ids) id: <int>{}};
    final local = await _diaryLocalIdsForTags(ids);
    final current = await _tagIdsOfLocalDiaries(local.values);
    for (final MapEntry(key: diaryId, value: localId) in local.entries) {
      result[diaryId]!.addAll(current[localId] ?? const <int>{});
    }
    return result;
  }

  /// 给一批日记（业务 id）整体加上 [add]、去掉 [remove] 里的标签（多选的
  /// 批量标签），返回撤销信息（见 [restoreDiaryTagBatch]）。
  ///
  /// - 单个事务内只改写 `diary_tags`：不改日记行，`updatedAt` 不变（与多选
  ///   置顶、日记本收录一致，按更新时间排序的列表不跳动）；首页列表与标签
  ///   栏的查询都订阅了 `diary_tags`，随之刷新，局域网同步的标签分面也由
  ///   这张表现算；
  /// - 去掉只删关联，不删标签本身；[add] 里此刻已不存在的标签（面板打开
  ///   期间在别处删掉）跳过，不留悬空关联（库里不开外键）；
  /// - 已有的不重复加、没有的不去删；整批没有任何变化时不写库、不触发
  ///   数据流，返回空的撤销信息；
  /// - [add] 与 [remove] 必须不相交（三态面板的结果天然如此）。
  Future<DiaryTagBatchUndo> applyDiaryTagBatch(
    Iterable<String> diaryIds, {
    Set<int> add = const <int>{},
    Set<int> remove = const <int>{},
  }) async {
    if (add.any(remove.contains)) {
      throw ArgumentError.value(add, 'add', '不能同时加上和去掉同一个标签');
    }
    final ids = diaryIds.toSet();
    if (ids.isEmpty || (add.isEmpty && remove.isEmpty)) {
      return const DiaryTagBatchUndo();
    }
    return transaction(() async {
      final local = await _diaryLocalIdsForTags(ids);
      final current = await _tagIdsOfLocalDiaries(local.values);
      final addable = await _existingTagIds(add);
      final before = <String, List<int>>{};
      final added = <int>{};
      final removed = <int>{};
      final inserts = <DiaryTagsCompanion>[];
      for (final MapEntry(key: diaryId, value: localId) in local.entries) {
        final tags = current[localId] ?? const <int>{};
        final toAdd = addable.difference(tags);
        final toRemove = remove.intersection(tags);
        if (toAdd.isEmpty && toRemove.isEmpty) continue;
        before[diaryId] = tags.toList()..sort();
        added.addAll(toAdd);
        removed.addAll(toRemove);
        if (toRemove.isNotEmpty) {
          await (delete(diaryTags)..where(
                (DiaryTags t) =>
                    t.diaryId.equals(localId) & t.tagId.isIn(toRemove),
              ))
              .go();
        }
        for (final tagId in toAdd) {
          inserts.add(
            DiaryTagsCompanion.insert(diaryId: localId, tagId: tagId),
          );
        }
      }
      if (inserts.isNotEmpty) {
        await batch(
          (Batch b) =>
              b.insertAll(diaryTags, inserts, mode: InsertMode.insertOrIgnore),
        );
      }
      return DiaryTagBatchUndo(before: before, add: added, remove: removed);
    });
  }

  /// 撤销 [applyDiaryTagBatch]：单个事务内把这次加上的去掉、去掉的放回，
  /// 同样不改 `updatedAt`。期间被彻底删除的日记跳过；被删掉的标签不再
  /// 放回（不留悬空关联）。
  Future<void> restoreDiaryTagBatch(DiaryTagBatchUndo undo) async {
    if (undo.isEmpty) return;
    await transaction(() async {
      final local = await _diaryLocalIdsForTags(undo.before.keys);
      final restorable = await _existingTagIds(undo.remove);
      final inserts = <DiaryTagsCompanion>[];
      for (final MapEntry(key: diaryId, value: tags) in undo.before.entries) {
        final localId = local[diaryId];
        if (localId == null) continue;
        final original = tags.toSet();
        final takeOut = undo.add.difference(original);
        if (takeOut.isNotEmpty) {
          await (delete(diaryTags)..where(
                (DiaryTags t) =>
                    t.diaryId.equals(localId) & t.tagId.isIn(takeOut),
              ))
              .go();
        }
        for (final tagId in restorable.intersection(original)) {
          inserts.add(
            DiaryTagsCompanion.insert(diaryId: localId, tagId: tagId),
          );
        }
      }
      if (inserts.isNotEmpty) {
        await batch(
          (Batch b) =>
              b.insertAll(diaryTags, inserts, mode: InsertMode.insertOrIgnore),
        );
      }
    });
  }

  /// 日记业务 id → 本地 id；不存在的日记不出现在结果里。
  Future<Map<String, int>> _diaryLocalIdsForTags(
    Iterable<String> diaryIds,
  ) async {
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

  /// 本地日记 id → 它现有的标签 id；没有标签的日记不出现在结果里。
  Future<Map<int, Set<int>>> _tagIdsOfLocalDiaries(
    Iterable<int> localIds,
  ) async {
    final result = <int, Set<int>>{};
    for (final chunk in _chunked(localIds.toSet().toList())) {
      final rows = await (select(
        diaryTags,
      )..where((DiaryTags t) => t.diaryId.isIn(chunk))).get();
      for (final row in rows) {
        (result[row.diaryId] ??= <int>{}).add(row.tagId);
      }
    }
    return result;
  }

  /// [tagIds] 里此刻仍存在的标签。
  Future<Set<int>> _existingTagIds(Set<int> tagIds) async {
    final result = <int>{};
    for (final chunk in _chunked(tagIds.toList())) {
      final query = selectOnly(tags)
        ..addColumns(<Expression<Object>>[tags.id])
        ..where(tags.id.isIn(chunk));
      for (final row in await query.get()) {
        result.add(row.read(tags.id)!);
      }
    }
    return result;
  }

  /// 删除标签并留下快照（标签本身与当时用着它的全部日记，含私密与回收站里
  /// 的），供撤销时原样放回；标签不存在时返回 null。
  Future<TagDeletion?> deleteTagWithSnapshot(int tagId) {
    return transaction(() async {
      final tag = await (select(
        tags,
      )..where((Tags t) => t.id.equals(tagId))).getSingleOrNull();
      if (tag == null) return null;
      final links = await (select(
        diaryTags,
      )..where((DiaryTags t) => t.tagId.equals(tagId))).get();
      await deleteTag(tagId);
      return TagDeletion(
        tag: tag,
        diaryIds: [for (final link in links) link.diaryId],
      );
    });
  }

  /// 撤销 [deleteTagWithSnapshot]：以原 id、名称与颜色放回标签，并给仍存在的
  /// 日记重新挂上。期间又建了同名标签时抛 [StateError]（不能悄悄合并）。
  Future<void> restoreTagDeletion(TagDeletion deletion) {
    return transaction(() async {
      final tag = deletion.tag;
      final sameName = await (select(
        tags,
      )..where((Tags t) => t.name.equals(tag.name))).getSingleOrNull();
      if (sameName != null && sameName.id != tag.id) {
        throw StateError('A tag named "${tag.name}" exists again');
      }
      if (sameName == null) {
        await into(tags).insert(
          TagsCompanion(
            id: Value<int>(tag.id),
            name: Value<String>(tag.name),
            color: Value<int>(tag.color),
          ),
        );
      }
      final existing =
          await (selectOnly(diaries)
                ..addColumns(<Expression<Object>>[diaries.id])
                ..where(diaries.id.isIn(deletion.diaryIds)))
              .map((row) => row.read(diaries.id)!)
              .get();
      for (final diaryId in existing) {
        await into(diaryTags).insert(
          DiaryTagsCompanion.insert(diaryId: diaryId, tagId: tag.id),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// 把 [sourceIds] 合并进 [targetId]：用着来源标签的日记（含私密与回收站
  /// 里的）都挂上目标标签，再删掉来源标签。返回撤销所需的记录。
  Future<TagMerge> mergeTags(Iterable<int> sourceIds, int targetId) {
    return transaction(() async {
      final had =
          (await (select(
                diaryTags,
              )..where((DiaryTags t) => t.tagId.equals(targetId))).get())
              .map((link) => link.diaryId)
              .toSet();
      final added = <int>{};
      final sources = <TagDeletion>[];
      for (final sourceId in sourceIds.toSet()..remove(targetId)) {
        final links = await (select(
          diaryTags,
        )..where((DiaryTags t) => t.tagId.equals(sourceId))).get();
        for (final link in links) {
          if (had.contains(link.diaryId) || !added.add(link.diaryId)) continue;
          await into(diaryTags).insert(
            DiaryTagsCompanion.insert(diaryId: link.diaryId, tagId: targetId),
            mode: InsertMode.insertOrIgnore,
          );
        }
        final deletion = await deleteTagWithSnapshot(sourceId);
        if (deletion != null) sources.add(deletion);
      }
      return TagMerge(
        targetId: targetId,
        sources: sources,
        addedTargetDiaryIds: added.toList(),
      );
    });
  }

  /// 撤销 [mergeTags]：去掉合并时新挂的目标标签，放回来源标签与它们的日记。
  Future<void> restoreTagMerge(TagMerge merge) {
    return transaction(() async {
      if (merge.addedTargetDiaryIds.isNotEmpty) {
        await (delete(diaryTags)..where(
              (DiaryTags t) =>
                  t.tagId.equals(merge.targetId) &
                  t.diaryId.isIn(merge.addedTargetDiaryIds),
            ))
            .go();
      }
      for (final source in merge.sources) {
        await restoreTagDeletion(source);
      }
    });
  }

  /// 删除标签及其关联，不依赖历史连接是否开启了 SQLite 外键级联。
  Future<void> deleteTag(int tagId) async {
    await transaction(() async {
      await (delete(
        diaryTags,
      )..where((DiaryTags t) => t.tagId.equals(tagId))).go();
      await (delete(tags)..where((Tags t) => t.id.equals(tagId))).go();
    });
  }
}
