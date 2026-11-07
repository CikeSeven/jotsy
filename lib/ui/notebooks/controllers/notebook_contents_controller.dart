import '../../../core/database/app_database.dart';
import '../../../core/services/editing_session_registry.dart';
import '../viewmodels/notebook_book_layout.dart';

/// 目录页的写操作：章节的增、改名、上下移、删除，日记的排序、换章、移出与
/// 撤销。
///
/// 章节存在日记本 payload 里：每次修改都先读库里最新的 payload 再改，避免
/// 页面上较旧的快照覆盖掉别处（编辑页、另一次操作）刚写入的字段。删除章节
/// 时 `updateNotebook` 在同一事务里把这一章的日记放回“未分章”。失败一律抛给
/// 页面提示。
///
/// 拖动排序从拿起到新顺序写完是局域网同步的阻塞者（[ReorderEditingGuard]）：
/// 写回的整份顺序来自拖动前的列表，期间同步来的顺序会被覆盖。页面在列表的
/// 拿起 / 松手回调里调 [startDrag] / [dropped]，移动了但不写库时调
/// [endDrag]，销毁时调 [dispose]。
///
/// 拖动章节时把这一章的日记收进来（[dragFolded]），看起来整章一起移动。
/// 落回原位时列表不会再报告放下，松手就放出来（[dropped] 返回 true）；移动了
/// 的等放下动画结束、`onReorderItem` 里再放出来（[unfoldDrag]）——松手时就
/// 展开会把落点前的行往下推，正在落下的那一行会落到错位的地方。
class NotebookContentsController {
  NotebookContentsController(this._database, this.notebookId);

  final AppDatabase _database;
  final String notebookId;
  final ReorderEditingGuard _drag = ReorderEditingGuard('notebook-contents');

  int? _dragIndex;
  String? _dragFolded;

  /// 正在拖动、日记收了进来的章节标题行 key；没有时为 null。
  String? get dragFolded => _dragFolded;

  /// 列表拿起 [item]（第 [index] 行，`onReorderStart`）。拿起的是有日记的
  /// 章节时返回 true：页面须重建，把这一章的日记收进来。
  bool startDrag(int index, NotebookContentsItem item) {
    _dragIndex = index;
    _drag.start(index);
    final folded =
        item is NotebookContentsHeader && item.chapter != null && item.count > 0
        ? item.key
        : null;
    if (folded == _dragFolded) return false;
    _dragFolded = folded;
    return true;
  }

  /// 列表松手（`onReorderEnd`，[insertIndex] 未修正）。落回原位（之后不会
  /// 再有 `onReorderItem`）时结束阻塞并返回 true，页面就此 [unfoldDrag]。
  bool dropped(int insertIndex) {
    final start = _dragIndex;
    _dragIndex = null;
    _drag.dropped(insertIndex);
    return start == null || insertIndex == start || insertIndex == start + 1;
  }

  /// 放出拖动时收进来的日记，返回那一章的标题行 key（没有收进来时为 null）。
  String? unfoldDrag() {
    final folded = _dragFolded;
    _dragFolded = null;
    return folded;
  }

  /// 移动了但顺序没变、不写库时结束这次拖动的阻塞。
  void endDrag() => _drag.end();

  void dispose() => _drag.dispose();

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

  /// 按拖动后的章节顺序（[ids]）重排章节，写完才结束这次拖动的阻塞。库里
  /// 的章节不在 [ids] 里的（拖动期间别处新加的）按原来的先后接在后面。
  Future<void> reorderChapters(List<String> ids) {
    return _drag.holdUntil(
      _writeChapters((chapters) => orderNotebookChapters(chapters, ids)),
    );
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

  /// 保存拖动后的完整顺序（一次写入），写完才结束这次拖动的阻塞。
  Future<void> reorder(List<NotebookEntryPlacement> placements) {
    return _drag.holdUntil(
      _database.reorderNotebookEntries(notebookId, placements),
    );
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
