import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final day = DateTime(2026, 3, 10, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.batch((batch) {
      batch.insertAll(db.tags, <TagsCompanion>[
        for (var id = 1; id <= 3; id++)
          TagsCompanion.insert(id: Value(id), name: 'tag-$id', color: id),
      ]);
    });
  });
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    List<int> tagIds = const <int>[],
    List<String>? notebookIds,
    bool withImage = false,
    String metadata = '{}',
    DateTime? createdAt,
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: withImage
          ? '[{"insert":{"image":"/img/$title.png"}},{"insert":"\\n"}]'
          : '[{"insert":"$title body\\n"}]',
      contentText: '$title body',
      metadataJson: metadata,
      tagIds: tagIds,
      notebookIds: notebookIds,
      createdAtOverride: createdAt ?? day,
    );
  }

  Future<String> notebook(
    String name, {
    NotebookVisibility visibility = NotebookVisibility.normal,
    NotebookPayload payload = NotebookPayload.defaults,
  }) {
    return db.createNotebook(
      name: name,
      visibility: visibility,
      payload: payload,
    );
  }

  Future<List<String>> titlesOf(DiaryListScope scope) async {
    final rows = await db.watchDiaries(scope: scope).first;
    return rows.map((row) => row.diary.title).toList();
  }

  /// 等到流推送一个满足 [matcher] 的值；表依赖漏订阅时流不会再推送，超时失败。
  Future<void> expectEventually<T>(
    StreamIterator<T> iterator,
    Matcher matcher,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      final moved = await iterator.moveNext().timeout(
        deadline.difference(DateTime.now()),
        onTimeout: () => false,
      );
      if (!moved) break;
      if (matcher.matches(iterator.current, <Object?, Object?>{})) return;
    }
    fail('stream never emitted a value matching $matcher');
  }

  group('notebook scope', () {
    late String book;
    late Map<String, String> ids;

    setUp(() async {
      book = await notebook(
        '书',
        payload: NotebookPayload(
          chapters: <NotebookChapter>[
            NotebookChapter(id: 'c1', title: '一'),
            NotebookChapter(id: 'c2', title: '二'),
          ],
        ),
      );
      ids = <String, String>{
        for (final title in <String>['A', 'B', 'C', 'D', 'E'])
          title: await diary(
            title,
            createdAt: day.add(Duration(hours: title.codeUnitAt(0))),
          ),
      };
      await diary('outside');
      // 加入顺序即成书位置 0..4。
      await db.addDiariesToNotebook(book, ids.values);
      await db.setNotebookEntriesChapter(book, <String>[
        ids['C']!,
        ids['D']!,
      ], 'c1');
      await db.setNotebookEntriesChapter(book, <String>[ids['A']!], 'c2');
      // 指向已不存在章节的成员行（例如章节在别处被删、尚未清理）。
      await db.customUpdate(
        "UPDATE diary_notebooks SET chapter_id = 'gone' "
        'WHERE diary_id = (SELECT id FROM diaries WHERE diary_id = ?)',
        variables: <Variable<Object>>[Variable<String>(ids['E']!)],
        updates: <TableInfo>{db.diaryNotebooks},
      );
      await db.pinDiary(ids['D']!);
    });

    DiaryNotebookScope scopeOf({
      String? chapterId,
      bool unassigned = false,
      bool bookOrder = false,
    }) => DiaryNotebookScope(
      notebookId: book,
      chapterId: chapterId,
      unassignedChapterOnly: unassigned,
      bookOrder: bookOrder,
      chapterOrder: const <String>['c1', 'c2'],
    );

    test('returns only members, filtered by chapter', () async {
      expect(
        await titlesOf(scopeOf()),
        unorderedEquals(<String>['A', 'B', 'C', 'D', 'E']),
      );
      expect(await titlesOf(scopeOf(chapterId: 'c1')), <String>['D', 'C']);
      expect(
        await titlesOf(scopeOf(unassigned: true)),
        unorderedEquals(<String>['B', 'E']),
      );
      expect(
        await titlesOf(
          DiaryNotebookScope(notebookId: book, unassignedChapterOnly: true),
        ),
        hasLength(5),
        reason: '没有章节时全部成员都算未分章',
      );
      expect(
        await titlesOf(const DiaryNotebookScope(notebookId: 'nope')),
        isEmpty,
      );
    });

    test(
      'book order follows chapters then position, pinned not floated',
      () async {
        expect(await titlesOf(scopeOf(bookOrder: true)), <String>[
          'C',
          'D',
          'A',
          'B',
          'E',
        ]);
        // 普通排序下置顶仍然在前。
        expect((await titlesOf(scopeOf())).first, 'D');
        expect(
          await titlesOf(DiaryNotebookScope(notebookId: book, bookOrder: true)),
          <String>['A', 'B', 'C', 'D', 'E'],
          reason: '没有章节顺序时按本内位置',
        );
      },
    );

    test('paged windows match the full id sequence', () async {
      for (final scope in <DiaryListScope>[
        scopeOf(),
        scopeOf(bookOrder: true),
        scopeOf(bookOrder: true, unassigned: true),
        scopeOf(chapterId: 'c1', bookOrder: true),
      ]) {
        for (final mode in DiarySortMode.values) {
          final all = await db.watchDiaries(scope: scope, sortMode: mode).first;
          final idsInOrder = await db.getActiveDiaryIds(
            scope: scope,
            sortMode: mode,
          );
          expect(idsInOrder, all.map((row) => row.diary.diaryId));
          final paged = <String>[];
          for (var offset = 0; offset < all.length + 2; offset += 2) {
            final page = await db
                .watchDiaries(
                  scope: scope,
                  sortMode: mode,
                  limit: 2,
                  offset: offset,
                )
                .first;
            paged.addAll(page.map((row) => row.diary.diaryId));
          }
          expect(paged, idsInOrder, reason: '$scope $mode');
        }
      }
    });

    test('keyword and tag filters combine with the scope', () async {
      await db.updateDiary(
        diaryId: ids['B']!,
        title: 'B needle',
        contentDocJson: '[{"insert":"x\\n"}]',
        contentText: 'x',
        metadataJson: '{}',
        tagIds: const <int>[2],
      );
      final rows = await db
          .watchDiaries(
            keyword: 'needle',
            requiredTagIds: const <int>[2],
            scope: scopeOf(),
          )
          .first;
      expect(rows.map((row) => row.diary.title), <String>['B needle']);
    });
  });

  group('privacy', () {
    late String normal;
    late String private;
    late String privateArchived;
    late String locked;
    late String hiddenBook;
    late String lockedBook;
    late String normalBook;

    setUp(() async {
      hiddenBook = await notebook('藏', visibility: NotebookVisibility.hidden);
      lockedBook = await notebook('锁', visibility: NotebookVisibility.locked);
      normalBook = await notebook('普通');
      normal = await diary(
        'normal',
        tagIds: const <int>[1],
        withImage: true,
        metadata: '{"weather":"sunny"}',
        notebookIds: <String>[normalBook],
      );
      private = await diary(
        'private',
        tagIds: const <int>[2],
        withImage: true,
        metadata: '{"weather":"sunny"}',
        notebookIds: <String>[hiddenBook, normalBook],
      );
      privateArchived = await diary(
        'private-archived',
        notebookIds: <String>[hiddenBook],
      );
      await db.archiveDiary(privateArchived);
      locked = await diary(
        'locked',
        tagIds: const <int>[3],
        notebookIds: <String>[lockedBook],
      );
    });

    Future<Set<String>> visibleEverywhere() async {
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final sets = <String, Set<String>>{
        'list': (await db.watchDiaries().first)
            .map((row) => row.diary.diaryId)
            .toSet(),
        'ids': (await db.getActiveDiaryIds()).toSet(),
        'search': (await db.watchDiaries(keyword: 'body').first)
            .map((row) => row.diary.diaryId)
            .toSet(),
        'explore': (await db.watchExploreDiaryOverviews().first)
            .map((row) => row.diaryId)
            .toSet(),
        'export': (await db.watchAllActiveDiaries().first)
            .map((row) => row.diary.diaryId)
            .toSet(),
        'media': (await db.getActiveDiariesPage(
          limit: 50,
          offset: 0,
        )).map((row) => row.diaryId).toSet(),
        'archived': (await db.watchArchivedDiaries().first)
            .map((row) => row.diary.diaryId)
            .toSet(),
        'markers': (await db.watchDiaryMarkersInRange(dayStart, dayEnd).first)
            .map((row) => row.diaryId)
            .toSet(),
        'month': (await db.watchDiaryMarkersByMonth(day).first)
            .map((row) => row.diaryId)
            .toSet(),
        'day': (await db.watchDiariesCreatedOnDay(day).first)
            .map((row) => row.diary.diaryId)
            .toSet(),
        'ranges': (await db.watchDiariesCreatedInRanges(<(DateTime, DateTime)>[
          (dayStart, dayEnd),
        ]).first).map((row) => row.diary.diaryId).toSet(),
        'images':
            (await db.watchDiaryImageCandidatesInRange(dayStart, dayEnd).first)
                .map((row) => row.diaryId)
                .toSet(),
        'metadata': (await db.findDiariesByMetadataValue(
          jsonPath: r'$.weather',
          expectedValue: 'sunny',
        )).map((row) => row.diaryId).toSet(),
      };
      // 普通日记在每个查询里都在（保证下面的“不在”不是查询本身查不到）。
      for (final entry in sets.entries) {
        if (entry.key == 'archived') continue;
        expect(entry.value, contains(normal), reason: entry.key);
      }
      return <String>{for (final values in sets.values) ...values};
    }

    test('private diaries vanish from every global query', () async {
      final visible = await visibleEverywhere();
      expect(visible, isNot(contains(private)));
      expect(visible, isNot(contains(privateArchived)));
      expect(visible, isNot(contains(locked)));
      expect(await db.watchActiveDiaryWithTags(normal).first, isNotNull);
      expect(await db.watchActiveDiaryWithTags(private).first, isNull);
      expect(await db.watchScopedDiaryCount(DiaryListScope.all).first, 1);
      // 按 id 直接打开不过滤。
      expect(await db.getDiaryWithTagsByDiaryId(private), isNotNull);
    });

    test('private notebook shows its members; other scopes do not', () async {
      expect(
        await titlesOf(DiaryNotebookScope(notebookId: hiddenBook)),
        <String>['private'],
      );
      expect(
        await titlesOf(DiaryNotebookScope(notebookId: lockedBook)),
        <String>['locked'],
      );
      expect(
        await titlesOf(DiaryNotebookScope(notebookId: normalBook)),
        <String>['normal'],
        reason: '私密优先于其他归属',
      );
      final explore = await db
          .watchExploreDiaryOverviews(
            scope: DiaryNotebookScope(notebookId: hiddenBook),
          )
          .first;
      expect(
        explore.map((row) => row.diaryId),
        unorderedEquals(<String>[private, privateArchived]),
        reason: '探索口径含归档',
      );
      expect(await db.watchManualNotebookEntryCounts().first, <String, int>{
        hiddenBook: 1,
        lockedBook: 1,
        normalBook: 1,
      });
    });

    test('smart scope applies its predicate and still hides private', () async {
      const predicate = DiaryScopePredicate(
        sql: 'd.title LIKE ?',
        variables: <Variable<Object>>[Variable<String>('%a%')],
      );
      const smart = DiarySmartScope(notebookId: 's', predicate: predicate);
      expect(await titlesOf(smart), <String>['normal']);
      expect(await db.watchScopedDiaryCount(smart).first, 1);
      expect(await db.getActiveDiaryIds(scope: smart), <String>[normal]);
    });

    test('tag ids, private ids and isDiaryPrivate', () async {
      expect(await db.watchTagIdsUsedInScope(DiaryListScope.all).first, <int>{
        1,
      });
      expect(
        await db
            .watchTagIdsUsedInScope(DiaryNotebookScope(notebookId: hiddenBook))
            .first,
        <int>{2},
      );
      expect(await db.watchPrivateDiaryIds().first, <String>{
        private,
        privateArchived,
        locked,
      });
      expect(await db.isDiaryPrivate(private), isTrue);
      expect(await db.isDiaryPrivate(normal), isFalse);
      expect(await db.isDiaryPrivate('nope'), isFalse);
    });

    test('streams re-emit when membership or visibility changes', () async {
      final list = StreamIterator(db.watchDiaries());
      final markers = StreamIterator(db.watchDiaryMarkersByMonth(day));
      final count = StreamIterator(
        db.watchScopedDiaryCount(DiaryListScope.all),
      );
      final archived = StreamIterator(db.watchArchivedDiaries());
      final images = StreamIterator(
        db.watchDiaryImageCandidatesInRange(
          DateTime(day.year, day.month, day.day),
          DateTime(day.year, day.month, day.day + 1),
        ),
      );
      final entryCounts = StreamIterator(db.watchManualNotebookEntryCounts());
      final privateIds = StreamIterator(db.watchPrivateDiaryIds());
      for (final iterator in <StreamIterator<Object?>>[
        list,
        markers,
        count,
        archived,
        images,
        entryCounts,
        privateIds,
      ]) {
        addTearDown(iterator.cancel);
      }
      Matcher listHas(String id, {bool present = true}) {
        final has = predicate<List<DiaryWithTags>>(
          (rows) => rows.any((row) => row.diary.diaryId == id),
        );
        return present ? has : isNot(has);
      }

      await expectEventually(list, listHas(locked, present: false));
      await expectEventually(count, equals(1));

      // 移出加锁的本子 → 重新出现。
      await db.removeDiariesFromNotebook(lockedBook, <String>[locked]);
      await expectEventually(list, listHas(locked));
      await expectEventually(count, equals(2));
      await expectEventually(
        privateIds,
        equals(<String>{private, privateArchived}),
      );

      // 隐藏本改回普通 → 成员回到全局；普通本的篇数也算上它。
      await db.updateNotebook(
        hiddenBook,
        visibility: NotebookVisibility.normal,
      );
      await expectEventually(list, listHas(private));
      await expectEventually(
        markers,
        predicate<List<DiaryCalendarMarker>>(
          (rows) => rows.any((row) => row.diaryId == private),
        ),
      );
      await expectEventually(
        archived,
        predicate<List<DiaryWithTags>>(
          (rows) => rows.any((row) => row.diary.diaryId == privateArchived),
        ),
      );
      await expectEventually(
        images,
        predicate<List<DiaryImageCandidate>>(
          (rows) => rows.any((row) => row.diaryId == private),
        ),
      );
      await expectEventually(
        entryCounts,
        equals(<String, int>{hiddenBook: 1, normalBook: 2}),
      );

      // 把普通日记加进加锁的本子 → 从全局消失。
      await db.addDiariesToNotebook(lockedBook, <String>[normal]);
      await expectEventually(list, listHas(normal, present: false));
      await expectEventually(count, equals(2));
      await expectEventually(
        entryCounts,
        equals(<String, int>{hiddenBook: 1, lockedBook: 1, normalBook: 1}),
      );
    });
  });

  test('scopes compare by value', () {
    expect(DiaryListScope.all, const DiaryAllScope());
    expect(
      const DiaryNotebookScope(notebookId: 'n', chapterOrder: <String>['a']),
      DiaryNotebookScope(notebookId: 'n', chapterOrder: <String>['a']),
    );
    expect(
      const DiaryNotebookScope(notebookId: 'n', bookOrder: true),
      isNot(const DiaryNotebookScope(notebookId: 'n')),
    );
    DiarySmartScope smart(String value) => DiarySmartScope(
      notebookId: 's',
      predicate: DiaryScopePredicate(
        sql: 'd.title = ?',
        variables: <Variable<Object>>[Variable<String>(value)],
      ),
    );
    expect(smart('x'), smart('x'));
    expect(smart('x').hashCode, smart('x').hashCode);
    expect(smart('x'), isNot(smart('y')));
  });
}
