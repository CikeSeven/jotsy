import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_blocks/diary_blocks_codec.dart';
import 'diary_blocks/diary_blocks_from_delta.dart';

/// 正文与原生编辑文档之间的编解码；历史数据只在读取时转换，写入一律为树。
String plainTextToContentJson(String text) =>
    encodeDiaryBlocks(diaryBlocksFromPlainText(text));

String diaryContentToPlainText(String content) =>
    diaryBlocksPlainText(decodeStoredDiaryBlocks(content));

af.Document decodeDiaryContentToDocument(String content) {
  final document = decodeStoredDiaryBlocks(content);
  try {
    final decoded = af.Document.fromJson(jsonDecode(jsonEncode(document)));
    if (decoded.root.children.isEmpty) decoded.root.insert(af.paragraphNode());
    return decoded;
  } catch (_) {
    // 历史手改的结构字段可能损坏：保留可读正文，避免加载失败阻断编辑。
    return documentFromPlainText(diaryBlocksPlainText(document));
  }
}

String encodeDiaryDocumentToJson(af.Document document) =>
    encodeDiaryBlocks(document.toJson());
String extractPlainTextFromDiaryDocument(af.Document document) =>
    diaryBlocksPlainText(document.toJson());
bool diaryDocumentHasVisibleContent(af.Document document) =>
    diaryBlocksHaveVisibleContent(document.toJson());
bool diaryContentHasEmbeddedContent(String content) =>
    diaryBlocksHaveEmbeds(decodeStoredDiaryBlocks(content));
af.Document documentFromPlainText(String text) => af.Document.fromJson(
  jsonDecode(encodeDiaryBlocks(diaryBlocksFromPlainText(text))),
);

/// 历史导入与模板 v1 的操作列表转换入口，不依赖旧编辑器。
af.Document documentFromLegacyDelta(List<Object?> ops) => af.Document.fromJson(
  jsonDecode(encodeDiaryBlocks(diaryBlocksFromQuillOps(ops))),
);

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
