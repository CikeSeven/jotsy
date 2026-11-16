import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../controllers/diary_find_replace.dart';
import '../../models/diary_find_query.dart';
import '../../viewmodels/search_highlight.dart';

/// 正文查找的高亮：与搜索结果卡片的关键词同一种标法（[searchHighlightStyle]：
/// 主色容器底、对应前景色、加粗），直接改匹配那几个字的文字样式，底色由
/// 文字排版自己画，所以与字严丝合缝（不再按选区矩形另画一层）。当前那一处
/// 换成主色底、主色上的前景色，比其余匹配深一档。
///
/// 怎么接进正文：[diaryFindSpanDecorator] 包在正文的行内片段装饰器外面
/// （`diaryEditorSpanDecorator`），AppFlowy 逐个行内片段调用它；片段与某处
/// 匹配重叠时先按匹配边界把片段切开，每一段照常交给原装饰器（链接、代码
/// 着色、上下标、字号档位都不受影响），落在匹配里的那几段再把高亮样式
/// 压到它的每一层文字上（链接色、代码着色同样被盖过，读起来与搜索页一致）。
/// 切开只改片段的拆分，不改文字与码元：光标、选区与点按的偏移照旧对应
/// 文档。
///
/// 什么时候重画：正文的文字块在装饰时经 [DiaryFindHighlightScope.maybeOf]
/// 按自己的节点订阅查找状态（`InheritedModel` 的 aspect），所以
/// - 查找条件变了（模式换了一个对象）或开关查找：看得见的文字块都重建；
/// - 只换了当前那一处（上一个 / 下一个）：只重建新旧当前匹配所在的两块；
/// - 正文改了字：那一块本来就重建，按新文字重新匹配（不等查找的防抖，
///   高亮总与眼前的文字一致）。
///
/// 匹配在装饰时就地计算并按节点缓存（文字或模式变了才重算），与
/// [DiaryFindReplace] 的匹配列表同一个正则、同一口径（零宽匹配没有字可标，
/// 不画）。相邻的非当前匹配合成一段，`.` 这类模式不会把一段话拆成逐字的
/// 片段。
///
/// 例外：引用、已勾选的待办与代码块的字色由块在行内装饰之后统一压上
/// （上游按块样式逐层合并颜色），高亮改不动它们的字色——主色底上的深色字
/// 读不清，代码配色更是任意。这三种块里只衬半透明的主色、加粗，不改字色
/// （[DiaryFindHighlightStyles.matchTint] / [DiaryFindHighlightStyles.currentTint]），
/// 在任何底色与字色上都读得清。
class DiaryFindHighlightScope extends InheritedModel<af.Node> {
  const DiaryFindHighlightScope({
    super.key,
    required this.pattern,
    required this.current,
    required this.styles,
    required super.child,
  });

  /// 正在查找的模式；查找关着、查找文字为空或正则写错时为 null（不标）。
  final RegExp? pattern;

  /// 当前那一处（标得更深）；没有时为 null。
  final DiaryFindMatch? current;
  final DiaryFindHighlightStyles styles;

  /// 在 [context]（正文文字块）里读取查找高亮，并按 [node] 订阅：只有这一块
  /// 的高亮可能变化时才让它重建。正文外面没有这一层时为 null。
  static DiaryFindHighlightScope? maybeOf(BuildContext context, af.Node node) =>
      InheritedModel.inheritFrom<DiaryFindHighlightScope>(
        context,
        aspect: node,
      );

  @override
  bool updateShouldNotify(DiaryFindHighlightScope oldWidget) =>
      !identical(pattern, oldWidget.pattern) ||
      styles != oldWidget.styles ||
      !_sameMatch(current, oldWidget.current);

  @override
  bool updateShouldNotifyDependent(
    DiaryFindHighlightScope oldWidget,
    Set<af.Node> dependencies,
  ) {
    if (!identical(pattern, oldWidget.pattern) || styles != oldWidget.styles) {
      // 模式没有（查找关着）时样式变了也不必重画。
      return pattern != null || oldWidget.pattern != null;
    }
    if (pattern == null || _sameMatch(current, oldWidget.current)) {
      return false;
    }
    return dependencies.contains(current?.node) ||
        dependencies.contains(oldWidget.current?.node);
  }

