import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../utils/pangu_spacing.dart';
import '../../models/diary_text_style_options.dart';
import '../diary_pangu_text.dart';

/// 正文编辑器的盘古之白行内片段装饰器，由 `DiaryEditor` 包在
/// `diaryEditorSpanDecorator` 外层、`diaryFindSpanDecorator` 内层。
///
/// - 输入：上游按 UTF-16 偏移给出的块、片段与样式；
/// - 输出：按整块纯文本盘古边界切分并追加 `letterSpacing` 的 [TextSpan]；
/// - 副作用：无；不修改文档 Delta，码元数与原文 1:1 对应，光标、选区、
///   点按、取词、查找替换与首行缩进（`diaryIndentFirstGlyph`）均不受影响。
///
/// 跳过规则：
/// - 代码块（`node.type == 'code'`）与行内代码（`code == true`）不追加
///   尾部间距，避免代码底色向右拖尾；行内代码左侧的普通中文仍可与它拉开间距；
/// - 上下标（`script`）是逐字 `WidgetSpan`，不参与左右两侧边界判定，避免
///   把注脚上标从文字旁推开。
af.TextSpanDecoratorForAttribute diaryPanguSpanDecorator({
  required bool enabled,
  required double fallbackFontSize,
  required double fallbackLetterSpacing,
  required af.TextSpanDecoratorForAttribute inner,
}) {
  if (!enabled) {
    return inner;
  }
  return (context, node, index, insert, before, after) {
    final decorated = inner(context, node, index, insert, before, after);
    if (decorated is! TextSpan ||
        node.type == 'code' ||
        insert.attributes?['code'] == true ||
        DiaryScript.fromAttribute(insert.attributes?[kDiaryInlineScript]) !=
            null ||
        decorated.text == null ||
        decorated.text!.isEmpty ||
        decorated.children != null) {
      return decorated;
    }
    final gaps = _panguGapsFor(node);
    if (gaps.isEmpty) {
      return decorated;
    }
    // 标题等块级样式会在行内装饰后覆盖字号，此时取块叠好后的字号（after）
    // 换算间距，以免大号标题仍按正文字号留出过窄空隙。
    final blockSetsSize =
        node.type == kDiaryBlockHeading ||
        after.style?.fontSize != before.style?.fontSize;
    final effectiveFontSize = blockSetsSize
        ? (after.style?.fontSize ??
              decorated.style?.fontSize ??
              fallbackFontSize)
        : (decorated.style?.fontSize ??
              after.style?.fontSize ??
              fallbackFontSize);
    final baseTracking =
        decorated.style?.letterSpacing ??
        after.style?.letterSpacing ??
        before.style?.letterSpacing ??
        fallbackLetterSpacing;
    final pieces = splitTextSpanWithPanguGaps(
      decorated,
      spanStart: index,
      allGaps: gaps,
      gapExtent: panguSpacingExtent(effectiveFontSize),
      baseLetterSpacing: baseTracking,
    );
    if (pieces == null) {
      return decorated;
    }
    return TextSpan(style: decorated.style, children: pieces);
  };
}

/// 一块的盘古边界缓存：与 `diary_find_highlight.dart` 相同，按 `delta` 原始
/// 列表引用缓存，文字没变时直接复用。
final Expando<_NodePanguGaps> _gapCache = Expando<_NodePanguGaps>(
  'diaryPanguGaps',
);

class _NodePanguGaps {
  const _NodePanguGaps(this.delta, this.gaps);

  final Object? delta;
  final List<(int, int)> gaps;
}

List<(int, int)> _panguGapsFor(af.Node node) {
  final raw = node.attributes['delta'];
  final cached = _gapCache[node];
  if (cached != null && identical(cached.delta, raw)) {
    return cached.gaps;
  }
  final delta = node.delta;
  if (delta == null || delta.isEmpty) {
    _gapCache[node] = _NodePanguGaps(raw, const <(int, int)>[]);
    return const <(int, int)>[];
  }

  final buffer = StringBuffer();
  List<(int, int)>? scriptRanges;
  List<(int, int)>? codeRanges;
  var cursor = 0;
  for (final op in delta) {
    if (op is! af.TextInsert) continue;
    final text = op.text;
    final end = cursor + text.length;
    buffer.write(text);
    final attrs = op.attributes;
    if (attrs != null) {
      if (DiaryScript.fromAttribute(attrs[kDiaryInlineScript]) != null) {
        (scriptRanges ??= <(int, int)>[]).add((cursor, end));
      } else if (attrs['code'] == true) {
        (codeRanges ??= <(int, int)>[]).add((cursor, end));
      }
    }
    cursor = end;
  }

  final gaps = findPanguGapRanges(
    buffer.toString(),
    ignoreAt: scriptRanges == null
        ? null
        : (int offset) => _containsOffset(scriptRanges!, offset),
    skipTrailingAt: codeRanges == null
        ? null
        : (int offset) => _containsOffset(codeRanges!, offset),
  );
  _gapCache[node] = _NodePanguGaps(raw, gaps);
  return gaps;
}

bool _containsOffset(List<(int, int)> ranges, int offset) {
  var low = 0;
  var high = ranges.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (ranges[mid].$2 <= offset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low < ranges.length &&
      offset >= ranges[low].$1 &&
      offset < ranges[low].$2;
}
