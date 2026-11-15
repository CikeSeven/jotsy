// 快照构建读取的数据，全部经已有的查询（私密日记的排除口径与日历、首页
// 一致，见 docs/rules/notebooks.md）。抽成接口是为了让快照构建可以脱离
// 数据库单测（`test/ui/home_widgets/` 里的假数据源）。

import 'dart:io';

import 'package:drift/drift.dart' show Variable;

import '../../../core/database/app_database.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../notebooks/models/notebook_scope_resolver.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';

abstract class HomeWidgetDataSource {
  /// [day] 当天写下的字数（按 `TextStats` 口径，不含私密日记）。
  Future<int> wordsOn(DateTime day);

  /// 未完成待办的截止日（`YYYY-MM-DD`；没有截止日为 null）。
  Future<List<String?>> openTodoDueDates();

  /// 能写进去的日记本：普通（非智能）、非私密（含继承）、未合上的本子，
  /// id → 名字。快速记录的“写进日记本”只认这里面的。
  Future<Map<String, String>> writableNotebooks();

  /// 全部纪念日（置顶在前）。
  Future<List<Anniversary>> anniversaries();

  /// 这天的心情（日期键 `YYYY-MM-DD` → 心情）；认不出的值不在其中。
  Future<Map<String, DayMood>> dayMoods();

  /// `[start, end)` 内的日历打点（不含私密日记，与日历同一查询）。
  Future<List<DiaryCalendarMarker>> markersBetween(
    DateTime start,
    DateTime end,
  );

  /// 未完成的待办。
  Future<List<TodoRow>> openTodos();

  /// 最近完成的待办（按完成时间倒序，最多几百条）。
  Future<List<TodoRow>> completedTodos();

  /// 待办清单。
  Future<List<TodoListRow>> todoLists();

  /// 发表时间落在任一 `[start, end)` 内的日记（不含私密日记，与日历的那年今日
  /// 同一查询；含未到期的胶囊，由调用方排除）。
  Future<List<DiaryWithTags>> diariesCreatedInRanges(
    List<(DateTime, DateTime)> ranges,
  );

  /// 最近日记的一个来源下按发表时间从新到旧的前 [limit] 篇：不含归档、私密日记与
  /// 未到期的胶囊。来源已失效（日记本被删除或变成私密、标签不存在）时为空。
  Future<List<DiaryWithTags>> recentDiaries(
    RecentDiariesSource source, {
    String? notebookId,
    String? tagName,
    required DateTime now,
    required int limit,
  });

  /// 照片回忆的候选：全部（[notebookId] 为 null）或某个日记本里可能带图的日记
  /// （有封面或正文里有图片块），按发表时间从新到旧的前 [limit] 篇，含归档，不含
  /// 私密日记与未到期的胶囊。日记本已不能看时为空。
  Future<List<DiaryWithTags>> photoDiaries({
    String? notebookId,
    required DateTime now,
    required int limit,
  });

  /// 能看的日记本：非私密（含继承）的普通与智能日记本，id → 名字。最近日记的
  /// “某个日记本”只认这里面的。
  Future<Map<String, String>> readableNotebooks();

  /// 现有标签的名字。
  Future<Set<String>> tagNames();

  /// 日记图片来源对应的本机文件：只认存在的本地文件（网络图片、内置示例图与
  /// base64 内嵌图不交给小组件），否则为 null。
  String? localImage(String source);
}

class DatabaseHomeWidgetDataSource implements HomeWidgetDataSource {
  DatabaseHomeWidgetDataSource(this._db);

  final AppDatabase _db;

  @override
  Future<int> wordsOn(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final markers = await markersBetween(
      start,
      DateTime(start.year, start.month, start.day + 1),
    );
    var words = 0;
    for (final marker in markers) {
      words += marker.wordCount;
    }
    return words;
  }

  @override
  Future<List<String?>> openTodoDueDates() async {
    final rows = await _db.getOpenTodos();
    return <String?>[for (final row in rows) row.dueDate];
  }

  @override
  Future<List<TodoRow>> openTodos() => _db.getOpenTodos();

  @override
  Future<List<TodoRow>> completedTodos() =>
      _db.watchCompletedTodos(limit: 200).first;

  @override
  Future<List<TodoListRow>> todoLists() => _db.getTodoLists();

  @override
  Future<List<Anniversary>> anniversaries() => _db.watchAnniversaries().first;

  @override
  Future<Map<String, DayMood>> dayMoods() async {
    final rows = await _db.watchDayMoods().first;
    return <String, DayMood>{
      for (final row in rows)
        if (DayMood.parse(row.mood) case final DayMood mood) row.day: mood,
    };
  }

