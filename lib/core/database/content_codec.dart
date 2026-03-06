import 'dart:convert';

/// Stores plain text as a minimal Quill-like Delta JSON array.
String plainTextToDeltaJson(String plainText) {
  final normalized = plainText.endsWith('\n') ? plainText : '$plainText\n';
  return jsonEncode(<Map<String, String>>[
    <String, String>{'insert': normalized},
  ]);
}

/// Converts a minimal Delta JSON array back to plain text for editing.
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

/// Ensures metadata is a valid JSON object string.
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

bool isValidMetadataJsonObject(String raw) {
  try {
    normalizeMetadataJson(raw);
    return true;
  } catch (_) {
    return false;
  }
}

String prettyMetadataJson(String raw) {
  final normalized = normalizeMetadataJson(raw);
  final decoded = jsonDecode(normalized);
  return const JsonEncoder.withIndent('  ').convert(decoded);
}
