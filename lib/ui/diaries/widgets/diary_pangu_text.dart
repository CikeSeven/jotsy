import 'package:flutter/material.dart';

import '../../../utils/pangu_spacing.dart';

/// 日记文本的盘古之白 Flutter 渲染工具：
/// - [splitTextSpanWithPanguGaps]：按整段文本的盘古边界切分单个 [TextSpan]
///   并追加 `letterSpacing`，码元数与原文 1:1 对应（编辑器与只读文本共用）；
/// - [buildPanguTextSpan]：把普通文字或已切分高亮的 [InlineSpan] 列表叠加
///   盘古之白（跨高亮边界同样生效）；
/// - [DiaryPanguText]：只读文字组件，关闭时退回普通 [Text]；
/// - [DiaryPanguTextEditingController]：支持盘古之白的标题输入框控制器，
///   输入法组字期间自动跳过组字区间以免来回抖动。

/// 把 [span] 中落在 [allGaps]（整段文本的 UTF-16 盘古边界列表，按起点升序）
/// 内的字符拆出子片段，追加 [gapExtent] 的 `letterSpacing`。
///
/// - [spanStart] 为 [span] 在整段文本中的起始 UTF-16 偏移；
/// - [baseLetterSpacing] 在 [span.style] 未设 `letterSpacing` 时用作基距；
/// - 没有任何边界落在本片段内时返回 `null`，调用方可零开销复用原 [span]。
List<TextSpan>? splitTextSpanWithPanguGaps(
  TextSpan span, {
  required int spanStart,
  required List<(int, int)> allGaps,
  required double gapExtent,
  double baseLetterSpacing = 0,
}) {
  final text = span.text;
  if (text == null || text.isEmpty || allGaps.isEmpty || gapExtent <= 0) {
    return null;
  }
  final spanEnd = spanStart + text.length;
  var idx = _firstGapAtOrAfter(allGaps, spanStart);
  if (idx >= allGaps.length || allGaps[idx].$1 >= spanEnd) {
    return null;
  }

  final style = span.style;
  final widened = (style ?? const TextStyle()).copyWith(
    letterSpacing: (style?.letterSpacing ?? baseLetterSpacing) + gapExtent,
  );
  TextSpan piece(String value, TextStyle? pieceStyle) => TextSpan(
    text: value,
    style: pieceStyle,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
  );

  final out = <TextSpan>[];
  var cursor = spanStart;
  while (idx < allGaps.length) {
    final (rawStart, rawEnd) = allGaps[idx];
    if (rawStart >= spanEnd) {
      break;
    }
    final start = rawStart < spanStart ? spanStart : rawStart;
    var end = rawEnd > spanEnd ? spanEnd : rawEnd;
    if (start >= end) {
      idx++;
      continue;
    }
    // 相邻且连续需要加宽的字素合并进同一个子片段（例如 "r写3行" 中的 "r写3"），
    // SkParagraph 会给其中每个字素的尾部都加上同样的 letterSpacing。
    while (idx + 1 < allGaps.length &&
        allGaps[idx + 1].$1 == end &&
        allGaps[idx + 1].$2 <= spanEnd) {
      idx++;
      end = allGaps[idx].$2;
    }
    if (start > cursor) {
      out.add(
        piece(text.substring(cursor - spanStart, start - spanStart), style),
      );
    }
    out.add(piece(text.substring(start - spanStart, end - spanStart), widened));
    cursor = end;
    idx++;
  }
  if (out.isEmpty) {
    return null;
  }
  if (cursor < spanEnd) {
    out.add(piece(text.substring(cursor - spanStart), style));
  }
  return out;
}

