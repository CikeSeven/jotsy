part of 'app_database.dart';

/// 日记查询的范围（[DiaryListScope]）与私密排除：所有日记读取共用的 SQL 片段。
///
/// 私密规则（唯一权威口径）：一篇日记只要在至少一本“手动 + 非 normal 可见性”
/// 的日记本里就是私密日记。私密日记：
/// - 不出现在任何全局查询里（全部日记、搜索、探索、日历、归档、导出候选等）；
/// - 只在它所在的那本私密日记本的范围里出现；
/// - 普通日记本与智能日记本的范围同样排除它（私密优先于其他归属）。
/// 回收站与按 id 直接打开不过滤，原因见各自的注释。
///
/// 凡是用到私密排除或成员关系的查询，`readsFrom` 都必须包含 `notebooks` 与
/// `diary_notebooks`：把日记加进 / 移出加锁的本子、改本子的可见性时，列表流
/// 才会重新推送（[_diaryScopeReadsFrom]）。
///
/// 输入：范围对象；输出：SQL 片段与参数（写入调用方的 StringBuffer / 列表）；
/// 无副作用。
mixin _AppDatabaseDiaryScopeSql on _$AppDatabase {
  /// [base] 加上范围与私密排除依赖的表。
  ///
  /// 私密排除对每种范围都生效，所以日记本两表总在其中；智能范围的谓词可能
  /// 引用标签（如“含某标签”），再加上标签两表。
  Set<ResultSetImplementation<HasResultSet, dynamic>> _diaryScopeReadsFrom(
    DiaryListScope scope,
    Iterable<ResultSetImplementation<HasResultSet, dynamic>> base,
  ) {
    return <ResultSetImplementation<HasResultSet, dynamic>>{
      ...base,
      notebooks,
      diaryNotebooks,
      if (scope is DiarySmartScope) ...<TableInfo>[diaryTags, tags],
    };
  }

  /// 写在 `FROM diaries d` 之后的连接：只有手动日记本范围需要连上成员行
  /// （别名 `sdn`）与日记本（别名 `sn`），供章节过滤与成书顺序使用。
  ///
  /// 不带参数：日记本 id 的条件写在 WHERE 里（[_writeDiaryScopeFilter]），
  /// 调用方的参数顺序因此只取决于 SELECT 列与 WHERE。同一篇日记在同一本里
  /// 只有一行（复合主键），连接不会让日记重复。
  String _diaryScopeJoinSql(DiaryListScope scope) {
    return switch (scope) {
      DiaryNotebookScope() =>
        'JOIN diary_notebooks sdn ON sdn.diary_id = d.id\n'
            'JOIN notebooks sn ON sn.id = sdn.notebook_id\n',
      DiaryAllScope() || DiarySmartScope() => '',
    };
  }

  /// 追加范围条件（以 `AND` 开头的若干行），含私密排除。须与
  /// [_diaryScopeJoinSql] 配对使用，接在调用方自己的 WHERE 条件之后。
  void _writeDiaryScopeFilter(
    StringBuffer sql,
    List<Variable<Object>> variables,
    DiaryListScope scope,
  ) {
    switch (scope) {
      case DiaryAllScope():
        sql.writeln('  AND ${_privateDiaryExclusionSql('d.id')}');
      case DiaryNotebookScope():
        sql.writeln('  AND sn.notebook_id = ?');
        variables.add(Variable<String>(scope.notebookId));
        // 只有手动本有成员行，sn 必是手动本；本子自己私密时显示全部成员
        // （这是私密日记唯一出现的地方），否则同样排除私密日记。
        sql.writeln(
          "  AND (sn.visibility <> '${NotebookVisibility.normal.name}' "
          "OR ${_privateDiaryExclusionSql('d.id')})",
        );
        final chapterId = scope.chapterId;
        if (chapterId != null) {
          sql.writeln('  AND sdn.chapter_id = ?');
          variables.add(Variable<String>(chapterId));
        } else if (scope.unassignedChapterOnly &&
            scope.chapterOrder.isNotEmpty) {
          // 章节列表为空时所有成员都算未分章，不加条件。
          sql.writeln(
            '  AND (sdn.chapter_id IS NULL OR sdn.chapter_id NOT IN '
            '(${_placeholders(scope.chapterOrder.length)}))',
          );
          variables.addAll(_stringVariables(scope.chapterOrder));
        }
      case DiarySmartScope():
        sql.writeln('  AND (${scope.predicate.sql})');
        variables.addAll(scope.predicate.variables);
        sql.writeln('  AND ${_privateDiaryExclusionSql('d.id')}');
    }
  }

  /// 成书顺序里的章节序号表达式：章节在 `chapterOrder` 中的下标，未分章与
  /// 认不出的章节排在最后。参数按出现顺序追加到 [variables]，调用方须在写
  /// SELECT 列时立即调用（它出现在 SQL 文本的最前面）。
  String _bookChapterRankSql(
    DiaryNotebookScope scope,
    List<Variable<Object>> variables,
  ) {
    final order = scope.chapterOrder;
    if (order.isEmpty) {
      // 没有章节时 CASE 没有 WHEN 分支（语法不允许），所有成员同一序号。
      return '0';
    }
    variables.addAll(_stringVariables(order));
    final whens = <String>[
      for (var i = 0; i < order.length; i++) 'WHEN ? THEN $i',
    ].join(' ');
    return 'CASE sdn.chapter_id $whens ELSE ${order.length} END';
  }

  /// 私密日记的业务 id（含回收站里的），用于回收站等不按范围过滤、但要
  /// 标出私密日记的地方。
  Stream<Set<String>> watchPrivateDiaryIds() {
    return customSelect(
      'SELECT d.diary_id FROM diaries d WHERE d.id IN ($_privateDiaryIdsSql)',
      readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
        diaries,
        notebooks,
        diaryNotebooks,
      },
    ).watch().map(
      (rows) => <String>{for (final row in rows) row.read<String>('diary_id')},
    );
  }

  /// 这篇日记当前是否私密；不存在的 id 为 false。
  Future<bool> isDiaryPrivate(String diaryId) async {
    final row = await customSelect(
      'SELECT EXISTS (SELECT 1 FROM diaries d WHERE d.diary_id = ? '
      'AND d.id IN ($_privateDiaryIdsSql)) AS private',
      variables: <Variable<Object>>[Variable<String>(diaryId)],
      readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
        diaries,
        notebooks,
        diaryNotebooks,
      },
    ).getSingle();
    return row.read<int>('private') != 0;
  }
}

