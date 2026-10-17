part of 'app_database.dart';

/// 首页与搜索的分页查询、预览翻页的完整 id 序列及其共用筛选/排序口径。
///
/// 先确定轻量 id 窗口，再读取正文和标签；保持查询只读及订阅失效范围不变。
mixin _AppDatabaseDiaryListQueries on _$AppDatabase, _AppDatabaseDiaryQueries {
  /// 监听日记列表（支持关键词 + 标签 AND 过滤）。
  ///
  /// 查询说明：
  /// 1. 默认仅返回未软删除、未归档记录；
  /// 2. 关键词匹配 `title` 与 `content_text`；
  /// 3. 多标签过滤采用 AND 语义；
  /// 4. 先在只含 id 的窗口内筛选、排序与分页，再读取正文并聚合标签；
  ///    否则 JOIN + GROUP BY 会先为全部命中项聚合标签与搬运正文，最后才
  ///    截取首屏。即使 LIMIT 很小，也会随整个日记库线性变慢。
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
WITH diary_page AS (
  SELECT d.id FROM diaries d
''');
    _writeActiveDiaryFilter(
      sql,
      variables,
      normalizedKeyword: normalizedKeyword,
      normalizedTagIds: normalizedTagIds,
    );
    sql.writeln(_diaryOrderBySql(sortMode));
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
${_diaryOrderBySql(sortMode)}
''');

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
}
