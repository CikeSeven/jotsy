import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// 验证性能索引在“全新建库”与“旧库升级”两条路径下都正确创建。
///
/// 背景：schemaVersion 7 为高频查询列补建索引：
/// - diaries: updated_at / created_at / capsule_unlock_at
/// - diary_tags: tag_id
///
/// 新库由 `m.createAll()`（依据 @TableIndex 注解）建索引；
/// 旧库由 `_migrateAddPerformanceIndexes()` 通过 `CREATE INDEX IF NOT EXISTS` 补建。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedIndexes = <String>{
    'idx_diaries_updated_at',
    'idx_diaries_created_at',
    'idx_diaries_capsule_unlock_at',
    'idx_diary_tags_tag_id',
    'idx_diaries_active_updated',
    'idx_diaries_active_created',
  };

  /// 从 sqlite_master 读取当前库中所有用户定义索引名。
  Future<Set<String>> readIndexNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name NOT LIKE 'sqlite_autoindex_%'",
        )
        .get();
    return rows.map((QueryRow row) => row.read<String>('name')).toSet();
  }

  test('全新建库包含全部性能索引', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // 触发建库（首次查询会惰性打开并执行 onCreate）。
    final indexes = await readIndexNames(db);

    expect(
      indexes,
      containsAll(expectedIndexes),
      reason: '新库应通过 createAll 依据 @TableIndex 建出全部索引',
    );
  });

  test('索引名称无重复定义（createAll 与手写迁移命名一致）', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name LIKE 'idx_%'",
        )
        .get();
    final names = rows.map((QueryRow r) => r.read<String>('name')).toList();

    expect(names.length, names.toSet().length, reason: '索引名不应重复');
  });

  test('旧库（v6，无索引）升级后补建全部性能索引', () async {
    // 在磁盘临时文件上手工搭建一个 schemaVersion=6 的旧库：
    // 仅建出迁移所需的两张表（无任何性能索引），并写入 user_version=6，
    // 然后用当前 AppDatabase 打开，触发 onUpgrade。
    final tempDir = await Directory.systemTemp.createTemp('jotsy_mig_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final documentsDirectory = await Directory(
      '${tempDir.path}/documents',
    ).create();
    final temporaryDirectory = await Directory(
      '${tempDir.path}/temporary',
    ).create();
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return switch (call.method) {
            'getTemporaryDirectory' => temporaryDirectory.path,
            'getApplicationDocumentsDirectory' => documentsDirectory.path,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null),
    );
    final dbFile = File('${tempDir.path}/legacy_v6.sqlite');

    // 第一步：以原始 sqlite3 写出 v6 结构（不含 idx_* 索引）。
    final legacy = sqlite3.open(dbFile.path);
    legacy.execute('''
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
);
''');
    legacy.execute('''
CREATE TABLE tags (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color INTEGER NOT NULL
);
''');
    legacy.execute('''
CREATE TABLE diary_tags (
  diary_id INTEGER NOT NULL REFERENCES diaries (id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
  PRIMARY KEY (diary_id, tag_id)
);
''');
    legacy.execute('PRAGMA user_version = 6;');

    // 确认旧库确实没有性能索引（基线对照）。
    final beforeRows = legacy.select(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'index' AND name LIKE 'idx_%'",
    );
    expect(beforeRows, isEmpty, reason: '旧库基线不应含 idx_* 索引');
    legacy.close();

    // 第二步：用当前 AppDatabase 打开同一文件，触发 onUpgrade。
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final indexes = await readIndexNames(db);
    expect(indexes, containsAll(expectedIndexes), reason: '旧库升级应补建全部索引');
  });

  test('v9 upgrade adds list indexes and preserves all stored data', () async {
    final root = await Directory.systemTemp.createTemp('jotsy_v9_indexes');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/v9.sqlite');
    final original = AppDatabase.forTesting(NativeDatabase(file));
    late DiaryWithTags before;
    late Anniversary anniversary;
    try {
      final tag = await original.createTag(name: '保留标签', color: 0xff225588);
      final id = await original.createDiary(
        title: '保留正文与封面',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        cover: '/private/cover.jpg',
        metadataJson: '{"context":{"moodEmoji":"😊"}}',
        tagIds: [tag],
      );
      await original.archiveDiary(id);
      await original.pinDiary(id);
      before = (await original.getDiaryWithTagsByDiaryId(id))!;
      await original.createAnniversary(
        title: '保留纪念日',
        baseDate: DateTime(2026, 10, 17),
        recurrence: AnniversaryRecurrence.solarYearly,
        linkedDiaryId: id,
      );
      anniversary = (await original.watchAnniversaries().first).single;
    } finally {
      await original.close();
    }
    // v9 的表结构与当前版本相同，仅缺少两项列表索引。
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP INDEX idx_diaries_active_updated');
    legacy.execute('DROP INDEX idx_diaries_active_created');
    legacy.execute('PRAGMA user_version = 9');
    legacy.close();

    // 第二次打开已经是当前版本，验证重开不会重复执行索引迁移。
    for (var attempt = 0; attempt < 2; attempt++) {
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(await readIndexNames(migrated), containsAll(expectedIndexes));
        final after = (await migrated.getDiaryWithTagsByDiaryId(
          before.diary.diaryId,
        ))!;
        expect(after.diary, before.diary);
        expect(after.tags, before.tags);
        expect((await migrated.watchAnniversaries().first).single, anniversary);
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), migrated.schemaVersion);
      } finally {
        await migrated.close();
      }
    }
  });
}
