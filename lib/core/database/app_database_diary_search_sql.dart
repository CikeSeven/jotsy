part of 'app_database.dart';

/// 首页 / 搜索口径的 WHERE 片段：未删除（默认也未归档）+ 关键词 + 标签 AND
/// + 搜索筛选谓词 + 范围（含私密排除）。
///
/// 列表分页、完整 id 序列（预览翻页）、时间轴与计数都经 [_writeActiveDiaryFilter]
/// 生成条件，口径因此处处一致：搜索页显示的“共 N 篇”、列表里的卡片与预览页
/// 左右翻到的篇目永远是同一批。
///
/// 关键词按 [splitSearchTerms] 拆成多个词，每个词都必须出现（各自在标题、
/// 已解封的正文或留言里任一处即可）；用户输入经 [escapeLike] 转义，`%`、`_`
/// 按字面匹配。输入：条件参数；输出：写入调用方的 SQL 与参数；无副作用。
mixin _AppDatabaseDiarySearchSql on _$AppDatabase, _AppDatabaseDiaryScopeSql {
  /// 追加 `WHERE …`：调用方须先写 `FROM diaries d` 与 [_diaryScopeJoinSql]。
  ///
  /// - [includeArchived]：搜索页勾选“含归档”时为 true，其余查询一律排除归档；
  /// - [filter]：搜索页的筛选（时间、心情、媒体、天气、地点，由智能日记本的
  ///   规则编译而来），作用于别名 `d`，参数按出现顺序排在标签之后、范围之前；
  /// - 不限“未归档”也不需要关键词的查询（如探索）直接用 [_writeDiaryScopeFilter]。
  void _writeActiveDiaryFilter(
    StringBuffer sql,
    List<Variable<Object>> variables, {
    required String normalizedKeyword,
    required List<int> normalizedTagIds,
    required DiaryListScope scope,
    bool matchComments = false,
    bool includeArchived = false,
    DiaryScopePredicate? filter,
  }) {
    sql.write('WHERE d.is_deleted = 0\n');
    if (!includeArchived) {
      sql.write('  AND d.is_archived = 0\n');
    }
    // 无关键词时不引用 title/content_text：让首屏 id 查询可以只读排序索引，
    // 不必为一个恒真的 OR 条件访问每篇日记的大文本列。
    final terms = splitSearchTerms(normalizedKeyword);
    if (terms.isNotEmpty) {
      // “已解封”的时刻对所有词相同，取一次。
      final now = DateTime.now();
      for (final term in terms) {
        _writeKeywordTermFilter(
          sql,
          variables,
          pattern: containsLikePattern(term),
          now: now,
          matchComments: matchComments,
        );
      }
    }
    if (normalizedTagIds.isNotEmpty) {
      _writeRequiredTagsFilter(sql, variables, normalizedTagIds);
    }
    if (filter != null) {
      sql.writeln('  AND (${filter.sql})');
      variables.addAll(filter.variables);
    }
    _writeDiaryScopeFilter(sql, variables, scope);
  }

  /// 一个词的条件：标题含它，或（已解封时）正文 / 留言含它。
  ///
  /// 留言与正文同属“解封后才看得到”的内容：未解封的胶囊只按标题匹配。
  void _writeKeywordTermFilter(
    StringBuffer sql,
    List<Variable<Object>> variables, {
    required String pattern,
    required DateTime now,
    required bool matchComments,
  }) {
    final commentMatch = matchComments
        ? '''
      OR EXISTS (
        SELECT 1 FROM diary_comments c
        WHERE c.diary_id = d.diary_id AND c.content LIKE ? ESCAPE '\\'
      )'''
        : '';
    sql.write('''
  AND (
    d.title LIKE ? ESCAPE '\\'
    OR ((d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?) AND (
      d.content_text LIKE ? ESCAPE '\\'$commentMatch
    ))
  )
''');
    variables
      ..add(Variable<String>(pattern))
      ..add(Variable<DateTime>(now))
      ..add(Variable<String>(pattern));
    if (matchComments) variables.add(Variable<String>(pattern));
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

  /// [_writeActiveDiaryFilter] 额外依赖的表（基础表与范围依赖之外）：
  ///
  /// - 关键词也匹配留言时订阅留言表（写留言后搜索结果随之更新）；其余情况
  ///   不订阅，写留言不会让首页列表连同正文整页重查；
  /// - 有筛选谓词时订阅标签两表：谓词由智能日记本规则编译而来，规则可能
  ///   引用标签（与 [_diaryScopeReadsFrom] 对智能范围的处理一致）。
  List<TableInfo> _activeFilterReadsFrom({
    required String keyword,
    required bool matchComments,
    DiaryScopePredicate? filter,
  }) => <TableInfo>[
    if (matchComments && keyword.trim().isNotEmpty) diaryComments,
    if (filter != null) ...<TableInfo>[diaryTags, tags],
  ];
}
