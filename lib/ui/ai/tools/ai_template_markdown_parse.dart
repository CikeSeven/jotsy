// 模板 Markdown → 模板正文（块文档）。写法与为什么另定一套见
// `ai_template_markdown.dart`；纯函数，无 IO。
//
// 逐行读：一行一个块，空行是空段落；缩进（两个空格一层，Tab 算一层）决定
// 父子关系，挂到不能有子块的块（标题、引用、提示块、代码块……）下面的行
// 提到同一层；代码块与表格各占连续几行。结果最后经模板白名单
// （`sanitizeDiaryTemplateBlocks`）清洗：认不出的属性、不安全的链接与媒体
// 一律去掉，与保存模板同一道关。
//
// 智能体读写日记正文用的是同一套写法（`ai_diary_markdown*.dart`）：逐行读
// [aiMarkdownBlockEntries]（带行号，另加媒体标记与对话图片的读法）、挂树
// [aiNestMarkdownBlocks]，不经模板白名单（日记里的媒体与日记链接要留下）。

import 'dart:math' as math;

import '../../../core/database/code_block_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import '../../diary_templates/models/diary_template_blocks.dart';
import 'ai_template_markdown.dart';
import 'ai_template_markdown_inline_parse.dart';

/// 读出模板 Markdown，返回清洗过的块文档。
Map<String, Object?> aiTemplateBodyFromMarkdown(String markdown) =>
    sanitizeDiaryTemplateBlocks(<String, Object?>{
      kDiaryBlocksDocumentKey: <String, Object?>{
        kDiaryBlockTypeKey: kDiaryBlockPage,
        kDiaryBlockChildrenKey: aiNestMarkdownBlocks([
          for (final entry in aiMarkdownBlockEntries(markdown))
            (depth: entry.depth, node: entry.node),
        ]),
      },
    });

/// 逐行读出的一个块：缩进层级、块本身（能有子块的类型带一个空的子块列表，
/// 由 [aiNestMarkdownBlocks] 挂上）与它占的行 `[start, end)`。
typedef AiMarkdownBlockEntry = ({
  int depth,
  Map<String, Object?> node,
  int start,
  int end,
});

/// 一行（去掉缩进与行尾空白后的内容）的另一种读法：返回块列表时代替通常的
/// 读法（可以为空：这一行不成块），返回 null 照常读。日记正文的媒体标记与
/// 对话图片用它（`ai_diary_markdown_edit.dart`），模板不用。代码块与表格里的
/// 行不经过这里。
typedef AiMarkdownLineReader =
    List<Map<String, Object?>>? Function(String content);

/// 把模板 Markdown 逐行读成块（未挂树、未清洗），并记下每块占的行，供日记
/// 正文的修改按行对照原文。[line] 见 [AiMarkdownLineReader]。
List<AiMarkdownBlockEntry> aiMarkdownBlockEntries(
  String markdown, {
  AiMarkdownLineReader? line,
}) {
  final lines = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final entries = <AiMarkdownBlockEntry>[];
  var i = 0;
  while (i < lines.length) {
    final start = i;
    final (:spaces, :content) = _indentOf(lines[i]);
    final depth = spaces ~/ 2;
    final fence = _fenceOpen.firstMatch(content);
    if (fence != null) {
      final (node, next) = _code(lines, i, spaces, fence);
      entries.add((depth: depth, node: node, start: start, end: next));
      i = next;
      continue;
    }
    final noHeader = content.trim() == aiTemplateNoHeaderMarker;
    final tableAt = noHeader ? i + 1 : i;
    if (_isTableStart(lines, tableAt)) {
      final (node, next) = _table(lines, tableAt, headerRow: !noHeader);
      entries.add((depth: depth, node: node, start: start, end: next));
      i = next;
      continue;
    }
    i++;
    // 注释与单独一行的结束标签（模型照 HTML 习惯写成多行时）不成块。
    if (_comment.hasMatch(content) || _closingTag.hasMatch(content)) continue;
    final special = line?.call(content);
    for (final node in special ?? [aiMarkdownLineBlock(content)]) {
      entries.add((depth: depth, node: node, start: start, end: i));
    }
  }
  return entries;
}

({int spaces, String content}) _indentOf(String line) {
  var spaces = 0;
  var index = 0;
  while (index < line.length) {
    final char = line[index];
    if (char == ' ') {
      spaces++;
    } else if (char == '\t') {
      spaces += 2;
    } else {
      break;
    }
    index++;
  }
  return (spaces: spaces, content: _trimRightUnescaped(line.substring(index)));
}