/// 全部私密日记的本地 id：在至少一本手动、可见性不是 normal 的日记本里。
///
/// - 可见性按“不等于 normal”判断而不是列举 hidden / locked：更新版本写入的
///   未知可见性一律当作私密，宁可多藏也不意外露出；
/// - 未知类型的本子不算（只有手动本能私密，写入时非手动本一律存 normal）；
/// - `diary_notebooks.diary_id` 非空，NOT IN 不会因子查询含 NULL 而整体为空；
/// - 不相关子查询，SQLite 只执行一次并建临时索引，不随日记数逐行重跑。
final String _privateDiaryIdsSql =
    'SELECT pdn.diary_id FROM diary_notebooks pdn '
    'JOIN notebooks pn ON pn.id = pdn.notebook_id '
    "WHERE pn.kind = '${NotebookKind.manual.name}' "
    "AND pn.visibility <> '${NotebookVisibility.normal.name}'";

/// 排除私密日记的条件，[idColumn] 是外层日记表的本地 id 列（如 `d.id`）。
/// 所有全局日记查询都经它过滤，见 [_AppDatabaseDiaryScopeSql] 的私密规则。
String _privateDiaryExclusionSql(String idColumn) =>
    '$idColumn NOT IN ($_privateDiaryIdsSql)';

String _placeholders(int count) => List<String>.filled(count, '?').join(', ');

List<Variable<Object>> _stringVariables(List<String> values) =>
    <Variable<Object>>[for (final value in values) Variable<String>(value)];
