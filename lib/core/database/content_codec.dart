import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

/// 将纯文本转换为最小可用的 Delta JSON 结构。
String plainTextToDeltaJson(String plainText) {
  final normalized = plainText.endsWith('\n') ? plainText : '$plainText\n';
  return jsonEncode(<Map<String, Object>>[
    <String, Object>{'insert': normalized},
  ]);
}

/// 将 Delta JSON 还原为纯文本。
String deltaJsonToPlainText(String deltaJson) {
  try {
    final decoded = jsonDecode(deltaJson);
    if (decoded is List) {
      final document = quill.Document.fromJson(List<dynamic>.from(decoded));
      return _normalizePlainText(document.toPlainText());
    }
  } catch (_) {
    // Fall through to legacy decode path.
  }

  try {
    final decoded = jsonDecode(deltaJson);
    if (decoded is! List) {
      return deltaJson;
    }

    final buffer = StringBuffer();
    for (final op in decoded) {
      if (op is Map<String, dynamic>) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        }
      }
    }
    return _normalizePlainText(buffer.toString());
  } catch (_) {
    return deltaJson;
  }
}

/// 将正文存储内容解码为 Quill 文档。
quill.Document decodeDiaryContentToDocument(String rawContent) {
  final trimmed = rawContent.trim();
  if (trimmed.isEmpty) {
    return documentFromPlainText('');
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return _ensureRenderableDocument(
        quill.Document.fromJson(List<dynamic>.from(decoded)),
      );
    }
    if (decoded is Map<String, dynamic>) {
      return _ensureRenderableDocument(
        quill.Document.fromJson(_appFlowyDocumentToQuillDelta(decoded)),
      );
    }
  } catch (_) {
    // Fall through to plain text fallback.
  }

  return documentFromPlainText(deltaJsonToPlainText(rawContent));
}

/// 将富文本正文编码为持久化 JSON。
String encodeDiaryDocumentToJson(quill.Document document) {
  return jsonEncode(document.toDelta().toJson());
}

/// 从正文文档提取纯文本镜像，用于列表摘要和搜索。
String extractPlainTextFromDiaryDocument(quill.Document document) {
  return _normalizePlainText(document.toPlainText());
}

/// 判断正文文档是否包含可见内容。
bool diaryDocumentHasVisibleContent(quill.Document document) {
  for (final op in document.toDelta().toJson().cast<Map<String, dynamic>>()) {
    final insert = op['insert'];
    if (insert is String && insert.trim().isNotEmpty) {
      return true;
    }
    if (insert is Map && insert.isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// 从纯文本构建一个最小可编辑文档。
quill.Document documentFromPlainText(String plainText) {
  return quill.Document.fromJson(
    List<dynamic>.from(jsonDecode(plainTextToDeltaJson(plainText)) as List),
  );
}

quill.Document _ensureRenderableDocument(quill.Document document) {
  final delta = document.toDelta().toJson();
  if (delta.isNotEmpty) {
    return document;
  }
  return documentFromPlainText('');
}

List<Map<String, Object>> _appFlowyDocumentToQuillDelta(
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

  final type = rawNode['type'] as String?;
  if (type == 'image') {
    final attributes = rawNode['attributes'];
    final url =
        attributes is Map<String, dynamic> ? attributes['url'] as String? : null;
    if (url != null && url.isNotEmpty) {
      ops.add(<String, Object>{
        'insert': <String, Object>{'image': url},
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

String _normalizePlainText(String text) {
  return text
      .replaceAll('\uFFFC', '')
      .replaceAll('\r\n', '\n')
      .trimRight();
}

/// 规范化 metadata 字段，保证最终存储为 JSON 对象字符串。
String normalizeMetadataJson(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return '{}';
  }

  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('metadata 必须是 JSON 对象');
  }
  return jsonEncode(decoded);
}

/// 校验 metadata 是否为合法 JSON 对象。
bool isValidMetadataJsonObject(String raw) {
  try {
    normalizeMetadataJson(raw);
    return true;
  } catch (_) {
    return false;
  }
}

/// 将 metadata 美化为多行缩进格式，便于在编辑页展示与人工修改。
String prettyMetadataJson(String raw) {
  final normalized = normalizeMetadataJson(raw);
  final decoded = jsonDecode(normalized);
  return const JsonEncoder.withIndent('  ').convert(decoded);
}
