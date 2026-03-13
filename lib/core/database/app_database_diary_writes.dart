part of 'app_database.dart';

/// 日记写入与状态变更实现。
///
/// 该分区负责：
/// - 创建/更新日记；
/// - 归档、软删除、恢复；
/// - 日记与标签关联关系维护。
mixin AppDatabaseDiaryWrites on _$AppDatabase {
  /// 创建日记并写入关联标签。
  ///
  /// 事务内完成“主表插入 + 关联表写入”，保证一致性。
  Future<String> createDiary({
    required String title,
    required String contentDocJson,
    required String contentText,
    required String metadataJson,
    String? cover,
    List<int> tagIds = const <int>[],
    DateTime? createdAtOverride,
  }) async {
    final now = createdAtOverride ?? DateTime.now();
    final diaryId = _generateDiaryId();
    final normalizedMetadata = normalizeMetadataJson(metadataJson);
    final normalizedCover = _normalizeCover(cover);
    final normalizedTagIds = tagIds.toSet().toList();

    return transaction<String>(() async {
      final localDiaryId = await into(diaries).insert(
        DiariesCompanion.insert(
          diaryId: diaryId,
          title: Value<String>(title.trim()),
          content: contentDocJson,
          contentText: contentText,
          cover: Value<String?>(normalizedCover),
          metadata: Value<String>(normalizedMetadata),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _replaceDiaryTags(localDiaryId, normalizedTagIds);
      return diaryId;
    });
  }

  /// 更新日记并覆盖标签绑定关系。
  ///
  /// 事务内先更新主表，再重建关联表数据。
  Future<void> updateDiary({
    required String diaryId,
    required String title,
    required String contentDocJson,
    required String contentText,
    required String metadataJson,
    String? cover,
    List<int> tagIds = const <int>[],
  }) async {
    final normalizedMetadata = normalizeMetadataJson(metadataJson);
    final normalizedCover = _normalizeCover(cover);
    final normalizedTagIds = tagIds.toSet().toList();

    await transaction<void>(() async {
      final diary = await (select(diaries)
            ..where((Diaries t) => t.diaryId.equals(diaryId)))
          .getSingleOrNull();
      if (diary == null) {
        throw StateError('未找到 diaryId=$diaryId 对应的日记');
      }

      await (update(diaries)
            ..where((Diaries t) => t.diaryId.equals(diaryId)))
          .write(
        DiariesCompanion(
          title: Value<String>(title.trim()),
          content: Value<String>(contentDocJson),
          contentText: Value<String>(contentText),
          cover: Value<String?>(normalizedCover),
          metadata: Value<String>(normalizedMetadata),
          updatedAt: Value<DateTime>(DateTime.now()),
          isArchived: const Value<bool>(false),
          archivedAt: const Value<DateTime?>(null),
          isDeleted: const Value<bool>(false),
          deletedAt: const Value<DateTime?>(null),
        ),
      );

      await _replaceDiaryTags(diary.id, normalizedTagIds);
    });
  }

  /// 置顶日记（固定显示在列表前部）。
  ///
  /// 默认不修改 `updatedAt`，避免仅置顶操作打乱“最近编辑时间”语义。
  Future<void> pinDiary(
    String diaryId, {
    bool touchUpdatedAt = false,
  }) async {
    await (update(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId)))
        .write(
      DiariesCompanion(
        isPinned: const Value<bool>(true),
        updatedAt:
            touchUpdatedAt
                ? Value<DateTime>(DateTime.now())
                : const Value.absent(),
      ),
    );
  }

  /// 取消置顶日记。
  Future<void> unpinDiary(
    String diaryId, {
    bool touchUpdatedAt = false,
  }) async {
    await (update(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId)))
        .write(
      DiariesCompanion(
        isPinned: const Value<bool>(false),
        updatedAt:
            touchUpdatedAt
                ? Value<DateTime>(DateTime.now())
                : const Value.absent(),
      ),
    );
  }

  /// 归档日记（不删除，仅从主列表隐藏）。
  Future<void> archiveDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    final now = DateTime.now();
    await (update(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId)))
        .write(
      DiariesCompanion(
        isArchived: const Value<bool>(true),
        archivedAt: Value<DateTime?>(now),
        updatedAt:
            touchUpdatedAt
                ? Value<DateTime>(now)
                : const Value.absent(),
      ),
    );
  }

  /// 取消归档日记。
  Future<void> unarchiveDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    await (update(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId)))
        .write(
      DiariesCompanion(
        isArchived: const Value<bool>(false),
        archivedAt: const Value<DateTime?>(null),
        updatedAt:
            touchUpdatedAt
                ? Value<DateTime>(DateTime.now())
                : const Value.absent(),
      ),
    );
  }

  /// 软删除日记（不物理删除）。
  ///
  /// `touchUpdatedAt=false` 可用于“可撤销删除”场景，避免恢复后排序变化。
  Future<void> softDeleteDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    final now = DateTime.now();
    await (update(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId)))
        .write(
      DiariesCompanion(
        isArchived: const Value<bool>(false),
        archivedAt: const Value<DateTime?>(null),
        isDeleted: const Value<bool>(true),
        deletedAt: Value<DateTime?>(now),
        updatedAt:
            touchUpdatedAt
                ? Value<DateTime>(now)
                : const Value.absent(),
      ),
    );
  }

  /// 恢复软删除日记。
  ///
  /// `touchUpdatedAt=false` 可用于“撤销删除”场景，避免列表排序跳到最前。
  Future<void> restoreDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    await (update(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId)))
        .write(
      DiariesCompanion(
        isArchived: const Value<bool>(false),
        archivedAt: const Value<DateTime?>(null),
        isDeleted: const Value<bool>(false),
        deletedAt: const Value<DateTime?>(null),
        updatedAt:
            touchUpdatedAt
                ? Value<DateTime>(DateTime.now())
                : const Value.absent(),
      ),
    );
  }

  /// 彻底删除日记（物理删除，不可恢复）。
  ///
  /// 依赖外键级联自动清理 diary_tags 关联关系。
  Future<void> hardDeleteDiary(String diaryId) async {
    final targetDiary =
        await (select(diaries)..where((Diaries t) => t.diaryId.equals(diaryId)))
            .getSingleOrNull();
    if (targetDiary == null) {
      return;
    }

    // 彻删前先清理托管资源文件，避免私有目录残留无主文件。
    await _deleteDiaryManagedAssets(targetDiary);

    await (delete(diaries)..where((Diaries t) => t.diaryId.equals(diaryId))).go();
  }

  /// 按业务 diaryId 获取单条日记及其标签。
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) async {
    final diary =
        await (select(diaries)
          ..where((Diaries t) => t.diaryId.equals(diaryId))).getSingleOrNull();
    if (diary == null) {
      return null;
    }

    final relatedTags = await _getTagsForDiary(diary.id);
    return DiaryWithTags(diary: diary, tags: relatedTags);
  }

  /// 覆盖写入某条日记的标签关系。
  Future<void> _replaceDiaryTags(int diaryId, List<int> tagIds) async {
    await (delete(diaryTags)
      ..where((DiaryTags t) => t.diaryId.equals(diaryId))).go();

    if (tagIds.isEmpty) {
      return;
    }

    await batch((Batch batch) {
      batch.insertAll(
        diaryTags,
        tagIds.map(
          (int tagId) =>
              DiaryTagsCompanion.insert(diaryId: diaryId, tagId: tagId),
        ),
      );
    });
  }

  /// 查询某条日记绑定的全部标签。
  Future<List<Tag>> _getTagsForDiary(int diaryId) async {
    final rows =
        await (select(
                diaryTags,
              ).join([innerJoin(tags, tags.id.equalsExp(diaryTags.tagId))])
              ..where(diaryTags.diaryId.equals(diaryId))
              ..orderBy([OrderingTerm.asc(tags.name)]))
            .get();

    return rows.map((TypedResult row) => row.readTable(tags)).toList();
  }

  /// 删除日记关联的托管资源文件（封面 + 正文图片）。
  Future<void> _deleteDiaryManagedAssets(Diary diary) async {
    await DiaryCoverStorageService.deleteManagedCover(_normalizeCover(diary.cover));

    final imagePaths = _extractManagedImagePathsFromContent(diary.content);
    for (final imagePath in imagePaths) {
      await DiaryMediaStorageService.deleteManagedDiaryImage(imagePath);
    }
  }

  /// 从正文 JSON 中提取所有图片路径（去重）。
  Set<String> _extractManagedImagePathsFromContent(String rawContent) {
    final normalizedContent = rawContent.trim();
    if (normalizedContent.isEmpty) {
      return <String>{};
    }

    try {
      final decoded = jsonDecode(normalizedContent);
      final paths = <String>{};
      _collectImagePathsFromNode(decoded, paths);
      return paths;
    } catch (_) {
      return <String>{};
    }
  }

  /// 递归扫描 JSON 节点，提取图片 embed 路径。
  void _collectImagePathsFromNode(Object? node, Set<String> output) {
    if (node is List) {
      for (final item in node) {
        _collectImagePathsFromNode(item, output);
      }
      return;
    }
    if (node is! Map) {
      return;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final imagePath = _normalizeImagePath(insert['image']);
      if (imagePath != null) {
        output.add(imagePath);
      }
    }

    final type = node['type'];
    if (type == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final attributePath = _normalizeImagePath(attributes['url']);
        if (attributePath != null) {
          output.add(attributePath);
        }
      }
    }

    for (final value in node.values) {
      _collectImagePathsFromNode(value, output);
    }
  }

  String? _normalizeImagePath(Object? rawPath) {
    if (rawPath is! String) {
      return null;
    }
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizeCover(String? rawCover) {
    final normalized = rawCover?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _generateDiaryId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
