import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover_tile.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 书架面板：分组、窄屏两列 / 宽屏三列、点选返回结果、“已合上”默认收起、
/// 长按菜单。
void main() {
  late List<NotebookShelfResult?> results;

  Future<DiaryDraftsHarness> open(
    WidgetTester tester, {
    double width = 400,
    String? current,
    Future<void> Function(DiaryDraftsHarness h)? seed,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = Size(width, 900);
    await seed?.call(h);
    results = <NotebookShelfResult?>[];
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => results.add(
              await showNotebookShelfSheet(context, currentNotebookId: current),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    return h;
  }

  Future<Map<String, String>> seedShelf(DiaryDraftsHarness h) async {
    final ids = <String, String>{
      '置顶本': await h.notebook('置顶本', pinned: true),
      '旅行': await h.notebook('旅行'),
      '读书': await h.notebook('读书'),
      '有照片的': await h.notebook('有照片的', kind: NotebookKind.smart),
      '旧事': await h.notebook('旧事', closed: true),
    };
    await h.diary('第一天', notebookIds: <String>[ids['旅行']!]);
    return ids;
  }

  Finder tileOf(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(NotebookCoverTile),
  );

  testWidgets('groups notebooks into sections and keeps closed collapsed', (
    tester,
  ) async {
    final h = await open(tester, seed: seedShelf);
    expect(find.text('全部日记'), findsOneWidget);
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('我的日记本'), findsOneWidget);
    expect(find.text('置顶本'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('1 篇'), findsOneWidget);
    expect(find.text('新建日记本'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('已合上'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('智能日记本'), findsOneWidget);
    expect(find.text('有照片的'), findsOneWidget);
    expect(find.text('旧事'), findsNothing);

    await tester.tap(find.text('已合上'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('旧事'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('旧事'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('uses two columns at 320dp', (tester) async {
    final h = await open(tester, width: 320, seed: seedShelf);
    // 两列：(320 - 2×16 - 12) / 2。
    expect(tester.getSize(tileOf('旅行')).width, closeTo(138, 0.5));
    await h.unmount();
  });

  testWidgets('uses three columns at 411dp', (tester) async {
    final h = await open(tester, width: 411, seed: seedShelf);
    // 三列：(411 - 2×16 - 2×12) / 3。
    expect(tester.getSize(tileOf('旅行')).width, closeTo(118.33, 0.5));
    await h.unmount();
  });

  testWidgets('tapping a notebook returns it', (tester) async {
    late Map<String, String> ids;
    final h = await open(tester, seed: (h) async => ids = await seedShelf(h));
    await tester.tap(tileOf('旅行'));
    await h.settleAll();
    expect(results, <NotebookShelfResult?>[
      NotebookShelfResult.selectNotebook(ids['旅行']!),
    ]);
    await h.unmount();
  });

  testWidgets('tapping all entries returns selectAll', (tester) async {
    final h = await open(tester, current: 'x', seed: seedShelf);
    await tester.tap(find.text('全部日记'));
    await h.settleAll();
    expect(results, <NotebookShelfResult?>[
      const NotebookShelfResult.selectAll(),
    ]);
    await h.unmount();
  });

  testWidgets('long-press opens the quick menu and pins', (tester) async {
    late Map<String, String> ids;
    final h = await open(tester, seed: (h) async => ids = await seedShelf(h));
    await tester.longPress(tileOf('旅行'));
    await tester.pumpAndSettle();
    final menu = find.byType(ExpressiveMenuItem);
    expect(menu, findsNWidgets(4));
    for (final label in <String>['编辑', '置顶', '合上', '删除']) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.tap(find.descendant(of: menu, matching: find.text('置顶')));
    await h.settleAll();
    expect((await h.notebookRow(ids['旅行']!))!.isPinned, isTrue);
    await h.unmount();
  });

  testWidgets('deleting from the shelf can be undone', (tester) async {
    late Map<String, String> ids;
    final h = await open(tester, seed: (h) async => ids = await seedShelf(h));
    await tester.longPress(tileOf('读书'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ExpressiveMenuItem),
        matching: find.text('删除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除「读书」？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await h.settleAll();
    expect(await h.notebookRow(ids['读书']!), isNull);
    expect(find.text('已删除「读书」'), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonUndo));
    await h.settleAll();
    expect(await h.notebookRow(ids['读书']!), isNotNull);
    expect(find.text('读书'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('shows the empty state without notebooks', (tester) async {
    final h = await open(tester);
    expect(find.text('把不同主题、不同时间的日记收进同一本'), findsOneWidget);
    expect(find.text('新建日记本'), findsOneWidget);
    await h.unmount();
  });
}
