import 'dart:convert';

import '../legacy_content_codec.dart';
import 'diary_blocks_from_delta.dart';
import 'diary_blocks_schema.dart';
import 'diary_blocks_table.dart';
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
/// 子块时，子块依次提到它后面成为同级，子树里的同样逐级处理；表格按
/// [normalizeDiaryTable] 校验与整理（格子与格内段落保留，其余提到表格
/// 后面，结构无效的表格展开为格子里的内容），表格外的格子换成它里面的块。
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
    final replacement = node is! Map
        ? null
        : switch (node[kDiaryBlockTypeKey]) {
            kDiaryBlockTable => _normalizedTable(node.cast<String, Object?>()),
            // 表格外的格子没有意义（编辑器的格子组件依赖所在的表格）：
            // 换成它里面的块。
            kDiaryBlockTableCell => _unwrappedCell(
              node.cast<String, Object?>(),
            ),
            _ => _liftedNode(node.cast<String, Object?>()),
          };
    if (replacement != null) out ??= nodes.sublist(0, i);
    if (out == null) continue;
    if (replacement != null) {
      out.addAll(replacement);
    } else {
      out.add(node);
    }
  }
  return out;
}

/// 一个普通块修正后的同级块（它自己 + 提出来的子块）；不需要修正时为 null。
List<Object?>? _liftedNode(Map<String, Object?> node) {
  final children = node[kDiaryBlockChildrenKey];
  if (children is! List || children.isEmpty) return null;
  final fixed = _liftHiddenChildren(children);
  if (!kDiaryContainerBlockTypes.contains(node[kDiaryBlockTypeKey])) {
    return [
      {...node}..remove(kDiaryBlockChildrenKey),
      ...(fixed ?? children),
    ];
  }
  return fixed == null
      ? null
      : [
          {...node, kDiaryBlockChildrenKey: fixed},
        ];
}

List<Object?> _unwrappedCell(Map<String, Object?> cell) {
  final children = diaryBlockChildren(cell);
  return _liftHiddenChildren(children) ?? children;
}

/// 表格整理后的同级块；提到表格后面的块（或无效表格展开的内容）同样逐级
/// 修正。表格内部只由 [normalizeDiaryTable] 处理：格子不在
/// [kDiaryContainerBlockTypes] 里，按普通规则会被整片提出来。
List<Object?>? _normalizedTable(Map<String, Object?> table) {
  final normalized = normalizeDiaryTable(table);
  if (normalized == null) return null;
  final following = normalized.following;
  return [?normalized.table, ...(_liftHiddenChildren(following) ?? following)];
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
/// 去掉嵌入占位符后的结果一致，去掉末尾空白。结构有效的表格每行一行、
/// 格与格之间 ` | `（[DiaryTableGrid.rowTexts]），不再逐格逐段各占一行。
String diaryBlocksPlainText(Map<String, Object?> document) {
  final buffer = StringBuffer();
  // 正在跳过的表格所在深度：它的格子与格内段落已经按行写过。
  int? tableDepth;
  for (final (node, depth) in walkDiaryBlocks(document)) {
    if (tableDepth != null) {
      if (depth > tableDepth) continue;
      tableDepth = null;
    }
    final grid = DiaryTableGrid.of(node);
    if (grid != null) {
      tableDepth = depth;
      for (final row in grid.rowTexts()) {
        buffer
          ..write(row)
          ..write('\n');
      }
      continue;
    }
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

/// 是否有可见内容：非空白文字（含表格格子里的段落），或任一媒体 / 分隔线块。
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
