part of 'app_database.dart';

/// 历史版本迁移实现。
///
/// 单独拆分迁移逻辑，避免主数据库文件被一次性历史 SQL 细节淹没。
mixin _AppDatabaseMigrations
    on _$AppDatabase, _AppDatabaseDiaryQueries, _AppDatabaseDiaryWrites {
  Future<void> _migrateDiariesAddBusinessId() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    await transaction(() async {
      await customStatement('ALTER TABLE diaries RENAME TO diaries_old');
      await customStatement('''
CREATE TABLE diaries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  diary_id TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL,
  content_text TEXT NOT NULL,
  cover TEXT NULL,
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  archived_at INTEGER NULL,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  capsule_unlock_at INTEGER NULL,
  capsule_locked_at INTEGER NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER NULL
)
''');

      final rows = await customSelect('''
SELECT
  id,
  title,
  content,
  content_text,
  NULL AS cover,
  metadata,
  created_at,
  updated_at,
  0 AS is_archived,
  NULL AS archived_at,
  0 AS is_pinned,
  NULL AS capsule_unlock_at,
  NULL AS capsule_locked_at,
  is_deleted,
  deleted_at
FROM diaries_old
ORDER BY id
''').get();

      for (final row in rows) {
        await into(diaries).insert(
          DiariesCompanion(
            id: Value<int>(row.read<int>('id')),
            diaryId: Value<String>(_generateDiaryId()),
            title: Value<String>(row.read<String>('title')),
            content: Value<String>(row.read<String>('content')),
            contentText: Value<String>(row.read<String>('content_text')),
            cover: Value<String?>(row.readNullable<String>('cover')),
            metadata: Value<String>(row.read<String>('metadata')),
            createdAt: Value<DateTime>(_readDateTime(row, 'created_at')),
            updatedAt: Value<DateTime>(_readDateTime(row, 'updated_at')),
            isArchived: Value<bool>(_readBool(row, 'is_archived')),
            archivedAt: Value<DateTime?>(
              _readNullableDateTime(row, 'archived_at'),
            ),
            isPinned: Value<bool>(_readBool(row, 'is_pinned')),
            capsuleUnlockAt: Value<DateTime?>(
              _readNullableDateTime(row, 'capsule_unlock_at'),
            ),
            capsuleLockedAt: Value<DateTime?>(
              _readNullableDateTime(row, 'capsule_locked_at'),
            ),
            isDeleted: Value<bool>(_readBool(row, 'is_deleted')),
            deletedAt: Value<DateTime?>(
              _readNullableDateTime(row, 'deleted_at'),
            ),
          ),
        );
      }

      await customStatement('DROP TABLE diaries_old');
    });
    await customStatement('PRAGMA foreign_keys = ON');
  }

  Future<void> _migrateDiariesAddArchiveFields() async {
    await customStatement('''
ALTER TABLE diaries
ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0
''');
    await customStatement('''
ALTER TABLE diaries
ADD COLUMN archived_at INTEGER NULL
''');
  }

  Future<void> _migrateDiariesAddCoverField() async {
    await customStatement('''
ALTER TABLE diaries
ADD COLUMN cover TEXT NULL
''');
  }

  Future<void> _migrateDiariesAddPinnedField() async {
    await customStatement('''
ALTER TABLE diaries
ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0
''');
  }

  Future<void> _migrateDiariesAddCapsuleFields() async {
    await customStatement('''
ALTER TABLE diaries
ADD COLUMN capsule_unlock_at INTEGER NULL
''');
    await customStatement('''
ALTER TABLE diaries
ADD COLUMN capsule_locked_at INTEGER NULL
''');
  }

  /// 为高频查询列补建索引（schemaVersion 7）。
  ///
  /// 背景：列表默认按 `updated_at` 倒序、日历/“那年今日”按 `created_at` 范围扫描、
  /// 时间胶囊过滤按 `capsule_unlock_at`、按标签反查走 `diary_tags.tag_id`。
  /// 旧库这些列无索引，数据量增大后会触发全表扫描/临时排序。
  ///
  /// 说明：
  /// - 新库由 `m.createAll()` 依据 `@TableIndex` 注解自动建索引，本迁移仅服务旧库升级；
  /// - 统一使用 `IF NOT EXISTS` 保证幂等，避免与历史可能存在的同名索引冲突；
  /// - `diary_tags.diary_id` 已由复合主键 `{diary_id, tag_id}` 的前缀覆盖，无需重复建。
  Future<void> _migrateAddPerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_diaries_updated_at '
      'ON diaries (updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_diaries_created_at '
      'ON diaries (created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_diaries_capsule_unlock_at '
      'ON diaries (capsule_unlock_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_diary_tags_tag_id '
      'ON diary_tags (tag_id)',
    );
  }

  /// Imports performed by releases before schema 8 restored image files into
  /// this installation but kept the exporting app's absolute paths in rows.
  /// Rebind only embedded media whose extracted target exists so external
  /// files and remote images retain their original behavior.
  Future<void> _migrateRebindImportedMediaPaths() async {
    final documents = await getApplicationDocumentsDirectory();
    final rows = await customSelect(
      'SELECT id, content, cover FROM diaries',
    ).get();
    for (final row in rows) {
      final id = row.read<int>('id');
      final content = row.read<String>('content');
      final cover = row.readNullable<String>('cover');
      final repairedContent = await _rebindEmbeddedImagePaths(
        content,
        documents,
      );
      final repairedCover = await _rebindManagedMediaPath(
        cover,
        documents,
        const <String>['diary_covers', 'diary_images'],
      );
      if (repairedContent == content && repairedCover == cover) {
        continue;
      }

      if (repairedCover == null) {
        await customUpdate(
          'UPDATE diaries SET content = ?, cover = NULL WHERE id = ?',
          variables: <Variable>[
            Variable<String>(repairedContent),
            Variable<int>(id),
          ],
          updates: {diaries},
        );
      } else {
        await customUpdate(
          'UPDATE diaries SET content = ?, cover = ? WHERE id = ?',
          variables: <Variable>[
            Variable<String>(repairedContent),
            Variable<String>(repairedCover),
            Variable<int>(id),
          ],
          updates: {diaries},
        );
      }
    }
  }

  Future<String> _rebindEmbeddedImagePaths(
    String content,
    Directory documents,
  ) async {
    Object? value;
    try {
      value = jsonDecode(content);
    } on FormatException {
      return content;
    }
    await _rebindImageNode(value, documents);
    return jsonEncode(value);
  }

  Future<void> _rebindImageNode(Object? node, Directory documents) async {
    if (node is List) {
      for (final child in node) {
        await _rebindImageNode(child, documents);
      }
      return;
    }
    if (node is! Map) return;

    final insert = node['insert'];
    if (insert is Map && insert['image'] is String) {
      insert['image'] = await _rebindManagedMediaPath(
        insert['image'] as String,
        documents,
        const <String>['diary_images'],
      );
    }
    if (node['type'] == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map && attributes['url'] is String) {
        attributes['url'] = await _rebindManagedMediaPath(
          attributes['url'] as String,
          documents,
          const <String>['diary_images'],
        );
      }
    }
    for (final child in node.values.toList(growable: false)) {
      await _rebindImageNode(child, documents);
    }
  }

  Future<String?> _rebindManagedMediaPath(
    String? source,
    Directory documents,
    List<String> managedDirectories,
  ) async {
    final path = source?.trim();
    if (path == null || path.isEmpty) return source;

    final segments = p.posix
        .split(path.replaceAll('\\', '/'))
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList(growable: false);
    for (final directory in managedDirectories) {
      final index = segments.lastIndexOf(directory);
      if (index < 0 || index + 1 >= segments.length) continue;
      final relative = p.posix.normalize(
        p.posix.joinAll(segments.skip(index + 1)),
      );
      if (relative == '..' ||
          relative.startsWith('../') ||
          p.posix.isAbsolute(relative)) {
        return source;
      }
      final candidate = p.join(documents.path, directory, relative);
      if (await File(candidate).exists()) return candidate;
    }
    return source;
  }
}
