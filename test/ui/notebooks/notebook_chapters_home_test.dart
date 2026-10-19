import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_contents_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_chapter_chips.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_chapter_divider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页日记本里的章节：头部章节胶囊（篇数、筛选、在某章里写日记）、
/// “目录”入口、书序时列表里的章节分隔行。
void main() {
  final tokyo = NotebookChapter(id: 'c1', title: '东京');
  final kyoto = NotebookChapter(id: 'c2', title: '京都');

  Future<DiaryDraftsHarness> pumpHome(
    WidgetTester tester,
    Future<void> Function(DiaryDraftsHarness h) seed,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed(h);
    await h.pump(
      const DiariesPage(),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    return h;
  }

  Future<void> enter(DiaryDraftsHarness h, String notebookId) async {
    ProviderScope.containerOf(
      h.tester.element(find.byType(DiariesPage)),
    ).read(homeNotebookScopeProvider.notifier).enter(notebookId);
    await h.settleAll();
  }

  Future<String> chaptered(
    DiaryDraftsHarness h, {
    NotebookSort sort = NotebookSort.createdDesc,
    List<NotebookChapter>? chapters,
  }) => h.notebook(
    '旅行',
    payload: NotebookPayload(
      chapters: chapters ?? <NotebookChapter>[tokyo, kyoto],
      sort: sort,
    ),
  );

  Future<void> place(
    DiaryDraftsHarness h,
    String notebookId,
    String diaryId,
    String? chapterId,
  ) async {
    await h.tester.runAsync(
      () => h.database.setNotebookEntriesChapter(notebookId, <String>[
        diaryId,
      ], chapterId),
    );
  }

  Finder chip(String key) =>
      find.byKey(ValueKey<String>('notebook_chapter_chip_$key'));

  /// 胶囊行可横向滚动：先把胶囊滚进屏幕再点。
  Future<void> tapChip(DiaryDraftsHarness h, String key) async {
    await h.tester.ensureVisible(chip(key));
    await h.tester.pumpAndSettle();
    await h.tester.tap(chip(key));
    await h.settleAll();
  }

  Finder card(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiarySelectionSurface),
  );

  Finder chipText(String text) => find.descendant(
    of: find.byType(NotebookChapterChips),
    matching: find.text(text),
  );

  testWidgets('chips show only for notebooks with chapters, with counts', (
    tester,
  ) async {
    late String travel;
    late String plain;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(h);
      plain = await h.notebook('工作');
      final a = await h.diary('甲', notebookIds: <String>[travel]);
      final b = await h.diary('乙', notebookIds: <String>[travel]);
      await h.diary('丙', notebookIds: <String>[travel]);
      await h.diary('丁', notebookIds: <String>[plain]);
      await place(h, travel, a, 'c1');
      await place(h, travel, b, 'c1');
    });
    await enter(h, plain);
    expect(find.byType(NotebookChapterChips), findsNothing);
    expect(find.text('目录'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(DiariesPage)),
    ).read(homeNotebookScopeProvider.notifier).showAll();
    await h.settleAll();
    await enter(h, travel);
    expect(chipText('全部 · 3'), findsOneWidget);
    expect(chipText('东京 · 2'), findsOneWidget);
    expect(chipText('京都 · 0'), findsOneWidget);
    expect(chipText('未分章 · 1'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the chip row scrolls edge to edge of the header card', (
    tester,
  ) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(
        h,
        chapters: <NotebookChapter>[
          for (var i = 1; i <= 6; i++)
            NotebookChapter(id: 'c$i', title: '第$i章的名字'),
        ],
      );
      await h.diary('甲', notebookIds: <String>[travel]);
    });
    await enter(h, travel);
    final cardRect = tester.getRect(
      find
          .descendant(
            of: find.byType(NotebookHeaderCard),
            matching: find.byType(Material),
          )
          .first,
    );
    final scroller = tester.getRect(
      find.descendant(
        of: find.byType(NotebookChapterChips),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(scroller.left, cardRect.left);
    expect(scroller.right, cardRect.right);
    // 第一个胶囊仍与卡片里的文字对齐。
    expect(
      tester.getRect(chip('all')).left,
      cardRect.left + NotebookHeaderCard.contentPadding,
    );
    await h.unmount();
  });

  testWidgets('selecting a chapter filters the list and new entries go into '
      'it', (tester) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(h);
      final a = await h.diary('甲', notebookIds: <String>[travel]);
      await h.diary('乙', notebookIds: <String>[travel]);
      await place(h, travel, a, 'c1');
    });
    await enter(h, travel);
    expect(card('甲'), findsOneWidget);
    expect(card('乙'), findsOneWidget);

    await tapChip(h, 'c1');
    expect(card('甲'), findsOneWidget);
    expect(card('乙'), findsNothing);

    await tapChip(h, 'unassigned');
    expect(card('甲'), findsNothing);
    expect(card('乙'), findsOneWidget);

    // 空的一章：空状态的“写第一篇”把新日记放进这一章。
    await tapChip(h, 'c2');
    await tester.tap(find.text('写第一篇'));
    await h.settleAll();
    final editor = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(editor.createNotebookId, travel);
    expect(editor.createNotebookChapterId, 'c2');
    await h.unmount();
  });

  testWidgets('a deleted selected chapter falls back to all chapters', (
    tester,
  ) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(h);
      final a = await h.diary('甲', notebookIds: <String>[travel]);
      await h.diary('乙', notebookIds: <String>[travel]);
      await place(h, travel, a, 'c1');
    });
    await enter(h, travel);
    await tapChip(h, 'c1');
    expect(card('乙'), findsNothing);

    await tester.runAsync(
      () => h.database.updateNotebook(
        travel,
        payload: NotebookPayload(chapters: <NotebookChapter>[kyoto]),
      ),
    );
    await h.settleAll();
    final state = ProviderScope.containerOf(
      tester.element(find.byType(DiariesPage)),
    ).read(homeNotebookScopeProvider);
    expect(state.chapterId, isNull);
    expect(card('甲'), findsOneWidget);
    expect(card('乙'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the contents button opens the contents page', (tester) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(h);
      await h.diary('甲', notebookIds: <String>[travel]);
    });
    await enter(h, travel);
    await tester.tap(find.text('目录'));
    await h.settleAll();
    expect(find.byType(NotebookContentsPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('book order shows chapter dividers in list layout only when all '
      'chapters are shown', (tester) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(h, sort: NotebookSort.book);
      final a = await h.diary('甲', notebookIds: <String>[travel]);
      final b = await h.diary('乙', notebookIds: <String>[travel]);
      await h.diary('丙', notebookIds: <String>[travel]);
      await place(h, travel, a, 'c2');
      await place(h, travel, b, 'c1');
    });
    await enter(h, travel);
    final dividers = find.byType(NotebookChapterDivider);
    expect(dividers, findsNWidgets(3));
    double top(Finder f) => tester.getTopLeft(f).dy;
    final tokyoDivider = find.byKey(
      const ValueKey<String>('notebook_chapter_divider_c1'),
    );
    final kyotoDivider = find.byKey(
      const ValueKey<String>('notebook_chapter_divider_c2'),
    );
    final unassignedDivider = find.byKey(
      const ValueKey<String>('notebook_chapter_divider_unassigned'),
    );
    // 东京（乙）→ 京都（甲）→ 未分章（丙）。
    expect(top(tokyoDivider), lessThan(top(card('乙'))));
    expect(top(card('乙')), lessThan(top(kyotoDivider)));
    expect(top(kyotoDivider), lessThan(top(card('甲'))));
    expect(top(card('甲')), lessThan(top(unassignedDivider)));
    expect(top(unassignedDivider), lessThan(top(card('丙'))));

    // 选了某一章：不再分隔。
    await tapChip(h, 'c1');
    expect(dividers, findsNothing);
    await h.unmount();
  });

  testWidgets('the waterfall layout has no dividers', (tester) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      await h.settings.setDiaryLayoutModeRaw('waterfall');
      travel = await chaptered(h, sort: NotebookSort.book);
      final a = await h.diary('甲', notebookIds: <String>[travel]);
      await place(h, travel, a, 'c1');
    });
    await enter(h, travel);
    expect(find.text('甲'), findsOneWidget);
    expect(find.byType(NotebookChapterDivider), findsNothing);
    await h.unmount();
  });

  testWidgets('non-book sorts have no dividers', (tester) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await chaptered(h);
      final a = await h.diary('甲', notebookIds: <String>[travel]);
      await place(h, travel, a, 'c1');
    });
    await enter(h, travel);
    expect(find.byType(NotebookChapterDivider), findsNothing);
    await h.unmount();
  });
}
