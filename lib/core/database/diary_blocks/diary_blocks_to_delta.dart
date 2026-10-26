import 'dart:convert';

import '../audio_embed_codec.dart';
import '../divider_embed_codec.dart';
import '../file_embed_codec.dart';
import 'diary_blocks_schema.dart';
import 'diary_blocks_walk.dart';

/// 把块文档投影为平铺的 Quill Delta。
///
/// 供仍按行读取正文的模块使用（PDF 预处理与历史兼容性调用）：嵌套按深度写成 `indent`，与 [diaryBlocksFromQuillOps]
/// 互逆——由 Delta 转来的文档投影回去逐 op 相同。块文档能表达而 Delta 不能
/// 的结构（例如引用下挂的列表）按深度缩进展开，读取方看到的是缩进的行。
///
/// 输出的 Delta 以换行结尾；空文档为单个换行。纯函数，无 IO。
List<Map<String, Object?>> diaryBlocksToQuillOps(
  Map<String, Object?> document,
) {
  final ops = <Map<String, Object?>>[];
  for (final (node, depth) in walkDiaryBlocks(document)) {
    _appendNode(ops, node, depth);
  }
  if (ops.isEmpty) ops.add(<String, Object?>{'insert': '\n'});
  return ops;
}

void _appendNode(
  List<Map<String, Object?>> ops,
  Map<String, Object?> node,
  int depth,
) {
  final type = node[kDiaryBlockTypeKey];
  final data = diaryBlockData(node);
  final indent = <String, Object?>{if (depth > 0) 'indent': depth};

  if (type == kDiaryBlockCode) {
    final language = data[kDiaryBlockLanguageKey];
    final lineAttributes = <String, Object?>{
      'code-block': language is String && language.isNotEmpty ? language : true,
      ...indent,
    };
    // 代码块里的每一行在 Delta 里各自以带 code-block 的换行结尾。
    for (final op in diaryBlockDelta(node)) {
      final text = op['insert'];
      if (text is! String) continue;
      final parts = text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) _insert(ops, '\n', lineAttributes);
        _insert(ops, parts[i], _quillInline(op['attributes']));
      }
    }
    _insert(ops, '\n', lineAttributes);
    return;
  }

  if (kDiaryTextBlockTypes.contains(type)) {
    for (final op in diaryBlockDelta(node)) {
      final text = op['insert'];
      if (text is String) _insert(ops, text, _quillInline(op['attributes']));
    }
    _insert(ops, '\n', <String, Object?>{
      ..._lineAttributes(type, data),
      ...indent,
    });
    return;
  }

  final align = data[kDiaryBlockAlignKey];
  final lineAttributes = <String, Object?>{
    if (align is String && align.isNotEmpty) 'align': align,
    ...indent,
  };
  switch (type) {
    case kDiaryBlockImage:
      final url = data[kDiaryBlockUrlKey];
      if (url is! String) return;
      ops.add(<String, Object?>{
        'insert': <String, Object?>{'image': url},
        if (_imageAttributes(data) case final attributes?)
          'attributes': attributes,
      });
    case kDiaryBlockVideo:
      final url = data[kDiaryBlockUrlKey];
      if (url is! String) return;
      ops.add(<String, Object?>{
        'insert': <String, Object?>{'video': url},
      });
    case kDiaryBlockAudio:
      ops.add(<String, Object?>{
        'insert': <String, Object?>{diaryAudioEmbedType: jsonEncode(data)},
      });
    case kDiaryBlockAttachment:
      ops.add(<String, Object?>{
        'insert': <String, Object?>{diaryAttachmentEmbedType: jsonEncode(data)},
      });
    case kDiaryBlockDivider:
      ops.add(<String, Object?>{
        'insert': Map<String, Object?>.of(diaryDividerEmbed),
      });
    case kDiaryBlockUnknownEmbed:
      final value = data[kDiaryBlockValueKey];
      if (value is! Map || value.isEmpty) return;
      ops.add(<String, Object?>{'insert': value});
    default:
      // 认不出的块类型（更新版本写入的新块）没有可投影的内容，略过。
      return;
  }
  _insert(ops, '\n', lineAttributes);
}

Map<String, Object?> _lineAttributes(Object? type, Map<String, Object?> data) {
  final align = data[kDiaryBlockAlignKey];
  return <String, Object?>{
    if (type == kDiaryBlockHeading) 'header': _headingLevel(data),
    if (type == kDiaryBlockBulletedList) 'list': 'bullet',
    if (type == kDiaryBlockNumberedList) 'list': 'ordered',
    if (type == kDiaryBlockTodoList)
      'list': data[kDiaryBlockCheckedKey] == true ? 'checked' : 'unchecked',
    if (type == kDiaryBlockQuote) 'blockquote': true,
    if (align is String && align.isNotEmpty) 'align': align,
  };
}

int _headingLevel(Map<String, Object?> data) {
  final level = data[kDiaryBlockLevelKey];
  return level is num && level.isFinite ? level.toInt().clamp(1, 6) : 1;
}

Map<String, Object?>? _imageAttributes(Map<String, Object?> data) {
  final attributes = <String, Object?>{
    for (final key in const ['width', 'height', 'style'])
      if (data[key] case final value?) key: value,
  };
  return attributes.isEmpty ? null : attributes;
}

Map<String, Object?> _quillInline(Object? attributes) {
  if (attributes is! Map) return const <String, Object?>{};
  return <String, Object?>{
    for (final entry in attributes.entries)
      if (entry.key is String && entry.value != null)
        kDiaryToQuillInlineKeys[entry.key] ?? entry.key as String: entry.value,
  };
}

/// 追加一段文字（含换行），与前一段属性相同时合并；换行符的属性是行级
/// 属性，不与文字合并以免改变行的格式。
void _insert(
  List<Map<String, Object?>> ops,
  String text,
  Map<String, Object?> attributes,
) {
  if (text.isEmpty) return;
  if (ops.isNotEmpty) {
    final last = ops.last;
    final lastInsert = last['insert'];
    final lastAttributes =
        last['attributes'] as Map<String, Object?>? ??
        const <String, Object?>{};
    if (lastInsert is String && _sameAttributes(lastAttributes, attributes)) {
      last['insert'] = '$lastInsert$text';
      return;
    }
  }
  ops.add(<String, Object?>{
    'insert': text,
    if (attributes.isNotEmpty)
      'attributes': Map<String, Object?>.of(attributes),
  });
}

bool _sameAttributes(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
