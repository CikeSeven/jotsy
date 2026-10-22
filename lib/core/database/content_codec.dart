import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

import 'diary_blocks/diary_blocks_codec.dart';
import 'diary_blocks/diary_blocks_from_delta.dart';
import 'diary_blocks/diary_blocks_to_delta.dart';
import 'file_embed_codec.dart';

/// 正文存储与仍使用 Quill 的界面之间的适配层。
/// 历史格式只在读取时转换，保存统一写块文档；这里保留 Quill 对视频块边界
/// 和末尾光标空行的兼容处理，不承担数据库迁移或媒体文件操作。

/// 将纯文本转换为最小可用的 Delta JSON 结构。
String plainTextToDeltaJson(String plainText) {
  final normalized = plainText.endsWith('\n') ? plainText : '$plainText\n';
  return jsonEncode(<Map<String, Object>>[
    <String, Object>{'insert': normalized},
  ]);
}

/// 从任一代正文存储格式提取纯文本镜像。
String diaryContentToPlainText(String content) =>
    diaryBlocksPlainText(decodeStoredDiaryBlocks(content));

/// 将正文存储内容解码为 Quill 文档。
quill.Document decodeDiaryContentToDocument(String rawContent) {
  try {
    return _documentFromDiaryDelta(
      diaryBlocksToQuillOps(decodeStoredDiaryBlocks(rawContent)),
    );
  } catch (_) {
    // 手改的损坏属性可能不被 Quill 接受，至少保留可读文字以供修复。
    return documentFromPlainText(diaryContentToPlainText(rawContent));
  }
}

/// 将富文本正文编码为持久化 JSON。
String encodeDiaryDocumentToJson(quill.Document document) {
  return encodeDiaryBlocks(
    diaryBlocksFromQuillOps(document.toDelta().toJson()),
  );
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

/// 只有媒体或分隔线的草稿也值得保留，不能只凭纯文本镜像判断。
bool diaryContentHasEmbeddedContent(String rawContent) =>
    diaryBlocksHaveEmbeds(decodeStoredDiaryBlocks(rawContent));

/// 从纯文本构建一个最小可编辑文档。
quill.Document documentFromPlainText(String plainText) {
  return quill.Document.fromJson(
    List<dynamic>.from(jsonDecode(plainTextToDeltaJson(plainText)) as List),
  );
}

/// Quill 的 fromJson 会为尾部视频重复补换行，反复打开/保存会让正文持续增长。
/// 在此只补确实缺失的块边界，再从 Delta 建文档，保证解码是幂等的。
quill.Document _documentFromDiaryDelta(List<dynamic> rawOps) {
  final ops = <dynamic>[];
  Object? insertOf(Object? op) => op is Map ? op['insert'] : null;
  for (var i = 0; i < rawOps.length; i++) {
    final op = rawOps[i];
    final insert = insertOf(op);
    if (insert is Map && insert.containsKey('video')) {
      final previous = ops.isEmpty ? null : insertOf(ops.last);
      if (ops.isNotEmpty && (previous is! String || !previous.endsWith('\n'))) {
        ops.add({'insert': '\n'});
      }
      ops.add(op);
      final next = i + 1 < rawOps.length ? insertOf(rawOps[i + 1]) : null;
      if (next is! String || !next.startsWith('\n')) {
        ops.add({'insert': '\n'});
      }
    } else {
      ops.add(op);
    }
  }
  final last = ops.isEmpty ? null : insertOf(ops.last);
  if (last is! String || !last.endsWith('\n')) {
    ops.add({'insert': '\n'});
  }
  final beforeLast = ops.length >= 2 ? insertOf(ops[ops.length - 2]) : null;
  if (insertOf(ops.last) == '\n' &&
      beforeLast is Map &&
      (beforeLast.containsKey('video') ||
          diaryFileEmbedTypes.any(beforeLast.containsKey))) {
    // 仅媒体正文也需要一个可放置光标的末尾空行。
    ops.add({'insert': '\n'});
  }
  return quill.Document.fromDelta(Delta.fromJson(ops));
}

String _normalizePlainText(String text) {
  return text.replaceAll('\uFFFC', '').replaceAll('\r\n', '\n').trimRight();
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
