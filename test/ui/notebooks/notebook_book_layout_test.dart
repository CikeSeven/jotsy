import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_book_layout.dart';

/// 章节与书序的纯换算：目录列表、拖动落点（含拖到最顶端时归第一章）与篇数。
void main() {
  final tokyo = NotebookChapter(id: 'c1', title: '东京');
  final kyoto = NotebookChapter(id: 'c2', title: '京都');
  final chapters = <NotebookChapter>[tokyo, kyoto];

  NotebookContentsEntry entry(String id, String? chapterId) =>
      NotebookContentsEntry(
        diaryId: id,
        title: id,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isArchived: false,
        chapterId: chapterId,
      );

  List<String> keys(List<NotebookContentsItem> items) => <String>[
    for (final item in items) item.key,
  ];

  test('contents list groups entries under chapters in book order, with '
      'unassigned and dangling chapters last', () {
    final items = buildNotebookContents(chapters, <NotebookContentsEntry>[
      entry('a', 'c2'),
      entry('b', null),
      entry('c', 'c1'),
      entry('d', 'gone'),
      entry('e', 'c2'),
    ]);
    expect(keys(items), <String>[
      'chapter_c1',
      'entry_c',
      'chapter_c2',
      'entry_a',
      'entry_e',
      'chapter__unassigned',
      'entry_b',
      'entry_d',
    ]);
    expect((items[2] as NotebookContentsHeader).count, 2);
  });

  test('without chapters there are no headers; empty chapters still show '
      'and the unassigned header is always last as a drop zone', () {
    expect(
      keys(
        buildNotebookContents(
          const <NotebookChapter>[],
          <NotebookContentsEntry>[entry('a', null), entry('b', 'x')],
        ),
      ),
      <String>['entry_a', 'entry_b'],
    );
    expect(
      keys(
        buildNotebookContents(chapters, <NotebookContentsEntry>[
          entry('a', 'c2'),
        ]),
      ),
      <String>['chapter_c1', 'chapter_c2', 'entry_a', 'chapter__unassigned'],
    );
  });

  test('a dropped entry joins the nearest header above it', () {
    final items = buildNotebookContents(chapters, <NotebookContentsEntry>[
      entry('a', 'c1'),
      entry('b', 'c1'),
      entry('c', 'c2'),
    ]);
    // [c1, a, b, c2, c]：把 a 拖到 c 之后。
    final placements = resolveNotebookContentsDrop(items, 1, 4);
    expect(placements, <NotebookEntryPlacement>[
      (diaryId: 'b', chapterId: 'c1'),
      (diaryId: 'c', chapterId: 'c2'),
      (diaryId: 'a', chapterId: 'c2'),
    ]);
  });

  test('dropping above the first header clamps to the first chapter', () {
    final items = buildNotebookContents(chapters, <NotebookContentsEntry>[
      entry('a', 'c1'),
      entry('c', 'c2'),
    ]);
    // [c1, a, c2, c]：把 c 拖到最顶端。
    final placements = resolveNotebookContentsDrop(items, 3, 0);
    expect(placements.first, (diaryId: 'c', chapterId: 'c1'));
    final rebuilt = buildNotebookContents(chapters, <NotebookContentsEntry>[
      entry('a', 'c1'),
      entry('c', 'c2'),
    ], pending: placements);
    expect(keys(rebuilt), <String>[
      'chapter_c1',
      'entry_c',
      'entry_a',
      'chapter_c2',
      'chapter__unassigned',
    ]);
  });

  test('dropping after the unassigned header removes the chapter', () {
    final items = buildNotebookContents(chapters, <NotebookContentsEntry>[
      entry('a', 'c1'),
      entry('b', null),
    ]);
    // [c1, a, c2, unassigned, b]：把 a 拖到最后。
    final placements = resolveNotebookContentsDrop(items, 1, 4);
    expect(placements.last, (diaryId: 'a', chapterId: null));
  });

  test('dropping onto the empty unassigned zone at the end removes the '
      'chapter', () {
    final items = buildNotebookContents(chapters, <NotebookContentsEntry>[
      entry('a', 'c1'),
      entry('b', 'c2'),
    ]);
    // [c1, a, c2, b, unassigned]：把 a 拖到列表末尾（“未分章”之后）。
    expect((items.last as NotebookContentsHeader).count, 0);
    final placements = resolveNotebookContentsDrop(items, 1, 4);
    expect(placements, <NotebookEntryPlacement>[
      (diaryId: 'b', chapterId: 'c2'),
      (diaryId: 'a', chapterId: null),
    ]);
  });

  test('chapter counts treat dangling chapter ids as unassigned', () {
    final counts = NotebookChapterCounts.from(chapters, <String, String?>{
      'a': 'c1',
      'b': 'c1',
      'c': null,
      'd': 'gone',
    });
    expect(counts.of('c1'), 2);
    expect(counts.of('c2'), 0);
    expect(counts.unassigned, 2);
    expect(counts.total, 4);
  });
}