/// 去掉行尾没有转义的空白（`\ ` 留下）。
String _trimRightUnescaped(String text) {
  var end = text.length;
  while (end > 0 && (text[end - 1] == ' ' || text[end - 1] == '\t')) {
    var slashes = 0;
    for (var i = end - 2; i >= 0 && text[i] == r'\'; i--) {
      slashes++;
    }
    if (slashes.isOdd) break;
    end--;
  }
  return text.substring(0, end);
}

/// 按缩进挂成树：比上一行深一层的挂到它下面（它不能有子块时挂到最近的
/// 能有子块的祖先，即提到同一层）；一次多缩进好几层的按一层算。父块的
/// 子块列表不是可追加的 `List<Map<String, Object?>>` 时换成一个新的（原有的
/// 子块排在前面），不改动传进来的列表。
List<Map<String, Object?>> aiNestMarkdownBlocks(
  Iterable<({int depth, Map<String, Object?> node})> entries,
) {
  final roots = <Map<String, Object?>>[];
  final stack = <({int depth, Map<String, Object?> node})>[];
  for (final entry in entries) {
    final depth = stack.isEmpty
        ? 0
        : math.min(entry.depth, stack.last.depth + 1);
    while (stack.isNotEmpty && stack.last.depth >= depth) {
      stack.removeLast();
    }
    final parent = stack.reversed
        .where(
          (item) =>
              kDiaryContainerBlockTypes.contains(item.node[kDiaryBlockTypeKey]),
        )
        .firstOrNull;
    if (parent == null) {
      roots.add(entry.node);
    } else {
      final existing = parent.node[kDiaryBlockChildrenKey];
      if (existing is List<Map<String, Object?>>) {
        existing.add(entry.node);
      } else {
        parent.node[kDiaryBlockChildrenKey] = <Map<String, Object?>>[
          if (existing is List)
            for (final child in existing)
              if (child is Map) child.cast<String, Object?>(),
          entry.node,
        ];
      }
    }
    stack.add((depth: depth, node: entry.node));
  }
  return roots;
}

final RegExp _comment = RegExp(r'^<!--.*-->$');
final RegExp _closingTag = RegExp(r'^</(?:callout|toggle)>$');
final RegExp _divider = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$');
final RegExp _heading = RegExp(r'^(#{1,6})(?:[ \t]+(.*))?$');
final RegExp _todo = RegExp(r'^[-*+][ \t]+\[([ xX])\](?:[ \t]+(.*))?$');
final RegExp _bullet = RegExp(r'^[-*+](?:[ \t]+(.*))?$');
final RegExp _numbered = RegExp(r'^\d{1,9}[.)](?:[ \t]+(.*))?$');
final RegExp _quote = RegExp(r'^>[ \t]*(.*)$');
final RegExp _callout = RegExp(r'^<callout\b([^>]*)>(.*?)(?:</callout>)?$');
final RegExp _toggle = RegExp(r'^<toggle\b([^>]*)>(.*?)(?:</toggle>)?$');
final RegExp _attribute = RegExp(
  r'''([a-zA-Z-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?''',
);

