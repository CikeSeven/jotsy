part of 'app_database.dart';

/// 日记留言的读写与回看查询。
///
/// 输入：预览页写下 / 编辑 / 删除的留言，卡片、搜索、探索与导出的读取；
/// 输出：drift watch 流与一次性读取。删除是硬删除，撤销由调用方持有被删的
/// 整行、经 [restoreDiaryComment] 原样写回（与纪念日、这天的心情同一做法）。
///
/// 口径：
/// - 按日记读取（预览页、导出、卡片计数）不过滤私密与胶囊：调用方已经拿到了
///   这篇日记，说明它来自允许看到它的范围；未解封的胶囊根本不显示留言区；
/// - 跨日记的回看（探索页最近的留言与统计、搜索命中）只算回收站以外、已解封、
///   非私密的日记，私密排除经 [_writeDiaryScopeFilter]，`readsFrom` 经
///   [_diaryScopeReadsFrom] 带上日记本两表，改动私密本子时流会重新推送。
mixin _AppDatabaseCommentOps
    on _$AppDatabase, _AppDatabaseDiaryScopeSql, _AppDatabaseDiaryQueries {
  /// 某篇日记的全部留言，按写下时间旧 → 新。
  Stream<List<DiaryCommentRow>> watchDiaryComments(String diaryId) {
    return (select(diaryComments)
          ..where((t) => t.diaryId.equals(diaryId))
          ..orderBy(<OrderClauseGenerator<$DiaryCommentsTable>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// 给 [diaryId] 写一条留言，返回新留言的业务 id。
  ///
  /// [content] 去掉首尾空白后为空时抛 [FormatException]；[mood] 为空串按
  /// 没选心情处理。
  Future<String> addDiaryComment({
    required String diaryId,
    required String content,
    String? mood,
  }) async {
    final commentId = _newBusinessUuid();
    await into(diaryComments).insert(
      DiaryCommentsCompanion.insert(
        commentId: commentId,
        diaryId: diaryId,
        content: _normalizeDiaryComment(content),
        mood: Value(_normalizeCommentMood(mood)),
        createdAt: DateTime.now(),
      ),
    );
    return commentId;
  }

  /// 改写一条留言的文字与心情；有变化时记下编辑时间（显示“已编辑”），
  /// 原样保存不算编辑。返回是否真的改动了。
  Future<bool> updateDiaryComment(
    String commentId, {
    required String content,
    String? mood,
  }) {
    final text = _normalizeDiaryComment(content);
    final normalizedMood = _normalizeCommentMood(mood);
    return transaction(() async {
      final row = await (select(
        diaryComments,
      )..where((t) => t.commentId.equals(commentId))).getSingleOrNull();
      if (row == null || (row.content == text && row.mood == normalizedMood)) {
        return false;
      }
      await (update(diaryComments)..where((t) => t.id.equals(row.id))).write(
        DiaryCommentsCompanion(
          content: Value(text),
          mood: Value(normalizedMood),
          editedAt: Value(DateTime.now()),
        ),
      );
      return true;
    });
  }

  /// 删除并返回被删的整行（供撤销）；不存在时返回 null。
  Future<DiaryCommentRow?> deleteDiaryComment(String commentId) {
    return transaction(() async {
      final row = await (select(
        diaryComments,
      )..where((t) => t.commentId.equals(commentId))).getSingleOrNull();
      if (row != null) {
        await (delete(diaryComments)..where((t) => t.id.equals(row.id))).go();
      }
      return row;
    });
  }

  /// 撤销删除：按原 id 与业务 id 写回整行（含写下与编辑时间）。
  Future<void> restoreDiaryComment(DiaryCommentRow row) {
    return into(diaryComments).insertOnConflictUpdate(row.toCompanion(false));
  }

  /// 每篇日记的留言条数（键为日记业务 id，没有留言的日记不在表里）。
  ///
  /// 卡片角上的留言数只读它：计数不放进卡片的派生数据（那份缓存按日记的
  /// 更新时间失效，写留言不改日记），也不进分页查询（否则每写一条留言整页
  /// 列表连同正文都要重查）。
  Stream<Map<String, int>> watchDiaryCommentCounts() {
    final count = diaryComments.id.count();
    final query = selectOnly(diaryComments)
      ..addColumns(<Expression<Object>>[diaryComments.diaryId, count])
      ..groupBy(<Expression<Object>>[diaryComments.diaryId]);
    return query.watch().map(
      (rows) => Map<String, int>.unmodifiable(<String, int>{
        for (final row in rows)
          row.read(diaryComments.diaryId)!: row.read(count) ?? 0,
      }),
    );
  }

  /// 一次读出 [diaryIds] 各篇的留言（导出用），每篇按写下时间旧 → 新；
  /// 没有留言的日记不在表里。
  Future<Map<String, List<DiaryCommentRow>>> getDiaryCommentsFor(
    Iterable<String> diaryIds,
  ) async {
    final ids = diaryIds.toSet().toList(growable: false);
    final result = <String, List<DiaryCommentRow>>{};
    // SQLite 单条语句的参数个数有上限，大批导出时分批读取。
    const chunk = 500;
    for (var start = 0; start < ids.length; start += chunk) {
      final part = ids.sublist(start, min(start + chunk, ids.length));
      final rows =
          await (select(diaryComments)
                ..where((t) => t.diaryId.isIn(part))
                ..orderBy(<OrderClauseGenerator<$DiaryCommentsTable>>[
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      for (final row in rows) {
        (result[row.diaryId] ??= <DiaryCommentRow>[]).add(row);
      }
    }
    return result;
  }

  /// 最近写下的 [limit] 条留言（新 → 旧），带所属日记的标题与创建时间；
  /// 只算回收站以外、已解封、非私密的日记（含归档）。
  Stream<List<DiaryCommentSummary>> watchRecentDiaryComments({
    required int limit,
  }) {
    final variables = <Variable<Object>>[];
    final sql = StringBuffer('''
SELECT
  c.comment_id,
  c.diary_id,
  c.content,
  c.mood,
  c.created_at,
  c.edited_at,
  d.title AS diary_title,
  d.created_at AS diary_created_at
FROM diary_comments c
JOIN diaries d ON d.diary_id = c.diary_id
''');
    _writeVisibleCommentFilter(sql, variables);
    sql.write('ORDER BY c.created_at DESC, c.id DESC\nLIMIT ?\n');
    variables.add(Variable<int>(limit < 0 ? 0 : limit));
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[
        diaries,
        diaryComments,
      ]),
    ).watch().map(
      (rows) => List<DiaryCommentSummary>.unmodifiable(<DiaryCommentSummary>[
        for (final row in rows)
          DiaryCommentSummary(
            commentId: row.read<String>('comment_id'),
            diaryId: row.read<String>('diary_id'),
            content: row.read<String>('content'),
            mood: row.readNullable<String>('mood'),
            createdAt: _readDateTime(row, 'created_at'),
            editedAt: _readNullableDateTime(row, 'edited_at'),
            diaryTitle: row.read<String>('diary_title'),
            diaryCreatedAt: _readDateTime(row, 'diary_created_at'),
          ),
      ]),
    );
  }

  /// 全部可见留言的时间（不带文字）：探索页的留言统计据此现算条数、回应了
  /// 几篇与平均隔多久回看。口径同 [watchRecentDiaryComments]。
  Stream<List<DiaryCommentTiming>> watchDiaryCommentTimings() {
    final variables = <Variable<Object>>[];
    final sql = StringBuffer('''
SELECT
  c.diary_id,
  c.created_at,
  d.created_at AS diary_created_at
FROM diary_comments c
JOIN diaries d ON d.diary_id = c.diary_id
''');
    _writeVisibleCommentFilter(sql, variables);
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[
        diaries,
        diaryComments,
      ]),
    ).watch().map(
      (rows) => List<DiaryCommentTiming>.unmodifiable(<DiaryCommentTiming>[
        for (final row in rows)
          DiaryCommentTiming(
            diaryId: row.read<String>('diary_id'),
            createdAt: _readDateTime(row, 'created_at'),
            diaryCreatedAt: _readDateTime(row, 'diary_created_at'),
          ),
      ]),
    );
  }

  /// 留言里含 [keyword] 的日记各取第一条命中的留言（按写下时间），键为
  /// 日记业务 id：搜索结果里“只命中留言”的卡片下方显示它。口径同
  /// [watchRecentDiaryComments]；关键词为空时为空表。
  Stream<Map<String, DiaryCommentRow>> watchDiaryCommentHits(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return Stream<Map<String, DiaryCommentRow>>.value(
        const <String, DiaryCommentRow>{},
      );
    }
    final variables = <Variable<Object>>[];
    final sql = StringBuffer('''
SELECT c.*
FROM diary_comments c
JOIN diaries d ON d.diary_id = c.diary_id
''');
    _writeVisibleCommentFilter(sql, variables);
    sql.write('  AND c.content LIKE ?\nORDER BY c.created_at ASC, c.id ASC\n');
    variables.add(Variable<String>('%$normalized%'));
    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: _diaryScopeReadsFrom(DiaryListScope.all, <TableInfo>[
        diaries,
        diaryComments,
      ]),
    ).watch().map((rows) {
      final hits = <String, DiaryCommentRow>{};
      for (final row in rows) {
        final comment = diaryComments.map(row.data);
        hits.putIfAbsent(comment.diaryId, () => comment);
      }
      return Map<String, DiaryCommentRow>.unmodifiable(hits);
    });
  }

  /// 跨日记回看的 WHERE：回收站以外、已解封、非私密（含归档）。调用方须
  /// 以 `FROM diary_comments c JOIN diaries d` 开头。
  void _writeVisibleCommentFilter(
    StringBuffer sql,
    List<Variable<Object>> variables,
  ) {
    sql.write('''
WHERE d.is_deleted = 0
  AND (d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)
''');
    variables.add(Variable<DateTime>(DateTime.now()));
    _writeDiaryScopeFilter(sql, variables, DiaryListScope.all);
  }

  String _normalizeDiaryComment(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const FormatException('留言不能为空');
    }
    return text;
  }

  String? _normalizeCommentMood(String? raw) {
    final mood = raw?.trim();
    return mood == null || mood.isEmpty ? null : mood;
  }
}

/// 一条留言连同所属日记的标题与创建时间（[AppDatabase.watchRecentDiaryComments]）。
@immutable
class DiaryCommentSummary {
  const DiaryCommentSummary({
    required this.commentId,
    required this.diaryId,
    required this.content,
    required this.createdAt,
    required this.diaryTitle,
    required this.diaryCreatedAt,
    this.mood,
    this.editedAt,
  });

  final String commentId;
  final String diaryId;
  final String content;
  final String? mood;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String diaryTitle;
  final DateTime diaryCreatedAt;
}

/// 一条留言的写下时间与所属日记的创建时间（[AppDatabase.watchDiaryCommentTimings]）。
@immutable
class DiaryCommentTiming {
  const DiaryCommentTiming({
    required this.diaryId,
    required this.createdAt,
    required this.diaryCreatedAt,
  });

  final String diaryId;
  final DateTime createdAt;
  final DateTime diaryCreatedAt;
}
