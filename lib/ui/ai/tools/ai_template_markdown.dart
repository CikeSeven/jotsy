// 模板正文 → “模板 Markdown”：智能体读写模板正文用的文字写法（读取见
// `ai_template_markdown_parse.dart`，行内部分见 `ai_template_markdown_inline.dart`）。
//
// 为什么不用通用的 Markdown：模板正文的格式就是模板的一部分——内置模板的
// 彩色粗体小标题、提示块、折叠块、表格、对齐与首行缩进，通用 Markdown 写
// 不出，读出再写回就丢了；写日记用的 Markdown 转换也不认行内 HTML。这里定
// 一套与模板白名单（`sanitizeDiaryTemplateBlocks`）一一对应的写法，读写
// 对称：`get_template` 给出的文字原样交回 `update_template`，正文不变
// （`ai_template_markdown_test.dart` 用全部内置模板与一份全格式样本兜底）。
//
// 写法（工具说明里的 [aiTemplateMarkdownGuide] 是给模型的简版）：
// - 一行一个块；空行是一个空段落（留给用户填写的空白），不是段落分隔；
// - 块：`#`…`######` 标题、`- ` 项目、`1. ` 编号、`- [ ] ` / `- [x] ` 待办、
//   `> ` 引用、`---` 分隔线、```` ```语言 ```` 代码块、GFM 管道表格（紧挨的
//   上一行 `<!-- no header row -->` 表示首行不是表头，格内多段以 `<br>`
//   分开）、`<callout icon="💡" tone="yellow">文字</callout>` 提示块、
//   `<toggle>标题</toggle>`（`collapsed` 收起 / `open` 展开）折叠块；
// - 子块比父块多缩进两个空格（段落、列表、待办与折叠块下面）；
// - 行尾 ` {align=center indent=on list=lower-roman}` 为块属性（对齐、段落
//   首行缩进 on/off、列表样式）；
// - 行内：`**粗**` `*斜*` `~~删~~` `` `代码` `` `[文字](https://…)`
//   `<u>下划线</u>` `<sup>上标</sup>` `<sub>下标</sub>`
//   `<span style="color: orange; background-color: yellow; font-size: large">`
//   （颜色优先用颜色面板的预设名，亮暗主题下都清楚；也认 `#RRGGBB`）；
// - `\` 转义下一个字符；`_` 与 `{{变量}}` 都是普通文字。

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_table.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import '../../diary_templates/models/diary_template_blocks.dart';
import 'ai_template_markdown_inline.dart';

/// 给模型的写法说明（英文，进 `create_template` / `update_template` 的说明）。
const String aiTemplateMarkdownGuide =
    'Body format ("template Markdown"): one line per block; an empty line is '
    'an empty paragraph (a blank for the user to fill), not a separator. '
    'Blocks: # to ###### headings, "- " bullets, "1. " numbers, "- [ ] " / '
    '"- [x] " to-dos, "> " quote, "---" divider, ```lang code fences, GFM '
    'pipe tables (a line <!-- no header row --> right above means the first '
    'row is not a header; <br> separates paragraphs in a cell), '
    '<callout icon="💡" tone="yellow">text</callout> '
    '(tones: default yellow green blue red purple), '
    '<toggle>title</toggle> (add collapsed to fold it). Indent children by '
    '2 spaces under paragraphs, list items, to-dos and toggles. A trailing '
    '{align=center|right|justify indent=on|off list=<style>} sets block '
    'options. Inline: **bold** *italic* ~~strike~~ `code` [text](https://…) '
    '<u>underline</u> <sup> <sub> and <span style="color: orange; '
    'background-color: yellow; font-size: small|large|huge">. Prefer the '
    'color names red orange yellow green teal blue indigo purple pink brown '
    'gray (readable in light and dark mode); #RRGGBB also works. Template '
    'section labels are usually bold colored text followed by a plain colon, '
    'e.g. <span style="color: orange">**Mood**</span>: . Use \\ to escape. '
    'Underscores and {{variables}} are plain text. No images or media.';

/// 模板正文（块文档 JSON 或 Map，先经白名单清洗）写成模板 Markdown。
String aiTemplateMarkdownOf(Object? body) {
  final document = sanitizeDiaryTemplateBlocks(body);
  final lines = <String>[];
  _writeBlocks(diaryBlockChildren(diaryBlocksRoot(document)!), 0, lines);
  return lines.join('\n');
}

void _writeBlocks(
  List<Map<String, Object?>> nodes,
  int depth,
  List<String> lines,
) {
  final indent = '  ' * depth;
  var number = 0;
  for (final node in nodes) {
    final type = node[kDiaryBlockTypeKey];
    number = type == kDiaryBlockNumberedList ? number + 1 : 0;
    switch (type) {
      case kDiaryBlockDivider:
        lines.add('$indent---');
      case kDiaryBlockTable:
        // 格子是表格的结构，不是子块。
        _writeTable(node, indent, lines);
        continue;
      case kDiaryBlockCode:
        _writeCode(node, indent, lines);
      default:
        lines.add('$indent${_textLine(node, type, number)}');
    }
    _writeBlocks(diaryBlockChildren(node), depth + 1, lines);
  }
}

