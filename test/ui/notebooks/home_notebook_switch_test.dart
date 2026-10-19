import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher_chip.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页原地切换到日记本：标签栏的切换胶囊、头部卡片、搜索提示、返回、
/// 本子排序、日记本被删除后的回退，以及上锁日记本的验证。
void main() {
  Future<DiaryDraftsHarness> pumpHome(
    WidgetTester tester, {
    Future<void> Function(DiaryDraftsHarness h)? seed,
    FakeDeviceAuth? auth,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed?.call(h);
    await h.pump(
      const DiariesPage(),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(auth ?? FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    return h;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiariesPage)));

  Future<void> openShelfAndPick(DiaryDraftsHarness h, String name) async {
    await h.tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await h.tester.tap(
      find.descendant(
        of: find.byType(NotebookShelf),
        matching: find.text(name),
      ),
    );
    await h.settleAll();
  }

  Finder inHeader(Finder finder) =>
      find.descendant(of: find.byType(NotebookHeaderCard), matching: finder);

  double tagBarHeight(WidgetTester tester) =>
      tester.getSize(find.byType(DiaryTagFilterBar)).height;

  testWidgets('tag bar stays hidden without tags or notebooks', (tester) async {
    final h = await pumpHome(tester, seed: (h) => h.diary('随手记'));
    expect(tagBarHeight(tester), 0);
    await h.unmount();
  });

  testWidgets('a notebook keeps the tag bar and its switcher visible', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: (h) => h.notebook('旅行'));
    expect(tagBarHeight(tester), greaterThan(0));
    expect(
      find.descendant(
        of: find.byType(NotebookSwitcherChip),
        matching: find.text('全部日记'),
      ),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('switching in place scopes the list, header and search hint', (
    tester,
  ) async {
    final h = await pumpHome(
      tester,
      seed: (h) async {
        final travel = await h.notebook(
          '旅行',
          payload: NotebookPayload(description: '走过的地方'),
        );
        await h.diary('在京都', notebookIds: <String>[travel]);
        await h.diary('上班路上');
      },
    );
    expect(find.text('在京都'), findsOneWidget);
    expect(find.text('上班路上'), findsOneWidget);
    expect(find.byType(NotebookHeaderCard), findsNothing);

    await openShelfAndPick(h, '旅行');

    expect(find.text('在京都'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    expect(inHeader(find.text('旅行')), findsOneWidget);
    expect(inHeader(find.text('走过的地方')), findsOneWidget);
    expect(inHeader(find.textContaining('1 篇 · ')), findsOneWidget);
    expect(find.text('在「旅行」中搜索'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NotebookSwitcherChip),
        matching: find.text('旅行'),
      ),
      findsOneWidget,
    );

    // 系统返回先回到全部日记，而不是离开页面。
    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(containerOf(tester).read(homeNotebookScopeProvider).isAll, isTrue);
    expect(find.byType(NotebookHeaderCard), findsNothing);
    expect(find.text('上班路上'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('an empty notebook shows its own empty state', (tester) async {
    final h = await pumpHome(
      tester,
      seed: (h) async {
        await h.notebook('读书');
        await h.diary('上班路上');
      },
    );
    await openShelfAndPick(h, '读书');
    expect(find.text('这本还空着'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    await h.unmount();
  });

  testWidgets('the view options sort writes the notebook sort', (tester) async {
    late String travel;
    final h = await pumpHome(
      tester,
      seed: (h) async {
        travel = await h.notebook('旅行');
        await h.diary('在京都', notebookIds: <String>[travel]);
      },
    );
    await openShelfAndPick(h, '旅行');
    await tester.tap(find.byTooltip(h.l10n.autoT0125));
    await h.settleAll();
    expect(find.text('本日记本的排序'), findsOneWidget);
    expect(find.text(h.l10n.notebookSortBook), findsOneWidget);
    await tester.tap(find.text(h.l10n.notebookSortCreatedAsc));
    await h.settleAll();

    final row = await h.notebookRow(travel);
    expect(row!.parsedPayload.sort, NotebookSort.createdAsc);
    final resolution = containerOf(
      tester,
    ).read(homeNotebookScopeResolutionProvider);
    expect(resolution.sort, NotebookSort.createdAsc);
    // 写回推送后临时排序已清除。
    expect(resolution.state.sortOverride, isNull);
    await h.unmount();
  });

  testWidgets('a deleted notebook falls back to all diaries with a hint', (
    tester,
  ) async {
    late String travel;
    final h = await pumpHome(
      tester,
      seed: (h) async {
        travel = await h.notebook('旅行');
        await h.diary('上班路上');
      },
    );
    await openShelfAndPick(h, '旅行');
    expect(find.byType(NotebookHeaderCard), findsOneWidget);

    await tester.runAsync(() => h.database.deleteNotebook(travel));
    await h.settleAll();
    expect(containerOf(tester).read(homeNotebookScopeProvider).isAll, isTrue);
    expect(find.byType(NotebookHeaderCard), findsNothing);
    expect(find.text('日记本已删除'), findsOneWidget);
    expect(find.text('上班路上'), findsOneWidget);
    await h.unmount();
  });

  group('locked notebooks', () {
    Future<void> seedVault(DiaryDraftsHarness h) async {
      final vault = await h.notebook(
        '保险箱',
        visibility: NotebookVisibility.locked,
      );
      await h.diary('秘密', notebookIds: <String>[vault]);
      await h.diary('上班路上');
    }

    testWidgets('entering asks the device and a denial stays in all', (
      tester,
    ) async {
      final auth = FakeDeviceAuth(results: <bool>[false, true]);
      final h = await pumpHome(tester, seed: seedVault, auth: auth);
      // 私密日记不在全部日记里。
      expect(find.text('秘密'), findsNothing);

      await openShelfAndPick(h, '保险箱');
      expect(auth.reasons, <String>['解锁「保险箱」']);
      expect(containerOf(tester).read(homeNotebookScopeProvider).isAll, isTrue);
      expect(find.byType(NotebookHeaderCard), findsNothing);

      await openShelfAndPick(h, '保险箱');
      expect(auth.reasons, hasLength(2));
      expect(find.byType(NotebookHeaderCard), findsOneWidget);
      expect(find.text('秘密'), findsOneWidget);
      expect(inHeader(find.text('仅在本日记本中显示')), findsOneWidget);
      await h.unmount();
    });

    testWidgets('a device without a screen lock refuses to open', (
      tester,
    ) async {
      final auth = FakeDeviceAuth(supported: false);
      final h = await pumpHome(tester, seed: seedVault, auth: auth);
      await openShelfAndPick(h, '保险箱');
      expect(find.text('无法打开上锁的日记本'), findsOneWidget);
      expect(auth.reasons, isEmpty);
      // 只有“知道了”：不再提供绕过验证的“去设置”。
      expect(find.text(h.l10n.commonCancel), findsNothing);
      expect(find.text('去设置'), findsNothing);
      await tester.tap(find.text('知道了'));
      await h.settleAll();
      expect(containerOf(tester).read(homeNotebookScopeProvider).isAll, isTrue);
      expect(find.text('秘密'), findsNothing);
      await h.unmount();
    });
  });
}