/// 二分查找第一个 `end > offset` 的边界下标。
int _firstGapAtOrAfter(List<(int, int)> gaps, int offset) {
  var low = 0;
  var high = gaps.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (gaps[mid].$2 <= offset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// 为纯文本 [text]（或已切好高亮的 [spans]）构造带盘古之白渲染间距的 [TextSpan]。
///
/// [fallbackStyle] 提供缺省字号与字间距（例如合并了 `DefaultTextStyle` 的样式）；
/// 没有任何盘古边界时不拆分片段。
TextSpan buildPanguTextSpan(
  String text, {
  TextStyle? style,
  TextStyle? fallbackStyle,
  List<InlineSpan>? spans,
  int? excludeStart,
  int? excludeEnd,
}) {
  if (text.isEmpty) {
    return TextSpan(text: text, style: style);
  }
  final gaps = findPanguGapRanges(
    text,
    excludeStart: excludeStart,
    excludeEnd: excludeEnd,
  );
  if (gaps.isEmpty) {
    return spans == null
        ? TextSpan(text: text, style: style)
        : TextSpan(style: style, children: spans);
  }

  final resolved = fallbackStyle ?? style;
  final defaultFontSize = resolved?.fontSize ?? 14;
  final defaultTracking = resolved?.letterSpacing ?? 0;

  if (spans == null) {
    final pieces = splitTextSpanWithPanguGaps(
      TextSpan(text: text, style: style),
      spanStart: 0,
      allGaps: gaps,
      gapExtent: panguSpacingExtent(defaultFontSize),
      baseLetterSpacing: defaultTracking,
    );
    return pieces == null
        ? TextSpan(text: text, style: style)
        : TextSpan(style: style, children: pieces);
  }

  final out = <InlineSpan>[];
  var cursor = 0;
  for (final child in spans) {
    if (child is TextSpan && child.text != null && child.children == null) {
      final length = child.text!.length;
      final fontSize = child.style?.fontSize ?? defaultFontSize;
      final pieces = splitTextSpanWithPanguGaps(
        child,
        spanStart: cursor,
        allGaps: gaps,
        gapExtent: panguSpacingExtent(fontSize),
        baseLetterSpacing: defaultTracking,
      );
      if (pieces != null) {
        out.addAll(pieces);
      } else {
        out.add(child);
      }
      cursor += length;
    } else {
      out.add(child);
      cursor += child.toPlainText(includeSemanticsLabels: false).length;
    }
  }
  return TextSpan(style: style, children: out);
}

/// 日记只读文本：关闭 [panguSpacing] 且无 [spans] 时直接返回普通 [Text]，
/// 保证默认外观与改版前逐项相同。
class DiaryPanguText extends StatelessWidget {
  const DiaryPanguText(
    this.text, {
    super.key,
    required this.panguSpacing,
    this.style,
    this.spans,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final bool panguSpacing;
  final TextStyle? style;

  /// 已切好的行内高亮片段（如搜索结果）；为 null 时整段按纯文本渲染。
  final List<InlineSpan>? spans;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final spans = this.spans;
    if (!panguSpacing) {
      if (spans == null) {
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      }
      return Text.rich(
        TextSpan(children: spans),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final fallback = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      buildPanguTextSpan(
        text,
        style: null,
        fallbackStyle: fallback,
        spans: spans,
      ),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 支持盘古之白渲染间距的输入框控制器（日记标题、模板标题共用）。
///
/// 不改动输入的真实文本，仅在 [buildTextSpan] 中为中西文 / 中数字边界追加
/// `letterSpacing`；输入法组字期间自动跳过组字区间，避免输入拼音时文字来回抖动。
/// [panguSpacing] 只是渲染选项，不调用 `notifyListeners()`（免得被宿主当成
/// 用户改字而触发草稿保存）；宿主在监听排版变化重建 `TextField` 时直接同步它，
/// `EditableText.build` 随后会立刻按新值调用 [buildTextSpan]。
class DiaryPanguTextEditingController extends TextEditingController {
  DiaryPanguTextEditingController({super.text, this.panguSpacing = false});

  bool panguSpacing;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!panguSpacing || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final fallback = DefaultTextStyle.of(context).style.merge(style);
    final composingOutOfRange = !value.isComposingRangeValid || !withComposing;
    if (composingOutOfRange) {
      return buildPanguTextSpan(text, style: style, fallbackStyle: fallback);
    }

    final composing = value.composing;
    final composingStyle =
        style?.merge(const TextStyle(decoration: TextDecoration.underline)) ??
        const TextStyle(decoration: TextDecoration.underline);
    final children = <InlineSpan>[
      if (composing.start > 0) TextSpan(text: composing.textBefore(text)),
      TextSpan(style: composingStyle, text: composing.textInside(text)),
      if (composing.end < text.length)
        TextSpan(text: composing.textAfter(text)),
    ];
    return buildPanguTextSpan(
      text,
      style: style,
      fallbackStyle: fallback,
      spans: children,
      excludeStart: composing.start,
      excludeEnd: composing.end,
    );
  }
}