/// 一行（去掉缩进后的内容）读成一个块：分隔线、标题、列表、待办、引用、
/// 提示块、折叠块或段落，行尾 `{…}` 为块属性。返回的块带一个空的子块列表。
Map<String, Object?> aiMarkdownLineBlock(String content) {
  if (_divider.hasMatch(content)) {
    return <String, Object?>{kDiaryBlockTypeKey: kDiaryBlockDivider};
  }
  var line = content;
  final options = <String, String>{};
  final suffix = aiTemplateSuffixPattern.firstMatch(line);
  if (suffix != null) {
    for (final part in suffix.group(1)!.split(RegExp(r'[ \t]+'))) {
      final equals = part.indexOf('=');
      options[part.substring(0, equals)] = part.substring(equals + 1);
    }
    line = _trimRightUnescaped(line.substring(0, suffix.start));
  }

  String type = kDiaryBlockParagraph;
  var text = line;
  final data = <String, Object?>{};
  if (_heading.firstMatch(line) case final match?) {
    type = kDiaryBlockHeading;
    data[kDiaryBlockLevelKey] = match.group(1)!.length;
    text = match.group(2) ?? '';
  } else if (_todo.firstMatch(line) case final match?) {
    type = kDiaryBlockTodoList;
    data[kDiaryBlockCheckedKey] = match.group(1) != ' ';
    text = match.group(2) ?? '';
  } else if (_bullet.firstMatch(line) case final match?) {
    type = kDiaryBlockBulletedList;
    text = match.group(1) ?? '';
  } else if (_numbered.firstMatch(line) case final match?) {
    type = kDiaryBlockNumberedList;
    text = match.group(1) ?? '';
  } else if (_quote.firstMatch(line) case final match?) {
    type = kDiaryBlockQuote;
    text = match.group(1)!;
  } else if (_callout.firstMatch(line) case final match?) {
    type = kDiaryBlockCallout;
    final attributes = _attributes(match.group(1)!);
    if (attributes['icon'] case final icon? when icon.isNotEmpty) {
      data[kDiaryCalloutIconKey] = icon;
    }
    if (attributes['tone'] case final tone? when tone.isNotEmpty) {
      data[kDiaryCalloutToneKey] = tone.toLowerCase();
    }
    text = match.group(2)!.trimLeft();
  } else if (_toggle.firstMatch(line) case final match?) {
    type = kDiaryBlockToggleList;
    final attributes = _attributes(match.group(1)!);
    if (attributes.containsKey('collapsed')) {
      data[kDiaryToggleCollapsedKey] = true;
    } else if (attributes.containsKey('open')) {
      data[kDiaryToggleCollapsedKey] = false;
    }
    text = match.group(2)!.trimLeft();
  }

  data[kDiaryBlockDeltaKey] = aiTemplateInlineDelta(text);
  final align = options['align'];
  if (align == kDiaryAlignCenter ||
      align == kDiaryAlignRight ||
      align == kDiaryAlignJustify) {
    data[kDiaryBlockAlignKey] = align;
  }
  if (type == kDiaryBlockParagraph) {
    switch (options['indent']) {
      case 'on':
        data[kDiaryParagraphIndentKey] = true;
      case 'off':
        data[kDiaryParagraphIndentKey] = false;
    }
  }
  if (options['list'] case final style?) data[kDiaryListStyleKey] = style;
  return <String, Object?>{
    kDiaryBlockTypeKey: type,
    kDiaryBlockChildrenKey: <Map<String, Object?>>[],
    kDiaryBlockDataKey: data,
  };
}

Map<String, String> _attributes(String raw) => <String, String>{
  for (final match in _attribute.allMatches(raw))
    match.group(1)!.toLowerCase():
        match.group(2) ?? match.group(3) ?? match.group(4) ?? '',
};

// ---- 代码块 ----

final RegExp _fenceOpen = RegExp(r'^(`{3,}|~{3,})[ \t]*([^`\s]*)[ \t]*$');

/// 从第 [start] 行的开始围栏读到结束围栏（没有结束时读到最后），返回代码块
/// 与下一行的下标。代码行去掉最多 [indent] 个空格的缩进。
(Map<String, Object?>, int) _code(
  List<String> lines,
  int start,
  int indent,
  RegExpMatch fence,
) {
  final marker = fence.group(1)!;
  final info = fence.group(2)!.trim();
  final close = RegExp(
    '^${RegExp.escape(marker[0])}{${marker.length},}[ \t]*\$',
  );
  final code = <String>[];
  var i = start + 1;
  while (i < lines.length) {
    final line = lines[i];
    i++;
    if (close.hasMatch(line.trim())) break;
    var cut = 0;
    while (cut < indent && cut < line.length && line[cut] == ' ') {
      cut++;
    }
    code.add(line.substring(cut));
  }
  final text = code.join('\n');
  final language = info.isEmpty ? null : normalizeCodeLanguageTag(info) ?? info;
  return (
    <String, Object?>{
      kDiaryBlockTypeKey: kDiaryBlockCode,
      kDiaryBlockDataKey: <String, Object?>{
        kDiaryBlockDeltaKey: <Map<String, Object?>>[
          if (text.isNotEmpty) <String, Object?>{'insert': text},
        ],
        kDiaryBlockLanguageKey: ?language,
      },
    },
    i,
  );
}

// ---- 表格 ----

final RegExp _separator = RegExp(
  r'^\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?$',
);

