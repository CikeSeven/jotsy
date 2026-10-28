import 'package:flutter/material.dart';

import 'diary_editor_styles.dart';

/// 段落首行缩进的行内片段改写，只由 [DiaryParagraphBlock] 调用。
///
/// Flutter 的文字排版没有首行缩进（CSS `text-indent`），段首又不能多塞一个
/// 占位：AppFlowy 按文档偏移直接查询 RenderParagraph，多一个码元会让光标、
/// 选区与点按整体错开一格。这里改为把段首第一个字（一个字素）换成同样长度
/// 的占位：第一个 [WidgetSpan] 先留出缩进、再画这个字，字素多出的码元
/// （emoji、组合字符）各补一个零宽占位，段落文字的偏移与文档一一对应。
/// 占位框因此比字宽出一段缩进，几何上的补偿（段首光标、选区、点按、取词）
/// 在块里完成。
///
/// [indent] 为未缩放的逻辑像素：占位里的内容与正文一起随字体缩放放大
/// （[WidgetSpan] 会按所在字号的缩放倍数整体缩放）。

/// 把根片段 [root] 的第一个字换成带缩进的占位；没有文字（空段落）或第一段
/// 不是普通文字片段时原样返回。
///
/// 上游也会拿单个行内片段调用块的片段装饰器（结果随后被编辑器的装饰器
/// 丢弃），只有根片段带 [TextSpan.children]，单个片段原样返回。
TextSpan diaryIndentFirstGlyph(
  TextSpan root, {
  required double indent,
  required TextDirection direction,
}) {
  final children = root.children;
  if (indent <= 0 || children == null || children.isEmpty) return root;
  final first = children.first;
  final text = first is TextSpan ? first.text : null;
  if (first is! TextSpan ||
      text == null ||
      text.isEmpty ||
      first.children != null) {
    return root;
  }
  final glyph = text.characters.first;
  TextSpan piece(String text) => TextSpan(
    text: text,
    style: first.style,
    recognizer: first.recognizer,
    mouseCursor: first.mouseCursor,
    locale: first.locale,
    spellOut: first.spellOut,
  );
  return TextSpan(
    style: root.style,
    children: <InlineSpan>[
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        style: first.style,
        child: _DiaryFirstGlyph(
          indent: indent,
          direction: direction,
          span: piece(glyph),
        ),
      ),
      for (var i = 1; i < glyph.length; i++)
        const WidgetSpan(child: SizedBox.shrink()),
      if (glyph.length < text.length) piece(text.substring(glyph.length)),
      ...children.skip(1),
    ],
  );
}

/// 空段落的占位提示（“开始记录…”、`/` 命令提示）同样缩进：与之后输入的
/// 第一个字对齐。也按段首的字改写而不是在前面垫一段空白：段首光标取自
/// 占位提示的第一个占位框，零高度的空白会让光标掉到行底。
TextSpan diaryIndentPlaceholder(
  TextSpan placeholder, {
  required double indent,
  required TextDirection direction,
}) {
  if (placeholder.children != null) return placeholder;
  return diaryIndentFirstGlyph(
    TextSpan(
      style: placeholder.style,
      children: <InlineSpan>[
        TextSpan(text: placeholder.text, style: placeholder.style),
      ],
    ),
    indent: indent,
    direction: direction,
  );
}

/// 段首的字：缩进 + 字本身，按基线与正文对齐。
///
/// 字的样式取自原片段（字体、字号、颜色、行内格式都在里面），行高规则与
/// 正文一致，首行高度不因换成占位而变化；缩放交给外层占位，这里不再缩放。
class _DiaryFirstGlyph extends StatelessWidget {
  const _DiaryFirstGlyph({
    required this.indent,
    required this.direction,
    required this.span,
  });

  final double indent;
  final TextDirection direction;
  final TextSpan span;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: direction,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: indent),
        child: RichText(
          text: span,
          textDirection: direction,
          textScaler: TextScaler.noScaling,
          textHeightBehavior: kDiaryTextHeightBehavior,
          softWrap: false,
          maxLines: 1,
        ),
      ),
    );
  }
}
