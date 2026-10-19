import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_add_diaries_page.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 添加日记页：已在本子里的停用，勾选后“完成”加入并返回。
void main() {
  Finder rowOf(String id) => find.byKey(ValueKey<String>('notebook_add_$id'));

  testWidgets('adds the selected diaries and disables existing members', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final inside = await h.diary('已经在里面', notebookIds: <String>[travel]);
    final first = await h.diary('第一篇');
    final second = await h.diary('第二篇');
    await h.diary('不选的');
    final notebook = NotebookView((await h.notebookRow(travel))!);

    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(NotebookAddDiariesPage.route(notebook: notebook)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();

    expect(find.text('添加到「旅行」'), findsOneWidget);
    expect(find.text('完成 (0)'), findsOneWidget);
    expect(
      find.descendant(
        of: rowOf(inside),
        matching: find.textContaining('已在本子里'),
      ),
      findsOneWidget,
    );

    // 已在本子里的点了不会被选中。
    await tester.tap(rowOf(inside));
    await tester.tap(rowOf(first));
    await tester.tap(rowOf(second));
    await tester.pumpAndSettle();
    expect(find.text('完成 (2)'), findsOneWidget);

    await tester.tap(find.text('完成 (2)'));
    await h.settleAll();
    expect(find.byType(NotebookAddDiariesPage), findsNothing);
    expect(find.text('已添加 2 篇'), findsOneWidget);

    final members = (await tester.runAsync(
      () => h.database.getNotebookIdsForDiaries(<String>[first, second]),
    ))!;
    expect(members[first], contains(travel));
    expect(members[second], contains(travel));
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('the keyword filters the candidates', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    await h.diary('京都的雨');
    await h.diary('上班路上');
    final notebook = NotebookView((await h.notebookRow(travel))!);
    await h.pump(NotebookAddDiariesPage(notebook: notebook));
    await h.settleAll();
    expect(find.text('上班路上'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '京都');
    await tester.pump(const Duration(milliseconds: 250));
    await h.settleAll();
    expect(find.text('京都的雨'), findsOneWidget);
    expect(find.text('上班路上'), findsNothing);
    await h.unmount();
  });
}
