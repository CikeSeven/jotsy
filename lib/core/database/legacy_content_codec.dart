import 'dart:convert';

import 'audio_embed_codec.dart';
import 'file_embed_codec.dart';

/// 将旧版 AppFlowy 节点映射为 Quill Delta，保留媒体引用及其 metadata。
/// 无文件 IO；实际恢复位置由备份服务处理。
List<Map<String, Object>> legacyDocumentToQuillDelta(
  Map<String, dynamic> rawDocument,
) {
  final ops = <Map<String, Object>>[];
  for (final node in _extractChildren(rawDocument)) {
    _appendAppFlowyNode(node, ops);
  }

  if (ops.isEmpty) {
    return <Map<String, Object>>[
      <String, Object>{'insert': '\n'},
    ];
  }

  final lastInsert = ops.last['insert'];
  if (lastInsert is! String || !lastInsert.endsWith('\n')) {
    ops.add(<String, Object>{'insert': '\n'});
  }
  return ops;
}

List<dynamic> _extractChildren(Map<String, dynamic> node) {
  final directChildren = node['children'];
  if (directChildren is List) {
    return directChildren;
  }
  final root = node['root'];
  if (root is Map<String, dynamic>) {
    final rootChildren = root['children'];
    if (rootChildren is List) {
      return rootChildren;
    }
  }
  return const <dynamic>[];
}

void _appendAppFlowyNode(dynamic rawNode, List<Map<String, Object>> ops) {
  if (rawNode is! Map<String, dynamic>) {
    return;
  }

  final rawType = rawNode['type'];
  final type = rawType is String ? rawType : null;
  final attributes = rawNode['attributes'];
  if (type == diaryAudioEmbedType) {
    if (DiaryAudioAttachment.tryDecode(attributes) != null) {
      ops.add(<String, Object>{
        'insert': <String, Object>{
          diaryAudioEmbedType: attributes is String
              ? attributes
              : jsonEncode(attributes),
        },
      });
      ops.add(<String, Object>{'insert': '\n'});
    }
    return;
  }
  if (type == 'video' || diaryFileEmbedTypes.contains(type)) {
    final file = DiaryFileAttachment.tryDecode(attributes);
    if (file != null) {
      ops.add(<String, Object>{
        'insert': <String, Object>{
          type == 'video' ? 'video' : diaryAttachmentEmbedType: type == 'video'
              ? file.path
              : attributes is Map
              ? jsonEncode(attributes)
              : attributes is String
              ? attributes
              : file.encode(),
        },
        if (type == 'video' && attributes is Map)
          'attributes': <String, Object?>{
            for (final entry in attributes.entries)
              if (entry.key is String &&
                  entry.key != 'url' &&
                  entry.key != 'path')
                entry.key as String: entry.value,
          },
      });
      ops.add(<String, Object>{'insert': '\n'});
    }
    return;
  }
  if (type == 'image') {
    final url = attributes is Map ? attributes['url'] : null;
    if (url is String && url.isNotEmpty) {
      ops.add(<String, Object>{
        'insert': <String, Object>{'image': url},
        if (attributes is Map)
          'attributes': <String, Object?>{
            for (final key in const ['width', 'height', 'style'])
              if (attributes[key] case final value?) key: value,
          },
      });
      ops.add(<String, Object>{'insert': '\n'});
    }
    return;
  }

  final text = _extractAppFlowyNodeText(rawNode);
  if (text.isNotEmpty) {
    ops.add(<String, Object>{'insert': text});
  }

  if (_isBlockNode(type) && (text.isNotEmpty || type == 'paragraph')) {
    ops.add(<String, Object>{'insert': '\n'});
  }

  for (final child in _extractChildren(rawNode)) {
    _appendAppFlowyNode(child, ops);
  }
}

String _extractAppFlowyNodeText(Map<String, dynamic> rawNode) {
  final attributes = rawNode['attributes'];
  if (attributes is! Map<String, dynamic>) {
    return '';
  }

  final delta = attributes['delta'];
  if (delta is! List) {
    return '';
  }

  final buffer = StringBuffer();
  for (final op in delta) {
    if (op is Map<String, dynamic>) {
      final insert = op['insert'];
      if (insert is String) {
        buffer.write(insert);
      }
    }
  }

  return buffer.toString().replaceAll(RegExp(r'\n+$'), '');
}

bool _isBlockNode(String? type) {
  return switch (type) {
    'paragraph' => true,
    'quote' => true,
    'bulleted_list' => true,
    'numbered_list' => true,
    'todo_list' => true,
    'heading' => true,
    'code_block' => true,
    _ => false,
  };
}
