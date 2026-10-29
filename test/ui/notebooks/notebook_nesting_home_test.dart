import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_breadcrumb.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_children_grid.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_actions.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher_chip.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页里的嵌套：父本汇总子本、头部的子本网格与面包屑、子本里返回先回到
/// 上级、同一上锁范围里切换不重复验证、删除所在的子本后回到上级。
void main() {
  Future<DiaryDraftsHarness> pumpHome(
    WidgetTester tester, {
    required Future<void> Function(DiaryDraftsHarness h) seed,
    FakeDeviceAuth? auth,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed(h);
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

  String? scopeId(WidgetTester tester) =>
      containerOf(tester).read(homeNotebookScopeProvider).notebookId;

  Future<void> openShelfAndPick(DiaryDraftsHarness h, String name) async {
    await h.tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    // 封面的墨水层盖在文字上面，点按落在它身上（与书架的真实点按一致）。
    await h.tester.tap(
      find.descendant(
        of: find.byType(NotebookShelf),
        matching: find.text(name),
      ),
      warnIfMissed: false,
    );
    await h.settleAll();
  }

  Finder inGrid(Finder finder) =>
      find.descendant(of: find.byType(NotebookChildrenGrid), matching: finder);

  Finder headerTitle(String name) => find.descendant(
    of: find.byType(NotebookHeaderCard),
    matching: find.text(name),
  );

  late String travel;
  late String year;
  late String tokyo;

  Future<void> seedTravel(DiaryDraftsHarness h) async {
    travel = await h.notebook('旅行');
    year = await h.notebook('2025', parentId: travel);
    tokyo = await h.notebook('东京', parentId: year);
    await h.diary('出发', notebookIds: <String>[travel]);
    await h.diary('浅草寺', notebookIds: <String>[tokyo]);
    await h.diary('上班路上');
  }

  testWidgets('the shelf lists top-level notebooks only', (tester) async {
    final h = await pumpHome(tester, seed: seedTravel);
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    final shelf = find.byType(NotebookShelf);
    expect(find.descendant(of: shelf, matching: find.text('旅行')), findsOne);
    expect(
      find.descendant(of: shelf, matching: find.text('2025')),
      findsNothing,
    );
    expect(find.descendant(of: shelf, matching: find.text('东京')), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await h.settleAll();
    await h.unmount();
  });

  testWidgets('a parent aggregates its children and lists them in the header', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTravel);
    await openShelfAndPick(h, '旅行');

    // 列表汇总子孙里的日记；头部的子本网格只列直接子本。
    expect(find.text('出发'), findsOneWidget);
    expect(find.text('浅草寺'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    expect(inGrid(find.text('2025')), findsOneWidget);
    expect(inGrid(find.text('东京')), findsNothing);
    expect(inGrid(find.text('新建子本')), findsOneWidget);
    expect(find.byType(NotebookBreadcrumb), findsNothing);

    // 点子本进入：面包屑显示上级，列表只剩它的范围。
    await tester.tap(inGrid(find.text('2025')));
    await h.settleAll();
    expect(scopeId(tester), year);
    expect(headerTitle('2025'), findsOneWidget);
    expect(find.text('出发'), findsNothing);
    expect(find.text('浅草寺'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NotebookBreadcrumb),
        matching: find.text('旅行'),
      ),
      findsOneWidget,
    );

    // 再进一层，面包屑为“旅行 › 2025”；最深一层不再有“新建子本”。
    await tester.tap(inGrid(find.text('东京')));
    await h.settleAll();
    expect(scopeId(tester), tokyo);
    expect(find.byType(NotebookChildrenGrid), findsNothing);
    final crumbs = find.byType(NotebookBreadcrumb);
    expect(find.descendant(of: crumbs, matching: find.text('旅行')), findsOne);
    expect(find.descendant(of: crumbs, matching: find.text('2025')), findsOne);

    // 点面包屑里的“旅行”直接回到顶层的父本。
    await tester.tap(find.descendant(of: crumbs, matching: find.text('旅行')));
    await h.settleAll();
    expect(scopeId(tester), travel);
    expect(find.text('出发'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('system back climbs to the parent before leaving to all', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTravel);
    await openShelfAndPick(h, '旅行');
    await tester.tap(inGrid(find.text('2025')));
    await h.settleAll();
    await tester.tap(inGrid(find.text('东京')));
    await h.settleAll();
    expect(scopeId(tester), tokyo);

    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(scopeId(tester), year);
    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(scopeId(tester), travel);
    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(containerOf(tester).read(homeNotebookScopeProvider).isAll, isTrue);
    expect(find.text('上班路上'), findsOneWidget);
    await h.unmount();
  });

  testWidgets(
    'the grid create button opens the editor with the parent filled in',
    (tester) async {
      final h = await pumpHome(tester, seed: seedTravel);
      await openShelfAndPick(h, '旅行');
      await tester.tap(inGrid(find.text('新建子本')));
      await h.settleAll();
      final editor = tester.widget<NotebookEditorPage>(
        find.byType(NotebookEditorPage),
      );
      expect(editor.initialParentId, travel);
      await h.unmount();
    },
  );

  Finder inActions(Finder finder) =>
      find.descendant(of: find.byType(NotebookHeaderActions), matching: finder);

  testWidgets('a notebook without children offers the first one in its '
      'action row', (tester) async {
    late String reading;
    final h = await pumpHome(
      tester,
      seed: (h) async {
        await seedTravel(h);
        reading = await h.notebook('读书');
      },
    );
    await openShelfAndPick(h, '读书');
    expect(find.byType(NotebookChildrenGrid), findsNothing);
    await tester.tap(inActions(find.text('新建子本')));
    await h.settleAll();
    expect(
      tester
          .widget<NotebookEditorPage>(find.byType(NotebookEditorPage))
          .initialParentId,
      reading,
    );
    await h.unmount();
  });

  testWidgets('once children exist only the grid offers a new one', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTravel);
    // 有子本的父本：入口只在子本网格的标题行；最深一层两处都没有。
    await openShelfAndPick(h, '旅行');
    expect(inActions(find.text('新建子本')), findsNothing);
    expect(inGrid(find.text('新建子本')), findsOneWidget);
    await tester.tap(inGrid(find.text('2025')));
    await h.settleAll();
    await tester.tap(inGrid(find.text('东京')));
    await h.settleAll();
    expect(find.text('新建子本'), findsNothing);
    await h.unmount();
  });

  testWidgets('many children fold into two rows and expand in place', (
    tester,
  ) async {
    const names = <String>['一月', '二月', '三月', '四月', '五月', '六月'];
    late List<String> months;
    final h = await pumpHome(
      tester,
      seed: (h) async {
        travel = await h.notebook('旅行');
        months = <String>[
          for (final name in names) await h.notebook(name, parentId: travel),
        ];
      },
    );
    await openShelfAndPick(h, '旅行');

    // 手机宽度两列：收起时列出前三本，第四格为“还有 3 本”。
    expect(inGrid(find.text('6')), findsOneWidget);
    for (final name in names.take(3)) {
      expect(inGrid(find.text(name)), findsOneWidget);
    }
    for (final name in names.skip(3)) {
      expect(inGrid(find.text(name)), findsNothing);
    }
    expect(inGrid(find.text('还有 3 本')), findsOneWidget);
    expect(inGrid(find.text('收起')), findsNothing);
    final firstTop = tester.getTopLeft(inGrid(find.text('一月'))).dy;
    expect(tester.getTopLeft(inGrid(find.text('二月'))).dy, firstTop);
    expect(
      tester.getTopLeft(inGrid(find.text('三月'))).dy,
      greaterThan(firstTop),
    );

    await tester.tap(inGrid(find.text('还有 3 本')));
    await h.settleAll();
    for (final name in names) {
      expect(inGrid(find.text(name)), findsOneWidget);
    }
    expect(inGrid(find.text('还有 3 本')), findsNothing);
    expect(inGrid(find.text('收起')), findsOneWidget);

    // 进了子本再回来仍是展开的。
    await tester.tap(inGrid(find.text('六月')));
    await h.settleAll();
    expect(scopeId(tester), months.last);
    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(scopeId(tester), travel);
    expect(inGrid(find.text('六月')), findsOneWidget);

    await tester.tap(inGrid(find.text('收起')));
    await h.settleAll();
    expect(inGrid(find.text('六月')), findsNothing);
    expect(inGrid(find.text('还有 3 本')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('children that fit in two rows show without a fold cell', (
    tester,
  ) async {
    const names = <String>['春', '夏', '秋', '冬'];
    final h = await pumpHome(
      tester,
      seed: (h) async {
        travel = await h.notebook('旅行');
        for (final name in names) {
          await h.notebook(name, parentId: travel);
        }
      },
    );
    await openShelfAndPick(h, '旅行');
    for (final name in names) {
      expect(inGrid(find.text(name)), findsOneWidget);
    }
    expect(inGrid(find.textContaining('还有')), findsNothing);
    expect(inGrid(find.text('收起')), findsNothing);
    await h.unmount();
  });

  testWidgets('deleting the child you are in goes back to its parent', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTravel);
    await openShelfAndPick(h, '旅行');
    await tester.tap(inGrid(find.text('2025')));
    await h.settleAll();
    expect(scopeId(tester), year);

    await tester.tap(
      find.descendant(
        of: find.byType(NotebookHeaderCard),
        matching: find.byTooltip('更多操作'),
      ),
    );
    await h.settleAll();
    await tester.tap(find.text('删除').last);
    await h.settleAll();
    // 有子本时确认框说明子本会移到上一层。
    expect(find.text('1 本子日记本会移到上一层，不会删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await h.settleAll();

    expect(scopeId(tester), travel);
    expect(find.text('日记本已删除'), findsNothing);
    // “东京”提到了“旅行”下面。
    expect(inGrid(find.text('东京')), findsOneWidget);
    expect((await h.notebookRow(tokyo))!.parentId, travel);
    await h.unmount();
  });

  testWidgets('a child deleted elsewhere falls back to its parent', (
    tester,
  ) async {
    final h = await pumpHome(tester, seed: seedTravel);
    await openShelfAndPick(h, '旅行');
    await tester.tap(inGrid(find.text('2025')));
    await h.settleAll();

    await tester.runAsync(() => h.database.deleteNotebook(year));
    await h.settleAll();
    expect(scopeId(tester), travel);
    expect(find.text('日记本已删除'), findsOneWidget);
    await h.unmount();
  });

  group('lock scopes', () {
    late String vault;
    late String daily;
    late String diaryBook;

    Future<void> seedLocks(DiaryDraftsHarness h) async {
      vault = await h.notebook('保险箱', visibility: NotebookVisibility.locked);
      daily = await h.notebook('日常', parentId: vault);
      travel = await h.notebook('旅行');
      diaryBook = await h.notebook(
        '心事',
        parentId: travel,
        visibility: NotebookVisibility.locked,
      );
      await h.diary('秘密', notebookIds: <String>[daily]);
      await h.diary('心里话', notebookIds: <String>[diaryBook]);
      await h.diary('出发', notebookIds: <String>[travel]);
    }

    testWidgets('moving within one locked tree asks only once', (tester) async {
      final auth = FakeDeviceAuth(results: <bool>[true]);
      final h = await pumpHome(tester, seed: seedLocks, auth: auth);
      await openShelfAndPick(h, '保险箱');
      expect(auth.reasons, hasLength(1));
      expect(scopeId(tester), vault);

      await tester.tap(inGrid(find.text('日常')));
      await h.settleAll();
      expect(scopeId(tester), daily);
      await tester.binding.handlePopRoute();
      await h.settleAll();
      expect(scopeId(tester), vault);
      expect(auth.reasons, hasLength(1));
      await h.unmount();
    });

    testWidgets('a locked child of a plain parent still asks', (tester) async {
      final auth = FakeDeviceAuth(results: <bool>[false, true]);
      final h = await pumpHome(tester, seed: seedLocks, auth: auth);
      await openShelfAndPick(h, '旅行');
      expect(auth.reasons, isEmpty);
      // 比父本更私密的子本不汇总进父本的列表。
      expect(find.text('出发'), findsOneWidget);
      expect(find.text('心里话'), findsNothing);

      await tester.tap(inGrid(find.text('心事')));
      await h.settleAll();
      expect(auth.reasons, <String>['解锁「心事」']);
      expect(scopeId(tester), travel);

      await tester.tap(inGrid(find.text('心事')));
      await h.settleAll();
      expect(scopeId(tester), diaryBook);
      expect(find.text('心里话'), findsOneWidget);
      // 回到普通的父本不用验证。
      await tester.binding.handlePopRoute();
      await h.settleAll();
      expect(scopeId(tester), travel);
      expect(auth.reasons, hasLength(2));
      await h.unmount();
    });
  });
}
