import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_from_delta.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_table.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import 'diary_template_body.dart';

/// 模板 v2 的树结构白名单。只重建允许的类型与字段：即使媒体节点藏在
/// children、未知块或额外 metadata 中，也不会把私有路径带到模板码里。
/// 旧 v1 Delta 先经既有白名单清洗，再转换；新树从不投影为平铺行，保留嵌套。
///
/// 富文本块只留各自的结构字段：标注的图标（单个字形的短字符串）与底色
/// 档位（[kDiaryCalloutTones] 之一），折叠列表的 `collapsed`（bool）与
/// 子块，结构有效的表格（[DiaryTableGrid] 认得）只留行列数、表头行与格子
/// 位置，格子里只留段落文字；不合法的字段单独丢弃，结构无效的表格与其他
/// 未知块一样只保留其中的文字。行内上下标只认 super / sub。
Map<String, Object?> sanitizeDiaryTemplateBlocks(Object? raw) {
  Object? decoded = raw;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      decoded = null;
    }
  }
  final document = isDiaryBlocksDocument(decoded)
      ? (decoded as Map).cast<String, Object?>()
      : diaryBlocksFromQuillOps(sanitizeDiaryTemplateOps(decoded));
  List<Map<String, Object?>> clean(List<Map<String, Object?>> nodes) {
    final result = <Map<String, Object?>>[];
    for (final node in nodes) {
      final type = node['type'];
      if (type == kDiaryBlockTable) {
        final grid = DiaryTableGrid.of(node);
        if (grid != null) {
          result.add(_table(grid));
          continue;
        }
      }
      final children = clean(diaryBlockChildren(node));
      if (type == 'divider') {
        result.add({'type': 'divider'});
        result.addAll(children);
      } else if (kDiaryTextBlockTypes.contains(type)) {
        final source = diaryBlockData(node);
        final data = <String, Object?>{
          'delta': _delta(node),
          if (type == 'heading' && source['level'] is num)
            'level': (source['level'] as num).toInt().clamp(1, 6),
          if (type == 'todo_list') 'checked': source['checked'] == true,
          if (source['align'] case final String align
              when ['center', 'right', 'justify'].contains(align))
            'align': align,
          if (type == 'code' && source['language'] is String)
            'language': source['language'],
          if (sanitizeDiaryListStyleId(type, source[kDiaryListStyleKey])
              case final String listStyle)
            kDiaryListStyleKey: listStyle,
          if (type == kDiaryBlockCallout) ...{
            kDiaryCalloutIconKey: ?_calloutIcon(source[kDiaryCalloutIconKey]),
            if (source[kDiaryCalloutToneKey] case final String tone
                when kDiaryCalloutTones.contains(tone))
              kDiaryCalloutToneKey: tone,
          },
          if (type == kDiaryBlockToggleList &&
              source[kDiaryToggleCollapsedKey] is bool)
            kDiaryToggleCollapsedKey: source[kDiaryToggleCollapsedKey],
        };
        // 不画子块的块（标题、引用、代码块）的子块提到它后面，与正文读取
        // 时的修正（liftHiddenDiaryBlockChildren）一致。
        final nests = kDiaryContainerBlockTypes.contains(type);
        result.add({
          'type': type,
          if (nests && children.isNotEmpty) 'children': children,
          'data': data,
        });
        if (!nests) result.addAll(children);
      } else {
        // 媒体与未知块自身丢弃；仍保留其中允许的后代文字。
        result.addAll(children);
      }
    }
    return result;
  }

  final children = clean(diaryBlockChildren(diaryBlocksRoot(document)!));
  return children.isEmpty
      ? diaryBlocksFromPlainText('')
      : {
          'document': {'type': 'page', 'children': children},
        };
}

/// 文字块的行内 Delta：空片段去掉，行内属性经 [_inline] 白名单。
List<Map<String, Object?>> _delta(Map<String, Object?> node) => [
  for (final op in diaryBlockDelta(node))
    if ((op['insert'] as String).isNotEmpty)
      {
        'insert': op['insert'],
        if (_inline(op['attributes']) case final attrs? when attrs.isNotEmpty)
          'attributes': attrs,
      },
];

/// 标注图标：单个字形、不超过 8 个 UTF-16 单位的非空白字符串（emoji 的
/// 组合序列也在其内）；其他值丢弃，显示时回落默认图标。
String? _calloutIcon(Object? raw) {
  if (raw is! String || raw.length > 8 || raw.trim().isEmpty) return null;
  return raw.characters.length == 1 ? raw : null;
}

/// 结构有效的表格按行列重建：只留行列数、表头行与格子位置；每格只留
/// 其中的文字块（按文档顺序）换成的段落（行内属性经白名单，保留对齐），
/// 媒体与其他块丢弃，空格子补一个空段落。
Map<String, Object?> _table(DiaryTableGrid grid) => {
  'type': kDiaryBlockTable,
  'children': <Map<String, Object?>>[
    for (var row = 0; row < grid.rows; row++)
      for (var col = 0; col < grid.cols; col++)
        {
          'type': kDiaryBlockTableCell,
          'children': _cellParagraphs(grid, row, col),
          'data': <String, Object?>{
            kDiaryTableRowPositionKey: row,
            kDiaryTableColPositionKey: col,
          },
        },
  ],
  'data': <String, Object?>{
    kDiaryTableColsLenKey: grid.cols,
    kDiaryTableRowsLenKey: grid.rows,
    if (grid.headerRow) kDiaryTableHeaderRowKey: true,
  },
};

List<Map<String, Object?>> _cellParagraphs(
  DiaryTableGrid grid,
  int row,
  int col,
) {
  final paragraphs = <Map<String, Object?>>[
    for (final block in grid.textBlocksAt(row, col))
      {
        'type': kDiaryBlockParagraph,
        'data': <String, Object?>{
          'delta': _delta(block),
          if (diaryBlockData(block)['align'] case final String align
              when ['center', 'right', 'justify'].contains(align))
            'align': align,
        },
      },
  ];
  return paragraphs.isEmpty
      ? <Map<String, Object?>>[
          {
            'type': kDiaryBlockParagraph,
            'data': <String, Object?>{'delta': <Map<String, Object?>>[]},
          },
        ]
      : paragraphs;
}

Map<String, Object?>? _inline(Object? raw) {
  if (raw is! Map) return null;
  final result = <String, Object?>{};
  for (final key in ['bold', 'italic', 'underline', 'strikethrough', 'code']) {
    if (raw[key] == true) result[key] = true;
  }
  for (final key in ['font_color', 'bg_color', 'size']) {
    final value = raw[key];
    if (value is String || value is num) result[key] = value;
  }
  if (raw[kDiaryInlineScript] case final String script
      when script == kDiaryScriptSuper || script == kDiaryScriptSub) {
    result[kDiaryInlineScript] = script;
  }
  final href = raw['href'];
  if (href is String &&
      ['https', 'http', 'mailto', 'tel'].contains(Uri.tryParse(href)?.scheme)) {
    result['href'] = href;
  }
  return result;
}

/// 变量只改每段行内文字，不改变其格式或父子结构。
Map<String, Object?> resolveDiaryTemplateBlockText(
  Map<String, Object?> document,
  String Function(String) resolve,
) {
  final copy = sanitizeDiaryTemplateBlocks(document);
  for (final (node, _) in walkDiaryBlocks(copy)) {
    final delta = diaryBlockData(node)['delta'];
    if (delta is! List) continue;
    for (final op in delta) {
      if (op is Map && op['insert'] is String) {
        op['insert'] = resolve(op['insert'] as String);
      }
    }
  }
  return copy;
}
