import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_paragraph_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';

import '../../../support/expressive_test_theme.dart';

/// 工具栏「缩进」作用在正文段落上时只缩进首行：多行段落折行后的各行顶格，
/// 段落不变成上一段的子块；列表仍是真实的嵌套层级。
void main() {
  // 默认排版（全局不缩进）：标记的段落缩进两个字 = 2 × 16px。
  const indent = 32.0;

  Map<String, Object?> block(String type, String text) => {
    'type': type,
    'data': {
      'delta': [
        if (text.isNotEmpty) {'insert': text},
      ],
    },
  };

  DiaryEditorController controllerOf(List<Map<String, Object?>> blocks) =>
      DiaryEditorController.fromContent(
        jsonEncode({
          'document': {'type': 'page', 'children': blocks},
        }),
      );

  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller, {
    DiaryTypography typography = const DiaryTypography(),
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: DiaryEditor(
                    controller: controller,
                    appearance: DiaryTextAppearance(typography: typography),
                  ),
                ),
                Builder(
                  builder: (context) => buildDiaryToolbarItem(
                    context,
                    DiaryToolbarItem.indent,
                    controller,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tearDownEditor(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }

  Future<void> tap(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String tooltip) =>
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  Object? mark(DiaryEditorController controller, List<int> path) {
    final attributes = controller.state.getNodeAtPath(path)!.attributes;
    return attributes.containsKey(kDiaryParagraphIndentKey)
        ? attributes[kDiaryParagraphIndentKey]
        : 'absent';
  }

  Rect caret(DiaryEditorController controller, List<int> path, int offset) =>
      controller.state
          .getNodeAtPath(path)!
          .selectable!
          .getCursorRectInPosition(af.Position(path: path, offset: offset))!;

  testWidgets('indenting a multi-line paragraph only indents its first line', (
    tester,
  ) async {
    final controller = controllerOf([
      block('paragraph', '前一段'),
      block('paragraph', '今天' * 30),
    ]);
    await pump(tester, controller);
    controller.state.selection = af.Selection.collapsed(
      af.Position(path: [1], offset: 3),
    );
    await tester.pumpAndSettle();
    // 默认排版：不缩进的段落仍是上游段落块。
    expect(find.byType(DiaryParagraphBlock), findsNothing);

    await tap(tester, '增加缩进');

    // 没有挂到上一段下面：仍是顶层第二块，只多了首行缩进标记。
    final node = controller.state.getNodeAtPath([1])!;
    expect(node.type, kDiaryBlockParagraph);
    expect(node.attributes[kDiaryParagraphIndentKey], isTrue);
    expect(controller.state.getNodeAtPath([0])!.children, isEmpty);
    expect(find.byType(DiaryParagraphBlock), findsOneWidget);

    // 首行从缩进之后开始，折到第二行的字回到行首。
    final blockLeft = tester.getTopLeft(find.byType(DiaryParagraphBlock)).dx;
    final first = caret(controller, [1], 0);
    expect(first.left - blockLeft, closeTo(indent, 1.5));
    final wrapped = [
      for (var offset = 1; offset < 60; offset++)
        caret(controller, [1], offset),
    ].firstWhere((rect) => rect.top > first.bottom - 1);
    expect(wrapped.left - blockLeft, closeTo(0, 1.5));
    expect(tester.takeException(), isNull);

    // 再按「缩进」不会再挂成子块；「减少缩进」去掉首行缩进，一步撤销可回来。
    await tap(tester, '减少缩进');
    expect(
      controller.state.getNodeAtPath([1])!.attributes[kDiaryParagraphIndentKey],
      isNull,
    );
    expect(find.byType(DiaryParagraphBlock), findsNothing);
    controller.undo();
    await tester.pumpAndSettle();
    expect(
      controller.state.getNodeAtPath([1])!.attributes[kDiaryParagraphIndentKey],
      isTrue,
    );
    await tearDownEditor(tester, controller);
  });

  // #253：全局首行缩进两字时，「取消缩进」只取消这一段，「缩进」再缩回来；
  // 每次按下画面都有变化，不会出现标记加了又删、画面不动。
  testWidgets('outdent cancels the global first-line indent for one paragraph '
      'and indent brings it back', (tester) async {
    final controller = controllerOf([
      block('paragraph', '第一段'),
      block('paragraph', '第二段'),
    ]);
    await pump(
      tester,
      controller,
      typography: const DiaryTypography(firstLineIndent: 2),
    );
    controller.state.selection = af.Selection.collapsed(
      af.Position(path: [1], offset: 0),
    );
    await tester.pumpAndSettle();
    double lead(List<int> path) =>
        caret(controller, path, 0).left -
        tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx;
    final edge = lead([0]) - indent;
    expect(lead([1]) - edge, closeTo(indent, 1.5));
    // 已经按全局缩进了两字：「缩进」按下也不会变，停用。
    expect(enabled(tester, '增加缩进'), isFalse);
    expect(enabled(tester, '减少缩进'), isTrue);

    await tap(tester, '减少缩进');
    expect(mark(controller, [1]), isFalse);
    expect(lead([1]) - edge, closeTo(0, 1.5));
    // 只有这一段：前一段照旧按全局缩进。
    expect(lead([0]) - edge, closeTo(indent, 1.5));
    expect(enabled(tester, '增加缩进'), isTrue);
    expect(enabled(tester, '减少缩进'), isFalse);

    // 缩回来即跟随全局（删键），之后改全局缩进时跟着变。
    await tap(tester, '增加缩进');
    expect(mark(controller, [1]), 'absent');
    expect(lead([1]) - edge, closeTo(indent, 1.5));

    controller.undo();
    await tester.pumpAndSettle();
    expect(mark(controller, [1]), isFalse);
    expect(tester.takeException(), isNull);
    await tearDownEditor(tester, controller);
  });

  testWidgets('with a global indent under two characters indent widens to two '
      'and outdent removes the indent entirely', (tester) async {
    final controller = controllerOf([block('paragraph', '一段')]);
    await pump(
      tester,
      controller,
      typography: const DiaryTypography(firstLineIndent: 1),
    );
    controller.state.selection = af.Selection.collapsed(
      af.Position(path: [0], offset: 0),
    );
    await tester.pumpAndSettle();
    final blockLeft = tester.getTopLeft(find.byType(DiaryParagraphBlock)).dx;
    expect(caret(controller, [0], 0).left - blockLeft, closeTo(16, 1.5));

    await tap(tester, '增加缩进');
    expect(mark(controller, [0]), isTrue);
    expect(caret(controller, [0], 0).left - blockLeft, closeTo(indent, 1.5));

    // 删掉 true 会回到全局的一个字，仍缩进着：直接写成不缩进。
    await tap(tester, '减少缩进');
    expect(mark(controller, [0]), isFalse);
    expect(find.byType(DiaryParagraphBlock), findsNothing);
    expect(enabled(tester, '减少缩进'), isFalse);
    await tearDownEditor(tester, controller);
  });

  testWidgets('list items still nest under the previous item', (tester) async {
    final controller = controllerOf([
      block('bulleted_list', '第一项'),
      block('bulleted_list', '第二项'),
    ]);
    await pump(tester, controller);
    controller.state.selection = af.Selection.collapsed(
      af.Position(path: [1], offset: 1),
    );
    await tester.pumpAndSettle();

    await tap(tester, '增加缩进');

    final parent = controller.state.getNodeAtPath([0])!;
    expect(parent.children, hasLength(1));
    expect(parent.children.single.attributes[kDiaryParagraphIndentKey], isNull);
    await tearDownEditor(tester, controller);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