  static bool _sameMatch(DiaryFindMatch? a, DiaryFindMatch? b) =>
      identical(a?.node, b?.node) && a?.start == b?.start && a?.end == b?.end;
}

/// 查找高亮的样式：其余匹配与搜索结果卡片的关键词完全相同
/// （[searchHighlightStyle]），当前那一处换成主色底；字色由块决定的块里
/// 改用不改字色的半透明主色衬底（见 [DiaryFindHighlightScope]）。
@immutable
class DiaryFindHighlightStyles {
  const DiaryFindHighlightStyles({
    required this.match,
    required this.current,
    required this.matchTint,
    required this.currentTint,
  });

  factory DiaryFindHighlightStyles.of(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    TextStyle tint(double alpha) => TextStyle(
      backgroundColor: scheme.primary.withValues(alpha: alpha),
      fontWeight: FontWeight.w600,
    );
    return DiaryFindHighlightStyles(
      match: searchHighlightStyle(scheme),
      current: searchHighlightStyle(
        scheme,
      ).copyWith(color: scheme.onPrimary, backgroundColor: scheme.primary),
      matchTint: tint(dark ? 0.30 : 0.20),
      currentTint: tint(dark ? 0.55 : 0.42),
    );
  }

  final TextStyle match;
  final TextStyle current;
  final TextStyle matchTint;
  final TextStyle currentTint;

  @override
  bool operator ==(Object other) =>
      other is DiaryFindHighlightStyles &&
      other.match == match &&
      other.current == current &&
      other.matchTint == matchTint &&
      other.currentTint == currentTint;

  @override
  int get hashCode => Object.hash(match, current, matchTint, currentTint);
}

/// [node] 的字色由块在行内装饰之后统一压上（见 [DiaryFindHighlightScope]）。
bool _blockOwnsInk(af.Node node) => switch (node.type) {
  'quote' || 'code' => true,
  'todo_list' => node.attributes['checked'] == true,
  _ => false,
};

/// 把 [find] 的状态交给正文里的文字块（[DiaryFindHighlightScope]），颜色取
/// 正文所在位置的主题（预览页换了配色基调时随之变化）。
class DiaryFindHighlightHost extends StatelessWidget {
  const DiaryFindHighlightHost({
    super.key,
    required this.find,
    required this.child,
  });

  final DiaryFindReplace find;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final styles = DiaryFindHighlightStyles.of(Theme.of(context).colorScheme);
    return ListenableBuilder(
      listenable: find,
      child: child,
      builder: (BuildContext context, Widget? child) => DiaryFindHighlightScope(
        pattern: find.isOpen ? find.pattern : null,
        current: find.isOpen ? find.current : null,
        styles: styles,
        child: child!,
      ),
    );
  }
}

/// 在正文的行内片段装饰器 [inner] 外面加上查找高亮（见
/// [DiaryFindHighlightScope]）。没有匹配落在这个片段里时原样交给 [inner]。
af.TextSpanDecoratorForAttribute diaryFindSpanDecorator(
  af.TextSpanDecoratorForAttribute inner,
) {
  return (context, node, index, insert, before, after) {
    final scope = DiaryFindHighlightScope.maybeOf(context, node);
    final pattern = scope?.pattern;
    if (scope == null || pattern == null) {
      return inner(context, node, index, insert, before, after);
    }
    final end = index + insert.text.length;
    final pieces = _highlightPieces(
      _matchRanges(node, pattern),
      scope.current,
      node,
      index,
      end,
    );
    if (pieces.isEmpty) {
      return inner(context, node, index, insert, before, after);
    }
    final styles = scope.styles;
    final tinted = _blockOwnsInk(node);
    final spans = <InlineSpan>[];
    var cursor = index;
    InlineSpan piece(int start, int stop, TextStyle? highlight) {
      final text = insert.text.substring(start - index, stop - index);
      final decorated = inner(
        context,
        node,
        start,
        af.TextInsert(text, attributes: insert.attributes),
        _withText(before, text, highlight),
        _withText(after, text, highlight),
      );
      return highlight == null
          ? decorated
          : _forceHighlight(decorated, highlight);
    }

    for (final (start, stop, isCurrent) in pieces) {
      if (start > cursor) spans.add(piece(cursor, start, null));
      spans.add(
        piece(start, stop, switch ((isCurrent, tinted)) {
          (true, false) => styles.current,
          (false, false) => styles.match,
          (true, true) => styles.currentTint,
          (false, true) => styles.matchTint,
        }),
      );
      cursor = stop;
    }
    if (cursor < end) spans.add(piece(cursor, end, null));
    return TextSpan(children: spans);
  };
}

