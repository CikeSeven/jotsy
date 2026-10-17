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
  d.capsule_unlock_at,
  d.capsule_locked_at,
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
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
GROUP BY d.id
ORDER BY d.is_pinned DESC, d.updated_at DESC
''',
      variables: <Variable<Object>>[Variable<DateTime>(DateTime.now())],
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 监听探索页轻量概览数据。
  ///
  /// 只读取统计与卡片展示需要的字段，刻意避开富文本 Delta `content`，
  /// 让探索页切入/刷新时不再被全量正文传输和正文图片解析拖慢。
  Stream<List<ExploreDiaryOverview>> watchExploreDiaryOverviews() {
    return customSelect(
      '''
SELECT
  d.diary_id,
  d.title,
  d.content_text,
  d.cover,
  d.metadata,
  d.created_at,
  d.updated_at,
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
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
GROUP BY d.id
ORDER BY d.updated_at DESC, d.id DESC
''',
      variables: <Variable<Object>>[Variable<DateTime>(DateTime.now())],
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapExploreOverviewRows);
  }

  /// 分页读取“未删除日记”候选集（含归档）。
  ///
  /// 用于探索页媒体画廊按批提取图片来源，避免一次性加载全量日记导致
  /// 首屏等待时间过长或内存抖动。
  Future<List<Diary>> getActiveDiariesPage({
    required int limit,
    required int offset,
  }) {
    final query = select(diaries)
      ..where(
        (tbl) =>
            tbl.isDeleted.equals(false) &
            (tbl.capsuleUnlockAt.isNull() |
                tbl.capsuleUnlockAt.isSmallerOrEqualValue(DateTime.now())),
      )
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
  /// 1. 默认仅返回未软删除、未归档记录；
  /// 2. 关键词匹配 `title` 与 `content_text`；
  /// 3. 多标签过滤采用 AND 语义；
  /// 4. [limit]/[offset] 直接下推到 SQL，避免首页/搜索先拉全量再本地截断。
  Stream<List<DiaryWithTags>> watchDiaries({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
    int? limit,
    int offset = 0,
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
  }) {
    final normalizedKeyword = keyword.trim();
    final normalizedTagIds = requiredTagIds.toSet().toList()..sort();
    final variables = <Variable<Object>>[];
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
  d.capsule_unlock_at,
  d.capsule_locked_at,
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
''');

    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: normalizedKeyword,
      normalizedTagIds: normalizedTagIds,
    );

    sql.write('''
GROUP BY d.id
${_diaryOrderBySql(sortMode)}
''');

    if (limit != null) {
      final normalizedLimit = limit < 0 ? 0 : limit;
      final normalizedOffset = offset < 0 ? 0 : offset;
      sql.write('LIMIT ? OFFSET ?\n');
      variables
        ..add(Variable<int>(normalizedLimit))
        ..add(Variable<int>(normalizedOffset));
    }

    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 按首页 / 搜索列表的同一筛选与排序取出全部日记 id（只取 id，不带正文）。
  ///
  /// 预览页左右滑动时用它把列表里还没加载的部分接上：筛选与排序复用
  /// [_writeActiveDiaryFilter] 与 [_diaryOrderBySql]，口径与列表完全一致。
  Future<List<String>> getActiveDiaryIds({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
  }) async {
    final normalizedTagIds = requiredTagIds.toSet().toList()..sort();
    final variables = <Variable<Object>>[];
    final sql = StringBuffer('SELECT d.diary_id FROM diaries d\n');
    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: keyword.trim(),
      normalizedTagIds: normalizedTagIds,
    );
    sql.write('${_diaryOrderBySql(sortMode)}\n');
    final rows = await customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags},
    ).get();
    return rows
        .map((row) => row.read<String>('diary_id'))
        .toList(growable: false);
  }

  void _writeActiveDiaryFilter(
    StringBuffer sql,
    List<Variable<Object>> variables, {
    required String normalizedKeyword,
    required List<int> normalizedTagIds,
  }) {
    final likePattern = '%$normalizedKeyword%';
    sql.write('''
WHERE d.is_deleted = 0
  AND d.is_archived = 0
  AND (
    ? = ''
    OR d.title LIKE ?
    OR ((d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?) AND d.content_text LIKE ?)
  )
''');
    variables
      ..add(Variable<String>(normalizedKeyword))
      ..add(Variable<String>(likePattern))
      ..add(Variable<DateTime>(DateTime.now()))
      ..add(Variable<String>(likePattern));

    if (normalizedTagIds.isEmpty) {
      return;
    }

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

  /// 生成列表排序子句：置顶在前，再按 [sortMode] 的依据与方向排序。
  ///
  /// - 末键总是唯一的 `d.id`，让顺序成为全序：分页窗口扩大（LIMIT 变大）
  ///   重新查询时，同一时间戳或同名日记的相对次序不变，加载更多不会换位；
  /// - 标题排序先按“是否无标题”分组：无标题（含纯空格）的日记在卡片上统一
  ///   显示为“无标题”，按空串排进 A→Z 最前没有意义，所以正/倒序都排在最后；
  ///   同名时最近更新的在前。
  String _diaryOrderBySql(DiarySortMode sortMode) {
    final direction = switch (sortMode.direction) {
      DiarySortDirection.descending => 'DESC',
      DiarySortDirection.ascending => 'ASC',
    };
    return switch (sortMode.field) {
      DiarySortField.updatedAt =>
        'ORDER BY d.is_pinned DESC, d.updated_at $direction, d.id $direction',
      DiarySortField.createdAt =>
        'ORDER BY d.is_pinned DESC, d.created_at $direction, d.id $direction',
      DiarySortField.title =>
        "ORDER BY d.is_pinned DESC, TRIM(d.title) = '' ASC, "
            'LOWER(TRIM(d.title)) $direction, d.updated_at DESC, d.id DESC',
    };
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
  d.capsule_unlock_at,
  d.capsule_locked_at,
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
  d.capsule_unlock_at,
  d.capsule_locked_at,
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

  /// 日历按日期范围查询日记时共用的列与标签聚合（含归档，不含已删除）。
  static const String _calendarDiaryWithTagsSelect = '''
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
  d.capsule_unlock_at,
  d.capsule_locked_at,
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
''';

  /// 监听“某天创建的日记列表”（含归档，不含已删除）。
  ///
  /// 日期按本地时区边界切分，使用 `[dayStart, nextDayStart)` 范围查询。
  Stream<List<DiaryWithTags>> watchDiariesCreatedOnDay(DateTime day) {
    final dayStart = _dateOnly(day);
    final nextDayStart = dayStart.add(const Duration(days: 1));
    return customSelect(
      '''
$_calendarDiaryWithTagsSelect
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

  /// 监听单篇日记及其标签（含归档，不含回收站中的）；不存在或已删除时推送
  /// null。用于纪念日关联的日记：日记进回收站后关联显示为“已删除”，从回收站
  /// 恢复后自动回来。
  Stream<DiaryWithTags?> watchActiveDiaryWithTags(String diaryId) {
    return customSelect(
      '''
$_calendarDiaryWithTagsSelect
  AND d.diary_id = ?
GROUP BY d.id
''',
      variables: <Variable<Object>>[Variable<String>(diaryId)],
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map((List<QueryRow> rows) {
      final mapped = _mapDiaryWithTagsRows(rows);
      return mapped.isEmpty ? null : mapped.first;
    });
  }

  /// 监听落在任一 `[start, end)` 区间内的日记（含归档，不含已删除），按创建
  /// 时间倒序。
  ///
  /// 用于日历“那年今日”：区间由调用方按本地日期逐年算好再传入，而不是在
  /// SQL 里用 `strftime(..., 'localtime')` 取月日——时区换算交给 Dart 与
  /// 其他日历查询保持同一口径，也兼容早期以毫秒存储的时间戳。
  Stream<List<DiaryWithTags>> watchDiariesCreatedInRanges(
    List<(DateTime, DateTime)> ranges,
  ) {
    if (ranges.isEmpty) {
      return Stream<List<DiaryWithTags>>.value(const <DiaryWithTags>[]);
    }
    final conditions = List<String>.filled(
      ranges.length,
      '(d.created_at >= ? AND d.created_at < ?)',
    ).join(' OR ');
    return customSelect(
      '''
$_calendarDiaryWithTagsSelect
  AND ($conditions)
GROUP BY d.id
ORDER BY d.created_at DESC, d.id DESC
''',
      variables: <Variable<Object>>[
        for (final (start, end) in ranges) ...<Variable<Object>>[
          Variable<DateTime>(start),
          Variable<DateTime>(end),
        ],
      ],
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 监听“某月的日历打点元数据”（含归档，不含已删除）。
  ///
  /// 返回轻量结构 `DiaryCalendarMarker`，只用于月历标记渲染。
  Stream<List<DiaryCalendarMarker>> watchDiaryMarkersByMonth(DateTime month) {
    return watchDiaryMarkersInRange(
      DateTime(month.year, month.month),
      DateTime(month.year, month.month + 1),
    );
  }

  /// 监听 `[start, end)` 内的日历打点元数据（含归档，不含已删除）。
  ///
  /// 字数要按 `TextStats` 的口径（汉字与全角标点各算 1、非中文按词）计算，
  /// SQL 做不到，所以读出纯文本在映射时计数，并按 (diaryId, updatedAt) 缓存，
  /// 数据库流再次推送时未改动的日记不再重新扫描。
  ///
  /// 标签色与标签 id（日历按标签筛选用）各用一个相关子查询拼接，而不是
  /// JOIN + GROUP BY：每篇日记仍是一行，且打点不需要标签名。group_concat
  /// 本身不保证顺序，内层按标签 id 排序后再拼接，同一天的标签色点不会随
  /// 查询计划变化而换位。readsFrom 包含标签两表，增删标签或改标签色后日期
  /// 格会刷新。
  Stream<List<DiaryCalendarMarker>> watchDiaryMarkersInRange(
    DateTime start,
    DateTime end,
  ) {
    return customSelect(
      '''
SELECT
  d.diary_id,
  d.created_at,
  d.cover,
  d.capsule_unlock_at,
  d.updated_at,
  d.content_text,
  json_extract(d.metadata, '\$.context.moodEmoji') AS mood_emoji,
  json_extract(d.metadata, '\$.context.weather') AS weather,
  json_extract(d.metadata, '\$.context.weatherIconCode') AS weather_icon_code,
  (
    SELECT group_concat(color)
    FROM (
      SELECT t.color AS color
      FROM diary_tags dt
      JOIN tags t ON t.id = dt.tag_id
      WHERE dt.diary_id = d.id
      ORDER BY dt.tag_id
    )
  ) AS tag_colors,
  (
    SELECT group_concat(tag_id)
    FROM (
      SELECT dt.tag_id AS tag_id
      FROM diary_tags dt
      WHERE dt.diary_id = d.id
      ORDER BY dt.tag_id
    )
  ) AS tag_ids
FROM diaries d
WHERE d.is_deleted = 0
  AND d.created_at >= ?
  AND d.created_at < ?
ORDER BY d.created_at ASC, d.id ASC
''',
      variables: <Variable<Object>>[
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
      readsFrom: <TableInfo<Table, Object>>{diaries, diaryTags, tags},
    ).watch().map((rows) {
      return rows
          .map((row) {
            final diaryId = row.read<String>('diary_id');
            return DiaryCalendarMarker(
              diaryId: diaryId,
              createdAt: _readDateTime(row, 'created_at'),
              moodEmoji: _readTrimmedText(row, 'mood_emoji'),
              wordCount: DiaryWordCounts.of(
                diaryId: diaryId,
                updatedAt: _readDateTime(row, 'updated_at'),
                text: row.readNullable<String>('content_text') ?? '',
              ),
              cover: _readTrimmedText(row, 'cover'),
              weather: _readTrimmedText(row, 'weather'),
              weatherIconCode: _readTrimmedText(row, 'weather_icon_code'),
              capsuleUnlockAt: _readNullableDateTime(row, 'capsule_unlock_at'),
              tagColors: _parseIntList(row.data['tag_colors']),
              tagIds: _parseIntList(row.data['tag_ids']),
            );
          })
          .toList(growable: false);
    });
  }

  /// 监听 `[start, end)` 内可能带正文图片、且没有显式封面的日记正文。
  ///
  /// 只在日历照片样式下订阅：`LIKE '%"image"%'` 先在数据库线程（后台
  /// isolate）里排除纯文字日记，UI 层只需解析少量候选正文。Quill 的
  /// `{"insert":{"image":…}}` 与旧版 AppFlowy 的 `"type":"image"` 都含该
  /// 片段，取图规则与日记卡片一致（见 DiaryCardViewData）。
  Stream<List<DiaryImageCandidate>> watchDiaryImageCandidatesInRange(
    DateTime start,
    DateTime end,
  ) {
    return customSelect(
      '''
SELECT
  diary_id,
  updated_at,
  content
FROM diaries
WHERE is_deleted = 0
  AND created_at >= ?
  AND created_at < ?
  AND (cover IS NULL OR trim(cover) = '')
  AND content LIKE '%"image"%'
ORDER BY created_at ASC, id ASC
''',
      variables: <Variable<Object>>[
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
      readsFrom: <TableInfo<Table, Object>>{diaries},
    ).watch().map((rows) {
      return rows
          .map((row) {
            return DiaryImageCandidate(
              diaryId: row.read<String>('diary_id'),
              updatedAt: _readDateTime(row, 'updated_at'),
              content: row.read<String>('content'),
            );
          })
          .toList(growable: false);
    });
  }

  /// 读取可空文本列并去首尾空白；非字符串（如 metadata 里写成数字）按
  /// toString 处理，空串视为 null。
  String? _readTrimmedText(QueryRow row, String columnName) {
    final value = row.data[columnName]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// 解析 `group_concat` 拼出的逗号分隔整数；无标签时为 NULL。
  List<int> _parseIntList(Object? raw) {
    if (raw == null) {
      return const <int>[];
    }
    return raw
        .toString()
        .split(',')
        .map((String part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  /// 示例：按 metadata 指定路径和值检索日记。
  ///
  /// `jsonPath` 形如 `$.weather`，底层使用 SQLite JSON1 的 `json_extract`。
  Future<List<Diary>> findDiariesByMetadataValue({
    required String jsonPath,
    required String expectedValue,
  }) async {
    final rows = await customSelect(
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

  /// 映射探索页轻量概览行。
  List<ExploreDiaryOverview> _mapExploreOverviewRows(List<QueryRow> rows) {
    return rows
        .map((row) {
          return ExploreDiaryOverview(
            diaryId: row.read<String>('diary_id'),
            title: row.read<String>('title'),
            contentText: row.read<String>('content_text'),
            cover: row.readNullable<String>('cover'),
            metadata: row.read<String>('metadata'),
            createdAt: _readDateTime(row, 'created_at'),
            updatedAt: _readDateTime(row, 'updated_at'),
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
      capsuleUnlockAt: _readNullableDateTime(row, 'capsule_unlock_at'),
      capsuleLockedAt: _readNullableDateTime(row, 'capsule_locked_at'),
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
