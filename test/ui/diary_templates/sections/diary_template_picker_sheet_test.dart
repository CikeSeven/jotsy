import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_preview.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_questions.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_selection.dart';
import 'package:node_diary/ui/diary_templates/sections/diary_template_picker_sheet.dart';

import '../../../support/diary_drafts_harness.dart';

/// 模板面板：列出模板、按分类筛选、预览（变量已替换）、换一题、选用。
void main() {
  final day = DateTime(2026, 10, 18);

  Future<({DiaryDraftsHarness h, List<DiaryTemplateSelection?> picked})>
  openSheet(WidgetTester tester, {String? prefsRaw}) async {
    final h = await DiaryDraftsHarness.create(tester);
    if (prefsRaw != null) await h.settings.setDiaryTemplatePrefsRaw(prefsRaw);
    final picked = <DiaryTemplateSelection?>[];
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked.add(
              await showDiaryTemplatePickerSheet(context, diaryDate: day),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();
    return (h: h, picked: picked);
  }

  Finder tile(String id) => find.byKey(ValueKey<String>('template_pick_$id'));

  String previewBody(WidgetTester tester) => tester
      .widget<PublishDiaryPreview>(find.byType(PublishDiaryPreview))
      .draft
      .contentDocJson;

  testWidgets('filters by category and leaves hidden built-ins out', (
    tester,
  ) async {
    final (:h, picked: _) = await openSheet(
      tester,
      prefsRaw: '{"v":1,"hidden":["builtin.morning"]}',
    );
    expect(find.text(h.l10n.diaryTemplatePickerTitle), findsOneWidget);
    expect(tile('builtin.daily'), findsOneWidget);
    expect(tile('builtin.morning'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '复盘'));
    await tester.pumpAndSettle();
    expect(tile('builtin.daily'), findsNothing);
    expect(tile('builtin.evening'), findsOneWidget);
    expect(tile('builtin.weekly'), findsOneWidget);
    // 没有用户模板时不出现“我的”。
    expect(find.widgetWithText(ChoiceChip, '我的'), findsNothing);
    await h.unmount();
  });

  testWidgets('the preview resolves variables, shuffles the question and '
      'returns the choice', (tester) async {
    final (:h, :picked) = await openSheet(tester);
    final questions = diaryTemplateQuestions(h.l10n);

    await tester.scrollUntilVisible(
      tile('builtin.question'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(tile('builtin.question'));
    await tester.pumpAndSettle();

    expect(find.text('每日一问 · 2026年10月18日'), findsOneWidget);
    final first = questions.firstWhere(previewBody(tester).contains);

    await tester.tap(find.text(h.l10n.diaryTemplatePickerShuffle));
    await tester.pumpAndSettle();
    final second = questions.firstWhere(previewBody(tester).contains);
    expect(questions.indexOf(second), (questions.indexOf(first) + 1) % 30);

    await tester.tap(find.text(h.l10n.diaryTemplatePickerUse));
    await tester.pumpAndSettle();
    expect(picked.single?.template.id, 'builtin.question');
    expect(picked.single?.questionShift, 1);
    await h.unmount();
  });

  testWidgets('going back from the preview returns to the list', (
    tester,
  ) async {
    final (:h, :picked) = await openSheet(tester);
    await tester.tap(tile('builtin.daily'));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.diaryTemplatePickerShuffle), findsNothing);

    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(tile('builtin.daily'), findsOneWidget);
    expect(picked, isEmpty);
    await h.unmount();
  });
}
