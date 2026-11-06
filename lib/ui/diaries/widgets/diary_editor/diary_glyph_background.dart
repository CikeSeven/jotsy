import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'diary_editor_styles.dart';

/// 画在占位（[WidgetSpan]）里的字的背景色（高亮、行内代码底色）：与同一行
/// 其他字的背景一样高、一样深。用在首行缩进的段首字（`diary_first_line_indent.dart`）
/// 与上下标的字（`diary_script_spans.dart`）。
///
/// 外层段落按 [kDiaryTextHeightBehavior] 排版，每段文字的背景按它所在的行取
/// 上下沿：首行的上沿裁到字体本身的上沿（不带上方半个行距），末行的下沿
/// 裁到字体本身的下沿，其余带着半个行距——中间各行的背景就是整行高。占位里的
/// 字没法交给外层画：外层给占位画背景时用占位框（比字宽出一段缩进，或是只有
/// 字框高），所以占位的样式一律不带背景色（只画一次，半透明的高亮叠两次会
/// 变深），由占位按同样的规则自己补画。也不能交给占位里的 [RichText]：
/// Skia 排版“一段文字、没有空白、只有一种样式、一行放得下”时走单行快速路径，
/// 这条路径不裁背景，背景永远是整行高。
///
/// 补画的框以“字框”为准：占位里的字按原字号、[kDiaryTextHeightBehavior]
/// 单行排版（裁掉上下行距）的那个框，占位与它上沿对齐、基线与正文对齐。
/// 再按这个字在外层段落的哪一行（[_linePlacement]），把上沿 / 下沿换成整行
/// 排版时的行框位置。外层重新排版后一定重绘，占位作为它的子节点（不是重绘
/// 边界）随之重绘，换行变化时背景跟着变。
class DiaryGlyphLineBox {
  DiaryGlyphLineBox({
    required TextSpan glyph,
    required TextDirection textDirection,
  }) : box = TextPainter(
         text: glyph,
         textDirection: textDirection,
         textScaler: TextScaler.noScaling,
         textHeightBehavior: kDiaryTextHeightBehavior,
         maxLines: 1,
       ),
       _line = TextPainter(
         text: glyph,
         textDirection: textDirection,
         textScaler: TextScaler.noScaling,
         textHeightBehavior: _fullLine,
         maxLines: 1,
       );

  /// 整行排版：首行上方、末行下方都带行距，量出的就是中间一行的行框。
  static final TextHeightBehavior _fullLine = TextHeightBehavior(
    leadingDistribution: kDiaryTextHeightBehavior.leadingDistribution,
  );

  /// 字框：这个字按正文行高规则单行排版的结果（不带上下行距）。
  final TextPainter box;
  final TextPainter _line;

  set glyph(TextSpan value) {
    box.text = value;
    _line.text = value;
  }

  set textDirection(TextDirection value) {
    box.textDirection = value;
    _line.textDirection = value;
  }

  void layout() {
    box.layout();
    _line.layout();
  }

  /// 在 [host] 下面画背景：[offset] 为与字框上沿对齐的绘制原点，[width] 为
  /// 背景的宽度（字宽）。
  void paint(
    Canvas canvas,
    RenderBox host,
    Offset offset,
    double width,
    Color color,
  ) {
    if (color.a == 0 || width <= 0) return;
    final (:first, :last) = _linePlacement(host);
    final ascent = box.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final lineAscent = _line.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    // 行距小于字体本身高度时（行距 1.0 配中文字体）整行的行框比字框还矮，
    // 旁边的字也是这样画的，不取两者中较大的。
    final top = first ? 0.0 : ascent - lineAscent;
    final bottom = last ? box.height : ascent + _line.height - lineAscent;
    canvas.drawRect(
      Rect.fromLTRB(
        offset.dx,
        offset.dy + top,
        offset.dx + width,
        offset.dy + bottom,
      ),
      Paint()..color = color,
    );
  }

  void dispose() {
    box.dispose();
    _line.dispose();
  }

