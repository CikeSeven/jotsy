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

      final rows =
          await customSelect('''
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
}
