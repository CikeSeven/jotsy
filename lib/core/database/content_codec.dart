import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

/// 将纯文本转换为最小可用的 Delta JSON 结构。
///
/// 这里保留旧方法，仅用于兼容历史数据读取路径。
/// 为兼容常见 Delta 语义，末尾统一补一个换行符。
String plainTextToDeltaJson(String plainText) {
  final normalized = plainText.endsWith('\n') ? plainText : '$plainText\n';
  return jsonEncode(<Map<String, String>>[
    <String, String>{'insert': normalized},
  ]);
}

/// 将 Delta JSON 还原为编辑器使用的纯文本。
///
/// 若格式异常（例如历史数据不是合法 Delta），直接回退原始字符串，
/// 避免读取阶段抛错导致页面不可用。
String deltaJsonToPlainText(String deltaJson) {
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

    final text = buffer.toString();
    if (text.endsWith('\n')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  } catch (_) {
    return deltaJson;
  }
}

/// 将日记正文存储内容解码为 AppFlowy 可编辑文档。
Document decodeDiaryContentToDocument(String rawContent) {
  final trimmed = rawContent.trim();
  if (trimmed.isNotEmpty) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final document = _ensureRenderableDocument(Document.fromJson(decoded));
        if (_looksLikeRenderableBlockDocument(document)) {
          return document;
        }
      }
    } catch (_) {
      // Fall through to legacy decode path.
    }
  }

  final plainText = deltaJsonToPlainText(rawContent);
  return documentFromPlainText(plainText);
}

/// 将富文本正文编码为持久化 JSON。
String encodeDiaryDocumentToJson(Document document) {
  final safeDocument = _ensureRenderableDocument(document);
  return jsonEncode(safeDocument.toJson());
}

/// 从正文文档提取纯文本镜像，用于列表摘要和搜索。
String extractPlainTextFromDiaryDocument(Document document) {
  final blocks = document.root.children;
  final parts = <String>[];

  for (final node in blocks) {
    final text = _nodePlainText(node);
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }

  return parts.join('\n').trim();
}

/// 判断正文文档是否包含可见内容。
bool diaryDocumentHasVisibleContent(Document document) {
  for (final node in document.root.children) {
    if (node.type == 'image') {
      return true;
    }
    if (_nodePlainText(node).isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// 从纯文本构建一个最小可编辑文档。
Document documentFromPlainText(String plainText) {
  final normalized = plainText.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  final children =
      lines.map((String line) => paragraphNode(text: line)).toList(growable: true);

  if (children.isEmpty) {
    children.add(paragraphNode());
  }

  return Document(root: Node(type: 'page', children: children));
}

Document _ensureRenderableDocument(Document document) {
  if (document.root.children.isNotEmpty) {
    return document;
  }
  return documentFromPlainText('');
}

bool _looksLikeRenderableBlockDocument(Document document) {
  if (document.root.children.isEmpty) {
    return false;
  }
  for (final node in document.root.children) {
    if (node.type == 'text') {
      return false;
    }
  }
  return true;
}

String _nodePlainText(Node node) {
  final parts = <String>[];

  final delta = node.delta;
  if (delta != null) {
    final text =
        delta
            .toPlainText()
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }

  for (final child in node.children) {
    final text = _nodePlainText(child);
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }

  return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
