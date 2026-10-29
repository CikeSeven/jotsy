/// 粘贴纯文字时的 Markdown 识别与转换（见 DiaryEditorClipboard.paste）。
///
/// 输入：剪贴板里的纯文字；输出：要不要按 Markdown 转换（[looksLikeDiaryMarkdown]）
/// 与转换后的块节点 JSON（[diaryMarkdownPasteNodes]）。纯函数，无 IO。
///
/// 识别刻意保守：普通文字里也常出现 `*`、`#`、`-`，误判会把用户的原文改掉，
/// 所以只认“几乎只会在 Markdown 里出现”的写法，见 [looksLikeDiaryMarkdown]。
/// 转换复用导入用的 [JournalMarkdownConverter]（源文本一行 = 正文一行），
/// 不开行内 HTML，也不给媒体 / 附件解析器：粘贴的文字不能指向本机文件。
library;

import '../../../core/services/journal_import_block_writer.dart';
import '../../../core/services/journal_import_markdown.dart';
import '../../../core/services/journal_import_markdown_table.dart';

final RegExp _heading = RegExp(r'^ {0,3}#{1,6} +\S');
final RegExp _fence = RegExp(r'^ {0,3}(```|~~~)');
final RegExp _quote = RegExp(r'^ {0,3}> ');
final RegExp _listItem = RegExp(r'^\s*(?:[-*+]|\d{1,9}\.) +\S');

/// 成对的行内标记：标记内侧紧贴非空白字符（`** x **` 不算），且不跨行。
final List<RegExp> _pairedInline = [
  RegExp(r'\*\*(?=\S)[^\n]*?\S\*\*'),
  RegExp(r'~~(?=\S)[^\n]*?\S~~'),
  RegExp(r'`[^`\n]+`'),
  RegExp(r'\[[^\]\n]+\]\((?:https?|mailto):[^)\s]+\)', caseSensitive: false),
];

/// 文字看起来是不是 Markdown。满足任一条即是：
/// - 标题行：行首 1~6 个 `#` 后跟空格与文字（`#话题`、`#` 单独一个不算）；
/// - 代码围栏行：行首 ```` ``` ```` 或 `~~~`；
/// - GFM 管道表格：带 `|` 的表头行紧跟格数相同的分隔行（`|---|---|`）；
/// - 引用行：行首 `> `；
/// - 至少两行列表 / 待办（`- `、`* `、`+ `、`1. `，含 `- [ ] ` / `- [x] `），
///   只有一行 `- ` 时多半是普通文字里的破折号；
/// - 成对的行内标记：`**粗**`、`~~删~~`、`` `代码` ``、`[文字](http…)`。
///
/// 普通文字、单独的 `*` / `_` / `#`、没有配对的标记、只有网址都不算。
bool looksLikeDiaryMarkdown(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  var listLines = 0;
  for (final (index, line) in lines.indexed) {
    if (_heading.hasMatch(line) ||
        _fence.hasMatch(line) ||
        _quote.hasMatch(line)) {
      return true;
    }
    if (_listItem.hasMatch(line) && ++listLines >= 2) return true;
    if (line.contains('|') &&
        journalPipeTableRows(lines, index, (_) => false) != null) {
      return true;
    }
  }
  return _pairedInline.any((pattern) => pattern.hasMatch(text));
}

/// 把 Markdown 文字转为块节点 JSON（页面的子块），交给与 HTML 粘贴相同的
/// 插入路径。图片的处理：`![说明](http…)` 与 HTML 粘贴一致写成图片块
/// （网络地址）；指向本地或相对路径的图片无从解析，转换器会整个丢掉，所以
/// 先把它的 `![` 转义，让整段原文作为文字留下，不悄悄丢内容。链接没有附件
/// 解析器：网址链接保留链接，本地链接只留链接文字。
List<Map<String, dynamic>> diaryMarkdownPasteNodes(String text) {
  final writer = JournalBlockWriter();
  JournalMarkdownConverter(writer).append(escapeLocalMarkdownImages(text));
  final document = writer.buildDocument();
  final page = document['document'];
  final children = page is Map ? page['children'] : null;
  return [
    if (children is List)
      for (final child in children)
        if (child is Map) child.cast<String, dynamic>(),
  ];
}

final RegExp _codeSpanOrImage = RegExp(r'(`+)[^\n]*?\1|!\[');
final RegExp _remoteImageTail = RegExp(
  r'^[^\]\n]*\]\(\s*<?https?://',
  caseSensitive: false,
);

/// 把目标不是 http(s) 地址的图片语法 `![` 转义为 `!\[`，使其按原文显示。
/// 代码围栏里的行与行内代码（反引号之间）是原文，不转义。
String escapeLocalMarkdownImages(String text) {
  final lines = text.split('\n');
  String? fence;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final fenceMatch = _fence.firstMatch(line.trimLeft());
    if (fence != null) {
      if (line.trimLeft().startsWith(fence)) fence = null;
      continue;
    }
    if (fenceMatch != null) {
      fence = fenceMatch.group(1);
      continue;
    }
    if (!line.contains('![')) continue;
    lines[i] = line.replaceAllMapped(_codeSpanOrImage, (match) {
      if (match.group(1) != null) return match.group(0)!;
      final tail = line.substring(match.end);
      return _remoteImageTail.hasMatch(tail) ? '![' : r'!\[';
    });
  }
  return lines.join('\n');
}
