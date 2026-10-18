part of 'app_database.dart';

/// 标签相关数据访问实现。
///
/// 这部分只负责标签本身的增删查，不处理日记正文与归档语义。
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