/// [ranges]（这一块全部匹配，按起点排序、互不重叠）落在片段 [start]～[end]
/// 里的部分，裁到片段之内；首尾相接的非当前匹配合成一段。
List<(int, int, bool)> _highlightPieces(
  List<(int, int)> ranges,
  DiaryFindMatch? current,
  af.Node node,
  int start,
  int end,
) {
  final pieces = <(int, int, bool)>[];
  final currentHere = current != null && identical(current.node, node);
  for (final (from, to) in ranges) {
    if (to <= start) continue;
    if (from >= end) break;
    final isCurrent = currentHere && current.start == from && current.end == to;
    final clippedStart = math.max(from, start);
    final clippedEnd = math.min(to, end);
    if (!isCurrent &&
        pieces.isNotEmpty &&
        !pieces.last.$3 &&
        pieces.last.$2 == clippedStart) {
      pieces.last = (pieces.last.$1, clippedEnd, false);
    } else {
      pieces.add((clippedStart, clippedEnd, isCurrent));
    }
  }
  return pieces;
}

/// 一块的匹配区间缓存：文字（`delta` 的原始列表，改字时上游整个换掉）与
/// 模式都没变时直接复用。
final Expando<_NodeMatches> _matchCache = Expando<_NodeMatches>(
  'diaryFindHighlight',
);

class _NodeMatches {
  const _NodeMatches(this.delta, this.pattern, this.ranges);

  final Object? delta;
  final RegExp pattern;
  final List<(int, int)> ranges;
}

/// [node] 的文字里 [pattern] 的全部非零宽匹配（按起点排序）。
List<(int, int)> _matchRanges(af.Node node, RegExp pattern) {
  final raw = node.attributes['delta'];
  final cached = _matchCache[node];
  if (cached != null &&
      identical(cached.delta, raw) &&
      identical(cached.pattern, pattern)) {
    return cached.ranges;
  }
  final text = node.delta?.toPlainText() ?? '';
  final ranges = <(int, int)>[
    for (final match in pattern.allMatches(text))
      if (match.end > match.start) (match.start, match.end),
  ];
  _matchCache[node] = _NodeMatches(raw, pattern, ranges);
  return ranges;
}

/// 换上切开后的文字；落在匹配里时把高亮样式先压上去：上下标逐字的占位
/// 按传入的样式画字与底色（它们是 widget，事后改不到）。
TextSpan _withText(TextSpan span, String text, TextStyle? highlight) =>
    TextSpan(
      text: text,
      style: highlight == null ? span.style : _applyTo(span.style, highlight),
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );

/// 把高亮样式压到 [span] 的每一层文字上：链接色、代码着色这类子片段自带
/// 的颜色同样被盖过。占位（上下标的字）已经按 [_withText] 的样式画好。
InlineSpan _forceHighlight(InlineSpan span, TextStyle highlight) {
  if (span is! TextSpan) return span;
  return TextSpan(
    text: span.text,
    children: span.children == null
        ? null
        : <InlineSpan>[
            for (final child in span.children!)
              _forceHighlight(child, highlight),
          ],
    style: _applyTo(span.style, highlight),
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

/// 高亮的前景色、底色与字重（原本更粗的不变细）。样式用了画笔
/// （`foreground` / `background`）时对应的颜色不能再设，保持原样。
TextStyle _applyTo(TextStyle? style, TextStyle highlight) {
  final base = style ?? const TextStyle();
  final weight = base.fontWeight;
  final wanted = highlight.fontWeight;
  return base.copyWith(
    color: base.foreground == null ? highlight.color : null,
    backgroundColor: base.background == null ? highlight.backgroundColor : null,
    fontWeight: weight != null && wanted != null && weight.value > wanted.value
        ? weight
        : wanted,
  );
}
