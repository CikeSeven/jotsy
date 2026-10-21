import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_draft_tile.dart';

import '../../../support/diary_drafts_harness.dart';

/// 草稿箱页：列表、续写、左滑删除与撤销、多选删除。
void main() {
  Future<DiaryDraftsHarness> openPage(
    WidgetTester tester, {
    List<(String, DateTime)> drafts = const [],
  }) async {
    final harness = await DiaryDraftsHarness.create(tester);
    for (final (title, at) in drafts) {
      await harness.seed(title, contentText: '$title 的正文', updatedAt: at);
    }
    await harness.pump(const DiaryDraftsPage());
    await tester.pumpAndSettle();
    return harness;
  }

  Finder tileOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiaryDraftTile),
  );

  Future<void> swipeAway(WidgetTester tester, String title) async {
    await tester.drag(tileOf(title), const Offset(-360, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('drafts are listed with the most recent first', (tester) async {
    final harness = await openPage(
      tester,
      drafts: [
        ('早一点的', DateTime(2026, 10, 1, 8)),
        ('最新的', DateTime(2026, 10, 2, 8)),
      ],
    );

    expect(find.byType(DiaryDraftTile), findsNWidgets(2));
    expect(
      tester.getTopLeft(tileOf('最新的')).dy,
      lessThan(tester.getTopLeft(tileOf('早一点的')).dy),
    );
    expect(find.text('最新的 的正文'), findsOneWidget);
    await harness.unmount();
  });

  testWidgets('an empty drafts box shows the hint', (tester) async {
    final harness = await openPage(tester);
    expect(find.text(harness.l10n.diaryDraftsEmpty), findsOneWidget);
    await harness.unmount();
  });

  testWidgets('tapping a draft continues it in the editor', (tester) async {
    final harness = await openPage(
      tester,
      drafts: [('继续写我', DateTime(2026, 10, 1))],
    );
    final id = (await harness.drafts()).single.draftId;

    await tester.tap(tileOf('继续写我'));
    await tester.pumpAndSettle();

    final editor = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(editor.createDraftId, id);
    expect(editor.entryMode, EditDiaryEntryMode.create);
    await harness.unmount();
  });

  testWidgets('swiping a draft away can be undone', (tester) async {
    final harness = await openPage(
      tester,
      drafts: [('滑走又回来', DateTime(2026, 10, 1))],
    );

    await swipeAway(tester, '滑走又回来');
    await harness.settle();
    expect(find.text(harness.l10n.diaryDraftDeleted), findsOneWidget);
    expect(await harness.drafts(), isEmpty);

    await tester.tap(find.text(harness.l10n.commonUndo));
    await tester.pumpAndSettle();
    await harness.settle();
    await tester.pumpAndSettle();

    expect((await harness.drafts()).single.title, '滑走又回来');
    expect(tileOf('滑走又回来'), findsOneWidget);
    // 撤销了：只被这份草稿引用的媒体不能被回收。
    expect(harness.mediaCleanup.sweeps, 0);
    await harness.unmount();
  });

  testWidgets('media is reclaimed only after the undo window closes', (
    tester,
  ) async {
    final harness = await openPage(
      tester,
      drafts: [('真的删掉', DateTime(2026, 10, 1))],
    );

    await swipeAway(tester, '真的删掉');
    await harness.settle();
    expect(harness.mediaCleanup.sweeps, 0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await harness.settle();

    expect(harness.mediaCleanup.sweeps, 1);
    expect(find.text(harness.l10n.diaryDraftsEmpty), findsOneWidget);
    await harness.unmount();
  });

  testWidgets('selected drafts are deleted after confirming', (tester) async {
    final harness = await openPage(
      tester,
      drafts: [
        ('留着', DateTime(2026, 10, 1)),
        ('删掉一', DateTime(2026, 10, 2)),
        ('删掉二', DateTime(2026, 10, 3)),
      ],
    );
    final l10n = harness.l10n;

    await tester.longPress(tileOf('删掉一'));
    await tester.pumpAndSettle();
    await tester.tap(tileOf('删掉二'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0099('2')), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryDraftsDeleteMessage(2)), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    await harness.settle();
    await tester.pumpAndSettle();

    expect((await harness.drafts()).map((row) => row.title), ['留着']);
    expect(find.text(l10n.diaryDraftsDeleted(2)), findsOneWidget);
    expect(find.text(l10n.diaryDraftsTitle), findsOneWidget);
    // 撤销窗口结束（提示条的强制关闭计时器走完）后才回收媒体。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(harness.mediaCleanup.sweeps, 1);
    await harness.unmount();
  });

  testWidgets('select all picks every draft and toggles back', (tester) async {
    final harness = await openPage(
      tester,
      drafts: [
        ('一', DateTime(2026, 10, 1)),
        ('二', DateTime(2026, 10, 2)),
        ('三', DateTime(2026, 10, 3)),
      ],
    );
    final l10n = harness.l10n;
    // 不在多选时没有全选按钮：多选由长按进入。
    expect(find.byTooltip(l10n.commonSelectAll), findsNothing);

    await tester.longPress(tileOf('二'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonSelectAll));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0099('3')), findsOneWidget);
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value),
      everyElement(isTrue),
    );

    // 取消全选即退出多选。
    await tester.tap(find.byTooltip(l10n.commonDeselectAll));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryDraftsTitle), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await harness.unmount();
  });

  testWidgets('select all then delete empties the drafts box', (tester) async {
    final harness = await openPage(
      tester,
      drafts: [('甲', DateTime(2026, 10, 1)), ('乙', DateTime(2026, 10, 2))],
    );
    final l10n = harness.l10n;

    await tester.longPress(tileOf('甲'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonSelectAll));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryDraftsDeleteMessage(2)), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    await harness.settle();
    await tester.pumpAndSettle();

    expect(await harness.drafts(), isEmpty);
    expect(find.text(l10n.diaryDraftsDeleted(2)), findsOneWidget);
    expect(find.text(l10n.diaryDraftsEmpty), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await harness.unmount();
  });

  testWidgets('back leaves selection mode before leaving the page', (
    tester,
  ) async {
    final harness = await DiaryDraftsHarness.create(tester);
    await harness.seed('一份', updatedAt: DateTime(2026, 10, 1));
    await harness.pump(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const DiaryDraftsPage()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await harness.settle();
    await tester.pumpAndSettle();

    await tester.longPress(tileOf('一份'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryDraftsPage), findsOneWidget);
    expect(find.text(harness.l10n.diaryDraftsTitle), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryDraftsPage), findsNothing);
    await harness.unmount();
  });
}
