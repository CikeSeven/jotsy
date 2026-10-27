part of 'app_database.dart';

/// 首页与搜索的分页查询、预览翻页的完整 id 序列及其共用筛选/排序口径。
///
/// 先确定轻量 id 窗口，再读取正文和标签；查询只读。每个查询都带一个
/// [DiaryListScope]（默认全部日记），范围条件与私密排除由
/// [_AppDatabaseDiaryScopeSql] 生成，`readsFrom` 一并订阅日记本两表。
mixin _AppDatabaseDiaryListQueries
    on _$AppDatabase, _AppDatabaseDiaryScopeSql, _AppDatabaseDiaryQueries {
  /// 监听日记列表（支持关键词 + 标签 AND 过滤）。
  ///
  /// 查询说明：
  /// 1. 默认仅返回未软删除、未归档记录；
  /// 2. 关键词匹配 `title` 与 `content_text`；
  /// 3. 多标签过滤采用 AND 语义；
  /// 4. 先在只含 id 的窗口内筛选、排序与分页，再读取正文并聚合标签；
  ///    否则 JOIN + GROUP BY 会先为全部命中项聚合标签与搬运正文，最后才
  ///    截取首屏。即使 LIMIT 很小，也会随整个日记库线性变慢；
  /// 5. [scope] 限定范围并排除私密日记；日记本范围开启成书顺序时忽略
  ///    [sortMode]，排序键（章节序号、本内位置）由 id 窗口带出，外层按同一
  ///    组键排序。
  Stream<List<DiaryWithTags>> watchDiaries({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
    int? limit,
    int offset = 0,
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
    DiaryListScope scope = DiaryListScope.all,
  }) {
    final normalizedKeyword = keyword.trim();
    final normalizedTagIds = requiredTagIds.toSet().toList()..sort();
    final variables = <Variable<Object>>[];
    final bookScope = _bookOrderScope(scope);
    final sql = StringBuffer('WITH diary_page AS (\n  SELECT d.id');
    if (bookScope != null) {
      // 章节序号的参数出现在 SQL 最前面，须先于 WHERE 的参数加入。
      sql.write(
        ', ${_bookChapterRankSql(bookScope, variables)} AS chapter_rank, '
        '${_bookPositionSql(bookScope, variables)} AS book_pos',
      );
    }
    sql.write('\n  FROM diaries d\n${_diaryScopeJoinSql(scope)}');
    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: normalizedKeyword,
      normalizedTagIds: normalizedTagIds,
      scope: scope,
    );
    sql.writeln(
      bookScope != null ? _bookOrderBySql() : _diaryOrderBySql(sortMode),
    );
    if (limit != null) {
      sql.write('LIMIT ? OFFSET ?\n');
      variables
        ..add(Variable<int>(limit < 0 ? 0 : limit))
        ..add(Variable<int>(offset < 0 ? 0 : offset));
    }
    sql.write('''
)
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
FROM diary_page page
JOIN diaries d ON d.id = page.id
LEFT JOIN diary_tags dt ON dt.diary_id = d.id
LEFT JOIN tags t ON t.id = dt.tag_id
GROUP BY d.id
${bookScope != null ? _bookOrderBySql(prefix: 'page.') : _diaryOrderBySql(sortMode)}
''');

    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[
        diaries,
        diaryTags,
        tags,
      ]),
    ).watch().map(_mapDiaryWithTagsRows);
  }

  /// 按首页 / 搜索列表的同一筛选与排序取出全部日记 id（只取 id，不带正文）。
  ///
  /// 预览页左右滑动时用它把列表里还没加载的部分接上：筛选、范围与排序复用
  /// [_writeActiveDiaryFilter] 与 [_diaryOrderBySql] / [_bookOrderBySql]，
  /// 口径与列表完全一致。
  Future<List<String>> getActiveDiaryIds({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
    DiaryListScope scope = DiaryListScope.all,
  }) async {
    final normalizedTagIds = requiredTagIds.toSet().toList()..sort();
    final variables = <Variable<Object>>[];
    final bookScope = _bookOrderScope(scope);
    final sql = StringBuffer('SELECT d.diary_id');
    if (bookScope != null) {
      sql.write(
        ', ${_bookChapterRankSql(bookScope, variables)} AS chapter_rank, '
        '${_bookPositionSql(bookScope, variables)} AS book_pos',
      );
    }
    sql.write(' FROM diaries d\n${_diaryScopeJoinSql(scope)}');
    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: keyword.trim(),
      normalizedTagIds: normalizedTagIds,
      scope: scope,
    );
    sql.writeln(
      bookScope != null ? _bookOrderBySql() : _diaryOrderBySql(sortMode),
    );
    final rows = await customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[diaries, diaryTags]),
    ).get();
    return rows
        .map((row) => row.read<String>('diary_id'))
        .toList(growable: false);
  }

  /// 范围内未删除、未归档的日记篇数（含私密排除）：智能日记本的实时篇数与
  /// 书架篇数。
  Stream<int> watchScopedDiaryCount(DiaryListScope scope) {
    final variables = <Variable<Object>>[];
    final sql = StringBuffer(
      'SELECT COUNT(*) AS c FROM diaries d\n${_diaryScopeJoinSql(scope)}',
    );
    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: '',
      normalizedTagIds: const <int>[],
      scope: scope,
    );
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[diaries]),
    ).watch().map((rows) => rows.single.read<int>('c'));
  }

  /// 范围内未删除、未归档的日记用到的标签 id：在日记本里时首页标签栏只列
  /// 这些，避免点了一个本子里没有的标签得到空列表。
  Stream<Set<int>> watchTagIdsUsedInScope(DiaryListScope scope) {
    final variables = <Variable<Object>>[];
    final sql = StringBuffer('''
SELECT DISTINCT dt.tag_id AS tag_id
FROM diary_tags dt
WHERE dt.diary_id IN (
  SELECT d.id FROM diaries d
${_diaryScopeJoinSql(scope)}''');
    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: '',
      normalizedTagIds: const <int>[],
      scope: scope,
    );
    sql.write(')\n');
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[diaries, diaryTags]),
    ).watch().map(
      (rows) => <int>{for (final row in rows) row.read<int>('tag_id')},
    );
  }

  /// 首页 / 搜索口径的 WHERE：未删除、未归档 + 关键词 + 标签 AND + [scope]
  /// （含私密排除）。调用方须先在 `FROM diaries d` 后写入
  /// [_diaryScopeJoinSql]；不限“未归档”的查询（如探索）直接用
  /// [_writeDiaryScopeFilter]。
  void _writeActiveDiaryFilter(
    StringBuffer sql,
    List<Variable<Object>> variables, {
    required String normalizedKeyword,
    required List<int> normalizedTagIds,
    required DiaryListScope scope,
  }) {
    sql.write('''
WHERE d.is_deleted = 0
  AND d.is_archived = 0
''');
    // 无关键词时不引用 title/content_text：让首屏 id 查询可以只读排序索引，
    // 不必为一个恒真的 OR 条件访问每篇日记的大文本列。
    if (normalizedKeyword.isNotEmpty) {
      final likePattern = '%$normalizedKeyword%';
      sql.write('''
  AND (
    d.title LIKE ?
    OR ((d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?) AND d.content_text LIKE ?)
  )
''');
      variables
        ..add(Variable<String>(likePattern))
        ..add(Variable<DateTime>(DateTime.now()))
        ..add(Variable<String>(likePattern));
    }

    if (normalizedTagIds.isNotEmpty) {
      _writeRequiredTagsFilter(sql, variables, normalizedTagIds);
    }
    _writeDiaryScopeFilter(sql, variables, scope);
  }

  /// 多标签 AND：日记须同时带有全部所选标签。
  void _writeRequiredTagsFilter(
    StringBuffer sql,
    List<Variable<Object>> variables,
    List<int> normalizedTagIds,
  ) {
    final placeholders = _placeholders(normalizedTagIds.length);
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

  /// 需要按成书顺序排列时返回日记本范围，否则为 null。
  DiaryNotebookScope? _bookOrderScope(DiaryListScope scope) =>
      scope is DiaryNotebookScope && scope.bookOrder ? scope : null;

  /// 成书顺序：章节序号 → 本内位置 → 创建时间 → 本地 id（全序，分页稳定）。
  ///
  /// 置顶不浮到最前：一本书的目录顺序是固定的，置顶是全局时间线上的概念，
  /// 在这里插队会打乱章节。[prefix] 为空时引用同一层 SELECT 的列别名
  /// （`chapter_rank` / `book_pos`，见 [_bookChapterRankSql] 与
  /// [_bookPositionSql]）；外层查询传 `page.`，按 id 窗口带出的同一组键排序。
  String _bookOrderBySql({String prefix = ''}) {
    return 'ORDER BY ${prefix}chapter_rank ASC, ${prefix}book_pos ASC, '
        'd.created_at ASC, d.id ASC';
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
}