  @override
  Future<List<DiaryCalendarMarker>> markersBetween(
    DateTime start,
    DateTime end,
  ) => _db.watchDiaryMarkersInRange(start, end).first;

  @override
  Future<List<DiaryWithTags>> diariesCreatedInRanges(
    List<(DateTime, DateTime)> ranges,
  ) => _db.watchDiariesCreatedInRanges(ranges).first;

  @override
  Future<List<DiaryWithTags>> recentDiaries(
    RecentDiariesSource source, {
    String? notebookId,
    String? tagName,
    required DateTime now,
    required int limit,
  }) async {
    var scope = DiaryListScope.all;
    var tagIds = const <int>[];
    if (source == RecentDiariesSource.notebook) {
      final notebookScope = await _readableNotebookScope(notebookId);
      if (notebookScope == null) return const [];
      scope = notebookScope;
    } else if (source == RecentDiariesSource.tag) {
      final tags = await _db.watchAllTags().first;
      final tag = tags.where((tag) => tag.name == tagName).firstOrNull;
      if (tag == null) return const [];
      tagIds = <int>[tag.id];
    }
    // 未到期的胶囊发表时间就是解封日，按发表时间倒序会排在最前面，在 SQL 里排除，
    // 不让它们占掉 [limit]。
    final filter = DiaryScopePredicate(
      sql:
          '(d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?)'
          '${source == RecentDiariesSource.pinned ? ' AND d.is_pinned = 1' : ''}',
      variables: <Variable<Object>>[Variable<DateTime>(now)],
    );
    return _db
        .watchDiaries(
          scope: scope,
          requiredTagIds: tagIds,
          sortMode: DiarySortMode.createdDesc,
          filter: filter,
          limit: limit,
        )
        .first;
  }

  @override
  Future<List<DiaryWithTags>> photoDiaries({
    String? notebookId,
    required DateTime now,
    required int limit,
  }) async {
    var scope = DiaryListScope.all;
    if (notebookId != null) {
      final notebookScope = await _readableNotebookScope(notebookId);
      if (notebookScope == null) return const [];
      scope = notebookScope;
    }
    // 与探索页“最近带图的日记”同一个粗筛（有封面或正文里有图片块）；图片是否真是
    // 本机文件由快照构建逐篇判断。
    final filter = DiaryScopePredicate(
      sql:
          '(d.capsule_unlock_at IS NULL OR d.capsule_unlock_at <= ?) AND '
          '((d.cover IS NOT NULL AND trim(d.cover) <> \'\') '
          'OR d.content LIKE \'%"image"%\')',
      variables: <Variable<Object>>[Variable<DateTime>(now)],
    );
    return _db
        .watchDiaries(
          scope: scope,
          sortMode: DiarySortMode.createdDesc,
          includeArchived: true,
          filter: filter,
          limit: limit,
        )
        .first;
  }

  /// 能看的（非私密）日记本的查询范围：按发表时间而不是本子自己的排序（书序），
  /// 小组件上是“最近”。本子不存在或是私密的为 null。
  Future<DiaryListScope?> _readableNotebookScope(String? notebookId) async {
    final tree = NotebookTree(await _db.watchNotebooks().first);
    final notebook = notebookId == null ? null : tree[notebookId];
    if (notebook == null || notebook.isPrivate) return null;
    return resolveNotebookScope(
      notebook,
      tree: tree,
      sort: NotebookSort.createdDesc,
    );
  }

  @override
  Future<Map<String, String>> readableNotebooks() async {
    final rows = await _db.watchNotebooks().first;
    return <String, String>{
      for (final notebook in NotebookTree(rows).notebooks)
        if (!notebook.isPrivate) notebook.id: notebook.name,
    };
  }

  @override
  Future<Set<String>> tagNames() async => <String>{
    for (final tag in await _db.watchAllTags().first) tag.name,
  };

  @override
  String? localImage(String source) {
    final path = source.trim();
    if (path.isEmpty ||
        path.startsWith('asset:') ||
        path.contains('base64,') ||
        Uri.tryParse(path)?.hasScheme == true && !path.startsWith('/')) {
      return null;
    }
    try {
      return File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, String>> writableNotebooks() async {
    final rows = await _db.watchNotebooks().first;
    return <String, String>{
      for (final notebook in NotebookTree(rows).notebooks)
        if (notebook.isManual && !notebook.isPrivate && !notebook.isClosed)
          notebook.id: notebook.name,
    };
  }
}
