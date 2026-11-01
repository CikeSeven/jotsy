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
    DiaryEditorController controller,
  ) async {
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
                    appearance: const DiaryTextAppearance(
                      typography: DiaryTypography(),
                    ),
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
