part of 'app_database.dart';

/// 日记本统计页专用的读取：范围内日记的图片来源（封面 + 正文图片）。
///
/// 轻量概览（`watchExploreDiaryOverviews`）刻意不带富文本正文，统计页的
/// “照片数”却要数正文里的图片，所以单独查：只取可能带图的行（有封面，或正文
/// 含 `"image"` 片段——Quill 与旧版 AppFlowy 的图片节点都含它），在数据库线程
/// 先排除纯文字日记，UI 层只解析少量候选正文。
///
/// 口径与统计页其余数字一致：含归档，不含已删除与未解封的胶囊（胶囊的内容
/// 在解封前不可见，图片同样不能提前计入）；范围与私密排除复用
/// [_AppDatabaseDiaryScopeSql]。
mixin _AppDatabaseNotebookStatsOps on _$AppDatabase, _AppDatabaseDiaryScopeSql {
  Stream<List<DiaryMediaContent>> watchScopedMediaContents(
    DiaryListScope scope,
  ) {
    final variables = <Variable<Object>>[Variable<DateTime>(DateTime.now())];
    final sql = StringBuffer('''
SELECT
  d.diary_id,
  d.cover,
  d.content
FROM diaries d
${_diaryScopeJoinSql(scope)}WHERE d.is_deleted = 0
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
  AND ((d.cover IS NOT NULL AND trim(d.cover) <> '') OR d.content LIKE '%"image"%')
''');
    _writeDiaryScopeFilter(sql, variables, scope);
    sql.write('ORDER BY d.created_at ASC, d.id ASC\n');
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(scope, <TableInfo>[diaries]),
    ).watch().map(
      (rows) => List<DiaryMediaContent>.unmodifiable(<DiaryMediaContent>[
        for (final row in rows)
          DiaryMediaContent(
            diaryId: row.read<String>('diary_id'),
            cover: row.readNullable<String>('cover'),
            content: row.read<String>('content'),
          ),
      ]),
    );
  }
}

/// 一篇可能带图的日记：封面与富文本正文原文（[AppDatabase.watchScopedMediaContents]）。
@immutable
class DiaryMediaContent {
  const DiaryMediaContent({
    required this.diaryId,
    required this.content,
    this.cover,
  });

  final String diaryId;
  final String? cover;
  final String content;
}
