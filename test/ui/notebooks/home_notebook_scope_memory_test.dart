import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/tag_order_codec.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/notebooks/models/home_notebook_scope_memory.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher_chip.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页范围跨重启记忆：切换范围时写进本机偏好，冷启动时停在上次所在的
/// 日记本 / 章节 / 未收录；本子不在、功能关闭时静默从全部日记开始，上锁的
/// 本子以重锁状态恢复。
void main() {
  group('HomeNotebookScopeMemory', () {
    test('round-trips notebook, chapter, unassigned and unfiled scopes', () {
      for (final memory in <HomeNotebookScopeMemory>[
        const HomeNotebookScopeMemory.notebook('travel'),
        const HomeNotebookScopeMemory.notebook('travel', chapterId: 'c1'),
        const HomeNotebookScopeMemory.notebook(
          'travel',
          unassignedChapterOnly: true,
        ),
        const HomeNotebookScopeMemory.unfiled(),
      ]) {
        final raw = HomeNotebookScopeMemory.encode(
          notebookId: memory.notebookId,
          unfiled: memory.unfiled,
          chapterId: memory.chapterId,
          unassignedChapterOnly: memory.unassignedChapterOnly,
        );
        expect(HomeNotebookScopeMemory.decode(raw), memory);
      }
    });

    test('all entries encode to no value', () {
      expect(HomeNotebookScopeMemory.encode(), isNull);
    });

    test('unreadable values decode as all entries', () {
      for (final raw in <String?>[
        null,
        '',
        'not json',
        '[]',
        '{"notebook": 3}',
        '{"notebook": ""}',
        '{"chapter": "c1"}',
      ]) {
        expect(HomeNotebookScopeMemory.decode(raw), isNull, reason: '$raw');
      }
    });
  });

  HomeNotebookScope scopeOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DiariesPage)),
  ).read(homeNotebookScopeProvider);

  Future<void> remember(DiaryDraftsHarness h, String? raw) =>
      h.tester.runAsync(() => h.settings.setHomeLastScopeRaw(raw));

  Future<void> pumpHome(DiaryDraftsHarness h) async {
    await h.pump(const DiariesPage());
    await h.settleAll();
  }

  testWidgets('the home page reopens in the notebook it was left in', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    await h.diary('出发', notebookIds: <String>[travel]);
    await h.diary('上班路上');
    await remember(h, HomeNotebookScopeMemory.encode(notebookId: travel));

    await pumpHome(h);

    expect(scopeOf(tester).notebookId, travel);
    expect(scopeOf(tester).relocked, isFalse);
    expect(find.byType(NotebookHeaderCard), findsOneWidget);
    expect(find.text('出发'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    await h.unmount();
  });

  testWidgets('switching scope is remembered and all entries clear it', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    await h.diary('出发', notebookIds: <String>[travel]);
    await pumpHome(h);
    expect(h.settings.homeLastScopeRaw, isNull);

    Finder inShelf(Finder finder) =>
        find.descendant(of: find.byType(NotebookShelf), matching: finder);

    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await tester.tap(inShelf(find.text('旅行')));
    await h.settleAll();
    expect(
      HomeNotebookScopeMemory.decode(h.settings.homeLastScopeRaw),
      HomeNotebookScopeMemory.notebook(travel),
    );

    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await tester.tap(inShelf(find.text('未收录')));
    await h.settleAll();
    expect(
      HomeNotebookScopeMemory.decode(h.settings.homeLastScopeRaw),
      const HomeNotebookScopeMemory.unfiled(),
    );

    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await tester.tap(inShelf(find.text('全部日记')));
    await h.settleAll();
    expect(h.settings.homeLastScopeRaw, isNull);
    await h.unmount();
  });

  testWidgets('a notebook that is gone falls back to all entries silently', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('旅行');
    await h.diary('上班路上');
    await remember(h, HomeNotebookScopeMemory.encode(notebookId: 'gone'));

    await pumpHome(h);

    expect(scopeOf(tester).isAll, isTrue);
    expect(find.text('上班路上'), findsOneWidget);
    expect(find.text(h.l10n.notebookScopeDeleted), findsNothing);
    await h.unmount();
  });

  testWidgets('a chapter that is gone falls back to the whole notebook', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook(
      '旅行',
      payload: NotebookPayload(
        chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
      ),
    );
    await remember(
      h,
      HomeNotebookScopeMemory.encode(notebookId: travel, chapterId: 'gone'),
    );

    await pumpHome(h);

    expect(scopeOf(tester).notebookId, travel);
    expect(scopeOf(tester).chapterId, isNull);
    expect(scopeOf(tester).unassignedChapterOnly, isFalse);
    await h.unmount();
  });

  testWidgets('a remembered chapter is restored with its notebook', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook(
      '旅行',
      payload: NotebookPayload(
        chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
      ),
    );
    await remember(
      h,
      HomeNotebookScopeMemory.encode(notebookId: travel, chapterId: 'c1'),
    );

    await pumpHome(h);

    expect(scopeOf(tester).notebookId, travel);
    expect(scopeOf(tester).chapterId, 'c1');
    await h.unmount();
  });

  testWidgets('a locked notebook comes back locked until verified', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final vault = await h.notebook(
      '保险箱',
      visibility: NotebookVisibility.locked,
    );
    final child = await h.notebook('子本', parentId: vault);
    await remember(h, HomeNotebookScopeMemory.encode(notebookId: child));

    await pumpHome(h);

    // 上级上了锁的子本同样要验证：以重锁状态恢复，NotebookLockLayer 盖住。
    expect(scopeOf(tester).notebookId, child);
    expect(scopeOf(tester).relocked, isTrue);
    await h.unmount();
  });

  testWidgets('with notebooks turned off the home page starts at all entries', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    await tester.runAsync(
      () => h.settings.setAppFeaturesRaw(
        AppFeatures.defaults.copyWith(notebooks: false).encode(),
      ),
    );
    await remember(h, HomeNotebookScopeMemory.encode(notebookId: travel));

    await pumpHome(h);

    expect(scopeOf(tester).isAll, isTrue);
    await h.unmount();
  });

  testWidgets('remembered tag filters wait for all entries after a restore', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final tagId = (await tester.runAsync(
      () => h.database.createTag(name: '工作', color: 0xFF2196F3),
    ))!;
    await tester.runAsync(() async {
      await h.settings.setTagFilterMemoryEnabled(true);
      await h.settings.setRememberedTagFilterIdsRaw(
        encodeTagOrder(<int>[tagId]),
      );
    });
    await remember(h, HomeNotebookScopeMemory.encode(notebookId: travel));

    await pumpHome(h);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiariesPage)),
    );
    // 本子里从空选择开始；全部日记的记忆回到全部日记时才生效。
    expect(container.read(diaryFilterProvider).selectedTagIds, isEmpty);
    container.read(homeNotebookScopeProvider.notifier).showAll();
    await h.settleAll();
    expect(container.read(diaryFilterProvider).selectedTagIds, <int>{tagId});
    await h.unmount();
  });
}
