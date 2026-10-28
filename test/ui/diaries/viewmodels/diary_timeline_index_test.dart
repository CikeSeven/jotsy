import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_timeline_index.dart';
import 'package:node_diary/ui/widgets/fast_scroller/fast_scroller.dart';

/// 首页快速滚动条的标签与分段：按排序方式取标签，置顶单独一段，后段来自
/// 完整时间轴。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  DiaryWithTags loaded(
    String id, {
    required DateTime created,
    DateTime? updated,
    String title = '',
    bool pinned = false,
  }) {
    return DiaryWithTags(
      diary: Diary(
        id: id.hashCode,
        diaryId: id,
        title: title,
        content: '[]',
        contentText: '',
        metadata: '{}',
        createdAt: created,
        updatedAt: updated ?? created,
        isArchived: false,
        isPinned: pinned,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
  }

  DiaryTimelineEntry entry(
    String id, {
    required DateTime created,
    String title = '',
    bool pinned = false,
    int? chapterRank,
  }) {
    return DiaryTimelineEntry(
      diaryId: id,
      isPinned: pinned,
      createdAt: created,
      updatedAt: created,
      title: title,
      chapterRank: chapterRank,
    );
  }

  List<(int, String)> sectionsOf(DiaryTimelineIndex index) => <(int, String)>[
    for (final FastScrollSection section in index.sections)
      (section.index, section.label),
  ];

  test('date sorts label months under years, with years as sections', () {
    final items = <DiaryWithTags>[
      loaded('p', created: DateTime(2020, 1, 1), pinned: true),
      loaded('a', created: DateTime(2026, 3, 12)),
      loaded('b', created: DateTime(2026, 1, 2)),
      loaded('c', created: DateTime(2025, 12, 30)),
    ];
    final index = DiaryTimelineIndex(
      loaded: items,
      timeline: null,
      hasMore: false,
      sortMode: DiarySortMode.createdDesc,
      bookOrder: false,
      chapterTitles: const <String>[],
      l10n: zh,
    );

    expect(index.length, 4);
    expect(index.labelAt(0), FastScrollLabel(zh.diaryFastScrollPinned));
    expect(index.labelAt(1), const FastScrollLabel('3月', caption: '2026年'));
    expect(index.labelAt(3), const FastScrollLabel('12月', caption: '2025年'));
    // 置顶不单独成段，第一个年份从置顶之后开始。
    expect(sectionsOf(index), <(int, String)>[(1, '2026'), (3, '2025')]);
  });

  test('a single year is divided by month instead', () {
    final index = DiaryTimelineIndex(
      loaded: <DiaryWithTags>[
        loaded(
          'a',
          created: DateTime(2026, 1, 1),
          updated: DateTime(2026, 5, 3),
        ),
        loaded(
          'b',
          created: DateTime(2026, 2, 1),
          updated: DateTime(2026, 5, 1),
        ),
        loaded(
          'c',
          created: DateTime(2026, 3, 1),
          updated: DateTime(2026, 4, 9),
        ),
      ],
      timeline: null,
      hasMore: false,
      sortMode: DiarySortMode.updatedDesc,
      bookOrder: false,
      chapterTitles: const <String>[],
      l10n: en,
    );

    expect(index.labelAt(0), const FastScrollLabel('May', caption: '2026'));
    expect(sectionsOf(index), <(int, String)>[(0, 'May'), (2, 'Apr')]);
  });

  test('unloaded items come from the timeline after the loaded part', () {
    final index = DiaryTimelineIndex(
      loaded: <DiaryWithTags>[
        loaded('a', created: DateTime(2026, 3, 1)),
        loaded('b', created: DateTime(2026, 2, 1)),
      ],
      timeline: <DiaryTimelineEntry>[
        entry('a', created: DateTime(2026, 3, 1)),
        entry('b', created: DateTime(2026, 2, 1)),
        entry('c', created: DateTime(2024, 7, 1)),
        entry('d', created: DateTime(2023, 1, 1)),
      ],
      hasMore: true,
      sortMode: DiarySortMode.createdDesc,
      bookOrder: false,
      chapterTitles: const <String>[],
      l10n: zh,
    );

    expect(index.length, 4);
    expect(index.labelAt(3), const FastScrollLabel('1月', caption: '2023年'));
    expect(sectionsOf(index), <(int, String)>[
      (0, '2026'),
      (2, '2024'),
      (3, '2023'),
    ]);

    // 全部加载完时不看时间轴（它可能还停在旧数据上）。
    final complete = DiaryTimelineIndex(
      loaded: <DiaryWithTags>[loaded('a', created: DateTime(2026, 3, 1))],
      timeline: <DiaryTimelineEntry>[
        entry('a', created: DateTime(2026, 3, 1)),
        entry('stale', created: DateTime(2020, 1, 1)),
      ],
      hasMore: false,
      sortMode: DiarySortMode.createdDesc,
      bookOrder: false,
      chapterTitles: const <String>[],
      l10n: zh,
    );
    expect(complete.length, 1);
  });

  test('title sorts label initials, untitled last', () {
    final index = DiaryTimelineIndex(
      loaded: <DiaryWithTags>[
        loaded('1', created: DateTime(2026), title: 'Apple'),
        loaded('2', created: DateTime(2026), title: '爱好'),
        loaded('3', created: DateTime(2026), title: '春天'),
        loaded('4', created: DateTime(2026), title: '  '),
      ],
      timeline: null,
      hasMore: false,
      sortMode: DiarySortMode.titleAsc,
      bookOrder: false,
      chapterTitles: const <String>[],
      l10n: zh,
    );

    expect(index.labelAt(1), const FastScrollLabel('A'));
    expect(index.labelAt(3), FastScrollLabel(zh.diaryFastScrollUntitled));
    expect(sectionsOf(index), <(int, String)>[
      (0, 'A'),
      (2, 'C'),
      (3, zh.diaryFastScrollUntitled),
    ]);
  });

  test('book order labels chapters with the month as caption', () {
    final index = DiaryTimelineIndex(
      loaded: <DiaryWithTags>[
        // 成书顺序不让置顶插队，也不标“置顶”。
        loaded('a', created: DateTime(2026, 3, 1), pinned: true),
        loaded('b', created: DateTime(2025, 1, 1)),
      ],
      timeline: <DiaryTimelineEntry>[
        entry('a', created: DateTime(2026, 3, 1), chapterRank: 0),
        entry('b', created: DateTime(2025, 1, 1), chapterRank: 0),
        entry('c', created: DateTime(2024, 1, 1), chapterRank: 1),
        entry('d', created: DateTime(2024, 2, 1), chapterRank: 2),
      ],
      hasMore: true,
      sortMode: DiarySortMode.createdDesc,
      bookOrder: true,
      chapterTitles: const <String>['序章', '远行'],
      l10n: zh,
    );

    expect(index.labelAt(0), const FastScrollLabel('序章', caption: '2026年3月'));
    expect(index.labelAt(3).primary, zh.notebookChapterUnassigned);
    expect(sectionsOf(index), <(int, String)>[
      (0, '序章'),
      (2, '远行'),
      (3, zh.notebookChapterUnassigned),
    ]);
  });

  test('book order without chapters shows dates and no sections', () {
    final index = DiaryTimelineIndex(
      loaded: <DiaryWithTags>[
        loaded('a', created: DateTime(2026, 3, 1)),
        loaded('b', created: DateTime(2024, 1, 1)),
      ],
      timeline: null,
      hasMore: false,
      sortMode: DiarySortMode.createdDesc,
      bookOrder: true,
      chapterTitles: const <String>[],
      l10n: zh,
    );

    expect(index.labelAt(1), const FastScrollLabel('1月', caption: '2024年'));
    expect(index.sections, isEmpty);
  });
}
