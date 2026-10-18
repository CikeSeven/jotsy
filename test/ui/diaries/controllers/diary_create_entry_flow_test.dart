import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_draft_picker_sheet.dart';

import '../../../support/diary_drafts_harness.dart';

/// 新建入口：没有草稿直接进空白页；有草稿时先弹选择面板，新建空白不再
/// 删除任何草稿。
void main() {
  final results = <DiaryCreateEntryResult>[];
  setUp(results.clear);

  Future<DiaryDraftsHarness> open(WidgetTester tester) async {
    final harness = await DiaryDraftsHarness.create(tester);
    return harness;
  }

  Future<void> pumpOpener(DiaryDraftsHarness harness) {
    return harness.pump(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                results.add(await runDiaryCreateEntryFlow(context, ref)),
            child: const Text('New'),
          ),
        ),
      ),
    );
  }

  Future<void> tapNew(WidgetTester tester, DiaryDraftsHarness harness) async {
    await tester.tap(find.text('New'));
    await harness.settle();
    await tester.pumpAndSettle();
  }

  EditDiaryPage editor(WidgetTester tester) =>
      tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));

  testWidgets('without drafts the blank editor opens directly', (tester) async {
    final harness = await open(tester);
    await pumpOpener(harness);

    await tapNew(tester, harness);

    expect(find.byType(BottomSheet), findsNothing);
    expect(editor(tester).createDraftId, isNull);
    await harness.unmount();
  });

  testWidgets('with drafts the picker lists the three most recent', (
    tester,
  ) async {
    final harness = await open(tester);
    for (var i = 1; i <= 5; i++) {
      await harness.seed('草稿 $i', updatedAt: DateTime(2026, 10, i));
    }
    await pumpOpener(harness);

    await tapNew(tester, harness);

    final l10n = harness.l10n;
    expect(find.text(l10n.diaryDraftPickerTitle), findsOneWidget);
    for (final shown in ['草稿 5', '草稿 4', '草稿 3']) {
      expect(find.text(shown), findsOneWidget);
    }
    expect(find.text('草稿 2'), findsNothing);
    expect(find.text(l10n.diaryDraftPickerViewAll(5)), findsOneWidget);
    // 最近编辑的在最上面。
    expect(
      tester.getTopLeft(find.text('草稿 5')).dy,
      lessThan(tester.getTopLeft(find.text('草稿 4')).dy),
    );
    expect(maxRecentDraftsInPicker, 3);
    await harness.unmount();
  });

  testWidgets('picking a draft continues that draft', (tester) async {
    final harness = await open(tester);
    await harness.seed('旧的', updatedAt: DateTime(2026, 10, 1));
    final target = await harness.seed('要续写的', updatedAt: DateTime(2026, 10, 2));
    await pumpOpener(harness);

    await tapNew(tester, harness);
    await tester.tap(find.text('要续写的'));
    await tester.pumpAndSettle();

    expect(editor(tester).createDraftId, target);
    await harness.unmount();
  });

  testWidgets('a blank entry keeps every existing draft', (tester) async {
    final harness = await open(tester);
    await harness.seed('不能被抹掉', updatedAt: DateTime(2026, 10, 1));
    await pumpOpener(harness);

    await tapNew(tester, harness);
    await tester.tap(find.text(harness.l10n.diaryDraftPickerNewBlank));
    await tester.pumpAndSettle();

    expect(editor(tester).createDraftId, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await harness.settle();
    expect((await harness.drafts()).single.title, '不能被抹掉');
    expect(results.single.opened, isTrue);
    await harness.unmount();
  });

  testWidgets('view all opens the drafts page', (tester) async {
    final harness = await open(tester);
    await harness.seed('一份', updatedAt: DateTime(2026, 10, 1));
    await pumpOpener(harness);

    await tapNew(tester, harness);
    await tester.tap(find.text(harness.l10n.diaryDraftPickerViewAll(1)));
    await tester.pumpAndSettle();
    await harness.settle();

    expect(find.byType(DiaryDraftsPage), findsOneWidget);
    expect(find.byType(EditDiaryPage), findsNothing);
    await harness.unmount();
  });

  testWidgets('dismissing the picker opens nothing', (tester) async {
    final harness = await open(tester);
    await harness.seed('一份', updatedAt: DateTime(2026, 10, 1));
    await pumpOpener(harness);

    await tapNew(tester, harness);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(find.byType(EditDiaryPage), findsNothing);
    expect(results.single.opened, isFalse);
    await harness.unmount();
  });
}