  /// [host] 在外层段落的首行 / 末行上。
  ///
  /// 首行与末行的范围取段落第一个、最后一个字的行框（[ui.BoxHeightStyle.max]，
  /// 整行高：零宽占位与上下标的占位框也按整行算），与 [host] 中心的纵坐标
  /// 比较。段尾是软换行时最后一行是空行，[host] 一定不在末行。找不到外层
  /// 段落（单独使用）时按只有一行处理，背景即字框。
  static ({bool first, bool last}) _linePlacement(RenderBox host) {
    final paragraph = _outerParagraph(host);
    if (paragraph == null || !paragraph.hasSize || !host.hasSize) {
      return (first: true, last: true);
    }
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    if (text.isEmpty) return (first: true, last: true);
    final center = MatrixUtils.transformPoint(
      host.getTransformTo(paragraph),
      host.size.center(Offset.zero),
    ).dy;
    // 段首是代理对（不缩进的段落以 emoji 开头）：半个代理对量不出字框。
    final head = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: _isHigh(text, 0) ? 2 : 1),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    var start = text.length - 1;
    if (start > 0 && _isLow(text, start)) start--;
    final tail = text.endsWith('\n')
        ? const <TextBox>[]
        : paragraph.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: text.length),
            boxHeightStyle: ui.BoxHeightStyle.max,
          );
    return (
      // 段首是软换行时首行是空行，量不出字框，[host] 也一定不在首行。
      first: head.isNotEmpty && center < head.first.bottom,
      last: tail.isNotEmpty && center > tail.last.top,
    );
  }

  /// 字所在的外层段落：向上找到第一个把自己当行内子节点的 [RenderParagraph]；
  /// 那个段落本身又在别的段落的占位里时（段首是上下标且首行缩进：上下标的字
  /// 在缩进占位的 [RichText] 里）继续往外找。占位与段落之间只隔几层
  /// （Padding、背景），[_inlineDepth] 层内找不到行内边界就停。
  static RenderParagraph? _outerParagraph(RenderObject host) {
    RenderParagraph? found;
    RenderObject? node = host;
    var budget = _inlineDepth;
    while (node != null && budget > 0) {
      final parent = node.parent;
      if (node.parentData is TextParentData && parent is RenderParagraph) {
        found = parent;
        budget = _inlineDepth;
      } else {
        budget--;
      }
      node = parent;
    }
    return found;
  }

  static const int _inlineDepth = 4;

  static bool _isHigh(String text, int index) {
    if (index >= text.length) return false;
    final unit = text.codeUnitAt(index);
    return unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length;
  }

  static bool _isLow(String text, int index) {
    final unit = text.codeUnitAt(index);
    return unit >= 0xDC00 && unit <= 0xDFFF;
  }
}

/// 首行缩进占位里那个字的背景：子节点是字本身（[RichText]，背景已换成透明），
/// 这里在它下面按 [DiaryGlyphLineBox] 的规则补画，只盖住字、不盖缩进。
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

  /// 段首的字（与子节点画的是同一个片段），用来量字框与行框。
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
/// 下面补画背景。子节点与 [DiaryGlyphLineBox.box] 是同一个字、同一套排版，
/// 上沿对齐。
class RenderDiaryFirstGlyphBackground extends RenderProxyBox {
  RenderDiaryFirstGlyphBackground({
    required this._color,
    required TextSpan glyph,
    required TextDirection textDirection,
  }) : _lineBox = DiaryGlyphLineBox(glyph: glyph, textDirection: textDirection);

  final DiaryGlyphLineBox _lineBox;

  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set glyph(TextSpan value) {
    if (_lineBox.box.text == value) return;
    _lineBox.glyph = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_lineBox.box.textDirection == value) return;
    _lineBox.textDirection = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    _lineBox.layout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!size.isEmpty) {
      _lineBox.paint(context.canvas, this, offset, size.width, _color);
    }
    super.paint(context, offset);
  }

  @override
  void dispose() {
    _lineBox.dispose();
    super.dispose();
  }
}
