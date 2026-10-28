import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 首页快速滚动条的完整时间轴：与列表同一筛选、范围与排序，只带排序依据。
///
/// drift 默认以秒存储 DateTime，测试时间戳之间至少相差 1 秒。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> insert(
    String title, {
    required DateTime createdAt,
    String text = '正文',
    List<int> tagIds = const <int>[],
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$text\\n"}]',
      contentText: text,
      metadataJson: '{}',
      tagIds: tagIds,
      createdAtOverride: createdAt,
    );
  }

  Future<List<String>> listed({
    String keyword = '',
    List<int> tagIds = const <int>[],
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
    DiaryListScope scope = DiaryListScope.all,
  }) async {
    final items = await db
        .watchDiaries(
          keyword: keyword,
          requiredTagIds: tagIds,
          sortMode: sortMode,
          scope: scope,
        )
        .first;
    return items.map((item) => item.diary.diaryId).toList();
  }

  Future<List<DiaryTimelineEntry>> timeline({
    String keyword = '',
    List<int> tagIds = const <int>[],
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
    DiaryListScope scope = DiaryListScope.all,
  }) {
    return db
        .watchDiaryTimeline(
          keyword: keyword,
          requiredTagIds: tagIds,
          sortMode: sortMode,
          scope: scope,
        )
        .first;
  }

  test('follows the list filter and order and carries the sort keys', () async {
    final travel = await db.createTag(name: '旅行', color: 0xFF4CAF50);
    final a = await insert(
      '海边',
      createdAt: DateTime(2024, 5, 1, 9),
      text: '看日落',
      tagIds: <int>[travel],
    );
    await insert('山里', createdAt: DateTime(2025, 2, 3, 9), text: '爬山');
    final c = await insert('', createdAt: DateTime(2026, 7, 4, 9), text: '海风');
    final archived = await insert('归档', createdAt: DateTime(2026, 8, 1, 9));
    final deleted = await insert('删除', createdAt: DateTime(2026, 8, 2, 9));
    await db.archiveDiary(archived);
    await db.softDeleteDiary(deleted);
    await db.pinDiary(a);

    for (final mode in DiarySortMode.values) {
      final entries = await timeline(sortMode: mode);
      expect(
        entries.map((entry) => entry.diaryId),
        await listed(sortMode: mode),
        reason: mode.name,
      );
    }
    final entries = await timeline(sortMode: DiarySortMode.createdAsc);
    expect(entries.first.diaryId, a, reason: '置顶在最前');
    expect(entries.first.isPinned, isTrue);
    expect(entries.first.createdAt.toLocal(), DateTime(2024, 5, 1, 9));
    expect(entries.first.title, '海边');
    expect(entries.last.diaryId, c);
    expect(entries.last.title, '');
    expect(entries.every((entry) => entry.chapterRank == null), isTrue);

    expect(
      (await timeline(keyword: '海')).map((entry) => entry.diaryId),
      await listed(keyword: '海'),
    );
    expect(
      (await timeline(tagIds: <int>[travel])).map((entry) => entry.diaryId),
      <String>[a],
    );
  });

  test('book order carries each entry\'s chapter rank', () async {
    final day = DateTime(2026, 3, 10, 9);
    final book = await db.createNotebook(
      name: '书',
      visibility: NotebookVisibility.normal,
      payload: NotebookPayload(
        chapters: <NotebookChapter>[
          NotebookChapter(id: 'c1', title: '一'),
          NotebookChapter(id: 'c2', title: '二'),
        ],
      ),
    );
    final ids = <String, String>{
      for (final title in <String>['A', 'B', 'C'])
        title: await insert(
          title,
          createdAt: day.add(Duration(hours: title.codeUnitAt(0))),
        ),
    };
    await db.addDiariesToNotebook(book, ids.values);
    await db.setNotebookEntriesChapter(book, <String>[ids['C']!], 'c1');
    await db.setNotebookEntriesChapter(book, <String>[ids['A']!], 'c2');
    final scope = DiaryNotebookScope(
      notebookId: book,
      bookOrder: true,
      chapterOrder: const <String>['c1', 'c2'],
    );

    final entries = await timeline(scope: scope);
    expect(entries.map((entry) => entry.diaryId), await listed(scope: scope));
    expect(
      <String?, int?>{
        for (final entry in entries) entry.diaryId: entry.chapterRank,
      },
      <String, int>{ids['C']!: 0, ids['A']!: 1, ids['B']!: 2},
      reason: '未分章的序号等于章节数',
    );
  });

  test('pushes a new timeline when a diary is written', () async {
    await insert('一', createdAt: DateTime(2026, 1, 1, 9));
    final iterator = StreamIterator<List<DiaryTimelineEntry>>(
      db.watchDiaryTimeline(),
    );
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    await insert('二', createdAt: DateTime(2026, 1, 2, 9));
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(2));
    await iterator.cancel();
  });
}
