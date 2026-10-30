import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_paragraph_block.dart';

import '../../../support/expressive_test_theme.dart';

/// 首行缩进：段首的字换成“缩进 + 字”的占位，几何查询把缩进当成段首空白。
void main() {
  // 两个字 = 2 × 16px = 32px。
  const indented = DiaryTextAppearance(
    typography: DiaryTypography(firstLineIndent: 2),
  );
  const indent = 32.0;

  Map<String, Object?> block(
    String type,
    String text, {
    Map<String, Object?> data = const {},
  }) => {
    'type': type,
    'data': {
      'delta': [
        if (text.isNotEmpty) {'insert': text},
      ],
      ...data,
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
    DiaryTextAppearance appearance = indented,
    Brightness brightness = Brightness.light,
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
          theme: expressiveTestTheme(brightness),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiaryEditor(controller: controller, appearance: appearance),
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

  /// 段首占位里画出来的那个字。
  Finder firstGlyph(String glyph) => find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == glyph,
  );

  af.SelectableMixin selectableAt(
    DiaryEditorController controller,
    List<int> path,
  ) => controller.state.getNodeAtPath(path)!.selectable!;

  /// 段落块的左边缘（编辑区没有左右留白，段落块从这里开始）。
  double blockLeft(WidgetTester tester) =>
      tester.getTopLeft(find.byType(DiaryParagraphBlock).first).dx;

  for (final brightness in Brightness.values) {
    testWidgets('only flush body paragraphs indent their first line in '
        '${brightness.name}', (tester) async {
      final controller = controllerOf([
        block('paragraph', '今天天气很好'),
        block('heading', '标题', data: {'level': 2}),
        block('paragraph', '居中', data: {'align': 'center'}),
        block('bulleted_list', '列表'),
        block('quote', '引用'),
      ]);
      await pump(tester, controller, brightness: brightness);

      expect(
        tester.getTopLeft(firstGlyph('今')).dx - blockLeft(tester),
        closeTo(indent, 0.5),
      );
      for (final glyph in ['标', '居', '列', '引']) {
        expect(firstGlyph(glyph), findsNothing, reason: glyph);
      }
      expect(tester.takeException(), isNull);
      await tearDownEditor(tester, controller);
    });
  }

  testWidgets('paragraphs inside table cells never indent their first line', (
    tester,
  ) async {
    final controller = controllerOf([
      block('paragraph', '正文段落'),
      {
        'type': 'table',
        'data': {'rowsLen': 1, 'colsLen': 2},
        'children': [
          for (var col = 0; col < 2; col++)
            {
              'type': 'table/cell',
              'data': {'rowPosition': 0, 'colPosition': col},
              'children': [
                block('paragraph', col == 0 ? '格子文字' : '第二格'),
                block('paragraph', col == 0 ? '格内二段' : ''),
              ],
            },
        ],
      },
    ]);
    await pump(tester, controller);

    // 正文段照常缩进；格内各段（含空段的占位）不换成段首占位。
    expect(
      tester.getTopLeft(firstGlyph('正')).dx - blockLeft(tester),
      closeTo(indent, 0.5),
    );
    for (final glyph in ['格', '第']) {
      expect(firstGlyph(glyph), findsNothing, reason: glyph);
    }
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .toList();
    expect(texts, containsAll(['格子文字', '格内二段', '第二格']));

    // 段首的光标贴着格子里的文字起点，不右移一个缩进。
    final caret = selectableAt(controller, [
      1,
      0,
      0,
    ]).getCursorRectInPosition(af.Position(path: [1, 0, 0]))!;
    expect(caret.center.dx, lessThan(indent / 2));
    expect(tester.takeException(), isNull);
    await tearDownEditor(tester, controller);
  });

  testWidgets('text offsets stay aligned with the document, emoji included', (
    tester,
  ) async {
    final controller = controllerOf([
      block('paragraph', '今天天气很好'),
      block('paragraph', '😀 ok'),
    ]);
    await pump(tester, controller);

    // 每个字素换成等长的占位，渲染文字与文档逐个码元对应。
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .toList();
    expect(texts, contains('￼天天气很好'));
    expect(texts, contains('￼￼ ok'));
    expect(firstGlyph('😀'), findsOneWidget);
    await tearDownEditor(tester, controller);
  });

  testWidgets('the caret at the paragraph start sits after the indent', (
    tester,
  ) async {
    // 段落要折行：多行段落的首行带下方的半个行距，段首光标须与之等高。
    final controller = controllerOf([
      block('paragraph', '今天' * 30),
      block('paragraph', ''),
    ]);
    await pump(tester, controller);
    final first = selectableAt(controller, [0]);

    final start = first.getCursorRectInPosition(af.Position(path: [0]))!;
    final afterFirst = first.getCursorRectInPosition(
      af.Position(path: [0], offset: 1),
    )!;
    expect(start.center.dx, closeTo(indent, 1.5));
    expect(afterFirst.center.dx, closeTo(indent + 16, 1.5));
    expect(start.top, closeTo(afterFirst.top, 0.5));
    expect(start.bottom, closeTo(afterFirst.bottom, 0.5));

    // 空段落：光标同样在缩进之后，接着输入的第一个字就在光标处。
    final empty = selectableAt(controller, [1]);
    final emptyStart = empty.getCursorRectInPosition(af.Position(path: [1]))!;
    expect(emptyStart.center.dx, closeTo(indent, 1.5));
    // 与占位提示同一行，而不是落到行底。
    expect(emptyStart.top, closeTo(0, 0.5));
    expect(emptyStart.height, greaterThanOrEqualTo(16));
    await tearDownEditor(tester, controller);
  });

  testWidgets('selections from the start do not paint over the indent', (
    tester,
  ) async {
    final controller = controllerOf([block('paragraph', '今天天气')]);
    await pump(tester, controller);
    final paragraph = selectableAt(controller, [0]);

    final fromStart = paragraph.getRectsInSelection(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 2),
    );
    expect(fromStart.first.left, closeTo(indent, 0.5));
    final inside = paragraph.getRectsInSelection(
      af.Selection.single(path: [0], startOffset: 1, endOffset: 2),
    );
    expect(inside.first.left, closeTo(indent + 16, 0.5));
    await tearDownEditor(tester, controller);
  });

  testWidgets('taps inside the indent land at the paragraph start', (
    tester,
  ) async {
    final controller = controllerOf([block('paragraph', '今天天气')]);
    await pump(tester, controller);
    final paragraph = selectableAt(controller, [0]);
    final glyph = tester.getRect(firstGlyph('今'));
    final y = glyph.center.dy;

    // 上游按“缩进 + 字”整框的中线（落在缩进里）判断，这里按字自己的中线。
    expect(paragraph.getPositionInOffset(Offset(glyph.left - 20, y)).offset, 0);
    expect(paragraph.getPositionInOffset(Offset(glyph.left + 4, y)).offset, 0);
    expect(paragraph.getPositionInOffset(Offset(glyph.right - 4, y)).offset, 1);
    expect(
      paragraph.getPositionInOffset(Offset(glyph.right + 20, y)).offset,
      greaterThan(1),
    );
    await tearDownEditor(tester, controller);
  });

  testWidgets('word selection keeps the first character with its word', (
    tester,
  ) async {
    final controller = controllerOf([block('paragraph', 'Hello world')]);
    await pump(tester, controller);
    final paragraph = selectableAt(controller, [0]);

    final word = paragraph.getWordBoundaryInPosition(
      af.Position(path: [0], offset: 2),
    )!;
    expect((word.start.offset, word.end.offset), (0, 5));
    final tapped = paragraph.getWordBoundaryInOffset(
      tester.getCenter(firstGlyph('H')),
    )!;
    expect((tapped.start.offset, tapped.end.offset), (0, 5));
    await tearDownEditor(tester, controller);
  });

  testWidgets('typography changes re-lay out the blocks of an open editor', (
    tester,
  ) async {
    final controller = controllerOf([
      block('paragraph', '今天'),
      block('paragraph', '明天'),
    ]);
    const flush = DiaryTextAppearance(typography: DiaryTypography());
    await pump(tester, controller, appearance: flush);
    double gap(Type type) {
      final blocks = find.byType(type);
      return tester.getTopLeft(blocks.at(1)).dy -
          tester.getTopLeft(blocks.at(0)).dy;
    }

    final flushGap = gap(af.ParagraphBlockComponentWidget);
    expect(firstGlyph('今'), findsNothing);

    // 上游只在挂载时装入块组件；排版变化要换上新的渲染器才看得到。
    await pump(
      tester,
      controller,
      appearance: const DiaryTextAppearance(
        typography: DiaryTypography(firstLineIndent: 2, paragraphSpacing: 20),
      ),
    );
    expect(firstGlyph('今'), findsOneWidget);
    expect(gap(DiaryParagraphBlock), closeTo(flushGap + 20, 0.5));

    await pump(tester, controller, appearance: flush);
    expect(firstGlyph('今'), findsNothing);
    expect(gap(af.ParagraphBlockComponentWidget), closeTo(flushGap, 0.5));
    expect(tester.takeException(), isNull);
    await tearDownEditor(tester, controller);
  });

  testWidgets('without an indent paragraphs use the upstream block', (
    tester,
  ) async {
    final controller = controllerOf([block('paragraph', '今天')]);
    await pump(
      tester,
      controller,
      appearance: const DiaryTextAppearance(typography: DiaryTypography()),
    );

    expect(find.byType(af.ParagraphBlockComponentWidget), findsOneWidget);
    expect(find.byType(DiaryParagraphBlock), findsNothing);
    expect(firstGlyph('今'), findsNothing);
    await tearDownEditor(tester, controller);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
