import 'package:flutter/foundation.dart' show mapEquals;

import '../database/code_block_codec.dart';
import '../database/diary_blocks/diary_blocks_builder.dart';
import '../database/diary_blocks/diary_blocks_embed.dart';
import '../database/diary_blocks/diary_blocks_schema.dart';
import '../database/diary_blocks/diary_blocks_table.dart';

/// 一行导入内容：文字行（[delta] + 块属性）、媒体行（[embed]）或调用方
/// 建好的结构块（[node]，如表格，原样进入文档）。
typedef JournalBlockLine = ({
  List<Map<String, Object?>> delta,
  Map<String, Object?> attributes,
  Map<String, Object?>? embed,
  Map<String, Object?>? node,
});

/// 导入器已经按行整理过空白与媒体；直接产出节点，避免先生成整份历史 Delta
/// 再解析。行内键与媒体字段仍复用存储 schema 的映射，嵌套由共用 builder 建树。
Map<String, Object?> buildJournalImportBlocks(List<JournalBlockLine> lines) {
  final builder = DiaryBlocksBuilder();
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    final attributes = line.attributes;
    final rawIndent = attributes['indent'];
    final indent = rawIndent is num && rawIndent.isFinite
        ? rawIndent.toInt()
        : 0;
    if (line.node != null) {
      builder.add(line.node!, indent);
      index++;
      continue;
    }
    if (line.embed != null) {
      builder.add(
        diaryBlockFromQuillEmbed(line.embed!, const {}, attributes),
        indent,
      );
      index++;
      continue;
    }
    final code = attributes['code-block'];
    if (code != null && code != false) {
      final language = codeBlockExplicitLanguage(code);
      final delta = <Map<String, Object?>>[];
      var first = true;
      while (index < lines.length) {
        final next = lines[index];
        final nextCode = next.attributes['code-block'];
        if (next.embed != null ||
            next.node != null ||
            nextCode == null ||
            nextCode == false ||
            codeBlockExplicitLanguage(nextCode) != language ||
            (next.attributes['indent'] ?? 0) != indent) {
          break;
        }
        if (!first) _append(delta, '\n', const {});
        first = false;
        for (final op in next.delta) {
          _append(
            delta,
            op['insert'] as String,
            op['attributes'] is Map
                ? Map<String, Object?>.from(op['attributes'] as Map)
                : const {},
          );
        }
        index++;
      }
      builder.add({
        'type': 'code',
        'data': {'delta': delta, if (language != null) 'language': language},
      }, indent);
      continue;
    }
    final header = attributes['header'];
    final list = attributes['list'];
    final toggle = attributes['toggle'] == true;
    final type = switch (list) {
      _ when toggle => kDiaryBlockToggleList,
      'bullet' => 'bulleted_list',
      'ordered' => 'numbered_list',
      'checked' || 'unchecked' => 'todo_list',
      _ when header is num && header.isFinite && header >= 1 => 'heading',
      _ when attributes['blockquote'] == true => 'quote',
      _ => 'paragraph',
    };
    final delta = <Map<String, Object?>>[];
    for (final op in line.delta) {
      _append(
        delta,
        op['insert'] as String,
        op['attributes'] is Map
            ? Map<String, Object?>.from(op['attributes'] as Map)
            : const {},
      );
    }
    builder.add({
      'type': type,
      'data': {
        'delta': delta,
        if (type == 'heading') 'level': (header as num).toInt().clamp(1, 6),
        if (type == 'todo_list') 'checked': list == 'checked',
        if (toggle) kDiaryToggleCollapsedKey: attributes['collapsed'] == true,
        if (attributes['align'] case final String align) 'align': align,
      },
    }, indent);
    index++;
  }
  return builder.build();
}

void _append(
  List<Map<String, Object?>> delta,
  String text,
  Map<String, Object?> source,
) {
  if (text.isEmpty) return;
  final attributes = <String, Object?>{
    for (final entry in source.entries)
      kQuillToDiaryInlineKeys[entry.key] ?? entry.key: entry.value,
  };
  if (delta.isNotEmpty &&
      mapEquals(delta.last['attributes'] as Map? ?? const {}, attributes)) {
    delta.last['insert'] = '${delta.last['insert']}$text';
  } else {
    delta.add({
      'insert': text,
      if (attributes.isNotEmpty) 'attributes': attributes,
    });
  }
}

/// 由导入来源里规整的表格建表格节点（结构见 diary_blocks_schema.dart 的
/// [kDiaryBlockTable]）：[rows] 为 `[行][列]` → 这一格的段落（至少一个，
/// 不带子块）。格子按行优先排列。调用方保证每行列数相同、行列数不超过
/// [journalImportTableFits]，这样读取时 DiaryTableGrid 认得、原样保留。
Map<String, Object?> journalImportTableNode(
  List<List<List<Map<String, Object?>>>> rows, {
  bool headerRow = false,
}) => {
  kDiaryBlockTypeKey: kDiaryBlockTable,
  kDiaryBlockChildrenKey: <Map<String, Object?>>[
    for (final (row, cells) in rows.indexed)
      for (final (col, body) in cells.indexed)
        {
          kDiaryBlockTypeKey: kDiaryBlockTableCell,
          kDiaryBlockChildrenKey: body,
          kDiaryBlockDataKey: <String, Object?>{
            kDiaryTableRowPositionKey: row,
            kDiaryTableColPositionKey: col,
          },
        },
  ],
  kDiaryBlockDataKey: <String, Object?>{
    kDiaryTableColsLenKey: rows.first.length,
    kDiaryTableRowsLenKey: rows.length,
    if (headerRow) kDiaryTableHeaderRowKey: true,
  },
};

/// 行列数是否能建成表格（至少一行一列，不超过 [kDiaryTableMaxRows] /
/// [kDiaryTableMaxCols]）；超出的按原来的方式写成文字。
bool journalImportTableFits(int rows, int cols) =>
    rows >= 1 &&
    cols >= 1 &&
    rows <= kDiaryTableMaxRows &&
    cols <= kDiaryTableMaxCols;

/// 一格的内容是否都是可放进格子的段落（没有子块）：媒体、列表、标题等
/// 块级结构出现时整个表格不规整。
bool journalImportCellIsInline(List<Map<String, Object?>> body) => body.every(
  (node) =>
      node[kDiaryBlockTypeKey] == kDiaryBlockParagraph &&
      node[kDiaryBlockChildrenKey] == null,
);
