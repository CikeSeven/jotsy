import 'dart:convert';

import 'diary_blocks/diary_link_target.dart';
import 'rich_text/inline_rich_text.dart';

/// 留言文字的格式（`diary_comments.delta`，schema v23）的编解码（纯 Dart）。
///
/// 口径（与导图主题的局部样式同一套，见 `inline_rich_text.dart`）：
/// - `content` 是唯一的权威文字：搜索、复制、AI、探索卡与纯文本导出都只读
///   它；`delta` 是附在上面的格式，JSON 数组，各段 insert 拼起来等于
///   `content` 才算数，对不上（旧版本改了文字、坏数据）一律按没有格式读；
/// - 留言只用粗体 / 斜体 / 下划线 / 删除线与链接：写入时只留这几种属性，
///   链接只认网址（http(s) / mailto / tel）与日记链接（[DiaryLinkTarget]），
///   其余属性与认不出的地址丢掉；读取时原样解析（颜色等由显示方忽略）；
/// - 没有任何格式时不存（NULL），与加格式之前的留言逐字节相同。

/// 一条留言的文字与格式（写库前经 [normalizeDiaryCommentText] 规整）。
typedef DiaryCommentText = ({String content, String? delta});

/// 规整留言文字：去掉首尾空白（与 `content` 同一口径），格式随文字一起
/// 裁剪；[runs] 为输入框里的文字与格式，拼起来不等于 [raw] 时不带格式。
DiaryCommentText normalizeDiaryCommentText(
  String raw, {
  List<InlineTextRun>? runs,
}) {
  final content = raw.trim();
  if (runs == null || content.isEmpty || inlineRunsText(runs) != raw) {
    return (content: content, delta: null);
  }
  final leading = raw.length - raw.trimLeft().length;
  final trimmed = sliceInlineRuns(runs, leading, leading + content.length);
  return (content: content, delta: encodeDiaryCommentDelta(trimmed));
}

/// 把格式编码成列值：只留留言用得到的属性；没有格式时为 null。
String? encodeDiaryCommentDelta(List<InlineTextRun> runs) {
  final delta = encodeInlineDelta(<InlineTextRun>[
    for (final run in runs) InlineTextRun(run.text, _commentMarks(run.marks)),
  ]);
  return delta == null ? null : jsonEncode(delta);
}

/// 读出 [content] 的格式；列为空、解析不了或与文字对不上时整段无格式。
List<InlineTextRun> decodeDiaryCommentRuns(String? delta, String content) {
  return inlineRunsFromDelta(_decodeDelta(delta), content);
}

/// 列值是否是一份与 [content] 对得上的格式（备份、同步规整时用）。
String? normalizeDiaryCommentDelta(String? delta, String content) {
  final ops = _decodeDelta(delta);
  if (ops == null || !inlineDeltaMatches(ops, content)) return null;
  return encodeDiaryCommentDelta(inlineRunsFromDelta(ops, content));
}

/// 留言里能写的链接：网址（http(s) 须有主机名、mailto、tel）或日记链接。
bool isDiaryCommentLink(String? href) {
  if (href == null || href.trim().isEmpty) return false;
  if (DiaryLinkTarget.isLink(href)) return true;
  final uri = Uri.tryParse(href.trim());
  if (uri == null) return false;
  return switch (uri.scheme) {
    'http' || 'https' => uri.host.isNotEmpty,
    'mailto' || 'tel' => true,
    _ => false,
  };
}

/// 只留粗体 / 斜体 / 下划线 / 删除线（只存打开的）与合法的链接。
InlineTextMarks _commentMarks(InlineTextMarks marks) => InlineTextMarks(
  bold: marks.bold == true ? true : null,
  italic: marks.italic == true ? true : null,
  underline: marks.underline == true ? true : null,
  strike: marks.strike == true ? true : null,
  href: isDiaryCommentLink(marks.href) ? marks.href!.trim() : null,
);

List<Map<String, Object?>>? _decodeDelta(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  final ops = <Map<String, Object?>>[];
  for (final op in decoded) {
    if (op is! Map) return null;
    ops.add(<String, Object?>{
      for (final entry in op.entries)
        if (entry.key is String) entry.key as String: entry.value,
    });
  }
  return ops;
}
