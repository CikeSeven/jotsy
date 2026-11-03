/// 粘贴纯文字时的 Markdown 识别与转换（见 DiaryEditorClipboard.paste）。
///
/// 输入：剪贴板里的纯文字；输出：要不要按 Markdown 转换（[looksLikeDiaryMarkdown]）
/// 与转换后的块节点 JSON（[diaryMarkdownPasteNodes]）。纯函数，无 IO。
///
/// 识别刻意保守：普通文字里也常出现 `*`、`#`、`-`，误判会把用户的原文改掉，
/// 所以只认“几乎只会在 Markdown 里出现”的写法，见 [looksLikeDiaryMarkdown]。
/// 转换复用导入用的 [JournalMarkdownConverter]（源文本一行 = 正文一行），
/// 不开行内 HTML，也不给媒体 / 附件解析器：粘贴的文字不能指向本机文件。
/// 剪贴板同时带 HTML 时，HTML 是否只是包着原文见 [htmlOnlyWrapsText]。
library;

import 'package:html/parser.dart' as html_parser;

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
  RegExp(
    r'\[[^\]\n]+\][ \t]*\((?:https?|mailto):[^)\s]+\)',
    caseSensitive: false,
  ),
];

/// 文字看起来是不是 Markdown。满足任一条即是：
/// - 标题行：行首 1~6 个 `#` 后跟空格与文字（`#话题`、`#` 单独一个不算）；
/// - 代码围栏行：行首 ```` ``` ```` 或 `~~~`；
/// - GFM 管道表格：带 `|` 的表头行紧跟格数相同的分隔行（`|---|---|`）；
/// - 引用行：行首 `> `；
/// - 至少两行列表 / 待办（`- `、`* `、`+ `、`1. `，含 `- [ ] ` / `- [x] `），
///   只有一行 `- ` 时多半是普通文字里的破折号；
/// - 成对的行内标记：`**粗**`、`~~删~~`、`` `代码` ``、`[文字](http…)`
///   （`]` 与 `(` 之间带空格的也算，见 [joinSpacedMarkdownLinks]）。
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

/// 带格式含义的 HTML 元素：出现任何一个，HTML 就是来源渲染好的格式（网页、
/// 文档、富文本笔记），粘贴以 HTML 为准。`pre` / `code` 也算：网页上的代码
/// 片段（如 Shell 脚本里的 `# 注释`）看起来也像 Markdown，按 HTML 粘贴才会
/// 留成代码块，不被误转成标题。
const Set<String> _formattingHtmlTags = {
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', //
  'ul', 'ol', 'li', 'dl', 'dt', 'dd', 'blockquote', 'hr',
  'pre', 'code', 'table', 'tr', 'td', 'th',
  'strong', 'b', 'em', 'i', 'u', 's', 'del', 'strike', 'ins', 'mark',
  'sub', 'sup', 'a', 'img', 'picture', 'svg', 'video', 'audio', 'figure',
};

/// 剪贴板里的 HTML 是不是只把原文包了一层（只有 `div`、`span`、`p`、`br`、
/// `font` 这类容器，没有任何 [_formattingHtmlTags]）。
///
/// Android 与 Windows 上不少应用复制纯文字时也附一份 HTML：代码编辑器（如
/// VS Code）把每行包成带颜色的 `span`，笔记与聊天应用把每行包成 `div` / `p`。
/// 这种 HTML 里的 `#`、`**` 只是字符，按 HTML 粘贴会把 Markdown 原文原样留
/// 下（有时换行也被 HTML 的空白规则合并掉），所以纯文字看起来像 Markdown 且
/// 这里为 true 时，粘贴改按 Markdown 转换（见 `DiaryEditorClipboard.pasteText`）。
/// 容器上的行内样式（颜色、字重）不看：它们是编辑器的语法着色，不是用户的格式。
bool htmlOnlyWrapsText(String html) {
  final document = html_parser.parse(html);
  for (final element in document.querySelectorAll('*')) {
    if (_formattingHtmlTags.contains(element.localName)) return false;
  }
  return true;
}

/// 把 Markdown 文字转为块节点 JSON（页面的子块），交给与 HTML 粘贴相同的
/// 插入路径。图片的处理：`![说明](http…)` 与 HTML 粘贴一致写成图片块
/// （网络地址）；指向本地或相对路径的图片无从解析，转换器会整个丢掉，所以
/// 先把它的 `![` 转义，让整段原文作为文字留下，不悄悄丢内容。链接没有附件
/// 解析器：网址链接保留链接，本地链接只留链接文字；`[文字] (https://…)`
/// 这种中间带空格的网址链接先经 [joinSpacedMarkdownLinks] 接上。
List<Map<String, dynamic>> diaryMarkdownPasteNodes(String text) {
  final writer = JournalBlockWriter();
  JournalMarkdownConverter(
    writer,
  ).append(escapeLocalMarkdownImages(joinSpacedMarkdownLinks(text)));
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
String escapeLocalMarkdownImages(String text) =>
    _mapLinesOutsideFences(text, (line) {
      if (!line.contains('![')) return line;
      return line.replaceAllMapped(_codeSpanOrImage, (match) {
        if (match.group(1) != null) return match.group(0)!;
        final tail = line.substring(match.end);
        return _remoteImageTail.hasMatch(tail) ? '![' : r'!\[';
      });
    });

/// 行内代码，或 `]` 与 `(` 之间隔着空白的网址链接（组 2 为 `[文字]`，组 3
/// 为 `(地址)`）。
final RegExp _codeSpanOrSpacedLink = RegExp(
  r'(`+)[^\n]*?\1|(\[[^\]\n]+\])[ \t]+(\((?:https?|mailto):[^)\s]+\))',
  caseSensitive: false,
);

/// 待办的勾选框 `[ ]` / `[x]`：`- [ ] (https://…)` 是一条以括号网址开头的
/// 待办，不是链接，不能接上。
final RegExp _taskBox = RegExp(r'^\[[ xX]\]$');

/// 把 `[文字] (https://…)` 中间的空白去掉，让它按链接转换。
///
/// CommonMark 要求 `]` 与 `(` 紧挨，带空格时整段按文字显示，地址只剩一个
/// 裸网址；手打或经其他应用转手的 Markdown 常带这个空格，本意都是链接。
/// 只认 http(s) / mailto 地址（相对路径本来就只留文字，接上也没用），代码
/// 围栏里的行与行内代码是原文，不动。
String joinSpacedMarkdownLinks(String text) =>
    _mapLinesOutsideFences(text, (line) {
      if (!line.contains(']')) return line;
      return line.replaceAllMapped(_codeSpanOrSpacedLink, (match) {
        final label = match.group(2);
        if (label == null || _taskBox.hasMatch(label)) return match.group(0)!;
        return '$label${match.group(3)}';
      });
    });

/// 对代码围栏之外的每一行做 [map]（围栏行与围栏里的行原样保留）。
String _mapLinesOutsideFences(String text, String Function(String line) map) {
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
    lines[i] = map(line);
  }
  return lines.join('\n');
}
