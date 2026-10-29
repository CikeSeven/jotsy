import 'dart:async';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_picker_sheet.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_stacked_cover.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 嵌套在书架、管理页、操作面板、编辑页与收录选择器里的样子与写入：父本
/// 叠放、树序与缩进、只在兄弟之间拖动排序、新建子本与移动、选上级保存、
/// 上级私密的提示、选本面板的缩进。
void main() {
  late String travel;
  late String year;
  late String spring;
  late String reading;

  Future<void> seedTree(DiaryDraftsHarness h) async {
    travel = await h.notebook('旅行');
    year = await h.notebook('2025', parentId: travel);
    spring = await h.notebook('2024', parentId: travel);
    reading = await h.notebook('读书');
  }

  /// 首页是一个按钮，点它执行 [open]（打开面板或推入页面）。
  Future<DiaryDraftsHarness> pumpLauncher(
    WidgetTester tester,
    Future<void> Function(DiaryDraftsHarness h) seed,
    void Function(BuildContext context) open, {
    FakeDeviceAuth? auth,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed(h);
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(auth ?? FakeDeviceAuth()),
      ],
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    return h;
  }

  testWidgets('a parent on the shelf is drawn as a stack with its count', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await pumpLauncher(
      tester,
      seedTree,
      (context) => unawaited(showNotebookShelfSheet(context)),
    );
    final stacks = tester
        .widgetList<NotebookStackedCover>(find.byType(NotebookStackedCover))
        .toList();
    // 只列顶层：旅行（2 本子本）与读书（没有子本，不叠放）。
    expect(stacks.map((s) => s.childCount), <int>[2, 0]);
    expect(find.bySemanticsLabel(RegExp('含 2 本子日记本')), findsOneWidget);
    expect(find.text('2025'), findsNothing);
    semantics.dispose();
    await h.unmount();
  });

  group('management page', () {
    Finder row(String id) => find.byKey(ValueKey<String>('notebook_row_$id'));

    Future<DiaryDraftsHarness> openManager(
      WidgetTester tester, {
      FakeDeviceAuth? auth,
      Future<void> Function(DiaryDraftsHarness h)? seed,
    }) async {
      final h = await DiaryDraftsHarness.create(tester);
      await (seed ?? seedTree)(h);
      await h.pump(
        const NotebooksPage(),
        overrides: [
          deviceAuthServiceProvider.overrideWithValue(auth ?? FakeDeviceAuth()),
        ],
      );
      await h.settleAll();
      return h;
    }

    Future<void> openMore(
      DiaryDraftsHarness h,
      String id,
      String action,
    ) async {
      await h.tester.tap(
        find.descendant(of: row(id), matching: find.byTooltip('更多操作')),
      );
      await h.tester.pumpAndSettle();
      await h.tester.tap(find.widgetWithText(ListTile, action));
      await h.settleAll();
    }

    testWidgets('lists children under their parent, indented per level', (
      tester,
    ) async {
      final h = await openManager(tester);
      double top(String id) => tester.getTopLeft(row(id)).dy;
      double left(String id) => tester
          .getTopLeft(
            find.descendant(of: row(id), matching: find.byType(Material)).first,
          )
          .dx;
      expect(top(travel), lessThan(top(year)));
      expect(top(year), lessThan(top(spring)));
      expect(top(spring), lessThan(top(reading)));
      expect(left(year) - left(travel), 20);
      expect(left(reading), left(travel));
      await h.unmount();
    });

    testWidgets('dragging reorders siblings only and keeps the parent', (
      tester,
    ) async {
      final h = await openManager(tester);
      // 把“2024”拖到“2025”上面。
      final handle = find.descendant(
        of: row(spring),
        matching: find.byType(ReorderableDragStartListener),
      );
      final distance =
          tester.getTopLeft(row(spring)).dy - tester.getTopLeft(row(year)).dy;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, -(distance + 10) / 20));
        await tester.pump();
      }
      await gesture.up();
      await h.settleAll();

      final names = (await h.shelf()).map((r) => r.name).toList();
      expect(names, <String>['旅行', '2024', '2025', '读书']);
      expect((await h.notebookRow(spring))!.parentId, travel);
      expect(
        tester.getTopLeft(row(spring)).dy,
        lessThan(tester.getTopLeft(row(year)).dy),
      );
      await h.unmount();
    });

    testWidgets('dragging a top-level book into a subtree only reorders it', (
      tester,
    ) async {
      final h = await openManager(tester);
      // 把“读书”拖到“2025”与“2024”之间：仍在顶层，排到“旅行”之后（不变）。
      final handle = find.descendant(
        of: row(reading),
        matching: find.byType(ReorderableDragStartListener),
      );
      final distance =
          tester.getTopLeft(row(reading)).dy -
          tester.getTopLeft(row(spring)).dy;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, -(distance + 10) / 20));
        await tester.pump();
      }
      await gesture.up();
      await h.settleAll();
      expect((await h.notebookRow(reading))!.parentId, isNull);
      expect((await h.shelf()).map((r) => r.name).toList(), <String>[
        '旅行',
        '2025',
        '2024',
        '读书',
      ]);
      await h.unmount();
    });

    testWidgets('new sub-notebook opens the editor under this notebook', (
      tester,
    ) async {
      final h = await openManager(tester);
      await openMore(h, travel, '新建子日记本');
      final editor = tester.widget<NotebookEditorPage>(
        find.byType(NotebookEditorPage),
      );
      expect(editor.initialParentId, travel);
      await h.unmount();
    });

    testWidgets('the deepest level offers no new sub-notebook', (tester) async {
      late String deepest;
      final h = await openManager(
        tester,
        seed: (h) async {
          await seedTree(h);
          deepest = await h.notebook('东京', parentId: year);
        },
      );
      await tester.tap(
        find.descendant(of: row(deepest), matching: find.byTooltip('更多操作')),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, '新建子日记本'), findsNothing);
      expect(find.widgetWithText(ListTile, '移动到…'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await h.settleAll();
      await h.unmount();
    });

    testWidgets('move to puts a child back on the shelf', (tester) async {
      final h = await openManager(tester);
      await openMore(h, year, '移动到…');
      // 面板标记当前的上级；不能当上级的（它自己）不列出。
      expect(
        find.byKey(const ValueKey<String>('notebook_parent_none')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_parent_$travel')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_parent_$year')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notebook_parent_none')),
      );
      await h.settleAll();
      expect((await h.notebookRow(year))!.parentId, isNull);
      expect(find.text('已放回书架'), findsOneWidget);
      await h.unmount();
    });

    testWidgets('move to under another notebook', (tester) async {
      final h = await openManager(tester);
      await openMore(h, reading, '移动到…');
      await tester.tap(find.byKey(ValueKey<String>('notebook_parent_$year')));
      await h.settleAll();
      expect((await h.notebookRow(reading))!.parentId, year);
      expect(find.text('已移到「2025」下'), findsOneWidget);
      await h.unmount();
    });

    double height(WidgetTester tester, String id) =>
        tester.getSize(row(id)).height;

    /// 按住 [start] 拖动 [dy]（分 20 步），松手后等数据库与动画。
    Future<void> drag(
      DiaryDraftsHarness h,
      Offset start,
      double dy, {
      Duration hold = Duration.zero,
    }) async {
      final gesture = await h.tester.startGesture(start);
      await h.tester.pump(hold);
      await h.tester.pump();
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, dy / 20));
        await h.tester.pump();
      }
      await gesture.up();
      await h.settleAll();
    }

    Offset handleOf(WidgetTester tester, String id) => tester.getCenter(
      find.descendant(
        of: row(id),
        matching: find.byType(ReorderableDragStartListener),
      ),
    );

    testWidgets('a parent row collapses and expands its children', (
      tester,
    ) async {
      final h = await openManager(tester);
      expect(
        find.descendant(
          of: row(travel),
          matching: find.textContaining('2 本子本'),
        ),
        findsOneWidget,
      );
      // 没有子本的行没有展开 / 收起按钮。
      expect(
        find.byKey(ValueKey<String>('notebook_toggle_$reading')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('收起子本'));
      await h.settleAll();
      expect(height(tester, year), 0);
      expect(height(tester, spring), 0);
      expect(
        tester.getTopLeft(row(reading)).dy,
        tester.getBottomLeft(row(travel)).dy,
      );

      await tester.tap(find.byTooltip('展开子本'));
      await h.settleAll();
      expect(height(tester, year), greaterThan(0));
      expect(height(tester, spring), height(tester, year));
      await h.unmount();
    });

    testWidgets('collapse all keeps the top level and expand all undoes it', (
      tester,
    ) async {
      late String tokyo;
      final h = await openManager(
        tester,
        seed: (h) async {
          await seedTree(h);
          tokyo = await h.notebook('东京', parentId: year);
        },
      );
      await tester.tap(find.byTooltip('全部收起'));
      await h.settleAll();
      for (final id in <String>[year, spring, tokyo]) {
        expect(height(tester, id), 0);
      }
      expect(height(tester, reading), greaterThan(0));

      // 只展开旅行：2025 自己也收起过，东京仍藏着。
      await tester.tap(find.byKey(ValueKey<String>('notebook_toggle_$travel')));
      await h.settleAll();
      expect(height(tester, year), greaterThan(0));
      expect(height(tester, tokyo), 0);

      // 还有展开着的时候，顶栏仍是“全部收起”。
      expect(find.byTooltip('全部展开'), findsNothing);
      await tester.tap(find.byTooltip('全部收起'));
      await h.settleAll();
      expect(height(tester, year), 0);

      await tester.tap(find.byTooltip('全部展开'));
      await h.settleAll();
      expect(height(tester, year), greaterThan(0));
      expect(height(tester, tokyo), greaterThan(0));
      expect(find.byTooltip('全部收起'), findsOneWidget);
      await h.unmount();
    });

    testWidgets('a collapsed parent is passed over in one step', (
      tester,
    ) async {
      final h = await openManager(tester);
      await tester.tap(find.byTooltip('收起子本'));
      await h.settleAll();
      // 收起后“读书”紧挨着“旅行”，拖过一行就到它上面。
      await drag(
        h,
        handleOf(tester, reading),
        -(tester.getTopLeft(row(reading)).dy -
            tester.getTopLeft(row(travel)).dy +
            10),
      );
      // 兄弟只在原本占着的全局位置之间对调，子本跟着上级（树序）。
      expect((await h.shelf()).map((r) => r.name).toList(), <String>[
        '读书',
        '2025',
        '2024',
        '旅行',
      ]);
      expect((await h.notebookRow(year))!.parentId, travel);
      expect(height(tester, year), 0);
      await h.unmount();
    });

    testWidgets('dragging a parent folds its children and lands with them', (
      tester,
    ) async {
      final h = await openManager(tester);
      final distance =
          tester.getTopLeft(row(reading)).dy -
          tester.getTopLeft(row(travel)).dy;
      final gesture = await tester.startGesture(handleOf(tester, travel));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, distance / 20));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      // 拖动中子本收进来，跟着上级走。
      expect(height(tester, year), 0);
      expect(height(tester, spring), 0);
      await gesture.up();
      await h.settleAll();

      // 兄弟只在原本占着的全局位置之间对调，子本跟着上级（树序）。
      expect((await h.shelf()).map((r) => r.name).toList(), <String>[
        '读书',
        '2025',
        '2024',
        '旅行',
      ]);
      // 放下后在新位置展开。
      expect(height(tester, year), greaterThan(0));
      expect(
        tester.getTopLeft(row(reading)).dy,
        lessThan(tester.getTopLeft(row(travel)).dy),
      );
      expect(
        tester.getTopLeft(row(travel)).dy,
        lessThan(tester.getTopLeft(row(year)).dy),
      );
      // 收起状态没有被拖动改写。
      expect(find.byTooltip('收起子本'), findsOneWidget);
      await h.unmount();
    });

    testWidgets('long-pressing a row starts a drag, a tap still edits', (
      tester,
    ) async {
      final h = await openManager(tester);
      final name = find.descendant(of: row(reading), matching: find.text('读书'));
      await drag(
        h,
        tester.getCenter(name),
        -(tester.getTopLeft(row(reading)).dy -
            tester.getTopLeft(row(travel)).dy +
            10),
        hold: kLongPressTimeout + const Duration(milliseconds: 100),
      );
      expect((await h.shelf()).first.name, '读书');
      expect(find.byType(NotebookEditorPage), findsNothing);

      await tester.tap(name);
      await h.settleAll();
      expect(find.byType(NotebookEditorPage), findsOneWidget);
      await h.unmount();
    });

    testWidgets('a book moved under a collapsed parent opens it up', (
      tester,
    ) async {
      final h = await openManager(tester);
      await tester.tap(find.byTooltip('收起子本'));
      await h.settleAll();
      await tester.runAsync(() => h.database.moveNotebook(reading, travel));
      await h.settleAll();
      expect(find.byTooltip('收起子本'), findsOneWidget);
      expect(height(tester, reading), greaterThan(0));
      expect(height(tester, year), greaterThan(0));
      double left(String id) => tester
          .getTopLeft(
            find.descendant(of: row(id), matching: find.byType(Material)).first,
          )
          .dx;
      expect(left(reading) - left(travel), 20);
      await h.unmount();
    });

    testWidgets('moving a child out of a locked parent asks first', (
      tester,
    ) async {
      late String vault;
      late String daily;
      final auth = FakeDeviceAuth(results: <bool>[false]);
      final h = await openManager(
        tester,
        auth: auth,
        seed: (h) async {
          vault = await h.notebook(
            '保险箱',
            visibility: NotebookVisibility.locked,
          );
          daily = await h.notebook('日常', parentId: vault);
        },
      );
      await openMore(h, daily, '移动到…');
      expect(auth.reasons, <String>['解锁「日常」']);
      expect(
        find.byKey(const ValueKey<String>('notebook_parent_none')),
        findsNothing,
      );
      expect((await h.notebookRow(daily))!.parentId, vault);
      await h.unmount();
    });
  });

  group('editor', () {
    Finder scrollable() => find.byType(Scrollable).first;
    final parentTile = find.byKey(
      const ValueKey<String>('notebook_editor_parent_tile'),
    );

    Future<void> chooseParent(DiaryDraftsHarness h, String parentId) async {
      await h.tester.scrollUntilVisible(
        parentTile,
        200,
        scrollable: scrollable(),
      );
      await h.tester.pumpAndSettle();
      await h.tester.tap(parentTile);
      await h.settleAll();
      await h.tester.tap(
        find.byKey(ValueKey<String>('notebook_parent_$parentId')),
      );
      await h.settleAll();
    }

    testWidgets('a new notebook can be saved under a chosen parent', (
      tester,
    ) async {
      final h = await pumpLauncher(
        tester,
        seedTree,
        (context) =>
            unawaited(Navigator.of(context).push(NotebookEditorPage.route())),
      );
      await tester.enterText(find.byType(TextField).first, '东京');
      await h.settleAll();
      await tester.scrollUntilVisible(
        parentTile,
        200,
        scrollable: scrollable(),
      );
      expect(
        find.descendant(of: parentTile, matching: find.text('无（放在书架上）')),
        findsOneWidget,
      );
      await chooseParent(h, year);
      expect(find.text('旅行 › 2025'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await h.settleAll();
      final created = (await h.shelf()).singleWhere((r) => r.name == '东京');
      expect(created.parentId, year);
      await h.unmount();
    });

    testWidgets('a private parent explains the inherited privacy', (
      tester,
    ) async {
      late String vault;
      final h = await pumpLauncher(
        tester,
        (h) async {
          vault = await h.notebook(
            '保险箱',
            visibility: NotebookVisibility.locked,
          );
          await h.notebook('旅行');
        },
        (context) =>
            unawaited(Navigator.of(context).push(NotebookEditorPage.route())),
      );
      const note = '上级「保险箱」已上锁，这本也随之上锁';
      expect(find.text(note), findsNothing);
      await chooseParent(h, vault);
      await tester.scrollUntilVisible(
        find.text(note),
        200,
        scrollable: scrollable(),
      );
      expect(find.text(note), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.unmount();
    });

    testWidgets('editing offers no parent that would break the depth limit', (
      tester,
    ) async {
      final h = await pumpLauncher(
        tester,
        seedTree,
        (context) => unawaited(
          Navigator.of(
            context,
          ).push(NotebookEditorPage.route(notebookId: travel)),
        ),
      );
      await tester.scrollUntilVisible(
        parentTile,
        200,
        scrollable: scrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(parentTile);
      await h.settleAll();
      // 旅行有子本（两层高）：只能放进顶层的本子，不能放进自己的子本。
      expect(
        find.byKey(ValueKey<String>('notebook_parent_$reading')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_parent_$year')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_parent_$travel')),
        findsNothing,
      );
      await tester.tapAt(const Offset(5, 5));
      await h.settleAll();
      await h.unmount();
    });
  });

  testWidgets('the add-to picker indents children under their parent', (
    tester,
  ) async {
    final h = await pumpLauncher(
      tester,
      seedTree,
      (context) => unawaited(showNotebookPickerSheet(context)),
    );
    Finder pick(String id) => find.byKey(ValueKey<String>('notebook_pick_$id'));
    double left(String id) => tester
        .getTopLeft(
          find.descendant(of: pick(id), matching: find.byType(Material)).first,
        )
        .dx;
    double top(String id) => tester.getTopLeft(pick(id)).dy;
    expect(top(travel), lessThan(top(year)));
    expect(top(spring), lessThan(top(reading)));
    expect(left(year) - left(travel), 20);
    expect(left(reading), left(travel));
    await h.unmount();
  });
}
