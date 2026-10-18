import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_preview.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_questions.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_selection.dart';
import 'package:node_diary/ui/diary_templates/sections/diary_template_picker_sheet.dart';
import 'package:node_diary/ui/diary_templates/widgets/diary_template_tile.dart';

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

  final searchBar = find.byType(SearchBar);

  EditableText searchText(WidgetTester tester) => tester.widget<EditableText>(
    find.descendant(of: searchBar, matching: find.byType(EditableText)),
  );

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(searchBar, query);
    await tester.pumpAndSettle();
  }

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

  testWidgets('the sheet opens without focusing the search field', (
    tester,
  ) async {
    final (:h, picked: _) = await openSheet(tester);
    expect(searchBar, findsOneWidget);
    expect(find.text(h.l10n.diaryTemplatePickerSearchHint), findsOneWidget);
    expect(searchText(tester).focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    // 没有搜索词时不出现清空按钮。
    expect(find.byTooltip(h.l10n.autoT0130), findsNothing);
    await h.unmount();
  });

  testWidgets('typing filters the list by name and description', (
    tester,
  ) async {
    final (:h, picked: _) = await openSheet(tester);
    await search(tester, '感恩');
    expect(tile('builtin.gratitude'), findsOneWidget);
    expect(tile('builtin.daily'), findsNothing);

    // 说明里的词同样能搜到；多个词要同时命中。
    await search(tester, '今天 明天');
    expect(tile('builtin.evening'), findsOneWidget);
    expect(tile('builtin.daily'), findsNothing);
    expect(tile('builtin.gratitude'), findsNothing);
    await h.unmount();
  });

  testWidgets('the search combines with the selected chip', (tester) async {
    final (:h, picked: _) = await openSheet(tester);
    await search(tester, '今天');
    expect(tile('builtin.daily'), findsOneWidget);
    expect(tile('builtin.evening'), findsOneWidget);
    // 胶囊按完整列表计算：搜索结果里没有“情绪”类，胶囊仍在。
    expect(find.widgetWithText(ChoiceChip, '情绪'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '复盘'));
    await tester.pumpAndSettle();
    expect(tile('builtin.evening'), findsOneWidget);
    expect(tile('builtin.daily'), findsNothing);
    expect(tile('builtin.weekly'), findsNothing);
    await h.unmount();
  });

  testWidgets('the clear button empties the query and restores the list', (
    tester,
  ) async {
    final (:h, picked: _) = await openSheet(tester);
    await search(tester, '感恩');
    expect(tile('builtin.daily'), findsNothing);

    await tester.tap(find.byTooltip(h.l10n.autoT0130));
    await tester.pumpAndSettle();
    expect(searchText(tester).controller.text, isEmpty);
    expect(tile('builtin.daily'), findsOneWidget);
    expect(tile('builtin.gratitude'), findsOneWidget);
    expect(find.byTooltip(h.l10n.autoT0130), findsNothing);
    await h.unmount();
  });

  testWidgets('a search without results says what was searched', (
    tester,
  ) async {
    final (:h, picked: _) = await openSheet(tester);
    await search(tester, '  没有这种模板 ');
    expect(find.byType(DiaryTemplateTile), findsNothing);
    expect(
      find.text(h.l10n.diaryTemplatePickerSearchEmpty('没有这种模板')),
      findsOneWidget,
    );
    expect(find.text('没有找到与「没有这种模板」相关的模板'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.magnifyingGlass.data), findsWidgets);
    expect(find.text(h.l10n.diaryTemplatePickerEmpty), findsNothing);
    await h.unmount();
  });

  testWidgets('the query survives opening a preview and going back', (
    tester,
  ) async {
    final (:h, picked: _) = await openSheet(tester);
    await search(tester, '感恩');
    expect(searchText(tester).focusNode.hasFocus, isTrue);

    await tester.tap(tile('builtin.gratitude'));
    await tester.pumpAndSettle();
    expect(searchBar, findsNothing);
    // 进入预览时收起键盘。
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(searchText(tester).controller.text, '感恩');
    expect(tile('builtin.gratitude'), findsOneWidget);
    expect(tile('builtin.daily'), findsNothing);
    await h.unmount();
  });

  testWidgets('the search row does not overflow at 320dp and 1.3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (:h, picked: _) = await openSheet(tester);
    await search(tester, '今天');
    expect(tester.takeException(), isNull);
    await search(tester, '没有这种模板');
    expect(tester.takeException(), isNull);
    await h.unmount();
  });
}
