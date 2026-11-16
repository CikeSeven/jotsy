import '../rich_text/inline_rich_text.dart';
import 'mind_map_document.dart';
import 'mind_map_schema.dart';

export '../rich_text/inline_rich_text.dart';

/// 导图主题文字的局部样式：节点 `delta` 的读取与只属于导图的改写。
///
/// 样式模型、校验、编码与通用改写在 `inline_rich_text.dart`（与日记留言
/// 共用，本文件原样导出）。导图的口径：
/// - `text` 是唯一的权威文字，delta 各段 insert 拼起来等于 `text` 才算数；
/// - 属性名与节点 `style` 同一套（[kMindMapStyleBoldKey] 等与行内样式键
///   相同）：四种开关样式在整条样式之上局部打开 / 取消，`color` /
///   `highlight` 与正文的文字色 / 背景色同一套，按原色存 `#AARRGGBB`；
///   导图不写链接（节点链接是节点自己的 `href`）。

/// 节点文字按样式分好的段；没有（或对不上的）delta 时整段一个无样式的 run，
/// 空文字为空列表。
List<InlineTextRun> mindMapRunsOf(MindMapNode node) =>
    inlineRunsFromDelta(node.delta, node.text);

/// 节点文字有没有局部样式。
bool mindMapHasRichText(MindMapNode node) =>
    node.delta != null && inlineDeltaMatches(node.delta!, node.text);

/// 去掉所有段上的 [key] 属性（整条主题改了同一项时用：整条设置就是整条
/// 生效）。[key] 为 [InlineMark.key] 或 [InlineColorMark.key]。
List<InlineTextRun> clearMindMapMark(List<InlineTextRun> runs, String key) =>
    normalizeInlineRuns(<InlineTextRun>[
      for (final run in runs)
        InlineTextRun(run.text, switch (key) {
          kMindMapStyleBoldKey => run.marks.withFlag(InlineMark.bold, null),
          kMindMapStyleItalicKey => run.marks.withFlag(InlineMark.italic, null),
          kMindMapStyleUnderlineKey => run.marks.withFlag(
            InlineMark.underline,
            null,
          ),
          kMindMapStyleStrikeKey => run.marks.withFlag(InlineMark.strike, null),
          kMindMapStyleColorKey => run.marks.withColor(
            InlineColorMark.color,
            null,
          ),
          kMindMapStyleHighlightKey => run.marks.withColor(
            InlineColorMark.highlight,
            null,
          ),
          _ => run.marks,
        }),
    ]);

/// 压成一行：与 `mindMapOutlineLines` 同一口径（换行连同两侧空白压成一个
/// 空格，再去掉首尾空白），样式跟着字走，压出来的空格取换行前那个字的样式。
List<InlineTextRun> oneLineMindMapRuns(List<InlineTextRun> runs) {
  final text = inlineRunsText(runs);
  final pieces = <InlineTextRun>[];
  var cursor = 0;
  for (final match in RegExp(r'\s*\n\s*').allMatches(text)) {
    pieces.addAll(sliceInlineRuns(runs, cursor, match.start));
    pieces.add(InlineTextRun(' ', inlineMarksForInsertion(runs, match.start)));
    cursor = match.end;
  }
  pieces.addAll(sliceInlineRuns(runs, cursor, text.length));
  final joined = normalizeInlineRuns(pieces);
  final flat = inlineRunsText(joined);
  final leading = flat.length - flat.trimLeft().length;
  final trailing = flat.length - flat.trimRight().length;
  if (leading + trailing >= flat.length) return const <InlineTextRun>[];
  return sliceInlineRuns(joined, leading, flat.length - trailing);
}
