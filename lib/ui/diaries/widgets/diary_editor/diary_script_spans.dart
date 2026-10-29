import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/diary_text_style_options.dart';
import 'diary_editor_styles.dart';

/// 正文上标 / 下标（行内属性 `script`）的渲染，只由 `diaryEditorSpanDecorator`
/// 调用；代码块不经过这里。
///
/// Flutter 的文字样式没有基线位移，只能把字画在占位（[WidgetSpan]）里再上下
/// 挪。难点是 AppFlowy 直接按文档偏移查询 RenderParagraph（光标、选区、点按、
/// 取词），一个占位只占一个码元，所以：
/// - 只有“单个码元、不是空白”的字素各换成一个占位（[DiaryScriptGlyph]），
///   文字偏移与文档一一对应；
/// - 多码元的字素（emoji、组合字符）保留为文字，只缩小、不上下挪：给它补零宽
///   占位虽能凑齐码元，点按却会落到字素中间（实测各种补位方式都会返回中间
///   偏移），之后的输入会把代理对拆开；
/// - 空白（含换行）保留为文字：占位不参与按空格换行与两端对齐。
///
/// 占位框的高度与基线取“这个字按原字号排版”的结果（与正文同一行高规则），
/// 字本身按 [DiaryScript.scale] 缩小后在框里上移 / 下移，所以夹着上下标的
/// 一行不变高，光标在上下标旁也是整行高。
///
/// 块级样式（引用的次要色、已勾选待办的划线、标题字号）由块在整段片段上
/// 再叠一层，叠不进占位里的 widget：调用方必须传入叠好块样式的 [style]。

/// 把一段上标 / 下标文字 [text] 改写成逐字的占位。
///
/// - [style]：这段文字最终的样式（原字号，含块样式与 `size` 字号档位），
///   占位里的字按它缩小绘制；
/// - [containerStyle]：外层片段的样式（块在整段上叠样式时也作用在它与留作
///   文字的部分上）；
/// - [recognizer] / [mouseCursor]：链接的点按与指针，逐字带上。
TextSpan diaryScriptSpan(
  String text, {
  required DiaryScript script,
  required TextStyle style,
  TextStyle? containerStyle,
  GestureRecognizer? recognizer,
  MouseCursor mouseCursor = MouseCursor.defer,
}) {
  final fontSize = style.fontSize ?? kDefaultFontSize;
  final small = TextStyle(fontSize: fontSize * DiaryScript.scale);
  final children = <InlineSpan>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    children.add(
      TextSpan(
        text: plain.toString(),
        style: small,
        recognizer: recognizer,
        mouseCursor: mouseCursor,
      ),
    );
    plain.clear();
  }

  for (final grapheme in text.characters) {
    if (!_drawnAsGlyph(grapheme)) {
      plain.write(grapheme);
      continue;
    }
    flush();
    children.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        // 外层按这个字号算字体缩放倍数（占位里的内容整体随正文缩放）。
        style: style,
        child: DiaryScriptGlyph(
          glyph: grapheme,
          style: style,
          script: script,
          recognizer: recognizer,
          mouseCursor: mouseCursor,
        ),
      ),
    );
  }
  flush();
  return TextSpan(style: containerStyle, children: children);
}

/// 只有一个码元、不是空白、也不是单独的代理码元的字素才画进占位。
bool _drawnAsGlyph(String grapheme) {
  if (grapheme.length != 1) return false;
  final unit = grapheme.codeUnitAt(0);
  if (unit >= 0xD800 && unit <= 0xDFFF) return false;
  return grapheme.trim().isNotEmpty;
}

/// 一个上标 / 下标字：占位框为这个字按原字号排版的高度与基线，字按
/// [DiaryScript.scale] 缩小、基线按 [DiaryScript.baselineShift] 上下挪。
///
/// 背景色（高亮）铺满占位框，与两旁正文的高亮连成一片；字的其余样式（颜色、
/// 粗斜体、下划线、删除线）随缩小的字一起画。链接的点按交给字自己的
/// [RichText]（与普通文字一样由片段的 [recognizer] 处理）。字体缩放交给外层
/// 占位（[WidgetSpan] 按所在字号整体缩放），这里一律不缩放。
class DiaryScriptGlyph extends StatelessWidget {
  const DiaryScriptGlyph({
    super.key,
    required this.glyph,
    required this.style,
    required this.script,
    this.recognizer,
    this.mouseCursor = MouseCursor.defer,
  });

