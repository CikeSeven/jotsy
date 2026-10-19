import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 日记本管理页：拖动排序写库、删除两种方式都可撤销、合并。
void main() {
  Future<DiaryDraftsHarness> open(
    WidgetTester tester,
    Future<void> Function(DiaryDraftsHarness h) seed,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed(h);
    await h.pump(const NotebooksPage());
    await h.settleAll();
    return h;
  }

  Finder row(String id) => find.byKey(ValueKey<String>('notebook_row_$id'));

  Future<bool> isTrashed(DiaryDraftsHarness h, String diaryId) async {
    final rows = (await h.tester.runAsync(
      () => h.database.select(h.database.diaries).get(),
    ))!;
    return rows.singleWhere((d) => d.diaryId == diaryId).isDeleted;
  }

  Future<void> openMore(DiaryDraftsHarness h, String id, String action) async {
    await h.tester.tap(
      find.descendant(of: row(id), matching: find.byTooltip('更多操作')),
    );
    await h.tester.pumpAndSettle();
    await h.tester.tap(find.widgetWithText(ListTile, action));
    await h.tester.pumpAndSettle();
  }

  testWidgets('lists sections with counts and state', (tester) async {
    final h = await open(tester, (h) async {
      final travel = await h.notebook('旅行', pinned: true);
      await h.notebook('有照片的', kind: NotebookKind.smart);
      await h.notebook('旧事', closed: true);
      await h.diary('第一天', notebookIds: <String>[travel]);
    });
    expect(find.text('我的日记本'), findsOneWidget);
    expect(find.text('智能日记本'), findsOneWidget);
    expect(find.text('已合上'), findsOneWidget);
    expect(find.text('1 篇 · 置顶'), findsOneWidget);
    expect(find.text('智能'), findsOneWidget);
    expect(find.text('0 篇 · 已合上'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('dragging a row persists the new order', (tester) async {
    late String work;
    final h = await open(tester, (h) async {
      await h.notebook('旅行');
      await h.notebook('读书');
      work = await h.notebook('工作');
      await h.notebook('有照片的', kind: NotebookKind.smart);
    });
    final handle = find.descendant(
      of: row(work),
      matching: find.byType(ReorderableDragStartListener),
    );
    final distance =
        tester.getTopLeft(row(work)).dy -
        tester.getTopLeft(find.byType(ReorderableDragStartListener).first).dy;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(0, -(distance + 20) / 20));
      await tester.pump();
    }
    await gesture.up();
    await h.settleAll();

    final names = (await h.shelf()).map((r) => r.name).toList();
    expect(names, <String>['工作', '旅行', '读书', '有照片的']);
    await h.unmount();
  });

  testWidgets('deleting only the notebook keeps diaries and undo restores', (
    tester,
  ) async {
    late String travel;
    late String diary;
    final h = await open(tester, (h) async {
      travel = await h.notebook('旅行');
      diary = await h.diary('第一天', notebookIds: <String>[travel]);
    });
    await openMore(h, travel, '删除');
    expect(find.text('删除「旅行」？'), findsOneWidget);
    expect(find.text('1 篇日记仍在全部日记里'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await h.settleAll();

    expect(await h.notebookRow(travel), isNull);
    expect(row(travel), findsNothing);
    expect(await isTrashed(h, diary), isFalse);
    expect(find.text('已删除「旅行」'), findsOneWidget);

    await tester.tap(find.text(h.l10n.commonUndo));
    await h.settleAll();
    expect(await h.notebookRow(travel), isNotNull);
    expect(row(travel), findsOneWidget);
    expect(find.text('1 篇'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('deleting with diaries trashes them and undo restores both', (
    tester,
  ) async {
    late String travel;
    late String diary;
    final h = await open(tester, (h) async {
      travel = await h.notebook('旅行');
      diary = await h.diary('第一天', notebookIds: <String>[travel]);
    });
    await openMore(h, travel, '删除');
    await tester.tap(find.text('连同日记移到回收站'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '删除'),
    );
    final colors = Theme.of(tester.element(find.text('连同日记移到回收站'))).colorScheme;
    expect(
      confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
      colors.error,
    );
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await h.settleAll();
    expect(await h.notebookRow(travel), isNull);
    expect(await isTrashed(h, diary), isTrue);

    await tester.tap(find.text(h.l10n.commonUndo));
    await h.settleAll();
    expect(await h.notebookRow(travel), isNotNull);
    expect(await isTrashed(h, diary), isFalse);
    await h.unmount();
  });

  testWidgets('merging moves the diaries and deletes the source', (
    tester,
  ) async {
    late String travel;
    late String trips;
    final h = await open(tester, (h) async {
      travel = await h.notebook('旅行');
      trips = await h.notebook('出游');
      await h.notebook('有照片的', kind: NotebookKind.smart);
      await h.diary('第一天', notebookIds: <String>[travel]);
    });
    await openMore(h, travel, '合并到…');
    // 智能日记本不能作为合并目标。
    expect(find.widgetWithText(ListTile, '有照片的'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '出游'));
    await tester.pumpAndSettle();
    expect(find.text('把「旅行」的 1 篇日记并入「出游」并删除「旅行」？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '合并'));
    await h.settleAll();

    expect(await h.notebookRow(travel), isNull);
    final counts = (await tester.runAsync(
      () => h.database.watchManualNotebookEntryCounts().first,
    ))!;
    expect(counts[trips], 1);
    expect(find.text('已并入「出游」'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('pinning from the actions sheet', (tester) async {
    late String travel;
    final h = await open(tester, (h) async {
      await h.notebook('读书');
      travel = await h.notebook('旅行');
    });
    await openMore(h, travel, '置顶');
    await h.settleAll();
    expect((await h.notebookRow(travel))!.isPinned, isTrue);
    expect(find.text('0 篇 · 置顶'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('shows the empty state', (tester) async {
    final h = await open(tester, (_) async {});
    expect(find.text('把不同主题、不同时间的日记收进同一本'), findsOneWidget);
    await h.unmount();
  });
}
