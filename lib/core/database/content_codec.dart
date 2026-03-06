import 'dart:convert';

/// 将纯文本转换为最小可用的 Delta JSON 结构。
///
/// 这里采用单条 `insert` 操作，便于后续无缝接入富文本编辑器。
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

/// 规范化 metadata 字段，保证最终存储为 JSON 对象字符串。
///
/// 规则：
/// 1. 空字符串按空对象 `{}` 处理；
/// 2. 仅允许 JSON 对象，数组/标量直接判定为非法；
/// 3. 返回 `jsonEncode` 后的标准字符串，便于存储与比较。
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
