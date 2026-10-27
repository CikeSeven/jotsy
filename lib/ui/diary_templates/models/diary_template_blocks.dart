import 'dart:convert';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_from_delta.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import 'diary_template_body.dart';

/// 模板 v2 的树结构白名单。只重建允许的类型与字段：即使媒体节点藏在
/// children、未知块或额外 metadata 中，也不会把私有路径带到模板码里。
/// 旧 v1 Delta 先经既有白名单清洗，再转换；新树从不投影为平铺行，保留嵌套。
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
      final children = clean(diaryBlockChildren(node));
      final type = node['type'];
      if (type == 'divider') {
        result.add({'type': 'divider'});
        result.addAll(children);
      } else if (kDiaryTextBlockTypes.contains(type)) {
        final source = diaryBlockData(node);
        final data = <String, Object?>{
          'delta': <Map<String, Object?>>[
            for (final op in diaryBlockDelta(node))
              if ((op['insert'] as String).isNotEmpty)
                {
                  'insert': op['insert'],
                  if (_inline(op['attributes']) case final attrs?
                      when attrs.isNotEmpty)
                    'attributes': attrs,
                },
          ],
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
