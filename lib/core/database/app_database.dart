import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../utils/text_stats.dart';
import 'content_codec.dart';
import 'diary_list_scope.dart';
import 'notebook_payload.dart';
import 'sync_rows.dart';
import '../services/app_data_directory.dart';

export 'diary_list_scope.dart';
export 'notebook_cover_style.dart';
export 'notebook_payload.dart';
export 'notebook_rules.dart';
export 'sync_rows.dart';

part 'app_database.g.dart';
part 'app_database_schema.dart';
part 'app_database_tag_ops.dart';
part 'app_database_diary_writes.dart';
part 'app_database_diary_scope_sql.dart';
part 'app_database_diary_queries.dart';
part 'app_database_diary_list_queries.dart';
part 'app_database_migrations.dart';
part 'app_database_anniversary_schema.dart';
part 'app_database_anniversary_ops.dart';
part 'app_database_draft_schema.dart';
part 'app_database_draft_ops.dart';
part 'app_database_template_schema.dart';
part 'app_database_template_ops.dart';
part 'app_database_notebook_schema.dart';
part 'app_database_notebook_ops.dart';
part 'app_database_notebook_entry_ops.dart';
part 'app_database_notebook_stats_ops.dart';
part 'app_database_explore_ops.dart';
part 'app_database_notebook_hierarchy.dart';
part 'app_database_notebook_tree_ops.dart';
part 'app_database_day_mood_schema.dart';
part 'app_database_day_mood_ops.dart';
part 'app_database_comment_schema.dart';
part 'app_database_comment_ops.dart';
part 'app_database_sync_ops.dart';
part 'app_database_sync_writes.dart';
part 'app_database_sync_order.dart';

@DriftDatabase(
  tables: <Type>[
    Diaries,
    Tags,
    DiaryTags,
    Anniversaries,
    DiaryDrafts,
    DiaryTemplates,
    Notebooks,
    DiaryNotebooks,
    DayMoods,
    DiaryComments,
  ],
)
class AppDatabase extends _$AppDatabase
    with
        _AppDatabaseTagOps,
        _AppDatabaseDiaryScopeSql,
        _AppDatabaseDiaryQueries,
        _AppDatabaseDiaryListQueries,
        _AppDatabaseNotebookEntryOps,
        _AppDatabaseDiaryWrites,
        _AppDatabaseAnniversaryOps,
        _AppDatabaseDraftOps,
        _AppDatabaseTemplateOps,
        _AppDatabaseNotebookTreeOps,
        _AppDatabaseNotebookOps,
        _AppDatabaseNotebookStatsOps,
        _AppDatabaseExploreOps,
        _AppDatabaseDayMoodOps,
        _AppDatabaseCommentOps,
        _AppDatabaseSyncOps,
        _AppDatabaseSyncWrites,
        _AppDatabaseSyncOrder,
        _AppDatabaseMigrations {
  AppDatabase() : super(_openConnection());

  /// 测试专用构造：注入自定义 [QueryExecutor]（如内存库），
  /// 便于在不依赖文件系统的前提下验证迁移与查询行为。
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  /// 新的业务唯一 id（UUID v4），与日记、纪念日、草稿、模板、日记本、留言写库时生成的
  /// 同一种。
  /// 供数据库之外需要先定好 id 的场合使用（如旧备份里的单份草稿转为草稿行）。
  static String newBusinessId() => _newBusinessUuid();

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // v9 新增独立的纪念日表，与日记表无关联，放在最前：下面 v1 的分支
      // 重建日记表后直接 return，排在后面会被跳过。
      if (from < 9) {
        await m.createTable(anniversaries);
      }
      // v11 草稿箱表同样独立于日记表，也要排在 v1 分支之前。
      if (from < 11) {
        await _migrateAddDiaryDrafts(m);
      }
      // v12 日记模板表同样独立，排在 v1 分支之前。
      if (from < 12) {
        await _migrateAddDiaryTemplates(m);
      }
      // v13 日记本表与关联表只引用日记的本地 id、不改日记表，同样排在 v1
      // 分支之前。
      if (from < 13) {
        await _migrateAddNotebooks(m);
      }
      // v14 这天的心情表只以日期为键、与其他表都无关联，同样排在 v1 分支之前。
      if (from < 14) {
        await _migrateAddDayMoods(m);
      }
      // v15 日记本加上级列（嵌套），只动日记本表，同样排在 v1 分支之前；
      // 必须在 v13 分支之后：从 v13 之前升级时那里已按最新定义建表、自带此列。
      if (from < 15) {
        await _migrateNotebooksAddParent(m);
      }
      // v16 日记留言表只存日记的业务 id、不改日记表，同样排在 v1 分支之前。
      if (from < 16) {
        await _migrateAddDiaryComments(m);
      }
      if (from < 2) {
        await _migrateDiariesAddBusinessId();
        // v1 分支已重建最新日记结构，不再逐列迁移，但仍需补齐当前索引。
        await _migrateAddPerformanceIndexes();
        await _migrateAddDiaryListIndexes(m);
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
      if (from < 8) {
        await _migrateRebindImportedMediaPaths();
      }
      if (from < 10) {
        await _migrateAddDiaryListIndexes(m);
      }
    },
  );
}

/// 打开 SQLite 连接。
///
/// 数据库存储在应用数据根目录（[appDataRootDirectory]：手机为文档目录，
/// 桌面为应用支持目录），文件名固定为 `node_diary.sqlite`。
/// 使用后台 isolate 建库，避免阻塞主线程。
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final root = await appDataRootDirectory();
    final file = File(p.join(root.path, 'node_diary.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
