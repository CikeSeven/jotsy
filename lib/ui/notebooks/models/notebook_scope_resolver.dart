import '../../../core/database/app_database.dart';
import '../viewmodels/notebook_view.dart';

/// 日记本 → 列表查询范围的换算（首页原地切换、搜索与统计共用）。
///
/// 输入是解析好的 [NotebookView] 与首页当前的章节选择，输出数据库层的
/// [DiaryListScope] 与列表排序。纯函数，无副作用。

/// 把智能日记本的规则原文编译成 SQL 条件——规则编译器接入的唯一接缝。
///
/// 空的或认不出的规则一律“什么都不匹配”（`0`）：宁可让智能日记本暂时是
/// 空的，也不能因为规则没解释就把全部日记都放进来。规则编译器接入时只替换
/// 这个函数体。
DiaryScopePredicate compileNotebookRules(Map<String, Object?>? rules) =>
    const DiaryScopePredicate(sql: '0');

/// 日记本排序对应的列表排序。“书序”由范围的 `bookOrder` 决定，列表排序
/// 在那时不生效，这里按发表时间新→旧占位（保证查询 key 稳定）。
DiarySortMode diarySortModeForNotebook(NotebookSort sort) => switch (sort) {
  NotebookSort.createdDesc => DiarySortMode.createdDesc,
  NotebookSort.createdAsc => DiarySortMode.createdAsc,
  NotebookSort.updatedDesc => DiarySortMode.updatedDesc,
  NotebookSort.book => DiarySortMode.createdDesc,
};

/// 这本日记本实际生效的排序：智能日记本没有成书顺序，“书序”回落到默认。
NotebookSort effectiveNotebookSort(NotebookView notebook, NotebookSort sort) =>
    notebook.isSmart && sort == NotebookSort.book
    ? NotebookSort.createdDesc
    : sort;

/// 首页在 [notebook] 里时的查询范围。
///
/// - 普通日记本：成员范围，[sort] 为书序时按章节顺序 + 本内位置排；
///   [chapterId] / [unassignedChapterOnly] 为章节筛选（两者互斥：同时给出时
///   以 [chapterId] 为准）；
/// - 智能日记本：规则编译出的条件（见 [compileNotebookRules]），章节不适用。
///
/// [sort] 缺省取日记本自己的排序（`payload.sort`）。
DiaryListScope resolveNotebookScope(
  NotebookView notebook, {
  NotebookSort? sort,
  String? chapterId,
  bool unassignedChapterOnly = false,
}) {
  if (notebook.isSmart) {
    return DiarySmartScope(
      notebookId: notebook.id,
      predicate: compileNotebookRules(notebook.payload.rules),
    );
  }
  final effectiveSort = effectiveNotebookSort(
    notebook,
    sort ?? notebook.payload.sort,
  );
  return DiaryNotebookScope(
    notebookId: notebook.id,
    chapterId: chapterId,
    unassignedChapterOnly: chapterId == null && unassignedChapterOnly,
    bookOrder: effectiveSort == NotebookSort.book,
    chapterOrder: <String>[
      for (final chapter in notebook.payload.chapters) chapter.id,
    ],
  );
}

/// 统计用的范围：整本（不分章、不排序），排序或章节变化时 key 不变，
/// 头部卡片的统计不会因此重新查询。
DiaryListScope notebookStatsScope(NotebookView notebook) {
  if (notebook.isSmart) {
    return resolveNotebookScope(notebook);
  }
  return DiaryNotebookScope(notebookId: notebook.id);
}
