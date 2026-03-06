import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'content_codec.dart';

part 'app_database.g.dart';
part 'app_database_schema.dart';

@DriftDatabase(tables: <Type>[Diaries, Tags, DiaryTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// 按名称升序实时监听全部标签。
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy(<OrderingTerm Function(Tags)>[
      (Tags t) => OrderingTerm.asc(t.name),
    ])).watch();
  }

  /// 创建标签。
  ///
  /// 若同名标签已存在，则直接返回已有标签 id，避免重复记录。
  Future<int> createTag({required String name, required int color}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('标签名不能为空');
    }

    final existing =
        await (select(tags)
          ..where((Tags t) => t.name.equals(normalizedName))).getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }

    return into(
      tags,
    ).insert(TagsCompanion.insert(name: normalizedName, color: color));
  }

  /// 删除标签（关联关系由外键级联删除）。
  Future<void> deleteTag(int tagId) async {
    await (delete(tags)..where((Tags t) => t.id.equals(tagId))).go();
  }

  /// 创建日记并写入关联标签。
  ///
  /// 事务内完成“主表插入 + 关联表写入”，保证一致性。
  Future<int> createDiary({
    required String title,
    required String plainTextContent,
    required String metadataJson,
    List<int> tagIds = const <int>[],
  }) async {
    final now = DateTime.now();
    final normalizedMetadata = normalizeMetadataJson(metadataJson);
    final normalizedTagIds = tagIds.toSet().toList();

    return transaction<int>(() async {
      final diaryId = await into(diaries).insert(
        DiariesCompanion.insert(
          title: Value<String>(title.trim()),
          content: plainTextToDeltaJson(plainTextContent),
          contentText: plainTextContent,
          metadata: Value<String>(normalizedMetadata),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _replaceDiaryTags(diaryId, normalizedTagIds);
      return diaryId;
    });
  }

  /// 更新日记并覆盖标签绑定关系。
  ///
  /// 事务内先更新主表，再重建关联表数据。
  Future<void> updateDiary({
    required int diaryId,
    required String title,
    required String plainTextContent,
    required String metadataJson,
    List<int> tagIds = const <int>[],
  }) async {
    final normalizedMetadata = normalizeMetadataJson(metadataJson);
    final normalizedTagIds = tagIds.toSet().toList();

    await transaction<void>(() async {
      await (update(diaries)..where((Diaries t) => t.id.equals(diaryId))).write(
        DiariesCompanion(
          title: Value<String>(title.trim()),
          content: Value<String>(plainTextToDeltaJson(plainTextContent)),
          contentText: Value<String>(plainTextContent),
          metadata: Value<String>(normalizedMetadata),
          updatedAt: Value<DateTime>(DateTime.now()),
          isDeleted: const Value<bool>(false),
          deletedAt: const Value<DateTime?>(null),
        ),
      );

      await _replaceDiaryTags(diaryId, normalizedTagIds);
    });
  }

  /// 软删除日记（不物理删除）。
  Future<void> softDeleteDiary(int diaryId) async {
    final now = DateTime.now();
    await (update(diaries)..where((Diaries t) => t.id.equals(diaryId))).write(
      DiariesCompanion(
        isDeleted: const Value<bool>(true),
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// 恢复软删除日记。
  Future<void> restoreDiary(int diaryId) async {
    await (update(diaries)..where((Diaries t) => t.id.equals(diaryId))).write(
      DiariesCompanion(
        isDeleted: const Value<bool>(false),
        deletedAt: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// 按主键获取单条日记及其标签。
  Future<DiaryWithTags?> getDiaryWithTagsById(int diaryId) async {
    final diary =
        await (select(diaries)
          ..where((Diaries t) => t.id.equals(diaryId))).getSingleOrNull();
    if (diary == null) {
      return null;
    }

    final relatedTags = await _getTagsForDiary(diaryId);
    return DiaryWithTags(diary: diary, tags: relatedTags);
  }

  /// 监听日记列表（支持关键词 + 标签 AND 过滤）。
  ///
  /// 查询说明：
  /// 1. 默认仅返回未软删除记录；
  /// 2. 关键词匹配 `title` 与 `content_text`；
  /// 3. 多标签过滤采用 AND 语义；
  /// 4. 通过 SQL 聚合一次性带回标签，减少 N+1 查询。
  Stream<List<DiaryWithTags>> watchDiaries({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
  }) {
    final normalizedKeyword = keyword.trim();
    final likePattern = '%$normalizedKeyword%';
    final normalizedTagIds = requiredTagIds.toSet().toList()..sort();

    final sql = StringBuffer('''
SELECT
  d.id,
  d.title,
  d.content,
  d.content_text,
  d.metadata,
  d.created_at,
  d.updated_at,
  d.is_deleted,
  d.deleted_at,
  COALESCE(
    json_group_array(
      CASE
        WHEN t.id IS NOT NULL THEN json_object('id', t.id, 'name', t.name, 'color', t.color)
      END
    ),
    '[]'
  ) AS tags_json
FROM diaries d
LEFT JOIN diary_tags dt ON dt.diary_id = d.id
LEFT JOIN tags t ON t.id = dt.tag_id
WHERE d.is_deleted = 0
  AND (? = '' OR d.title LIKE ? OR d.content_text LIKE ?)
''');

    final variables = <Variable<Object>>[
      Variable<String>(normalizedKeyword),
      Variable<String>(likePattern),
      Variable<String>(likePattern),
    ];

    if (normalizedTagIds.isNotEmpty) {
      final placeholders = List<String>.filled(
        normalizedTagIds.length,
        '?',
      ).join(', ');
      sql.write('''
  AND d.id IN (
    SELECT dt2.diary_id
    FROM diary_tags dt2
    WHERE dt2.tag_id IN ($placeholders)
    GROUP BY dt2.diary_id
    HAVING COUNT(DISTINCT dt2.tag_id) = ?
  )
''');
      variables.addAll(
        normalizedTagIds.map<Variable<Object>>((int id) => Variable<int>(id)),
      );
      variables.add(Variable<int>(normalizedTagIds.length));
    }

    sql.write('''
GROUP BY d.id
ORDER BY d.updated_at DESC
''');

    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map((List<QueryRow> rows) {
      return rows.map((QueryRow row) {
        return DiaryWithTags(
          diary: _mapDiaryFromRow(row),
          tags: _parseTagsJson(row.read<String>('tags_json')),
        );
      }).toList();
    });
  }

  /// 示例：按 metadata 指定路径和值检索日记。
  ///
  /// `jsonPath` 形如 `$.weather`，底层使用 SQLite JSON1 的 `json_extract`。
  Future<List<Diary>> findDiariesByMetadataValue({
    required String jsonPath,
    required String expectedValue,
  }) async {
    final rows =
        await customSelect(
          '''
SELECT *
FROM diaries
WHERE is_deleted = 0
  AND json_extract(metadata, ?) = ?
ORDER BY updated_at DESC
''',
          variables: <Variable<Object>>[
            Variable<String>(jsonPath),
            Variable<String>(expectedValue),
          ],
          readsFrom: <TableInfo<Table, Object>>{diaries},
        ).get();

    return rows.map(_mapDiaryFromRow).toList();
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

  /// 解析 SQL 聚合得到的标签 JSON 字符串。
  List<Tag> _parseTagsJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) {
        return const <Tag>[];
      }

      return decoded.whereType<Map<String, dynamic>>().map((entry) {
        return Tag(
          id: (entry['id'] as num).toInt(),
          name: entry['name'] as String,
          color: (entry['color'] as num).toInt(),
        );
      }).toList();
    } catch (_) {
      return const <Tag>[];
    }
  }

  /// 将 `customSelect` 行记录映射为 Drift 的 `Diary` 数据对象。
  Diary _mapDiaryFromRow(QueryRow row) {
    return Diary(
      id: row.read<int>('id'),
      title: row.read<String>('title'),
      content: row.read<String>('content'),
      contentText: row.read<String>('content_text'),
      metadata: row.read<String>('metadata'),
      createdAt: _readDateTime(row, 'created_at'),
      updatedAt: _readDateTime(row, 'updated_at'),
      isDeleted: _readBool(row, 'is_deleted'),
      deletedAt: _readNullableDateTime(row, 'deleted_at'),
    );
  }

  /// 兼容 bool 在不同 SQL 场景下的读取类型（bool/int）。
  bool _readBool(QueryRow row, String columnName) {
    final boolValue = row.readNullable<bool>(columnName);
    if (boolValue != null) {
      return boolValue;
    }
    return row.read<int>(columnName) != 0;
  }

  /// 兼容 DateTime 在不同 SQL 场景下的读取类型（DateTime/int）。
  DateTime _readDateTime(QueryRow row, String columnName) {
    final dateTimeValue = row.readNullable<DateTime>(columnName);
    if (dateTimeValue != null) {
      return dateTimeValue;
    }
    final intValue = row.read<int>(columnName);
    if (intValue > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intValue);
    }
    return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
  }

  /// 读取可空 DateTime 字段。
  DateTime? _readNullableDateTime(QueryRow row, String columnName) {
    final dateTimeValue = row.readNullable<DateTime>(columnName);
    if (dateTimeValue != null) {
      return dateTimeValue;
    }
    final intValue = row.readNullable<int>(columnName);
    if (intValue == null) {
      return null;
    }
    if (intValue > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intValue);
    }
    return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
  }
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
