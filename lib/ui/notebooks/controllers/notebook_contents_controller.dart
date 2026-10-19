import '../../../core/database/app_database.dart';
import '../viewmodels/notebook_book_layout.dart';

/// 目录页的写操作：章节的增、改名、上下移、删除，日记的排序、换章、移出与
/// 撤销。
///
/// 章节存在日记本 payload 里：每次修改都先读库里最新的 payload 再改，避免
/// 页面上较旧的快照覆盖掉别处（编辑页、另一次操作）刚写入的字段。删除章节
/// 时 `updateNotebook` 在同一事务里把这一章的日记放回“未分章”。失败一律抛给
/// 页面提示。
class NotebookContentsController {
  NotebookContentsController(this._database, this.notebookId);

  final AppDatabase _database;
  final String notebookId;

  Future<NotebookPayload> _payload() async {
    final row = await _database.getNotebook(notebookId);
    if (row == null) {
      throw StateError('日记本不存在');
    }
    return row.parsedPayload;
  }

  Future<void> _writeChapters(
    List<NotebookChapter> Function(List<NotebookChapter> chapters) change,
  ) async {
    final payload = await _payload();
    await _database.updateNotebook(
      notebookId,
      payload: payload.copyWith(chapters: change(payload.chapters)),
    );
  }

  /// 在最后加一章，返回新章节。
  Future<NotebookChapter> addChapter(String title) async {
    final chapter = NotebookChapter.create(title);
    await _writeChapters((chapters) => <NotebookChapter>[...chapters, chapter]);
    return chapter;
  }

  Future<void> renameChapter(String chapterId, String title) {
    return _writeChapters(
      (chapters) => <NotebookChapter>[
        for (final chapter in chapters)
          chapter.id == chapterId ? chapter.withTitle(title) : chapter,
      ],
    );
  }

  /// 把章节上移（[delta] 为 -1）或下移（+1）一位；已在两端时不变。
  Future<void> moveChapter(String chapterId, int delta) {
    return _writeChapters((chapters) {
      final next = <NotebookChapter>[...chapters];
      final index = next.indexWhere((chapter) => chapter.id == chapterId);
      final target = index + delta;
      if (index < 0 || target < 0 || target >= next.length) return chapters;
      next.insert(target, next.removeAt(index));
      return next;
    });
  }

  /// 删除章节；其中的日记回到“未分章”，日记本身不动。
  Future<void> deleteChapter(String chapterId) {
    return _writeChapters(
      (chapters) => <NotebookChapter>[
        for (final chapter in chapters)
          if (chapter.id != chapterId) chapter,
      ],
    );
  }

  /// 保存拖动后的完整顺序（一次写入）。
  Future<void> reorder(List<NotebookEntryPlacement> placements) {
    return _database.reorderNotebookEntries(notebookId, placements);
  }

  /// 把日记放进 [chapterId]（null 为未分章）。
  Future<void> moveToChapter(Iterable<String> diaryIds, String? chapterId) {
    return _database.setNotebookEntriesChapter(notebookId, diaryIds, chapterId);
  }

  /// 从本日记本移出，返回被删的关联行供撤销。
  Future<List<DiaryNotebookRow>> remove(Iterable<String> diaryIds) {
    return _database.removeDiariesFromNotebook(notebookId, diaryIds);
  }

  Future<void> restore(List<DiaryNotebookRow> rows) {
    return _database.restoreNotebookMemberships(rows);
  }
}
