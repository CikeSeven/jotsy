import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_switcher_chip.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 书架“全部日记”下面的“未收录”：列出没有收进任何日记本的日记，切换胶囊
/// 随之显示“未收录”，返回回到全部日记；两行行尾都有篇数。
void main() {
  Future<DiaryDraftsHarness> pumpHome(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final child = await h.notebook('东京', parentId: travel);
    final secret = await h.notebook(
      '心事',
      visibility: NotebookVisibility.hidden,
    );
    await h.diary('出发', notebookIds: <String>[travel]);
    await h.diary('浅草寺', notebookIds: <String>[child]);
    await h.diary('悄悄话', notebookIds: <String>[secret]);
    await h.diary('上班路上');
    await h.diary('买菜');
    await h.pump(const DiariesPage());
    await h.settleAll();
    return h;
  }

  HomeNotebookScope scopeOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DiariesPage)),
  ).read(homeNotebookScopeProvider);

  Finder inShelf(Finder finder) =>
      find.descendant(of: find.byType(NotebookShelf), matching: finder);

  testWidgets('the shelf offers unfiled entries right below all entries', (
    tester,
  ) async {
    final h = await pumpHome(tester);
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();

    final all = tester.getTopLeft(inShelf(find.text('全部日记')));
    final unfiled = tester.getTopLeft(inShelf(find.text('未收录')));
    expect(unfiled.dy, greaterThan(all.dy));
    expect(
      unfiled.dy,
      lessThan(tester.getTopLeft(inShelf(find.text('我的日记本'))).dy),
    );
    Finder rowCount(String row, String count) => find.descendant(
      of: find.ancestor(
        of: inShelf(find.text(row)),
        matching: find.byType(ListTile),
      ),
      matching: find.text(count),
    );
    // 全部日记与首页列表同一口径：私密本子里的那篇不计入、也不透露。
    expect(rowCount('全部日记', '4 篇'), findsOneWidget);
    // 只算不在任何日记本里的两篇。
    expect(rowCount('未收录', '2 篇'), findsOneWidget);

    await tester.tap(inShelf(find.text('未收录')));
    await h.settleAll();
    expect(scopeOf(tester).unfiled, isTrue);
    expect(find.text('上班路上'), findsOneWidget);
    expect(find.text('买菜'), findsOneWidget);
    expect(find.text('出发'), findsNothing);
    expect(find.text('浅草寺'), findsNothing);
    expect(find.text('悄悄话'), findsNothing);
    expect(find.byType(NotebookHeaderCard), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NotebookSwitcherChip),
        matching: find.text('未收录'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await h.unmount();
  });

  testWidgets('back leaves unfiled for all entries, and the shelf marks it', (
    tester,
  ) async {
    final h = await pumpHome(tester);
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    await tester.tap(inShelf(find.text('未收录')));
    await h.settleAll();

    // 再打开书架时高亮的是“未收录”。
    await tester.tap(find.byType(NotebookSwitcherChip));
    await h.settleAll();
    final unfiledTile = tester.widget<ListTile>(
      find.ancestor(
        of: inShelf(find.text('未收录')),
        matching: find.byType(ListTile),
      ),
    );
    final allTile = tester.widget<ListTile>(
      find.ancestor(
        of: inShelf(find.text('全部日记')),
        matching: find.byType(ListTile),
      ),
    );
    expect(unfiledTile.selected, isTrue);
    expect(allTile.selected, isFalse);
    await tester.tapAt(const Offset(5, 5));
    await h.settleAll();

    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(scopeOf(tester).isAll, isTrue);
    expect(find.text('出发'), findsOneWidget);
    expect(find.text('上班路上'), findsOneWidget);
    await h.unmount();
  });
}
