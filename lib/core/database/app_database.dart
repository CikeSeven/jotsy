import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'content_codec.dart';

part 'app_database.g.dart';

class Diaries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title =>
      text().withLength(min: 0, max: 200).withDefault(const Constant(''))();

  TextColumn get content => text()();

  TextColumn get contentText => text().named('content_text')();

  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 40).unique()();

  IntColumn get color => integer()();
}

class DiaryTags extends Table {
  IntColumn get diaryId =>
      integer()
          .named('diary_id')
          .references(Diaries, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer()
          .named('tag_id')
          .references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{diaryId, tagId};
}

class DiaryWithTags {
  const DiaryWithTags({required this.diary, required this.tags});

  final Diary diary;
  final List<Tag> tags;
}

@DriftDatabase(tables: <Type>[Diaries, Tags, DiaryTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy(<OrderingTerm Function(Tags)>[
      (Tags t) => OrderingTerm.asc(t.name),
    ])).watch();
  }

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

  Future<void> deleteTag(int tagId) async {
    await (delete(tags)..where((Tags t) => t.id.equals(tagId))).go();
  }

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

  Future<void> restoreDiary(int diaryId) async {
    await (update(diaries)..where((Diaries t) => t.id.equals(diaryId))).write(
      DiariesCompanion(
        isDeleted: const Value<bool>(false),
        deletedAt: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

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

  bool _readBool(QueryRow row, String columnName) {
    final boolValue = row.readNullable<bool>(columnName);
    if (boolValue != null) {
      return boolValue;
    }
    return row.read<int>(columnName) != 0;
  }

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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File(p.join(root.path, 'node_note.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
