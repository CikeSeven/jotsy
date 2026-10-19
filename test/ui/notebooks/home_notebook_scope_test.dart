import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/notebooks/models/notebook_scope_resolver.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_header_meta.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

/// 首页日记本范围：范围解析（普通 / 智能 / 书序 / 章节）、按范围分开的标签
/// 筛选记忆、日记本消失时的回退判定，以及头部统计行的格式。
NotebookView _view(
  String id, {
  NotebookKind kind = NotebookKind.manual,
  NotebookPayload payload = NotebookPayload.defaults,
  NotebookVisibility visibility = NotebookVisibility.normal,
}) {
  final now = DateTime(2026, 10, 1);
  return NotebookView(
    NotebookRow(
      id: id.hashCode,
      notebookId: id,
      name: 'Notebook $id',
      kind: kind.name,
      visibility: visibility.name,
      payload: payload.encode(),
      isPinned: false,
      isClosed: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

final _chapters = <NotebookChapter>[
  NotebookChapter(id: 'c1', title: 'One'),
  NotebookChapter(id: 'c2', title: 'Two'),
];

void main() {
  group('resolveNotebookScope', () {
    test('manual notebook uses membership scope with chapter order', () {
      final notebook = _view(
        'travel',
        payload: NotebookPayload(chapters: _chapters),
      );
      expect(
        resolveNotebookScope(notebook),
        const DiaryNotebookScope(
          notebookId: 'travel',
          chapterOrder: <String>['c1', 'c2'],
        ),
      );
    });

    test('book sort turns on book order, other sorts map to list sorts', () {
      final notebook = _view(
        'travel',
        payload: NotebookPayload(sort: NotebookSort.book),
      );
      final scope = resolveNotebookScope(notebook) as DiaryNotebookScope;
      expect(scope.bookOrder, isTrue);
      expect(
        (resolveNotebookScope(notebook, sort: NotebookSort.createdAsc)
                as DiaryNotebookScope)
            .bookOrder,
        isFalse,
      );
      expect(
        diarySortModeForNotebook(NotebookSort.createdAsc),
        DiarySortMode.createdAsc,
      );
      expect(
        diarySortModeForNotebook(NotebookSort.updatedDesc),
        DiarySortMode.updatedDesc,
      );
      expect(
        diarySortModeForNotebook(NotebookSort.createdDesc),
        DiarySortMode.createdDesc,
      );
    });

    test('chapter selection is carried; chapter id wins over unassigned', () {
      final notebook = _view(
        'travel',
        payload: NotebookPayload(chapters: _chapters),
      );
      final chapter =
          resolveNotebookScope(
                notebook,
                chapterId: 'c2',
                unassignedChapterOnly: true,
              )
              as DiaryNotebookScope;
      expect(chapter.chapterId, 'c2');
      expect(chapter.unassignedChapterOnly, isFalse);
      final unassigned =
          resolveNotebookScope(notebook, unassignedChapterOnly: true)
              as DiaryNotebookScope;
      expect(unassigned.chapterId, isNull);
      expect(unassigned.unassignedChapterOnly, isTrue);
    });

    test('smart notebook compiles rules and has no book order', () {
      final notebook = _view(
        'photos',
        kind: NotebookKind.smart,
        payload: NotebookPayload(
          sort: NotebookSort.book,
          rules: const <String, Object?>{'any': true},
        ),
      );
      final scope = resolveNotebookScope(notebook);
      expect(scope, isA<DiarySmartScope>());
      // 规则编译器接入前：什么都不匹配。
      expect((scope as DiarySmartScope).predicate.sql, '0');
      expect(compileNotebookRules(null).sql, '0');
      expect(
        effectiveNotebookSort(notebook, NotebookSort.book),
        NotebookSort.createdDesc,
      );
    });
  });

  group('HomeNotebookScopeNotifier', () {
    late StreamController<List<NotebookView>> shelf;
    late ProviderContainer container;

    setUp(() {
      shelf = StreamController<List<NotebookView>>.broadcast();
      container = ProviderContainer(
        overrides: [notebooksProvider.overrideWith((ref) => shelf.stream)],
      );
      // 保持解析 provider 被监听，书架流才会被订阅。
      container.listen(homeNotebookScopeResolutionProvider, (_, _) {});
    });

    tearDown(() async {
      container.dispose();
      await shelf.close();
    });

    test('keeps the all-scope tag selection separate from notebooks', () {
      final filter = container.read(diaryFilterProvider.notifier);
      final scope = container.read(homeNotebookScopeProvider.notifier);
      filter.setTags(<int>[1, 2]);

      scope.enter('travel');
      expect(container.read(diaryFilterProvider).selectedTagIds, isEmpty);
      filter.toggleTag(7, true);
      expect(container.read(diaryFilterProvider).selectedTagIds, <int>{7});

      scope.showAll();
      expect(container.read(diaryFilterProvider).selectedTagIds, <int>{1, 2});
      expect(container.read(homeNotebookScopeProvider).isAll, isTrue);

      // 再进日记本仍从空选择开始。
      scope.enter('travel');
      expect(container.read(diaryFilterProvider).selectedTagIds, isEmpty);
    });

    test('resolution follows the shelf and flags a missing notebook', () async {
      final scope = container.read(homeNotebookScopeProvider.notifier);
      expect(
        container.read(homeNotebookScopeResolutionProvider),
        HomeNotebookScopeResolution.all,
      );
      scope.enter('travel');
      // 书架还没推送：不当作消失，范围什么都不匹配。
      var resolution = container.read(homeNotebookScopeResolutionProvider);
      expect(resolution.missing, isFalse);
      expect(resolution.scope, isA<DiarySmartScope>());

      shelf.add(<NotebookView>[
        _view('travel', payload: NotebookPayload(sort: NotebookSort.book)),
      ]);
      await Future<void>.delayed(Duration.zero);
      resolution = container.read(homeNotebookScopeResolutionProvider);
      expect(resolution.notebook?.id, 'travel');
      expect(resolution.sort, NotebookSort.book);
      expect((resolution.scope as DiaryNotebookScope).bookOrder, isTrue);

      // 临时排序优先于本子里存的排序。
      scope.setSortOverride(NotebookSort.createdAsc);
      resolution = container.read(homeNotebookScopeResolutionProvider);
      expect(resolution.sort, NotebookSort.createdAsc);
      expect((resolution.scope as DiaryNotebookScope).bookOrder, isFalse);

      shelf.add(const <NotebookView>[]);
      await Future<void>.delayed(Duration.zero);
      resolution = container.read(homeNotebookScopeResolutionProvider);
      expect(resolution.missing, isTrue);
      expect(resolution.notebook, isNull);
    });

    test('relock only applies inside a notebook and unlock clears it', () {
      final scope = container.read(homeNotebookScopeProvider.notifier);
      scope.relock();
      expect(container.read(homeNotebookScopeProvider).relocked, isFalse);
      scope.enter('vault');
      scope.relock();
      expect(container.read(homeNotebookScopeProvider).relocked, isTrue);
      scope.unlock();
      expect(container.read(homeNotebookScopeProvider).relocked, isFalse);
    });
  });

  group('notebook header meta line', () {
    setUpAll(() async {
      await initializeDateFormatting('zh');
      await initializeDateFormatting('en');
    });
    final zh = lookupAppLocalizations(const Locale('zh'));
    final en = lookupAppLocalizations(const Locale('en'));
    ExploreDiaryOverview overview(String id, DateTime created, int words) =>
        ExploreDiaryOverview(
          diaryId: id,
          title: '',
          contentText: List<String>.filled(words, '字').join(),
          metadata: '{}',
          createdAt: created,
          updatedAt: created,
          tags: const <Tag>[],
        );

    test('count, grouped words and an ongoing span', () {
      final stats = NotebookHeaderStats.from(23, <ExploreDiaryOverview>[
        overview('a', DateTime(2023, 5, 3), 12000),
        overview('b', DateTime(2026, 10, 2), 9000),
      ]);
      expect(
        notebookHeaderMetaLine(zh, stats, now: DateTime(2026, 10, 18)),
        '23 篇 · 21,000 字 · 2023年5月 – 至今',
      );
      expect(
        notebookHeaderMetaLine(en, stats, now: DateTime(2026, 10, 18)),
        contains('21,000 words'),
      );
    });

    test('a closed span names both months, a single month only one', () {
      final span = NotebookHeaderStats.from(2, <ExploreDiaryOverview>[
        overview('a', DateTime(2024, 1, 3), 10),
        overview('b', DateTime(2024, 3, 9), 10),
      ]);
      expect(
        notebookSpanLabel(zh, span, now: DateTime(2026, 10, 18)),
        '2024年1月 – 2024年3月',
      );
      final single = NotebookHeaderStats.from(1, <ExploreDiaryOverview>[
        overview('a', DateTime(2026, 10, 3), 10),
      ]);
      expect(
        notebookHeaderMetaLine(zh, single, now: DateTime(2026, 10, 18)),
        '1 篇 · 10 字 · 2026年10月',
      );
      expect(
        notebookHeaderMetaLine(
          zh,
          const NotebookHeaderStats(count: 0, words: 0),
          now: DateTime(2026, 10, 18),
        ),
        '0 篇 · 0 字',
      );
    });
  });
}
