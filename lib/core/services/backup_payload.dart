import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import 'backup_constants.dart';
import 'backup_media_paths.dart';
import 'backup_settings.dart';
import 'settings_service.dart';

/// 强类型备份数据及表结构/关联校验；解析、媒体重绑阶段不修改现有数据。
/// writeDatabase 只在外层恢复事务内写表，文件换入和设置回滚交由归档服务。
class BackupPayload {
  const BackupPayload({
    required this.diaries,
    required this.tags,
    required this.diaryTags,
    this.settings,
  });

  final List<Diary> diaries;
  final List<Tag> tags;
  final List<DiaryTag> diaryTags;
  final Map<String, dynamic>? settings;

  factory BackupPayload.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份数据格式错误');
    }
    final version = decoded['formatVersion'];
    // 无版本标记时仍严格校验 v1 表结构；明确标记的未知版本不能按空库导入。
    if (version != null && version != backupFormatVersion) {
      throw const FormatException('不支持的备份版本');
    }
    final database = decoded['database'];
    if (database is! Map<String, dynamic>) {
      throw const FormatException('备份数据缺少 database 节点');
    }
    final settings = decoded['settings'];
    if (settings != null && settings is! Map<String, dynamic>) {
      throw const FormatException('备份设置格式错误');
    }

    try {
      final payload = BackupPayload(
        diaries: _rows(database, 'diaries')
            .map((row) {
              return Diary.fromJson({
                // 这些字段随 schema 演进新增，旧备份省略时采用数据库默认值。
                'isArchived': false,
                'isPinned': false,
                'isDeleted': false,
                ...row,
              });
            })
            .toList(growable: false),
        tags: _rows(database, 'tags').map(Tag.fromJson).toList(growable: false),
        diaryTags: _rows(
          database,
          'diaryTags',
        ).map(DiaryTag.fromJson).toList(growable: false),
        settings: settings as Map<String, dynamic>?,
      );
      payload._validateRelations();
      return payload;
    } on TypeError {
      throw const FormatException('备份数据字段格式错误');
    }
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> database,
    String name,
  ) {
    final rows = database[name];
    // 空表必须明确写为 []，不能把缺失、错误类型或坏行悄悄当作空表。
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw FormatException('备份表 $name 格式错误');
    }
    return rows.cast<Map<String, dynamic>>();
  }

  void _validateRelations() {
    final diaryIds = _unique(diaries.map((row) => row.id));
    final tagIds = _unique(tags.map((row) => row.id));
    _unique(diaries.map((row) => row.diaryId));
    _unique(tags.map((row) => row.name));
    _unique(diaryTags.map((row) => (row.diaryId, row.tagId)));
    if (diaries.any(
          (row) =>
              row.id <= 0 ||
              row.diaryId.trim().isEmpty ||
              row.title.length > 200,
        ) ||
        tags.any(
          (row) => row.id <= 0 || row.name.isEmpty || row.name.length > 40,
        ) ||
        diaryTags.any(
          (row) =>
              !diaryIds.contains(row.diaryId) || !tagIds.contains(row.tagId),
        )) {
      throw const FormatException('备份数据约束或标签关联无效');
    }
  }

  static Set<T> _unique<T>(Iterable<T> values) {
    final result = <T>{};
    for (final value in values) {
      if (!result.add(value)) {
        throw const FormatException('备份数据包含重复记录');
      }
    }
    return result;
  }

  static Future<Map<String, Object?>> capture({
    required AppDatabase database,
    required SettingsService settingsService,
  }) async {
    // 三张表读取同一个事务快照，避免日记与标签在导出时不同步。
    final tables = await database.transaction(
      () async => <String, Object?>{
        'diaries': (await database.select(database.diaries).get())
            .map((row) => row.toJson())
            .toList(),
        'tags': (await database.select(database.tags).get())
            .map((row) => row.toJson())
            .toList(),
        'diaryTags': (await database.select(database.diaryTags).get())
            .map((row) => row.toJson())
            .toList(),
      },
    );
    return {
      'formatVersion': backupFormatVersion,
      'generatedAt': DateTime.now().toIso8601String(),
      'database': tables,
      'settings': BackupSettings.capture(settingsService),
    };
  }

  Future<BackupPayload> rebindMedia(BackupMediaPaths paths) async {
    final restored = <Diary>[];
    for (final diary in diaries) {
      restored.add(
        diary.copyWith(
          content: await paths.rewriteContent(diary.content),
          cover: Value(
            await paths.rewritePath(
              diary.cover,
              directoryNames: const ['diary_covers', 'diary_images'],
            ),
          ),
        ),
      );
    }
    final restoredSettings = settings == null
        ? null
        : Map<String, dynamic>.from(settings!);
    final rawDraft = restoredSettings?['createDiaryDraftRaw'];
    if (rawDraft is String && rawDraft.isNotEmpty) {
      try {
        final draft = jsonDecode(rawDraft);
        if (draft is Map<String, dynamic>) {
          if (draft['contentDocJson'] is String) {
            draft['contentDocJson'] = await paths.rewriteContent(
              draft['contentDocJson'] as String,
            );
          }
          if (draft['cover'] is String) {
            draft['cover'] = await paths.rewritePath(
              draft['cover'] as String,
              directoryNames: const ['diary_covers', 'diary_images'],
            );
          }
          restoredSettings!['createDiaryDraftRaw'] = jsonEncode(draft);
        }
      } on FormatException {
        // 历史草稿容错行为保持一致；不会因此覆盖或删除原媒体。
      }
    }
    return BackupPayload(
      diaries: restored,
      tags: tags,
      diaryTags: diaryTags,
      settings: restoredSettings,
    );
  }

  /// 调用方负责整个恢复事务；生成的 companion 自动包含所有 schema 字段。
  Future<void> writeDatabase(AppDatabase database) async {
    await database.delete(database.diaryTags).go();
    await database.delete(database.diaries).go();
    await database.delete(database.tags).go();
    await database.batch((batch) {
      batch.insertAll(
        database.tags,
        tags.map((row) => row.toCompanion(false)).toList(),
      );
      batch.insertAll(
        database.diaries,
        diaries.map((row) => row.toCompanion(false)).toList(),
      );
      batch.insertAll(
        database.diaryTags,
        diaryTags.map((row) => row.toCompanion(false)).toList(),
      );
    });
  }
}
