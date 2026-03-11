part of 'app_database.dart';

/// 标签相关数据访问实现。
///
/// 这部分只负责标签本身的增删查，不处理日记正文与归档语义。
mixin AppDatabaseTagOps on _$AppDatabase {
  /// 按名称升序实时监听全部标签。
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy(<OrderingTerm Function(Tags)>[
      (Tags t) => OrderingTerm.asc(t.name),
    ])).watch();
  }

  /// 创建标签。
  ///
  /// 若同名标签已存在，则复用已有标签并同步更新颜色，避免重复记录。
  Future<int> createTag({required String name, required int color}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('标签名不能为空');
    }

    final existing =
        await (select(tags)
          ..where((Tags t) => t.name.equals(normalizedName))).getSingleOrNull();
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

    final duplicate =
        await (select(tags)..where((Tags t) => t.name.equals(normalizedName)))
            .getSingleOrNull();
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

  /// 删除标签（关联关系由外键级联删除）。
  Future<void> deleteTag(int tagId) async {
    await (delete(tags)..where((Tags t) => t.id.equals(tagId))).go();
  }
}
