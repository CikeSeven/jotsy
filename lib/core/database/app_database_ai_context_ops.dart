part of 'app_database.dart';

/// 发给 AI 的一篇日记（只取提示词需要的字段）。
class AiContextDiary {
  const AiContextDiary({
    required this.diaryId,
    required this.title,
    required this.contentText,
    required this.createdAt,
    required this.isArchived,
    this.mood,
    this.weather,
    this.location,
    this.tags = const <String>[],
    this.contentJson,
  });

  /// 业务 id（引用、打开原文用）。
  final String diaryId;
  final String title;
  final String contentText;

  /// 发表时间（时间胶囊为解封时间），按它划分时间范围。
  final DateTime createdAt;
  final bool isArchived;
  final String? mood;
  final String? weather;
  final String? location;
  final List<String> tags;

  /// 块文档原文：只在需要读图片时（[_AppDatabaseAiContextOps.getAiDiary]）
  /// 带上，批量读取不带，免得把整段正文 JSON 都搬进内存。
  final String? contentJson;
}

/// AI 上下文的日记读取：**多篇上下文只经 [getAiContextDiaries]**。
///
/// 隐私口径（AGENTS.md 的 AI 助手规则）：
/// - 排除回收站与未解封的时间胶囊；
/// - 排除私密日记——即使范围是一本私密日记本也排除：私密本自己的范围会把
///   它的成员放进来（那是私密日记唯一出现的地方），所以这里在
///   [_writeDiaryScopeFilter] 之外**总是再加一层** [_privateDiaryExclusionSql]；
/// - 用户在 AI 隐私设置里排除的日记本（连同子孙本子）与标签也排除。
///
/// 一次性读取（`.get()`），不挂数据库订阅：对话与回顾在发送那一刻取快照。
mixin _AppDatabaseAiContextOps
    on
        _$AppDatabase,
        _AppDatabaseDiaryScopeSql,
        _AppDatabaseDiaryQueries,
        _AppDatabaseDiaryListQueries {
  /// 读取发给 AI 的日记，按发表时间排序（[newestFirst] 决定方向）。
  ///
  /// - [start]（含）/ [end]（不含）限定发表时间；
  /// - [keywords] 非空时只要标题或正文含其中任一词的；
  /// - [requiredTagIds] 为多标签 AND；
  /// - [limit] 为最多篇数（先按时间排序再截断）。
  Future<List<AiContextDiary>> getAiContextDiaries({
    DateTime? start,
    DateTime? end,
    DiaryListScope scope = DiaryListScope.all,
    List<int> requiredTagIds = const <int>[],
    List<String> keywords = const <String>[],
    Set<String> excludedNotebookIds = const <String>{},
    Set<String> excludedTagNames = const <String>{},
    bool includeArchived = true,
    bool newestFirst = false,
    int? limit,
    DateTime? now,
  }) async {
    final variables = <Variable<Object>>[
      Variable<DateTime>(now ?? DateTime.now()),
    ];
    final sql = StringBuffer('''
SELECT
  d.diary_id,
  d.title,
  d.content_text,
  d.created_at,
  d.is_archived,
  json_extract(d.metadata, '\$.context.moodEmoji') AS mood,
  json_extract(d.metadata, '\$.context.weather') AS weather,
  json_extract(d.metadata, '\$.context.location') AS location,
  COALESCE(
    (SELECT json_group_array(t.name) FROM diary_tags dt
     JOIN tags t ON t.id = dt.tag_id WHERE dt.diary_id = d.id),
    '[]'
  ) AS tag_names
FROM diaries d
${_diaryScopeJoinSql(scope)}WHERE d.is_deleted = 0
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
  AND ${_privateDiaryExclusionSql('d.id')}
''');
    if (!includeArchived) sql.writeln('  AND d.is_archived = 0');
    if (start != null) {
      sql.writeln('  AND d.created_at >= ?');
      variables.add(Variable<DateTime>(start));
    }
    if (end != null) {
      sql.writeln('  AND d.created_at < ?');
      variables.add(Variable<DateTime>(end));
    }
    final words = <String>{
      for (final word in keywords)
        if (word.trim().isNotEmpty) word.trim(),
    }.take(24).toList();
    if (words.isNotEmpty) {
      final clauses = <String>[];
      for (final word in words) {
        clauses.add(
          "(d.title LIKE ? ESCAPE '\\' OR d.content_text LIKE ? ESCAPE '\\')",
        );
        final pattern = '%${_escapeAiLike(word)}%';
        variables
          ..add(Variable<String>(pattern))
          ..add(Variable<String>(pattern));
      }
      sql.writeln('  AND (${clauses.join(' OR ')})');
    }
    final tagIds = requiredTagIds.toSet().toList()..sort();
    if (tagIds.isNotEmpty) {
      _writeRequiredTagsFilter(sql, variables, tagIds);
    }
    if (excludedNotebookIds.isNotEmpty) {
      final ids = excludedNotebookIds.toList()..sort();
      sql.writeln(
        '  AND d.id NOT IN (SELECT xdn.diary_id FROM diary_notebooks xdn '
        'WHERE xdn.notebook_id IN (WITH RECURSIVE ex_nb(id, notebook_id) AS ('
        'SELECT id, notebook_id FROM notebooks WHERE notebook_id IN '
        '(${_placeholders(ids.length)}) '
        'UNION SELECT c.id, c.notebook_id FROM notebooks c '
        'JOIN ex_nb p ON c.parent_id = p.notebook_id'
        ') SELECT id FROM ex_nb))',
      );
      variables.addAll(_stringVariables(ids));
    }
    if (excludedTagNames.isNotEmpty) {
      final names = excludedTagNames.toList()..sort();
      sql.writeln(
        '  AND d.id NOT IN (SELECT xdt.diary_id FROM diary_tags xdt '
        'JOIN tags xt ON xt.id = xdt.tag_id '
        'WHERE xt.name IN (${_placeholders(names.length)}))',
      );
      variables.addAll(_stringVariables(names));
    }
    _writeDiaryScopeFilter(sql, variables, scope);
    final direction = newestFirst ? 'DESC' : 'ASC';
    sql.writeln('ORDER BY d.created_at $direction, d.id $direction');
    if (limit != null) {
      sql.writeln('LIMIT ?');
      variables.add(Variable<int>(limit));
    }
    final rows = await customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[
        diaries,
        diaryTags,
        tags,
      ]),
    ).get();
    return <AiContextDiary>[
      for (final row in rows) _mapAiContextRow(row, withContent: false),
    ];
  }

  /// 读一篇日记（含块文档原文），回收站里的与不存在的返回 null。不过滤
  /// 私密：单篇功能由调用方按 AI 隐私设置（`allowPrivate`）决定能否发送。
  Future<AiContextDiary?> getAiDiary(String diaryId) async {
    final row = await customSelect(
      '''
SELECT
  d.diary_id,
  d.title,
  d.content_text,
  d.content,
  d.created_at,
  d.is_archived,
  json_extract(d.metadata, '\$.context.moodEmoji') AS mood,
  json_extract(d.metadata, '\$.context.weather') AS weather,
  json_extract(d.metadata, '\$.context.location') AS location,
  COALESCE(
    (SELECT json_group_array(t.name) FROM diary_tags dt
     JOIN tags t ON t.id = dt.tag_id WHERE dt.diary_id = d.id),
    '[]'
  ) AS tag_names
FROM diaries d
WHERE d.diary_id = ? AND d.is_deleted = 0
''',
      variables: <Variable<Object>>[Variable<String>(diaryId)],
      readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
        diaries,
        diaryTags,
        tags,
      },
    ).getSingleOrNull();
    return row == null ? null : _mapAiContextRow(row, withContent: true);
  }

  AiContextDiary _mapAiContextRow(QueryRow row, {required bool withContent}) {
    String? text(String column) {
      final value = row.readNullable<String>(column)?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final tags = <String>[];
    try {
      final decoded = jsonDecode(row.read<String>('tag_names'));
      if (decoded is List) {
        for (final name in decoded) {
          if (name is String && name.isNotEmpty) tags.add(name);
        }
      }
    } on FormatException {
      // 标签读不出来就当没有标签。
    }
    return AiContextDiary(
      diaryId: row.read<String>('diary_id'),
      title: row.read<String>('title'),
      contentText: row.read<String>('content_text'),
      createdAt: _readDateTime(row, 'created_at'),
      isArchived: row.read<int>('is_archived') != 0,
      mood: text('mood'),
      weather: text('weather'),
      location: text('location'),
      tags: tags,
      contentJson: withContent ? row.read<String>('content') : null,
    );
  }
}
