import '../../../core/database/app_database.dart';
import '../../diaries/export/diary_export_book.dart';
import '../viewmodels/notebook_book_layout.dart';
import '../viewmodels/notebook_view.dart';

/// 日记本 → 导出成书的结构（[DiaryExportBook]）。纯函数，无副作用。
///
/// 书名、简介与封面取自日记本；一本书是完整的，归档的日记同样收进来（读取
/// 方给的列表已含归档、不含回收站），未解封的胶囊由导出链路跳过并计数。

/// 普通日记本：各章按章节列表的先后，未分章的一组在最后（它是否写成
/// “未分章”标题由导出版式决定）。章内的先后：日记本排序为“书序”时按本内
/// 位置（[contents] 已按位置排好，与目录页一致）；其他排序一律按发表时间
/// 从旧到新——一本书从最早的一篇读起，不跟随列表的“新→旧”。
DiaryExportBook notebookExportBook(
  NotebookView notebook,
  List<NotebookContentsEntry> contents,
) {
  final chapters = notebook.payload.chapters;
  final byBook = notebook.payload.sort == NotebookSort.book;
  final createdAt = <String, DateTime>{
    for (final entry in contents) entry.diaryId: entry.createdAt,
  };
  final position = <String, int>{
    for (final (index, entry) in contents.indexed) entry.diaryId: index,
  };
  final grouped = <String?, List<String>>{};
  for (final placement in notebookBookPlacements(chapters, contents)) {
    grouped
        .putIfAbsent(placement.chapterId, () => <String>[])
        .add(placement.diaryId);
  }

  List<String> ordered(String? chapterId) {
    final ids = <String>[...?grouped[chapterId]];
    if (!byBook) {
      // List.sort 不保证稳定：同一时刻发表的按本内位置排。
      ids.sort((String a, String b) {
        final byDate = createdAt[a]!.compareTo(createdAt[b]!);
        return byDate != 0 ? byDate : position[a]!.compareTo(position[b]!);
      });
    }
    return ids;
  }

  return DiaryExportBook(
    title: notebook.name,
    description: notebook.payload.description,
    coverPath: notebook.coverPath,
    chapters: <DiaryExportBookChapter>[
      for (final chapter in chapters)
        DiaryExportBookChapter(
          title: chapter.title,
          diaryIds: ordered(chapter.id),
        ),
      DiaryExportBookChapter(diaryIds: ordered(null)),
    ],
  );
}

/// 有子本的日记本：在本子自己的书（[book]）之后，每本子本按树序各成一章
/// （[parts]：章名为从这本往下的路径，如“日本 · 东京”；日记按子本自己的
/// 成书先后）。成书只有一级章节，子本内部的章节不再分层。同一篇日记同时在
/// 父本与子本里时只在第一次出现的地方收录（版式解析时去重）。
DiaryExportBook withSubNotebookChapters(
  DiaryExportBook book,
  List<({String title, List<String> diaryIds})> parts,
) {
  if (parts.isEmpty) return book;
  return DiaryExportBook(
    title: book.title,
    description: book.description,
    coverPath: book.coverPath,
    chapters: <DiaryExportBookChapter>[
      ...book.chapters,
      for (final part in parts)
        DiaryExportBookChapter(title: part.title, diaryIds: part.diaryIds),
    ],
  );
}

/// 智能日记本：没有章节，按发表时间从旧到新（[orderedIds] 由查询排好）。
DiaryExportBook smartNotebookExportBook(
  NotebookView notebook,
  List<String> orderedIds,
) {
  return DiaryExportBook(
    title: notebook.name,
    description: notebook.payload.description,
    coverPath: notebook.coverPath,
    chapters: <DiaryExportBookChapter>[
      DiaryExportBookChapter(diaryIds: orderedIds),
    ],
  );
}
