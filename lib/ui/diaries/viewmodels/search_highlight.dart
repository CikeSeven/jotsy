import 'package:flutter/material.dart';

/// 搜索结果的关键词高亮与摘录（纯函数）：结果卡片的标题 / 摘要与“命中的
/// 留言”共用。
///
/// 词由调用方经 `splitSearchTerms` 拆好（与数据库同一口径），这里只负责在
/// 文字里找出它们：不分大小写，多个词的命中区间合并后再标出。大小写转换会
/// 改变个别字符长度时（如土耳其语 İ）下标对不上，整段不标，宁可少标也不
/// 标错位置。

/// 命中处前面保留的字数：再往前的用省略号代替，关键词不会被挤出可见行。
const int searchExcerptLead = 16;

/// 高亮样式：主色容器底 + 对应前景色，任意卡片底色上都读得清。
TextStyle searchHighlightStyle(ColorScheme scheme) => TextStyle(
  color: scheme.onPrimaryContainer,
  backgroundColor: scheme.primaryContainer,
  fontWeight: FontWeight.w600,
);

/// [text] 里所有词的命中区间（按起点排序、重叠或相接的已合并）。
List<TextRange> searchMatchRanges(String text, List<String> terms) {
  if (text.isEmpty || terms.isEmpty) {
    return const <TextRange>[];
  }
  final lower = text.toLowerCase();
  if (lower.length != text.length) {
    return const <TextRange>[];
  }
  final ranges = <TextRange>[];
  for (final term in terms) {
    final needle = term.toLowerCase();
    if (needle.isEmpty || needle.length != term.length) {
      continue;
    }
    var from = 0;
    while (true) {
      final at = lower.indexOf(needle, from);
      if (at < 0) {
        break;
      }
      ranges.add(TextRange(start: at, end: at + needle.length));
      from = at + needle.length;
    }
  }
  if (ranges.isEmpty) {
    return const <TextRange>[];
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <TextRange>[ranges.first];
  for (final range in ranges.skip(1)) {
    final last = merged.last;
    if (range.start <= last.end) {
      if (range.end > last.end) {
        merged[merged.length - 1] = TextRange(
          start: last.start,
          end: range.end,
        );
      }
    } else {
      merged.add(range);
    }
  }
  return merged;
}

/// 把 [text] 拆成普通段与高亮段；没有命中时只有一段原文。
List<InlineSpan> searchHighlightSpans(
  String text,
  List<String> terms,
  TextStyle highlight,
) {
  final ranges = searchMatchRanges(text, terms);
  if (ranges.isEmpty) {
    return <InlineSpan>[TextSpan(text: text)];
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final range in ranges) {
    if (range.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, range.start)));
    }
    spans.add(
      TextSpan(text: text.substring(range.start, range.end), style: highlight),
    );
    cursor = range.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

/// 文字里第一个命中处的下标；没有命中（或无法可靠定位）时为 null。
int? firstSearchMatch(String text, List<String> terms) {
  final ranges = searchMatchRanges(text, terms);
  return ranges.isEmpty ? null : ranges.first.start;
}

/// 从第一个命中处前 [lead] 个字开始的摘录：命中在开头附近时原样返回，
/// 否则前面以“…”代替；[maxLength] 给出时截到这么长（不含省略号）。
///
/// 空白（含换行）先压成单个空格：摘录总是显示在一两行里。没有命中时为
/// null，调用方沿用原来的摘要。
String? searchExcerpt(
  String text,
  List<String> terms, {
  int lead = searchExcerptLead,
  int? maxLength,
}) {
  final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final at = firstSearchMatch(collapsed, terms);
  if (at == null) {
    return null;
  }
  final start = _codePointBoundary(collapsed, at > lead ? at - lead : 0);
  var shown = collapsed.substring(start);
  if (maxLength != null && shown.length > maxLength) {
    shown = shown.substring(0, _codePointBoundary(shown, maxLength));
  }
  return start > 0 ? '…$shown' : shown;
}

/// 不把代理对（emoji 等）从中间切开：落在低位代理上时往后挪一位。
int _codePointBoundary(String text, int index) {
  if (index <= 0 || index >= text.length) {
    return index;
  }
  final unit = text.codeUnitAt(index);
  return unit >= 0xDC00 && unit <= 0xDFFF ? index + 1 : index;
}