  /// 一个字素，只有一个码元。
  final String glyph;

  /// 原字号的样式（含背景色）。
  final TextStyle style;
  final DiaryScript script;
  final GestureRecognizer? recognizer;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final fontSize = style.fontSize ?? kDefaultFontSize;
    final background = style.backgroundColor;
    return _DiaryScriptGlyphBox(
      reference: TextSpan(text: glyph, style: style),
      shift: fontSize * script.baselineShift,
      background: background,
      textDirection: direction,
      child: RichText(
        text: TextSpan(
          text: glyph,
          // 背景由占位框铺满，字自己不再画一块更矮的底。
          style: style.copyWith(
            fontSize: fontSize * DiaryScript.scale,
            backgroundColor: background == null
                ? null
                : const Color(0x00000000),
          ),
          recognizer: recognizer,
          mouseCursor: mouseCursor,
        ),
        textDirection: direction,
        textScaler: TextScaler.noScaling,
        textHeightBehavior: kDiaryTextHeightBehavior,
        softWrap: false,
        maxLines: 1,
      ),
    );
  }
}

class _DiaryScriptGlyphBox extends SingleChildRenderObjectWidget {
  const _DiaryScriptGlyphBox({
    required this.reference,
    required this.shift,
    required this.background,
    required this.textDirection,
    required super.child,
  });

  final TextSpan reference;
  final double shift;
  final Color? background;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDiaryScriptGlyph(
        reference: reference,
        shift: shift,
        background: background,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDiaryScriptGlyph renderObject,
  ) {
    renderObject
      ..reference = reference
      ..shift = shift
      ..background = background
      ..textDirection = textDirection;
  }
}

/// 尺寸：宽为缩小后的字宽，高与基线取 [reference]（原字号的同一个字）单行
/// 排版的结果。单行排版按正文的行高规则不加行距（[kDiaryTextHeightBehavior]），
/// 与段落首行、末行的文字一样高，不会把所在行撑高。
class _RenderDiaryScriptGlyph extends RenderShiftedBox {
  _RenderDiaryScriptGlyph({
    required TextSpan reference,
    required this._shift,
    required this._background,
    required TextDirection textDirection,
  }) : _reference = TextPainter(
         text: reference,
         textDirection: textDirection,
         textScaler: TextScaler.noScaling,
         textHeightBehavior: kDiaryTextHeightBehavior,
         maxLines: 1,
       ),
       super(null);

  final TextPainter _reference;

  set reference(TextSpan value) {
    if (_reference.text == value) return;
    _reference.text = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_reference.textDirection == value) return;
    _reference.textDirection = value;
    markNeedsLayout();
  }

  double _shift;
  set shift(double value) {
    if (_shift == value) return;
    _shift = value;
    markNeedsLayout();
  }

  Color? _background;
  set background(Color? value) {
    if (_background == value) return;
    _background = value;
    markNeedsPaint();
  }

  TextPainter get _laidOutReference => _reference..layout();

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(double.infinity) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(double.infinity) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => _laidOutReference.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _laidOutReference.height;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width =
        child?.getDryLayout(_childConstraints(constraints)).width ?? 0;
    return constraints.constrain(Size(width, _laidOutReference.height));
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _laidOutReference.computeDistanceToActualBaseline(baseline);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _laidOutReference.computeDistanceToActualBaseline(baseline);

  @override
  void performLayout() {
    final reference = _laidOutReference;
    final baseline = reference.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, reference.height));
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(Size(child.size.width, reference.height));
    final childBaseline =
        child.getDistanceToBaseline(TextBaseline.alphabetic) ??
        child.size.height;
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      baseline - _shift - childBaseline,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final background = _background;
    if (background != null && background.a > 0) {
      context.canvas.drawRect(offset & size, Paint()..color = background);
    }
    super.paint(context, offset);
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }
}