bool _isTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) return false;
  final header = lines[index].trim();
  final separator = lines[index + 1].trim();
  return header.startsWith('|') &&
      separator.contains('|') &&
      _separator.hasMatch(separator);
}

(Map<String, Object?>, int) _table(
  List<String> lines,
  int start, {
  required bool headerRow,
}) {
  final rows = <List<String>>[_cells(lines[start])];
  var i = start + 2;
  // 紧跟着的下一张表格（表头行 + 分隔行）不并进这张；表体里恰好全是
  // `---` 的一行写出时已转义（见 `aiTemplateBlockLines`），不会被当成分隔行。
  while (i < lines.length &&
      lines[i].trim().startsWith('|') &&
      !_isTableStart(lines, i)) {
    rows.add(_cells(lines[i]));
    i++;
  }
  final cols = rows.first.length;
  return (
    <String, Object?>{
      kDiaryBlockTypeKey: kDiaryBlockTable,
      kDiaryBlockChildrenKey: <Map<String, Object?>>[
        for (final (row, cells) in rows.indexed)
          for (var col = 0; col < cols; col++)
            <String, Object?>{
              kDiaryBlockTypeKey: kDiaryBlockTableCell,
              kDiaryBlockChildrenKey: _cellParagraphs(
                col < cells.length ? cells[col] : '',
              ),
              kDiaryBlockDataKey: <String, Object?>{
                kDiaryTableRowPositionKey: row,
                kDiaryTableColPositionKey: col,
              },
            },
      ],
      kDiaryBlockDataKey: <String, Object?>{
        kDiaryTableColsLenKey: cols,
        kDiaryTableRowsLenKey: rows.length,
        if (headerRow) kDiaryTableHeaderRowKey: true,
      },
    },
    i,
  );
}

/// 一行表格拆成各格原文（按没有转义的 `|` 拆，去掉两端的竖线与空白）。
List<String> _cells(String line) {
  var row = _trimRightUnescaped(line.trim());
  if (row.startsWith('|')) row = row.substring(1);
  if (row.endsWith('|') && !_escapedBefore(row, row.length - 1)) {
    row = row.substring(0, row.length - 1);
  }
  final cells = <String>[];
  final cell = StringBuffer();
  for (var i = 0; i < row.length; i++) {
    final char = row[i];
    if (char == r'\' && i + 1 < row.length) {
      cell
        ..write(char)
        ..write(row[i + 1]);
      i++;
    } else if (char == '|') {
      cells.add(_trimRightUnescaped(cell.toString().trimLeft()));
      cell.clear();
    } else {
      cell.write(char);
    }
  }
  cells.add(_trimRightUnescaped(cell.toString().trimLeft()));
  return cells;
}

bool _escapedBefore(String text, int index) {
  var slashes = 0;
  for (var i = index - 1; i >= 0 && text[i] == r'\'; i--) {
    slashes++;
  }
  return slashes.isOdd;
}

final RegExp _br = RegExp(r'<br\s*/?>', caseSensitive: false);

/// 一格的原文按没有转义的 `<br>` 分成几段。
List<Map<String, Object?>> _cellParagraphs(String cell) {
  final parts = <String>[];
  final part = StringBuffer();
  var i = 0;
  while (i < cell.length) {
    final char = cell[i];
    if (char == r'\' && i + 1 < cell.length) {
      part
        ..write(char)
        ..write(cell[i + 1]);
      i += 2;
      continue;
    }
    final br = char == '<' ? _br.matchAsPrefix(cell, i) : null;
    if (br != null) {
      parts.add(part.toString());
      part.clear();
      i = br.end;
      continue;
    }
    part.write(char);
    i++;
  }
  parts.add(part.toString());
  return <Map<String, Object?>>[
    for (final raw in parts)
      () {
        var text = _trimRightUnescaped(raw.trimLeft());
        String? align;
        final suffix = aiTemplateSuffixPattern.firstMatch(text);
        if (suffix != null) {
          final value = RegExp(r'align=([A-Za-z-]+)').firstMatch(suffix[1]!);
          align = value?.group(1);
          text = _trimRightUnescaped(text.substring(0, suffix.start));
        }
        return <String, Object?>{
          kDiaryBlockTypeKey: kDiaryBlockParagraph,
          kDiaryBlockDataKey: <String, Object?>{
            kDiaryBlockDeltaKey: aiTemplateInlineDelta(text),
            kDiaryBlockAlignKey: ?align,
          },
        };
      }(),
  ];
}
