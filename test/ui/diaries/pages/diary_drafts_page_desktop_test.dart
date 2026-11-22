import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_draft_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_item.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

import '../../../support/diary_drafts_harness.dart';

/// 草稿箱页在桌面上（#350）：顶栏“多选”直接进入多选、右键菜单继续写或
/// 删除、Ctrl / Shift + 点按多选，不提供左滑；手机上没有“多选”按钮。
void main() {
  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  Future<DiaryDraftsHarness> openPage(
    WidgetTester tester, {
    required List<String> titles,
  }) async {
    final harness = await DiaryDraftsHarness.create(tester);
    // 越靠后越新：列表里最后一个排在最上面。
    for (var i = 0; i < titles.length; i++) {
      await harness.seed(titles[i], updatedAt: DateTime(2026, 10, 1 + i));
    }
    await harness.pump(const DiaryDraftsPage());
    await tester.pumpAndSettle();
    return harness;
  }

  Finder tileOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiaryDraftTile),
  );

  Future<void> rightClick(WidgetTester tester, String title) async {
    await tester.tap(
      tileOf(title),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapWith(
    WidgetTester tester,
    LogicalKeyboardKey key,
    String title,
  ) async {
    await tester.sendKeyDownEvent(key);
    await tester.tap(tileOf(title));
    await tester.sendKeyUpEvent(key);
    await tester.pumpAndSettle();
  }

  Iterable<bool?> checkboxValues(WidgetTester tester) =>
      tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value);

  IconButton deleteButton(WidgetTester tester, DiaryDraftsHarness harness) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(harness.l10n.commonDelete),
          matching: find.byType(IconButton),
        ),
      );

  testWidgets(
    'the select button shows checkboxes and deletes the ticked drafts',
    (tester) async {
      final harness = await openPage(tester, titles: ['留着', '删掉']);
      final l10n = harness.l10n;

      await tester.tap(find.byTooltip(l10n.diaryDraftsSelect));
      await tester.pumpAndSettle();
      // 直接进入多选：每行都有勾选框，一份都没勾，删除停用。
      expect(find.text(l10n.autoT0099('0')), findsOneWidget);
      expect(checkboxValues(tester), [false, false]);
      expect(deleteButton(tester, harness).onPressed, isNull);

      // 多选里点按只切换勾选，不打开编辑页。
      await tester.tap(tileOf('删掉'));
      await tester.pumpAndSettle();
      expect(find.byType(EditDiaryPage), findsNothing);
      expect(find.text(l10n.autoT0099('1')), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.commonDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.diaryDraftsDeleteMessage(1)), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
      await tester.pumpAndSettle();
      await harness.settle();
      await tester.pumpAndSettle();

      expect((await harness.drafts()).map((row) => row.title), ['留着']);
      // 删除后退出多选，回到平时的顶栏。
      expect(find.text(l10n.diaryDraftsTitle), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await harness.unmount();
    },
    variant: desktop,
  );

  testWidgets('selection entered from the button stays until cancelled', (
    tester,
  ) async {
    final harness = await openPage(tester, titles: ['一份']);
    final l10n = harness.l10n;

    await tester.tap(find.byTooltip(l10n.diaryDraftsSelect));
    await tester.pumpAndSettle();
    await tester.tap(tileOf('一份'));
    await tester.pumpAndSettle();
    await tester.tap(tileOf('一份'));
    await tester.pumpAndSettle();
    // 取消最后一份不退出（与长按进入的不同）。
    expect(find.text(l10n.autoT0099('0')), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryDraftsTitle), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await harness.unmount();
  }, variant: desktop);

  testWidgets('the select button is disabled when there are no drafts', (
    tester,
  ) async {
    final harness = await openPage(tester, titles: const []);
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(harness.l10n.diaryDraftsSelect),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    await harness.unmount();
  }, variant: desktop);

  testWidgets('deleting from the right-click menu can be undone', (
    tester,
  ) async {
    final harness = await openPage(tester, titles: ['右键删掉']);
    final l10n = harness.l10n;

    await rightClick(tester, '右键删掉');
    expect(find.text(l10n.diaryDraftContinue), findsOneWidget);
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    await harness.settle();
    await tester.pumpAndSettle();

    // 单份删除与左滑一样不确认，直接给撤销。
    expect(find.byType(AlertDialog), findsNothing);
    expect(await harness.drafts(), isEmpty);
    expect(find.text(l10n.diaryDraftDeleted), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    await harness.settle();
    await tester.pumpAndSettle();

    expect((await harness.drafts()).single.title, '右键删掉');
    expect(tileOf('右键删掉'), findsOneWidget);
    expect(harness.mediaCleanup.sweeps, 0);
    await harness.unmount();
  }, variant: desktop);

  testWidgets('continue from the right-click menu opens the editor', (
    tester,
  ) async {
    final harness = await openPage(tester, titles: ['接着写']);
    final id = (await harness.drafts()).single.draftId;

    await rightClick(tester, '接着写');
    await tester.tap(find.text(harness.l10n.diaryDraftContinue));
    await tester.pumpAndSettle();

    final editor = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(editor.createDraftId, id);
    await harness.unmount();
  }, variant: desktop);

  testWidgets('right-click does nothing while selecting', (tester) async {
    final harness = await openPage(tester, titles: ['多选中']);

    await tester.tap(find.byTooltip(harness.l10n.diaryDraftsSelect));
    await tester.pumpAndSettle();
    await rightClick(tester, '多选中');
    expect(find.byType(ExpressiveMenuItem), findsNothing);
    await harness.unmount();
  }, variant: desktop);

  testWidgets('ctrl-click and shift-click select drafts', (tester) async {
    // 列表自上而下：五、四、三、二、一。
    final harness = await openPage(tester, titles: ['一', '二', '三', '四', '五']);
    final l10n = harness.l10n;

    await tapWith(tester, LogicalKeyboardKey.controlLeft, '五');
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(find.text(l10n.autoT0099('1')), findsOneWidget);

    // Shift + 点按：从起点“五”勾到“三”。
    await tapWith(tester, LogicalKeyboardKey.shiftLeft, '三');
    expect(find.text(l10n.autoT0099('3')), findsOneWidget);
    expect(checkboxValues(tester), [true, true, true, false, false]);

    // Ctrl + 点按已勾的取消勾选。
    await tapWith(tester, LogicalKeyboardKey.controlLeft, '四');
    expect(find.text(l10n.autoT0099('2')), findsOneWidget);
    await harness.unmount();
  }, variant: desktop);

  testWidgets('dragging a draft with the mouse does not delete it', (
    tester,
  ) async {
    final harness = await openPage(tester, titles: ['拖不走']);

    expect(find.byType(DiarySwipeActionItem), findsNothing);
    await tester.drag(
      tileOf('拖不走'),
      const Offset(-360, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await harness.settle();

    expect((await harness.drafts()).single.title, '拖不走');
    await harness.unmount();
  }, variant: desktop);

  testWidgets('phones have no select button and keep swipe to delete', (
    tester,
  ) async {
    final harness = await openPage(tester, titles: ['手机上']);

    expect(find.byTooltip(harness.l10n.diaryDraftsSelect), findsNothing);
    expect(find.byType(DiarySwipeActionItem), findsOneWidget);
    await harness.unmount();
  });
}
