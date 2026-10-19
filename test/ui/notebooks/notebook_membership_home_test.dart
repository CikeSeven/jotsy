import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页多选的日记本操作：收进日记本、从本日记本移出、移动到，都可撤销；
/// 空日记本的两个入口。
void main() {
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

  Finder card(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiarySelectionSurface),
  );

  Future<Set<String>> notebooksOf(DiaryDraftsHarness h, String diaryId) async =>
      (await h.tester.runAsync(() => h.database.getDiaryNotebookIds(diaryId)))!;

  Future<void> tapUndo(DiaryDraftsHarness h) async {
    await h.tester.tap(find.text('撤销'));
    await h.settleAll();
  }

  testWidgets('adds selected diaries to a notebook and undo takes them out', (
    tester,
  ) async {
    late String travel;
    late String diary;
    final h = await pumpHome(tester, (h) async {
      travel = await h.notebook('旅行');
      diary = await h.diary('在京都');
    });
    await tester.longPress(card('在京都'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收进日记本'));
    await h.settleAll();
    await tester.tap(find.byKey(ValueKey<String>('notebook_pick_$travel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();

    expect(await notebooksOf(h, diary), <String>{travel});
    expect(find.text('已收进 1 本日记本'), findsOneWidget);
    // 退出了多选。
    expect(find.byTooltip('收进日记本'), findsNothing);

    await tapUndo(h);
    expect(await notebooksOf(h, diary), isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('removing from the current notebook hides the card and undo '
      'brings it back', (tester) async {
    late String travel;
    late String diary;
    final h = await pumpHome(tester, (h) async {
      travel = await h.notebook('旅行');
      diary = await h.diary('在京都', notebookIds: <String>[travel]);
    });
    await enter(h, travel);
    expect(find.text('在京都'), findsOneWidget);

    await tester.longPress(card('在京都'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('从本日记本移出'));
    await h.settleAll();

    expect(await notebooksOf(h, diary), isEmpty);
    expect(find.text('已从「旅行」移出 1 篇'), findsOneWidget);
    expect(find.text('在京都'), findsNothing);

    await tapUndo(h);
    expect(await notebooksOf(h, diary), <String>{travel});
    expect(find.text('在京都'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('moving to another notebook and undoing', (tester) async {
    late String travel;
    late String work;
    late String diary;
    final h = await pumpHome(tester, (h) async {
      travel = await h.notebook('旅行');
      work = await h.notebook('工作');
      diary = await h.diary('在京都', notebookIds: <String>[travel]);
    });
    await enter(h, travel);
    await tester.longPress(card('在京都'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动到…'));
    await h.settleAll();
    // 当前这本不在目标里。
    expect(find.byKey(ValueKey<String>('notebook_pick_$travel')), findsNothing);
    await tester.tap(find.byKey(ValueKey<String>('notebook_pick_$work')));
    await h.settleAll();

    expect(await notebooksOf(h, diary), <String>{work});
    expect(find.text('已将 1 篇移到「工作」'), findsOneWidget);

    await tapUndo(h);
    expect(await notebooksOf(h, diary), <String>{travel});
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('an empty manual notebook offers writing and picking', (
    tester,
  ) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await h.notebook('旅行');
      await h.diary('上班路上');
    });
    await enter(h, travel);
    expect(find.text('写第一篇'), findsOneWidget);
    expect(find.text('从已有日记挑选'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NotebookHeaderCard),
        matching: find.text('添加日记'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('从已有日记挑选'));
    await h.settleAll();
    expect(find.text('添加到「旅行」'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the header card lines up with the list cards', (tester) async {
    late String travel;
    final h = await pumpHome(tester, (h) async {
      travel = await h.notebook('旅行');
      await h.diary('在京都', notebookIds: <String>[travel]);
    });
    await enter(h, travel);
    final header = tester.getRect(
      find
          .descendant(
            of: find.byType(NotebookHeaderCard),
            matching: find.byType(Material),
          )
          .first,
    );
    final cardRect = tester.getRect(card('在京都'));
    expect(header.left, cardRect.left);
    expect(header.right, cardRect.right);
    await h.unmount();
  });
}