String _textLine(Map<String, Object?> node, Object? type, int number) {
  final data = diaryBlockData(node);
  var text = aiTemplateInlineMarkdown(diaryBlockDelta(node));
  final suffix = _suffix(type, data);
  if (suffix.isEmpty) text = aiTemplateEscapeSuffix(text);
  final line = switch (type) {
    kDiaryBlockHeading =>
      '${'#' * ((data[kDiaryBlockLevelKey] as num?)?.toInt() ?? 1)} $text',
    kDiaryBlockBulletedList => '- $text',
    kDiaryBlockNumberedList => '$number. $text',
    kDiaryBlockTodoList =>
      '- [${data[kDiaryBlockCheckedKey] == true ? 'x' : ' '}] $text',
    kDiaryBlockQuote => '> $text',
    kDiaryBlockCallout => '<callout${_calloutAttributes(data)}>$text</callout>',
    kDiaryBlockToggleList => switch (data[kDiaryToggleCollapsedKey]) {
      true => '<toggle collapsed>$text</toggle>',
      false => '<toggle open>$text</toggle>',
      _ => '<toggle>$text</toggle>',
    },
    _ => aiTemplateEscapeParagraphStart(text),
  };
  // 只有前缀的空块（`- `）去掉行尾空格，免得被当成缩进或被顺手删掉。
  final trimmed = text.isEmpty ? line.trimRight() : line;
  return suffix.isEmpty ? trimmed : '$trimmed $suffix'.trimLeft();
}

String _calloutAttributes(Map<String, Object?> data) {
  final icon = data[kDiaryCalloutIconKey];
  final tone = data[kDiaryCalloutToneKey];
  return [
    if (icon is String) ' icon="$icon"',
    if (tone is String) ' tone="$tone"',
  ].join();
}

/// 行尾的块属性 `{…}`；没有时为空串。
String _suffix(Object? type, Map<String, Object?> data) {
  final parts = <String>[
    if (data[kDiaryBlockAlignKey] case final String align) 'align=$align',
    if (type == kDiaryBlockParagraph)
      if (data[kDiaryParagraphIndentKey] case final bool indent)
        'indent=${indent ? 'on' : 'off'}',
    if (sanitizeDiaryListStyleId(type, data[kDiaryListStyleKey])
        case final String style)
      'list=$style',
  ];
  return parts.isEmpty ? '' : '{${parts.join(' ')}}';
}

/// 行尾块属性的写法（读取时据此拆出）。
final RegExp aiTemplateSuffixPattern = RegExp(
  r'(?:^|[ \t])\{((?:align|indent|list)=[A-Za-z-]+(?:[ \t]+(?:align|indent|list)=[A-Za-z-]+)*)\}[ \t]*$',
);

/// 文字恰好以像块属性的 `{…}` 结尾时转义那个 `{`。
String aiTemplateEscapeSuffix(String text) {
  final match = aiTemplateSuffixPattern.firstMatch(text);
  if (match == null) return text;
  final brace = text.indexOf('{', match.start);
  return '${text.substring(0, brace)}\\${text.substring(brace)}';
}

final RegExp _headingStart = RegExp(r'^#{1,6}(?:[ \t]|$)');
final RegExp _listStart = RegExp(r'^[-+](?:[ \t]|$)');
final RegExp _numberStart = RegExp(r'^(\d{1,9})([.)])(?:[ \t]|$)');
final RegExp _dividerLine = RegExp(r'^(?:-{3,}|_{3,})[ \t]*$');

/// 段落文字恰好像块写法（标题、列表、引用、分隔线、表格行）时转义开头。
String aiTemplateEscapeParagraphStart(String text) {
  if (_headingStart.hasMatch(text) ||
      _listStart.hasMatch(text) ||
      _dividerLine.hasMatch(text) ||
      text.startsWith('>') ||
      text.startsWith('|')) {
    return '\\$text';
  }
  final number = _numberStart.firstMatch(text);
  if (number != null) {
    final digits = number.group(1)!;
    return '$digits\\${text.substring(digits.length)}';
  }
  return text;
}

void _writeCode(Map<String, Object?> node, String indent, List<String> lines) {
  final code = diaryBlockText(node);
  final language = diaryBlockData(node)[kDiaryBlockLanguageKey];
  final codeLines = code.split('\n');
  var fence = '```';
  while (codeLines.any((line) => line.trimLeft().startsWith(fence))) {
    fence += '`';
  }
  lines.add('$indent$fence${language is String ? language : ''}');
  for (final line in codeLines) {
    lines.add(line.isEmpty ? '' : '$indent$line');
  }
  lines.add('$indent$fence');
}

/// 表格首行不是表头时紧挨在表格上一行的标记。
const String aiTemplateNoHeaderMarker = '<!-- no header row -->';

void _writeTable(Map<String, Object?> node, String indent, List<String> lines) {
  final grid = DiaryTableGrid.of(node);
  if (grid == null) return;
  if (!grid.headerRow) lines.add('$indent$aiTemplateNoHeaderMarker');
  for (var row = 0; row < grid.rows; row++) {
    final cells = <String>[
      for (var col = 0; col < grid.cols; col++)
        [for (final block in grid.textBlocksAt(row, col)) _cellParagraph(block)]
            .join('<br>'),
    ];
    lines.add('$indent| ${cells.join(' | ')} |');
    if (row == 0) {
      lines.add('$indent|${List.filled(grid.cols, ' --- ').join('|')}|');
    }
  }
}

String _cellParagraph(Map<String, Object?> block) {
  final text = aiTemplateInlineMarkdown(diaryBlockDelta(block), cell: true);
  final align = diaryBlockData(block)[kDiaryBlockAlignKey];
  if (align is String) return '$text {align=$align}'.trimLeft();
  return aiTemplateEscapeSuffix(text);
}
