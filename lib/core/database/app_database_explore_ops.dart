part of 'app_database.dart';

/// 探索页的两条轻量查询：待解封的时间胶囊与最近带图的日记。
///
/// 探索页的统计都由概览流（`watchExploreDiaryOverviews`）现算；这两样概览
/// 里没有——概览刻意排除未解封的胶囊、也不带富文本正文——所以单独查，且
/// 只取需要的列：
/// - 胶囊只取 id、标题与封存 / 解封时间，正文在解封前不可见，不读；
/// - 图片只取最近更新的少数几篇（LIMIT），探索页的媒体卡最多显示十几张，
///   不必像日记本统计页那样扫全部带图日记。
///
/// 口径：不含回收站；私密日记经 [_writeDiaryScopeFilter] 排除，`readsFrom`
/// 带上日记本两表（[_diaryScopeReadsFrom]），改动私密本子时流会重新推送。
mixin _AppDatabaseExploreOps
    on _$AppDatabase, _AppDatabaseDiaryScopeSql, _AppDatabaseDiaryQueries {
  /// 还没解封的时间胶囊（含归档），按解封时间由近到远。
  ///
  /// “现在”取订阅时刻：胶囊在页面打开期间到期不会自动移出，与概览流的
  /// 口径一致；下次订阅（回到探索页、数据变化重建）即更新。
  Stream<List<LockedCapsuleSummary>> watchLockedCapsules({DateTime? now}) {
    final variables = <Variable<Object>>[
      Variable<DateTime>(now ?? DateTime.now()),
    ];
    final sql = StringBuffer('''
SELECT
  d.diary_id,
  d.title,
  d.capsule_locked_at,
  d.capsule_unlock_at
FROM diaries d
WHERE d.is_deleted = 0
  AND d.capsule_unlock_at IS NOT NULL
  AND d.capsule_unlock_at > ?
''');
    _writeDiaryScopeFilter(sql, variables, DiaryListScope.all);
    sql.write('ORDER BY d.capsule_unlock_at ASC, d.id ASC\n');
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[diaries]),
    ).watch().map(
      (rows) => List<LockedCapsuleSummary>.unmodifiable(<LockedCapsuleSummary>[
        for (final row in rows)
          LockedCapsuleSummary(
            diaryId: row.read<String>('diary_id'),
            title: row.read<String>('title'),
            lockedAt: _readNullableDateTime(row, 'capsule_locked_at'),
            unlockAt: _readDateTime(row, 'capsule_unlock_at'),
          ),
      ]),
    );
  }

  /// 最近更新的 [limit] 篇可能带图的日记（有封面，或正文含 `"image"`
  /// 片段），按更新时间新 → 旧；不含未解封的胶囊。
  Stream<List<DiaryMediaContent>> watchRecentMediaContents({
    required int limit,
  }) {
    final variables = <Variable<Object>>[Variable<DateTime>(DateTime.now())];
    final sql = StringBuffer('''
SELECT
  d.diary_id,
  d.cover,
  d.content
FROM diaries d
WHERE d.is_deleted = 0
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
  AND ((d.cover IS NOT NULL AND trim(d.cover) <> '') OR d.content LIKE '%"image"%')
''');
    _writeDiaryScopeFilter(sql, variables, DiaryListScope.all);
    sql.write('ORDER BY d.updated_at DESC, d.id DESC\nLIMIT ?\n');
    variables.add(Variable<int>(limit));
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[diaries]),
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

/// 一个还没解封的时间胶囊（[AppDatabase.watchLockedCapsules]）：不含正文。
@immutable
class LockedCapsuleSummary {
  const LockedCapsuleSummary({
    required this.diaryId,
    required this.title,
    required this.unlockAt,
    this.lockedAt,
  });

  final String diaryId;
  final String title;
  final DateTime? lockedAt;
  final DateTime unlockAt;
}
