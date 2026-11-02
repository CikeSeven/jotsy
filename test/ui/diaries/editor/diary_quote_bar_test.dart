import 'dart:convert';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_quote_bar.dart';

import '../../../support/expressive_test_theme.dart';

/// 引用竖条（`DiaryQuoteBar`）：相邻的引用连成一条，接缝处不留缝；与正文
/// 段落、嵌套层级不同的引用、竖条不在同一竖列的引用之间照旧断开；单独的
/// 引用仍是与文字齐平的圆头竖条；邻块变化（转为引用、只改对齐、撤销）时
/// 及时接上或断开。

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  if (children.isNotEmpty) 'children': children,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
};

String _json(List<Map<String, Object?>> children) => jsonEncode({
  'document': {'type': 'page', 'children': children},
});

af.Node _page(List<Map<String, Object?>> children) => af.Document.fromJson(
  jsonDecode(_json(children)) as Map<String, dynamic>,
).root;

DiaryEditorController _controller(
  List<Map<String, Object?>> children, {
  bool readOnly = false,
}) {
  final controller = DiaryEditorController.fromContent(
    _json(children),
    readOnly: readOnly,
  );
  addTearDown(controller.dispose);
  return controller;
}

final _boundaryKey = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  FocusNode? focusNode,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RepaintBoundary(
            key: _boundaryKey,
            child: DiaryEditor(
              controller: controller,
              appearance: const DiaryTextAppearance(
                typography: DiaryTypography(),
              ),
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 软键盘输入：在当前光标处插入 [text]（与提示块测试同一写法）。
Future<void> _type(WidgetTester tester, String text) async {
  final state = tester.testTextInput.editingState!;
  final value = state['text'] as String;
  final caret = state['selectionBase'] as int;
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: '${value.substring(0, caret)}$text${value.substring(caret)}',
      selection: TextSelection.collapsed(offset: caret + text.length),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _barOf(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is DiaryQuoteBar && widget.node.delta?.toPlainText() == text,
);

Finder _paintOf(String text) =>
    find.descendant(of: _barOf(text), matching: find.byType(CustomPaint));

DiaryQuoteBarPainter _painterOf(WidgetTester tester, String text) =>
    tester.widget<CustomPaint>(_paintOf(text)).painter! as DiaryQuoteBarPainter;

/// 竖条实际画出的纵向范围（全局坐标）：布局框加上相接一端多画的部分。
({double top, double bottom}) _span(WidgetTester tester, String text) {
  final rect = tester.getRect(_paintOf(text));
  final painter = _painterOf(tester, text);
  return (
    top: rect.top - (painter.extendTop ?? 0),
    bottom: rect.bottom + (painter.extendBottom ?? 0),
  );
}

/// 这行引用整块（含上下留白）的全局矩形。
Rect _blockRect(WidgetTester tester, String text) => tester.getRect(
  find.byWidgetPredicate(
    (widget) =>
        widget is af.QuoteBlockComponentWidget &&
        widget.node.delta?.toPlainText() == text,
  ),
);

List<String> _types(DiaryEditorController controller) => [
  for (final node in controller.document.root.children) node.type,
];

void main() {
  group('diaryQuoteBarsJoin', () {
    test('joins a quote with the quote right below it', () {
      final [a, b] = _page([
        _block('quote', 'a'),
        _block('quote', 'b'),
      ]).children;
      expect(diaryQuoteBarsJoin(a, b), isTrue);
      // 方向有序：上一块在前。
      expect(diaryQuoteBarsJoin(b, a), isFalse);
      expect(diaryQuoteBarsJoin(null, a), isFalse);
      expect(diaryQuoteBarsJoin(b, null), isFalse);
    });

    test('never joins across other blocks or nesting levels', () {
      final [a, p, b, item, c] = _page([
        _block('quote', 'a'),
        _block('paragraph', 'p'),
        _block('quote', 'b'),
        _block('bulleted_list', 'item', children: [_block('quote', 'nested')]),
        _block('quote', 'c'),
      ]).children;
      expect(diaryQuoteBarsJoin(a, p), isFalse);
      expect(diaryQuoteBarsJoin(p, b), isFalse);
      // 中间隔着段落的两行引用不算相邻。
      expect(diaryQuoteBarsJoin(a, b), isFalse);
      // 列表项里的引用与外面的引用不在同一层级。
      expect(diaryQuoteBarsJoin(item.children.single, c), isFalse);
      expect(diaryQuoteBarsJoin(item, c), isFalse);
    });

    test('joins only when both bars sit in the same column', () {
      bool joins(Map<String, Object?> upper, Map<String, Object?> lower) {
        final [a, b] = _page([
          _block('quote', 'a', data: upper),
          _block('quote', 'b', data: lower),
        ]).children;
        return diaryQuoteBarsJoin(a, b);
      }

      // 两端对齐只作用于文字，竖条仍在起始边。
      expect(joins({'align': 'justify'}, {}), isTrue);
      // 居中 / 靠右 / 靠左时竖条随文字宽度摆放，位置不一定对得上。
      for (final align in ['center', 'right', 'left']) {
        expect(joins({'align': align}, {}), isFalse, reason: align);
        expect(joins({}, {'align': align}), isFalse, reason: align);
        expect(joins({'align': align}, {'align': align}), isFalse);
      }
      const direction = af.blockComponentTextDirection;
      expect(joins({direction: 'rtl'}, {direction: 'rtl'}), isTrue);
      expect(joins({direction: 'rtl'}, {}), isFalse);
      // auto 随内容决定左右，不能保证同侧。
      expect(joins({direction: 'auto'}, {direction: 'auto'}), isFalse);
    });
  });

  testWidgets('consecutive quote lines draw one bar edge to edge', (
    tester,
  ) async {
    final controller = _controller([
      _block('paragraph', 'before'),
      _block('quote', 'a'),
      _block('quote', 'b'),
      _block('quote', 'c'),
      _block('paragraph', 'after'),
    ]);
    await _pump(tester, controller);

    final a = _span(tester, 'a');
    final b = _span(tester, 'b');
    final c = _span(tester, 'c');
    // 相接处都画到块的分界，上下两段正好对接。
    expect(a.bottom, moreOrLessEquals(_blockRect(tester, 'a').bottom));
    expect(b.top, moreOrLessEquals(_blockRect(tester, 'b').top));
    expect(b.bottom, moreOrLessEquals(c.top));
    expect(a.bottom, moreOrLessEquals(b.top));
    // 与正文段落交界的两端不伸进留白，仍与文字齐平。
    expect(a.top, tester.getRect(_paintOf('a')).top);
    expect(c.bottom, tester.getRect(_paintOf('c')).bottom);
    expect(_painterOf(tester, 'a').extendTop, isNull);
    expect(_painterOf(tester, 'c').extendBottom, isNull);

    // 中间一行两端方头，裁剪边正好在块的上下边缘。
    final size = tester.getSize(_paintOf('b'));
    final inset = _painterOf(tester, 'b').extendTop!;
    expect(
      tester.renderObject(_paintOf('b')),
      paints
        ..clipRect(rect: Rect.fromLTRB(-3, -inset, 6, size.height + inset))
        ..rrect(
          rrect: RRect.fromLTRBR(
            0,
            -inset - 1,
            3,
            size.height + inset + 1,
            Radius.zero,
          ),
        ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lone quote keeps its rounded bar flush with the text', (
    tester,
  ) async {
    final controller = _controller([
      _block('paragraph', 'before'),
      _block('quote', 'alone'),
      _block('paragraph', 'between'),
      _block('quote', 'centered', data: {'align': 'center'}),
      _block('quote', 'next'),
    ]);
    await _pump(tester, controller);

    for (final text in ['alone', 'centered', 'next']) {
      final painter = _painterOf(tester, text);
      expect(painter.extendTop, isNull, reason: text);
      expect(painter.extendBottom, isNull, reason: text);
    }
    // 与改版前同一画法：3dp 宽、1.5 圆角的竖条，不裁剪。
    final size = tester.getSize(_paintOf('alone'));
    expect(size.width, 3);
    final bar = tester.renderObject(_paintOf('alone'));
    expect(
      bar,
      paints..rrect(
        rrect: RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(1.5),
        ),
        color: Theme.of(
          tester.element(_barOf('alone')),
        ).colorScheme.primary.withValues(alpha: 0.55),
      ),
    );
    expect(bar, isNot(paints..clipRect()));
  });

  testWidgets('typing > on the line after a quote joins the bars', (
    tester,
  ) async {
    final controller = _controller([_block('quote', 'first')]);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    await _pump(tester, controller, focusNode: focus);
    focus.requestFocus();
    await tester.pumpAndSettle();

    // 引用里回车新起的是正文段落，竖条仍是单独的一条。
    await _type(tester, '\n');
    expect(_types(controller), ['quote', 'paragraph']);
    expect(_painterOf(tester, 'first').extendBottom, isNull);

    // 行首输入 `> ` 转为引用后，两行的竖条接上。
    await _type(tester, '>');
    await _type(tester, ' ');
    await _type(tester, 'second');
    expect(_types(controller), ['quote', 'quote']);
    expect(
      _span(tester, 'first').bottom,
      moreOrLessEquals(_span(tester, 'second').top),
    );
    expect(_painterOf(tester, 'first').extendBottom, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bars follow attribute-only changes of the neighbour', (
    tester,
  ) async {
    final controller = _controller([
      _block('quote', 'upper'),
      _block('quote', 'lower'),
    ]);
    await _pump(tester, controller);
    expect(_painterOf(tester, 'upper').extendBottom, isNotNull);

    // 只把下一行设为居中：上游只通知那一块，上一行的竖条也要断开。
    final lower = controller.document.nodeAtPath([1])!;
    controller.apply(
      controller.state.transaction..updateNode(lower, {'align': 'center'}),
    );
    await tester.pumpAndSettle();
    expect(_painterOf(tester, 'upper').extendBottom, isNull);
    expect(_painterOf(tester, 'lower').extendTop, isNull);

    controller.undo();
    await tester.pumpAndSettle();
    expect(_painterOf(tester, 'upper').extendBottom, isNotNull);
    expect(_painterOf(tester, 'lower').extendTop, isNotNull);

    // 下一行转回正文：上一行回到圆头。
    controller.select(af.Selection.collapsed(af.Position(path: [1])));
    controller.setBlockType('paragraph');
    await tester.pumpAndSettle();
    expect(_types(controller), ['quote', 'paragraph']);
    expect(_painterOf(tester, 'upper').extendBottom, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the joined bar has no seam at fractional block boundaries', (
    tester,
  ) async {
    final controller = _controller([
      _block('paragraph', 'before'),
      _block('quote', 'a'),
      _block('quote', 'b'),
      _block('quote', 'c'),
      _block('paragraph', 'after'),
    ], readOnly: true);
    await _pump(tester, controller);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final origin = boundary.localToGlobal(Offset.zero);
    final junctions = [
      _span(tester, 'a').bottom - origin.dy,
      _span(tester, 'b').bottom - origin.dy,
    ];
    double fraction(double value) => value - value.floorToDouble();
    // 取一个让分界落在像素中间的缩放：抗锯齿的接缝在这里最明显。
    final ratio = [1.0, 1.5, 2.0, 2.5, 2.625, 2.75, 3.0, 3.5].firstWhere(
      (ratio) => junctions.every((y) {
        final f = fraction(y * ratio);
        return f > 0.2 && f < 0.8;
      }),
    );

    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (data!, width);
    });
    final (data, width) = bytes!;
    final bar = tester.getRect(_paintOf('b'));
    final x = ((bar.center.dx - origin.dx) * ratio).floor();
    int pixel(int y) => data.getUint32((y * width + x) * 4);
    final reference = pixel(((bar.center.dy - origin.dy) * ratio).floor());
    final top = ((_span(tester, 'a').top - origin.dy) * ratio).ceil() + 2;
    final bottom =
        ((_span(tester, 'c').bottom - origin.dy) * ratio).floor() - 2;
    // 从第一行竖条的圆头之后到最后一行的圆头之前，这一列像素颜色一致。
    for (var y = top; y <= bottom; y++) {
      expect(
        pixel(y).toRadixString(16),
        reference.toRadixString(16),
        reason: 'row $y at ratio $ratio',
      );
    }
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
