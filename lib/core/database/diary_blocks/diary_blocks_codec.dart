import 'dart:convert';

import '../legacy_content_codec.dart';
import 'diary_blocks_from_delta.dart';
import 'diary_blocks_schema.dart';
import 'diary_blocks_walk.dart';

/// 正文存储内容 ↔ 块文档。
///
/// 库里、备份里、草稿与导入结果里的正文有三代格式，读取时一律经
/// [decodeStoredDiaryBlocks] 收敛为块文档：
/// - 块文档 JSON（当前格式，见 diary_blocks_schema.dart）；
/// - Quill Delta 的 op 列表（2026-03 起到改用块编辑器之前的正文）；
/// - 更早的旧版节点文档（`children` / `root` 结构，经 Quill Delta 中转）。
/// 解析失败或不是 JSON 的内容按纯文本处理，保证任何历史数据都能打开。
/// 写入一律经 [encodeDiaryBlocks]。

/// 解码正文存储内容为块文档；空内容为只有一个空段落的文档。
Map<String, Object?> decodeStoredDiaryBlocks(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return diaryBlocksFromPlainText('');
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return diaryBlocksFromPlainText(raw);
  }
  if (isDiaryBlocksDocument(decoded)) {
    return liftHiddenDiaryBlockChildren(
      (decoded as Map).cast<String, Object?>(),
    );
  }
  if (decoded is List) return diaryBlocksFromQuillOps(decoded);
  if (decoded is Map<String, dynamic>) {
    return diaryBlocksFromQuillOps(legacyDocumentToQuillDelta(decoded));
  }
  // 数字、字符串等合法但不是文档的 JSON：原文就是用户写的字。
  return diaryBlocksFromPlainText(raw);
}

/// 不画子块的块（不在 [kDiaryContainerBlockTypes] 里，如引用、标题）带着
/// 子块时，子块依次提到它后面成为同级，子树里的同样逐级处理。
///
/// 来源：早先旧版正文转换时把引用后面缩进的行挂成了引用的子块，编辑器的
/// 引用块不画子块，这些行在编辑页、预览页都看不见。提到后面只少一级缩进，
/// 阅读顺序不变（纯文本镜像、搜索与导出照旧）；保存后即为修正后的结构。
/// 没有这样的块时原样返回同一个对象，不做拷贝。
Map<String, Object?> liftHiddenDiaryBlockChildren(
  Map<String, Object?> document,
) {
  final page = document[kDiaryBlocksDocumentKey];
  if (page is! Map) return document;
  final children = page[kDiaryBlockChildrenKey];
  if (children is! List) return document;
  final lifted = _liftHiddenChildren(children);
  if (lifted == null) return document;
  return {
    ...document,
    kDiaryBlocksDocumentKey: {
      ...page.cast<String, Object?>(),
      kDiaryBlockChildrenKey: lifted,
    },
  };
}

/// 返回修正后的同级列表；不需要修正时为 null。
List<Object?>? _liftHiddenChildren(List<Object?> nodes) {
  List<Object?>? out;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    Map<String, Object?>? replaced;
    List<Object?>? following;
    if (node is Map) {
      final children = node[kDiaryBlockChildrenKey];
      if (children is List && children.isNotEmpty) {
        final fixed = _liftHiddenChildren(children);
        if (!kDiaryContainerBlockTypes.contains(node[kDiaryBlockTypeKey])) {
          replaced = {...node.cast<String, Object?>()}
            ..remove(kDiaryBlockChildrenKey);
          following = fixed ?? children;
        } else if (fixed != null) {
          replaced = {
            ...node.cast<String, Object?>(),
            kDiaryBlockChildrenKey: fixed,
          };
        }
      }
    }
    if (replaced != null) out ??= nodes.sublist(0, i);
    if (out == null) continue;
    out.add(replaced ?? node);
    if (following != null) out.addAll(following);
  }
  return out;
}

/// 块文档编码为存储用 JSON（紧凑写法，库里的 LIKE 模式依赖这一点）。
String encodeDiaryBlocks(Map<String, Object?> document) => jsonEncode(document);

/// 由纯文本构建块文档：每行一个段落，保留空行。
Map<String, Object?> diaryBlocksFromPlainText(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.endsWith('\n')
      ? normalized.substring(0, normalized.length - 1).split('\n')
      : normalized.split('\n');
  return <String, Object?>{
    kDiaryBlocksDocumentKey: <String, Object?>{
      kDiaryBlockTypeKey: kDiaryBlockPage,
      kDiaryBlockChildrenKey: <Map<String, Object?>>[
        for (final line in lines)
          <String, Object?>{
            kDiaryBlockTypeKey: kDiaryBlockParagraph,
            kDiaryBlockDataKey: <String, Object?>{
              kDiaryBlockDeltaKey: <Map<String, Object?>>[
                if (line.isNotEmpty) <String, Object?>{'insert': line},
              ],
            },
          },
      ],
    },
  };
}

/// 块文档的纯文本镜像（列表摘要、搜索与字数统计的来源）。
///
/// 每个块一行，媒体与分隔线只占一个空行；与 Quill `Document.toPlainText`
/// 去掉嵌入占位符后的结果一致，去掉末尾空白。
String diaryBlocksPlainText(Map<String, Object?> document) {
  final buffer = StringBuffer();
  for (final (node, _) in walkDiaryBlocks(document)) {
    buffer
      ..write(diaryBlockText(node))
      ..write('\n');
  }
  return buffer
      .toString()
      .replaceAll('￼', '')
      .replaceAll('\r\n', '\n')
      .trimRight();
}

/// 是否有可见内容：非空白文字，或任一媒体 / 分隔线块。
bool diaryBlocksHaveVisibleContent(Map<String, Object?> document) {
  for (final (node, _) in walkDiaryBlocks(document)) {
    if (kDiaryEmbedBlockTypes.contains(node[kDiaryBlockTypeKey])) return true;
    if (diaryBlockText(node).trim().isNotEmpty) return true;
  }
  return false;
}

/// 是否含媒体或分隔线（纯文本镜像为空的草稿据此判断是否值得保留）。
bool diaryBlocksHaveEmbeds(Map<String, Object?> document) {
  for (final (node, _) in walkDiaryBlocks(document)) {
    if (kDiaryEmbedBlockTypes.contains(node[kDiaryBlockTypeKey])) return true;
  }
  return false;
}
