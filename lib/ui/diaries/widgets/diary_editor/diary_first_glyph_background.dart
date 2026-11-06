import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'diary_editor_styles.dart';

/// 首行缩进占位里那个字的背景色（高亮、行内代码底色），与同一行其他字的背景
/// 一样高。只由 `diary_first_line_indent.dart` 的段首占位使用。
///
/// 为什么不让占位里的字自己画：Skia 排版“一段文字、没有空白、只有一种样式、
/// 一行放得下”时走单行快速路径，这条路径不按 [kDiaryTextHeightBehavior]
/// 裁背景，背景按整行行高画，上下各比字框多出半个行距；占位里恰好只有一个
/// 字，永远走这条路径，行距越大，段首的字的背景比旁边的字高得越多。外层段落
/// （段首有占位）走常规排版：首行背景的上沿裁到字体本身的上沿；段落只有一行
/// 时下沿也裁到字体本身，多于一行时下沿带着下方半个行距。这里按外层的规则补画：
/// - 上沿：子节点（占位里的字，排版时同样裁掉首行上方的行距、基线与正文对齐）
///   的上沿；
/// - 下沿：外层段落只有一行时为子节点的下沿，否则为这个字按行高排版、带
///   下方半个行距的下沿。
///
/// 外层是否多于一行在绘制时向外层 [RenderParagraph] 查询：外层重新排版后一定
/// 重绘，占位作为它的子节点（不是重绘边界）随之重绘，行数变化时背景跟着变。
class DiaryFirstGlyphBackground extends SingleChildRenderObjectWidget {
  const DiaryFirstGlyphBackground({
    super.key,
    required this.color,
    required this.glyph,
    required this.textDirection,
    required super.child,
  });

  /// 背景色。
  final Color color;

  /// 段首的字（与子节点画的是同一个片段），用来量带行距的下沿。
  final TextSpan glyph;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderDiaryFirstGlyphBackground(
        color: color,
        glyph: glyph,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDiaryFirstGlyphBackground renderObject,
  ) {
    renderObject
      ..color = color
      ..glyph = glyph
      ..textDirection = textDirection;
  }
}

/// [DiaryFirstGlyphBackground] 的渲染对象：尺寸与命中交给子节点，只在子节点
/// 下面补画背景。
class RenderDiaryFirstGlyphBackground extends RenderProxyBox {
  RenderDiaryFirstGlyphBackground({
    required this._color,
    required TextSpan glyph,
    required TextDirection textDirection,
  }) : _spaced = TextPainter(
         text: glyph,
         textDirection: textDirection,
         textScaler: TextScaler.noScaling,
         textHeightBehavior: _keepLastDescent,
         maxLines: 1,
       );

  /// 与正文同一行高规则，只是保留末行下方的行距：量出的高度即“首行上沿到
  /// 这个字带下方半个行距的下沿”。
  static final TextHeightBehavior _keepLastDescent = TextHeightBehavior(
    applyHeightToFirstAscent: kDiaryTextHeightBehavior.applyHeightToFirstAscent,
    leadingDistribution: kDiaryTextHeightBehavior.leadingDistribution,
  );

  /// 判断“落在下一行”时容许的误差（逻辑像素）。
  static const double _lineTolerance = 0.5;

  final TextPainter _spaced;

  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set glyph(TextSpan value) {
    if (_spaced.text == value) return;
    _spaced.text = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_spaced.textDirection == value) return;
    _spaced.textDirection = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    _spaced.layout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_color.a > 0 && !size.isEmpty) {
      // 不取两者中较大的：行距小于字体本身高度时（行距 1.0 配中文字体），
      // 外层带行距的下沿比字框还短，旁边的字也是这样画的。
      final bottom = _paragraphHasMoreLines() ? _spaced.height : size.height;
      context.canvas.drawRect(
        offset & Size(size.width, bottom),
        Paint()..color = _color,
      );
    }
    super.paint(context, offset);
  }

  /// 外层段落是否多于一行：最后一个字所在行的行框顶不在首行之内。
  ///
  /// 行框取 [ui.BoxHeightStyle.max]（整行高）：零宽占位（emoji 段首字补的码元）
  /// 与上下标的占位框也按整行算，不会因为贴着行底被误认作下一行。段尾是软换行
  /// 时最后一行是空行、没有字可量，直接算多于一行。找不到外层段落（单独使用）
  /// 时按一行处理，背景即字框。
  bool _paragraphHasMoreLines() {
    var node = parent;
    while (node != null && node is! RenderParagraph) {
      node = node.parent;
    }
    if (node is! RenderParagraph || !node.hasSize) return false;
    final text = node.text.toPlainText(includeSemanticsLabels: false);
    if (text.isEmpty) return false;
    if (text.endsWith('\n')) return true;
    var start = text.length - 1;
    // 最后一个码元是代理对的后半：从前半开始量，半个代理对量不出字框。
    final last = text.codeUnitAt(start);
    if (start > 0 && last >= 0xDC00 && last <= 0xDFFF) start--;
    final first = node.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    final tail = node.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: text.length),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (first.isEmpty || tail.isEmpty) return false;
    return tail.last.top >= first.first.bottom - _lineTolerance;
  }

  @override
  void dispose() {
    _spaced.dispose();
    super.dispose();
  }
}
