part of 'app_database.dart';

/// 反向链接里的一篇：链接到目标的那篇日记的标题、摘要与写下时间。
class DiaryBacklink {
  const DiaryBacklink({
    required this.diaryId,
    required this.title,
    required this.excerpt,
    required this.createdAt,
  });

  final String diaryId;
  final String title;

  /// 纯文本镜像的开头（最多 [_backlinkExcerptLength] 字，未单行化）。
  final String excerpt;
  final DateTime createdAt;
}

const int _backlinkExcerptLength = 120;

/// 日记链接（diary_link_target.dart）的反向查询：哪些日记提到了某篇日记或
/// 某本日记本。不另建索引表——链接就在正文 JSON 里，按地址 LIKE 现查：
/// 地址两侧带引号（[DiaryLinkTarget.backlinkLikePattern]），id 互为前缀时
/// 不误配；正文以紧凑 JSON 存储（`encodeDiaryBlocks`），写法固定。
///
/// 口径：含归档；排除回收站、未解封的时间胶囊（正文还不能看，不能借反向
/// 链接露出它提到了谁）与私密日记（经 [_writeDiaryScopeFilter]）；目标是
/// 日记时排除它自己。按写下时间新 → 旧。只读。
///
/// [watchDiaryBacklinks] 随写入推送（日记本头部）；[getDiaryBacklinks] 只读
/// 一次（预览页：与它的正文、所在日记本一样每次打开时读取）。
mixin _AppDatabaseDiaryLinkOps
    on _$AppDatabase, _AppDatabaseDiaryScopeSql, _AppDatabaseDiaryQueries {
  Stream<List<DiaryBacklink>> watchDiaryBacklinks(DiaryLinkTarget target) =>
      _diaryBacklinksQuery(target).watch();

  Future<List<DiaryBacklink>> getDiaryBacklinks(DiaryLinkTarget target) =>
      _diaryBacklinksQuery(target).get();

  Selectable<DiaryBacklink> _diaryBacklinksQuery(DiaryLinkTarget target) {
    final variables = <Variable<Object>>[
      Variable<DateTime>(DateTime.now()),
      Variable<String>(target.backlinkLikePattern()),
    ];
    final sql = StringBuffer('''
SELECT
  d.diary_id,
  d.title,
  substr(d.content_text, 1, $_backlinkExcerptLength) AS excerpt,
  d.created_at
FROM diaries d
WHERE d.is_deleted = 0
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
  AND d.content LIKE ? ESCAPE '\\'
''');
    if (target.kind == DiaryLinkKind.diary) {
      sql.write('  AND d.diary_id <> ?\n');
      variables.add(Variable<String>(target.id));
    }
    _writeDiaryScopeFilter(sql, variables, DiaryListScope.all);
    sql.write('ORDER BY d.created_at DESC, d.id DESC\n');
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[diaries]),
    ).map(
      (row) => DiaryBacklink(
        diaryId: row.read<String>('diary_id'),
        title: row.read<String>('title'),
        excerpt: row.readNullable<String>('excerpt') ?? '',
        createdAt: _readDateTime(row, 'created_at'),
      ),
    );
  }
}
