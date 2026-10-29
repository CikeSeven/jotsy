import 'dart:convert';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_text_style_options.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_paragraph_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_script_spans.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_body.dart';

import '../../../support/expressive_test_theme.dart';

/// 上标 / 下标的渲染：逐字换成占位后，光标、选区、点按、输入（含组字）与
/// 删除仍按文档偏移工作，所在行不变高。

Map<String, Object?> _block(
  String type,
  List<Map<String, Object?>> ops, {
  Map<String, Object?> data = const {},
}) => {
  'type': type,
  'data': {'delta': ops, ...data},
};

Map<String, Object?> _op(String text, [Map<String, Object?>? attributes]) => {
  'insert': text,
  'attributes': ?attributes,
};

const _sup = {'script': 'super'};
const _sub = {'script': 'sub'};

DiaryEditorController _document(
  List<Map<String, Object?>> blocks, {
  bool readOnly = false,
}) => DiaryEditorController.fromContent(
  jsonEncode({
    'document': {'type': 'page', 'children': blocks},
  }),
  readOnly: readOnly,
);

Widget _app(Widget child) => ProviderScope(
  overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
  child: MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    locale: const Locale('zh'),
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      af.AppFlowyEditorLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  FocusNode? focusNode,
  DiaryTypography typography = const DiaryTypography(),
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      DiaryEditor(
        controller: controller,
        appearance: DiaryTextAppearance(typography: typography),
        focusNode: focusNode,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tearDown(
  WidgetTester tester,
  DiaryEditorController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  await tester.pump(const Duration(milliseconds: 500));
}

af.SelectableMixin _selectable(
  DiaryEditorController controller,
  List<int> path,
) => controller.state.getNodeAtPath(path)!.selectable!;

/// 块 [path] 里偏移 [offset] 处的光标框（屏幕坐标）。
Rect _caret(DiaryEditorController controller, List<int> path, int offset) {
  final selectable = _selectable(controller, path);
  return selectable.transformRectToGlobal(
    selectable.getCursorRectInPosition(
      af.Position(path: path, offset: offset),
    )!,
  );
}

/// 显示块 [path] 文字的 RenderParagraph（不含占位提示）。
RenderParagraph _paragraph(
  WidgetTester tester,
  DiaryEditorController controller,
  List<int> path,
) {
  final length = controller.document.nodeAtPath(path)!.delta!.length;
  final block = find.byKey(controller.document.nodeAtPath(path)!.key);
  return tester
      .renderObjectList<RenderParagraph>(
        find.descendant(of: block, matching: find.byType(RichText)),
      )
      .firstWhere((p) => p.text.toPlainText().length == length);
}

List<Map<String, Object?>> _ops(DiaryEditorController controller, int index) =>
    [
      for (final op in controller.document.nodeAtPath([index])!.delta!)
        {'insert': (op as af.TextInsert).text, 'attributes': ?op.attributes},
    ];

/// 软键盘输入：把编辑值改为 [value]（[composing] 为组字区间）。
Future<void> _imeUpdate(
  WidgetTester tester,
  String Function(String text, int caret) edit, {
  required int caretDelta,
  TextRange Function(int caret)? composing,
}) async {
  final state = tester.testTextInput.editingState!;
  final text = state['text'] as String;
  final caret = state['selectionBase'] as int;
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: edit(text, caret),
      selection: TextSelection.collapsed(offset: caret + caretDelta),
      composing: composing?.call(caret) ?? TextRange.empty,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) => _imeUpdate(
  tester,
  (value, caret) =>
      '${value.substring(0, caret)}$text${value.substring(caret)}',
  caretDelta: text.length,
);

Future<FocusNode> _focusAt(
  WidgetTester tester,
  DiaryEditorController controller,
  int offset,
) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  controller.select(af.Selection.collapsed(af.Position(path: [0])));
  await _pump(tester, controller, focusNode: focus);
  focus.requestFocus();
  await tester.pumpAndSettle();
  controller.select(
    af.Selection.collapsed(af.Position(path: [0], offset: offset)),
  );
  await tester.pumpAndSettle();
  return focus;
}

void main() {
  // 'ab' + 上标 'cd' + 'ef'：偏移 2–4 是上标。
  List<Map<String, Object?>> mixed() => [
    _block('paragraph', [_op('ab'), _op('cd', _sup), _op('ef')]),
  ];

  testWidgets('script characters render as glyph placeholders, one code unit '
      'each, raised or lowered at a smaller size', (tester) async {
    final controller = _document([
      _block('paragraph', [_op('x'), _op('2', _sup), _op('H'), _op('2', _sub)]),
    ]);
    await _pump(tester, controller);

    final paragraph = _paragraph(tester, controller, [0]);
    expect(paragraph.text.toPlainText(), 'x\uFFFCH\uFFFC');
    final glyphs = tester
        .widgetList<DiaryScriptGlyph>(find.byType(DiaryScriptGlyph))
        .toList();
    expect(glyphs.map((g) => g.script), [
      DiaryScript.superscript,
      DiaryScript.subscript,
    ]);

    // 字缩小到 0.7 倍；上标的字在基线之上，下标的字低于正文基线。
    final body = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single
        .toRect()
        .shift(paragraph.localToGlobal(Offset.zero));
    final sup = tester.getRect(
      find.descendant(
        of: find.byWidget(glyphs.first),
        matching: find.byType(RichText),
      ),
    );
    final sub = tester.getRect(
      find.descendant(
        of: find.byWidget(glyphs.last),
        matching: find.byType(RichText),
      ),
    );
    expect(sup.height, closeTo(body.height * DiaryScript.scale, 0.5));
    expect(sup.bottom, lessThan(body.bottom - 3));
    expect(sub.bottom, greaterThan(body.bottom + 1));
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('the caret moves one superscript character at a time', (
    tester,
  ) async {
    final controller = _document(mixed());
    await _focusAt(tester, controller, 2);

    // 每个偏移都有自己的光标位置，从左到右依次排开。
    final carets = [
      for (var i = 0; i <= 6; i++) _caret(controller, [0], i),
    ];
    for (var i = 1; i <= 6; i++) {
      expect(carets[i].left, greaterThan(carets[i - 1].left + 4), reason: '$i');
    }
    // 光标可以停在两个上标字之间，方向键逐字移动。
    expect(controller.selection!.end.offset, 2);
    for (final expected in [3, 4, 5]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.selection!.end.offset, expected);
    }
    for (final expected in [4, 3, 2, 1]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.selection!.end.offset, expected);
    }
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('tapping between superscript characters places the caret there', (
    tester,
  ) async {
    final controller = _document(mixed());
    await _pump(tester, controller);
    final selectable = _selectable(controller, [0]);
    for (var i = 0; i <= 6; i++) {
      final caret = _caret(controller, [0], i);
      expect(
        selectable.getPositionInOffset(caret.center).offset,
        i,
        reason: 'offset $i',
      );
    }
    await _tearDown(tester, controller);
  });

  testWidgets('selecting from normal into superscript text highlights exactly '
      'that range', (tester) async {
    final controller = _document(mixed());
    await _pump(tester, controller);
    final selectable = _selectable(controller, [0]);

    // 拖选：从 'b' 前到第一个上标字之后。
    final range = selectable.getSelectionInRange(
      _caret(controller, [0], 1).center,
      _caret(controller, [0], 3).center,
    );
    expect(range.normalized.startIndex, 1);
    expect(range.normalized.endIndex, 3);

    final rects = selectable
        .getRectsInSelection(range)
        .map(selectable.transformRectToGlobal)
        .toList();
    final union = rects.reduce((a, b) => a.expandToInclude(b));
    expect(union.left, closeTo(_caret(controller, [0], 1).center.dx, 0.5));
    expect(union.right, closeTo(_caret(controller, [0], 3).center.dx, 0.5));
    await _tearDown(tester, controller);
  });

  testWidgets('typing inside and right after a superscript run stays '
      'superscript', (tester) async {
    final controller = _document(mixed());
    await _focusAt(tester, controller, 3);

    await _type(tester, 'X');
    expect(_ops(controller, 0), [_op('ab'), _op('cXd', _sup), _op('ef')]);
    expect(controller.selection!.end.offset, 4);

    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    await tester.pumpAndSettle();
    await _type(tester, 'Y');
    expect(_ops(controller, 0), [_op('ab'), _op('cXdY', _sup), _op('ef')]);
    // 渲染文字仍与文档逐个码元对应。
    expect(
      _paragraph(tester, controller, [0]).text.toPlainText(),
      'ab\uFFFC\uFFFC\uFFFC\uFFFCef',
    );
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('deleting inside a superscript run removes one character', (
    tester,
  ) async {
    final controller = _document(mixed());
    await _focusAt(tester, controller, 4);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_ops(controller, 0), [_op('ab'), _op('c', _sup), _op('ef')]);
    expect(controller.selection!.end.offset, 3);

    // 软键盘删除跨普通与上标文字的选区。
    controller.select(
      af.Selection.single(path: [0], startOffset: 1, endOffset: 3),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_ops(controller, 0), [_op('aef')]);
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('IME composing inside a superscript run commits cleanly', (
    tester,
  ) async {
    final controller = _document(mixed());
    await _focusAt(tester, controller, 3);

    // 拼音组字：n → ni → 提交“你”。编辑器不会把组字中的值回写给输入法，
    // 每一步都在上一步发出的值上改。
    final state = tester.testTextInput.editingState!;
    final text = state['text'] as String;
    final caret = state['selectionBase'] as int;
    final head = text.substring(0, caret);
    final tail = text.substring(caret);
    Future<void> send(String middle, {required bool composing}) async {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$head$middle$tail',
          selection: TextSelection.collapsed(offset: caret + middle.length),
          composing: composing
              ? TextRange(start: caret, end: caret + middle.length)
              : TextRange.empty,
        ),
      );
      await tester.pumpAndSettle();
    }

    await send('n', composing: true);
    await send('ni', composing: true);
    // 组字中的拼音同样是上标，渲染仍逐码元对应。
    expect(_ops(controller, 0), [_op('ab'), _op('cnid', _sup), _op('ef')]);
    expect(
      _paragraph(tester, controller, [0]).text.toPlainText(),
      'ab\uFFFC\uFFFC\uFFFC\uFFFCef',
    );
    await send('你', composing: false);
    expect(_ops(controller, 0), [_op('ab'), _op('c你d', _sup), _op('ef')]);
    expect(controller.selection!.end.offset, 4);
    expect(
      _paragraph(tester, controller, [0]).text.toPlainText(),
      'ab\uFFFC\uFFFC\uFFFCef',
    );
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('lines with superscript or subscript are exactly as tall as '
      'plain lines', (tester) async {
    // 每段折成多行：上下标分别落在首行、中间行与末行；最后一段整段上标。
    final words = List.generate(24, (i) => 'w$i').join(' ');
    List<Map<String, Object?>> scripted(Map<String, Object?> script) => [
      _op(words.substring(0, 3)),
      _op(words.substring(3, 6), script),
      _op(words.substring(6, 40)),
      _op(words.substring(40, 44), script),
      _op(words.substring(44, words.length - 3)),
      _op(words.substring(words.length - 3), script),
    ];
    final controller = _document([
      _block('paragraph', [_op(words)]),
      _block('paragraph', scripted(_sup)),
      _block('paragraph', scripted(_sub)),
      _block('heading', [_op('Title')], data: {'level': 2}),
      _block('heading', [_op('Ti'), _op('tle', _sup)], data: {'level': 2}),
      _block('paragraph', [_op('short')]),
      _block('paragraph', [_op('short', _sup)]),
      _block('bulleted_list', [_op('item')]),
      _block('bulleted_list', [_op('it'), _op('em', _sub)]),
    ]);
    await _pump(tester, controller);

    double height(int index) =>
        _paragraph(tester, controller, [index]).size.height;
    final plain = _paragraph(tester, controller, [0]);
    expect(
      plain
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: words.length),
            boxHeightStyle: ui.BoxHeightStyle.max,
          )
          .map((b) => b.top)
          .toSet()
          .length,
      greaterThan(2),
      reason: 'the sample paragraph must wrap into several lines',
    );
    expect(height(1), height(0));
    expect(height(2), height(0));
    expect(height(4), height(3));
    expect(height(6), height(5));
    expect(height(8), height(7));
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('emoji and spaces in a script run keep their code units as '
      'text', (tester) async {
    final controller = _document([
      _block('paragraph', [_op('a'), _op('b 😀c', _sup), _op('d')]),
    ]);
    await _pump(tester, controller);
    final paragraph = _paragraph(tester, controller, [0]);
    // 'b'、'c' 是占位；空格与 emoji（两个码元）留作文字。
    expect(paragraph.text.toPlainText(), 'a\uFFFC 😀\uFFFCd');
    expect(find.byType(DiaryScriptGlyph), findsNWidgets(2));

    // 点按任何位置都不会落到 emoji 的两个码元之间。
    final selectable = _selectable(controller, [0]);
    final line = _caret(controller, [0], 0);
    final end = _caret(controller, [0], 7).right;
    for (var x = line.left; x <= end + 4; x += 0.5) {
      final offset = selectable
          .getPositionInOffset(Offset(x, line.center.dy))
          .offset;
      expect(offset, isNot(4), reason: 'x=$x');
    }
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('the glyph keeps colour, background, bold, link, size and the '
      'block style', (tester) async {
    final controller = _document([
      _block('paragraph', [
        _op('n'),
        _op('1', {
          ..._sup,
          'bold': true,
          'font_color': '#FFE53935',
          'bg_color': '#4DFFC107',
          'size': 'large',
        }),
        _op('2', {..._sup, 'href': 'https://example.com'}),
      ]),
      _block('quote', [_op('q'), _op('3', _sup)]),
      _block('code', [_op('x'), _op('4', _sup)]),
    ]);
    await _pump(tester, controller);

    final glyphs = {
      for (final glyph in tester.widgetList<DiaryScriptGlyph>(
        find.byType(DiaryScriptGlyph),
      ))
        glyph.glyph: glyph,
    };
    // 代码块按原文显示，不画上下标。
    expect(glyphs.keys, unorderedEquals(['1', '2', '3']));
    final styled = glyphs['1']!.style;
    expect(styled.fontWeight, FontWeight.bold);
    expect(styled.color, const Color(0xFFE53935));
    expect(styled.backgroundColor, const Color(0x4DFFC107));
    expect(styled.fontSize, closeTo(16 * DiaryFontSize.large.scale, 0.01));
    expect(glyphs['2']!.recognizer, isNotNull);
    final quote = Theme.of(
      tester.element(find.byType(DiaryEditor)),
    ).colorScheme.onSurfaceVariant;
    expect(glyphs['3']!.style.color, quote);
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('a superscript first character keeps the first-line indent', (
    tester,
  ) async {
    final controller = _document([
      _block('paragraph', [_op('2', _sup), _op('nd')]),
    ]);
    await _pump(
      tester,
      controller,
      typography: const DiaryTypography(firstLineIndent: 2),
    );
    final blockLeft = tester
        .getTopLeft(find.byType(DiaryParagraphBlock).first)
        .dx;
    final glyph = find.descendant(
      of: find.byType(DiaryScriptGlyph),
      matching: find.byType(RichText),
    );
    expect(tester.getTopLeft(glyph).dx - blockLeft, closeTo(32, 0.5));
    expect(_paragraph(tester, controller, [0]).text.toPlainText(), '\uFFFCnd');
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });

  testWidgets('the read-only preview lays out superscript and selects across '
      'it', (tester) async {
    final controller = _document(mixed(), readOnly: true);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: DiaryPreviewBody(
            controller: controller,
            appearance: const DiaryTextAppearance(
              typography: DiaryTypography(),
            ),
            textSelection: true,
            onOpenImage: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryScriptGlyph), findsNWidgets(2));

    // 只读正文与编辑态共用上游的选区服务：手势按屏幕坐标经
    // getSelectionInRange 换算选区（从 'b' 前拖到两个上标字之间）。
    final range = _selectable(controller, [0]).getSelectionInRange(
      _caret(controller, [0], 1).center,
      _caret(controller, [0], 3).center,
    );
    controller.select(range);
    await tester.pumpAndSettle();
    final dragged = controller.state.selection!.normalized;
    expect((dragged.startIndex, dragged.endIndex), (1, 3));

    final selectable = _selectable(controller, [0]);
    final union = selectable
        .getRectsInSelection(dragged)
        .map(selectable.transformRectToGlobal)
        .reduce((a, b) => a.expandToInclude(b));
    expect(union.left, closeTo(_caret(controller, [0], 1).center.dx, 0.5));
    expect(union.right, closeTo(_caret(controller, [0], 3).center.dx, 0.5));
    expect(controller.revision, 0);
    expect(tester.takeException(), isNull);
    await _tearDown(tester, controller);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
