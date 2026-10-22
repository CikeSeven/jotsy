import 'diary_blocks_schema.dart';

/// 块文档的只读访问工具：容错读取节点字段，按文档顺序遍历。
///
/// 读取的 JSON 可能来自旧备份、导入或手改数据，字段类型都不可信：类型
/// 不对的字段按缺省处理，绝不抛出。

/// 文档根节点（`document` 键下的 page）；不是块文档时为 null。
Map<String, Object?>? diaryBlocksRoot(Object? document) {
  if (document is! Map) return null;
  final root = document[kDiaryBlocksDocumentKey];
  if (root is! Map || root[kDiaryBlockTypeKey] != kDiaryBlockPage) return null;
  return root.cast<String, Object?>();
}

/// 是否为块文档（`{"document": {"type": "page", …}}`）。
bool isDiaryBlocksDocument(Object? decoded) => diaryBlocksRoot(decoded) != null;

/// 节点的 `data`，缺失或类型不对时为空 Map。
Map<String, Object?> diaryBlockData(Map<String, Object?> node) {
  final data = node[kDiaryBlockDataKey];
  return data is Map ? data.cast<String, Object?>() : const <String, Object?>{};
}

/// 节点的子块，缺失或类型不对时为空列表；跳过不是 Map 的元素。
List<Map<String, Object?>> diaryBlockChildren(Map<String, Object?> node) {
  final children = node[kDiaryBlockChildrenKey];
  if (children is! List) return const <Map<String, Object?>>[];
  return <Map<String, Object?>>[
    for (final child in children)
      if (child is Map) child.cast<String, Object?>(),
  ];
}

/// 文字块的行内 Delta；只保留 `insert` 为字符串的 op。
List<Map<String, Object?>> diaryBlockDelta(Map<String, Object?> node) {
  final delta = diaryBlockData(node)[kDiaryBlockDeltaKey];
  if (delta is! List) return const <Map<String, Object?>>[];
  return <Map<String, Object?>>[
    for (final op in delta)
      if (op is Map && op['insert'] is String) op.cast<String, Object?>(),
  ];
}

/// 文字块的纯文字（代码块含块内换行）；非文字块为空串。
String diaryBlockText(Map<String, Object?> node) {
  final buffer = StringBuffer();
  for (final op in diaryBlockDelta(node)) {
    buffer.write(op['insert']);
  }
  return buffer.toString();
}

/// 按文档顺序（先序、深度优先）遍历全部块，附带深度（顶层为 0）。
Iterable<(Map<String, Object?>, int)> walkDiaryBlocks(
  Map<String, Object?> document,
) sync* {
  final root = diaryBlocksRoot(document);
  if (root == null) return;
  Iterable<(Map<String, Object?>, int)> visit(
    List<Map<String, Object?>> nodes,
    int depth,
  ) sync* {
    for (final node in nodes) {
      yield (node, depth);
      yield* visit(diaryBlockChildren(node), depth + 1);
    }
  }

  yield* visit(diaryBlockChildren(root), 0);
}
