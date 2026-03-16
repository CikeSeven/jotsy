part of 'app_database.dart';

/// 日记查询与映射实现。
///
/// 该分区负责：
/// - 列表监听（普通/归档/回收站）；
/// - 日历页月份打点与按日列表查询；
/// - metadata 条件检索；
/// - SQL 行记录映射为领域对象。
mixin _AppDatabaseDiaryQueries on _$AppDatabase {
  /// 监听全部未删除日记（包含归档与未归档）。
  ///
  /// 用于探索页这类“全量回顾/统计”场景，避免被列表筛选条件影响。
  Stream<List<DiaryWithTags>> watchAllActiveDiaries() {
    return customSelect(
      '''
SELECT
  d.id,
  d.diary_id,
  d.title,
  d.content,
  d.content_text,
  d.cover,
  d.metadata,
  d.created_at,
  d.updated_at,
  d.is_archived,
  d.archived_at,
  d.is_pinned,
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
GROUP BY d.id
ORDER BY d.is_pinned DESC, d.updated_at DESC
''',
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 分页读取“未删除日记”候选集（含归档）。
  ///
  /// 用于探索页媒体画廊按批提取图片来源，避免一次性加载全量日记导致
  /// 首屏等待时间过长或内存抖动。
  Future<List<Diary>> getActiveDiariesPage({
    required int limit,
    required int offset,
  }) {
    final query =
        select(diaries)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy(<OrderingTerm Function(Diaries)>[
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
            (tbl) => OrderingTerm.desc(tbl.id),
          ])
          ..limit(limit, offset: offset);
    return query.get();
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
  d.diary_id,
  d.title,
  d.content,
  d.content_text,
  d.cover,
  d.metadata,
  d.created_at,
  d.updated_at,
  d.is_archived,
  d.archived_at,
  d.is_pinned,
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
  AND d.is_archived = 0
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
ORDER BY d.is_pinned DESC, d.updated_at DESC
''');

    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 监听已归档日记列表（仅归档且未删除）。
  Stream<List<DiaryWithTags>> watchArchivedDiaries() {
    return customSelect(
      '''
SELECT
  d.id,
  d.diary_id,
  d.title,
  d.content,
  d.content_text,
  d.cover,
  d.metadata,
  d.created_at,
  d.updated_at,
  d.is_archived,
  d.archived_at,
  d.is_pinned,
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
  AND d.is_archived = 1
GROUP BY d.id
ORDER BY d.is_pinned DESC, d.updated_at DESC
''',
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 监听回收站日记列表（仅软删除记录）。
  Stream<List<DiaryWithTags>> watchDeletedDiaries() {
    return customSelect(
      '''
SELECT
  d.id,
  d.diary_id,
  d.title,
  d.content,
  d.content_text,
  d.cover,
  d.metadata,
  d.created_at,
  d.updated_at,
  d.is_archived,
  d.archived_at,
  d.is_pinned,
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
WHERE d.is_deleted = 1
GROUP BY d.id
ORDER BY d.deleted_at DESC, d.updated_at DESC
''',
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 监听“某天创建的日记列表”（含归档，不含已删除）。
  ///
  /// 日期按本地时区边界切分，使用 `[dayStart, nextDayStart)` 范围查询。
  Stream<List<DiaryWithTags>> watchDiariesCreatedOnDay(DateTime day) {
    final dayStart = _dateOnly(day);
    final nextDayStart = dayStart.add(const Duration(days: 1));
    return customSelect(
      '''
SELECT
  d.id,
  d.diary_id,
  d.title,
  d.content,
  d.content_text,
  d.cover,
  d.metadata,
  d.created_at,
  d.updated_at,
  d.is_archived,
  d.archived_at,
  d.is_pinned,
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
  AND d.created_at >= ?
  AND d.created_at < ?
GROUP BY d.id
ORDER BY d.created_at ASC, d.updated_at ASC, d.id ASC
''',
      variables: <Variable<Object>>[
        Variable<DateTime>(dayStart),
        Variable<DateTime>(nextDayStart),
      ],
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 监听“某月的日历打点元数据”（含归档，不含已删除）。
  ///
  /// 返回轻量结构 `DiaryCalendarMarker`，只用于月历标记渲染。
  Stream<List<DiaryCalendarMarker>> watchDiaryMarkersByMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonthStart = DateTime(month.year, month.month + 1);
    return customSelect(
      '''
SELECT
  diary_id,
  created_at,
  json_extract(metadata, '\$.context.moodEmoji') AS mood_emoji
FROM diaries
WHERE is_deleted = 0
  AND created_at >= ?
  AND created_at < ?
ORDER BY created_at ASC
''',
      variables: <Variable<Object>>[
        Variable<DateTime>(monthStart),
        Variable<DateTime>(nextMonthStart),
      ],
      readsFrom: <TableInfo<Table, Object>>{diaries},
    ).watch().map((rows) {
      return rows
          .map((row) {
            final rawMood = row.readNullable<String>('mood_emoji');
            final mood = rawMood?.trim();
            return DiaryCalendarMarker(
              diaryId: row.read<String>('diary_id'),
              createdAt: _readDateTime(row, 'created_at'),
              moodEmoji: (mood == null || mood.isEmpty) ? null : mood,
            );
          })
          .toList(growable: false);
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
  AND is_archived = 0
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

  /// 映射“日记 + 标签”聚合行。
  List<DiaryWithTags> _mapDiaryWithTagsRows(List<QueryRow> rows) {
    return rows
        .map((row) {
          return DiaryWithTags(
            diary: _mapDiaryFromRow(row),
            tags: _parseTagsJson(row.read<String>('tags_json')),
          );
        })
        .toList(growable: false);
  }

  /// 解析 SQL 聚合得到的标签 JSON 字符串。
  List<Tag> _parseTagsJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) {
        return const <Tag>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((entry) {
            return Tag(
              id: (entry['id'] as num).toInt(),
              name: entry['name'] as String,
              color: (entry['color'] as num).toInt(),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const <Tag>[];
    }
  }

  /// 将 `customSelect` 行记录映射为 Drift 的 `Diary` 数据对象。
  Diary _mapDiaryFromRow(QueryRow row) {
    return Diary(
      id: row.read<int>('id'),
      diaryId: row.read<String>('diary_id'),
      title: row.read<String>('title'),
      content: row.read<String>('content'),
      contentText: row.read<String>('content_text'),
      cover: row.readNullable<String>('cover'),
      metadata: row.read<String>('metadata'),
      createdAt: _readDateTime(row, 'created_at'),
      updatedAt: _readDateTime(row, 'updated_at'),
      isArchived: _readBool(row, 'is_archived'),
      archivedAt: _readNullableDateTime(row, 'archived_at'),
      isPinned: _readBool(row, 'is_pinned'),
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

  DateTime _dateOnly(DateTime input) {
    return DateTime(input.year, input.month, input.day);
  }
}
