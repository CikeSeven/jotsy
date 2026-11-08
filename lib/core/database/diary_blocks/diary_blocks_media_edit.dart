import 'diary_blocks_media.dart';
import 'diary_blocks_schema.dart';
import 'diary_blocks_walk.dart';

/// 从块文档里移除媒体块（存储管理删除文件时用）。
///
/// - 输入：本次解码得到的独立文档（会被原地修改）与判定函数；
/// - 输出：移除的块数；
/// - 不读写文件，不重算纯文本镜像（调用方经 `diaryBlocksPlainText` 重算）。
///
/// 为什么直接改原始 `children` 列表：`diaryBlockChildren` 返回的是过滤后
/// 的副本，从副本里删不会写回文档。媒体可能在任意层（列表、折叠块等容器
/// 的子块里），所以逐层处理；被删媒体块自己的子块（坏数据才会有）提到原
/// 位置，正文文字一个字也不丢。
///
/// 旧版 `quill_embed` 的一个块可能装着多个嵌入键：命中的键逐个删掉，键删空
/// 时整块移除。删完根下没有块时补一个空段落，与新建空文档的结构一致（编辑
/// 器需要至少一个可落光标的段落）。
int removeDiaryBlocksMedia(
  Map<String, Object?> document,
  bool Function(DiaryBlockMediaKind kind, String path) shouldRemove,
) {
  final root = diaryBlocksRoot(document);
  if (root == null) return 0;
  final removed = _removeFrom(root, shouldRemove);
  final children = root[kDiaryBlockChildrenKey];
  if (removed > 0 && (children is! List || children.isEmpty)) {
    root[kDiaryBlockChildrenKey] = <Object?>[
      <String, Object?>{
        kDiaryBlockTypeKey: kDiaryBlockParagraph,
        kDiaryBlockDataKey: <String, Object?>{kDiaryBlockDeltaKey: <Object?>[]},
      },
    ];
  }
  return removed;
}

int _removeFrom(
  Map<Object?, Object?> parent,
  bool Function(DiaryBlockMediaKind kind, String path) shouldRemove,
) {
  final children = parent[kDiaryBlockChildrenKey];
  if (children is! List) return 0;
  var removed = 0;
  final next = <Object?>[];
  for (final child in children) {
    if (child is! Map) {
      next.add(child);
      continue;
    }
    final node = child.cast<String, Object?>();
    removed += _removeFrom(node, shouldRemove);
    switch (_matchNode(node, shouldRemove)) {
      case _NodeMatch.keep:
        next.add(child);
      case _NodeMatch.trimmed:
        removed++;
        next.add(child);
      case _NodeMatch.remove:
        removed++;
        final orphans = node[kDiaryBlockChildrenKey];
        if (orphans is List) next.addAll(orphans);
    }
  }
  if (removed > 0) parent[kDiaryBlockChildrenKey] = next;
  return removed;
}

enum _NodeMatch { keep, trimmed, remove }

_NodeMatch _matchNode(
  Map<String, Object?> node,
  bool Function(DiaryBlockMediaKind kind, String path) shouldRemove,
) {
  final data = diaryBlockData(node);
  if (node[kDiaryBlockTypeKey] != kDiaryBlockUnknownEmbed) {
    final media = diaryBlockMediaOf(node[kDiaryBlockTypeKey], data);
    final path = media?.path;
    if (media == null || path == null || !shouldRemove(media.kind, path)) {
      return _NodeMatch.keep;
    }
    return _NodeMatch.remove;
  }
  final value = data[kDiaryBlockValueKey];
  if (value is! Map) return _NodeMatch.keep;
  final kept = <Object?, Object?>{};
  var dropped = false;
  for (final entry in value.entries) {
    final media = diaryBlockMediaOf(entry.key, entry.value);
    final path = media?.path;
    if (media != null && path != null && shouldRemove(media.kind, path)) {
      dropped = true;
    } else {
      kept[entry.key] = entry.value;
    }
  }
  if (!dropped) return _NodeMatch.keep;
  if (kept.isEmpty) return _NodeMatch.remove;
  node[kDiaryBlockDataKey] = Map<String, Object?>.of(data)
    ..[kDiaryBlockValueKey] = kept;
  return _NodeMatch.trimmed;
}
