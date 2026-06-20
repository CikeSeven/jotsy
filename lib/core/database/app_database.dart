import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';

import 'content_codec.dart';

part 'app_database.g.dart';
part 'app_database_schema.dart';
part 'app_database_tag_ops.dart';
part 'app_database_diary_writes.dart';
part 'app_database_diary_queries.dart';
part 'app_database_migrations.dart';

@DriftDatabase(tables: <Type>[Diaries, Tags, DiaryTags])
class AppDatabase extends _$AppDatabase
    with
        _AppDatabaseTagOps,
        _AppDatabaseDiaryQueries,
        _AppDatabaseDiaryWrites,
        _AppDatabaseMigrations {
  AppDatabase() : super(_openConnection());

  /// 测试专用构造：注入自定义 [QueryExecutor]（如内存库），
  /// 便于在不依赖文件系统的前提下验证迁移与查询行为。
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await _migrateDiariesAddBusinessId();
        return;
      }
      if (from < 3) {
        await _migrateDiariesAddArchiveFields();
      }
      if (from < 4) {
        await _migrateDiariesAddCoverField();
      }
      if (from < 5) {
        await _migrateDiariesAddPinnedField();
      }
      if (from < 6) {
        await _migrateDiariesAddCapsuleFields();
      }
      if (from < 7) {
        await _migrateAddPerformanceIndexes();
      }
    },
  );
}

/// 打开 SQLite 连接。
///
/// 数据库存储在应用文档目录，文件名固定为 `node_diary.sqlite`。
/// 使用后台 isolate 建库，避免阻塞主线程。
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File(p.join(root.path, 'node_diary.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
