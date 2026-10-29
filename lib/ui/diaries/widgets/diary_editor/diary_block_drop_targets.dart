import 'dart:ui' show Rect;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../controllers/diary_block_reorder.dart';

/// 拖动段落的几何判断：手指下的落点，以及预览移动后该停在原处的块。
/// 只读节点的全局矩形（上一帧的布局），不改文档。

/// 纵坐标 [dy]（全局）处的落点：先定落在哪条缝（[DiaryBlockGaps]），再在
/// 缝里取最接近 [depth] 的层级，返回按当前的树解释的目标路径；落在自身、
/// 后代或等于没动时为 null。
///
/// 缝按手指所在的块（嵌套时取最内层；表格整个算一块，格子与格内段落不是
/// 落点）找：在它自身文字的上半区为它之前，下半区为它之后。带子块的块只取之前——它“之后”就是第一个子块之前，
/// 由子块的上半区给出。手指不在任何块上（页头、末尾留白、块之间的空隙、
/// 父块里子块之外的部分）时，取下方最近的块之前，下方没有块时取最后一个
/// 可见块之后。
///
/// 层级按拖动开始时的 [depth] 取，不跟着手指所在的块：缩进的段落拖到哪里
/// 都还是缩进的（接到上一块的子块里），顶层段落拖过列表也不会被并进去，
/// 除非那条缝只容得下更深的层级。
///
/// 预览会把块真的挪到落点，挪过去后 [dy] 就落在它自己身上，所以不会来回
/// 跳——前提是 [dy] 在视口里（视口外还建着的缓存块会被命中，块会挪到
/// 看不见的地方），由调用方夹好。
af.Path? resolveDiaryBlockDrop(
  af.Node root,
  af.Node source,
  double dy, {
  required int depth,
}) {
  final hit = _hitBlock(root.children, dy);
  if (hit == source || (hit != null && source.isParentOf(hit))) return null;
  final gaps = DiaryBlockGaps(root, source);
  final gap = hit == null ? null : _gapOn(gaps, hit, dy);
  final destination = gaps.destination(gap ?? _gapBelow(gaps, dy), depth);
  if (destination == null) return null;
  final sourcePath = source.path;
  if (destination.equals(sourcePath) || destination.equals(sourcePath.next)) {
    return null;
  }
  return destination;
}

/// 手指在 [hit] 自身文字上时的缝；在它的子块区域里（子块之间的空隙）时
/// 为 null，交给 [_gapBelow]。
int? _gapOn(DiaryBlockGaps gaps, af.Node hit, double dy) {
  final index = gaps.blocks.indexOf(hit);
  final rect = hit.rect;
  final atomic = hit.type == kDiaryBlockTable;
  final ownBottom = atomic
      ? rect.bottom
      : _firstVisibleTop(hit.children) ?? rect.bottom;
  if (dy >= ownBottom) return null;
  // 被拖的块自己挂在它下面时不算子块：否则手指停在它的下半区，块会在
  // “它之前”与“它的子块”之间来回跳。
  final hasChildren =
      !atomic && hit.children.any((child) => child != gaps.source);
  return !hasChildren && dy >= (rect.top + ownBottom) / 2 ? index + 1 : index;
}

/// 下方最近的可见块之前；下方没有时为最后一个可见块之后。
int _gapBelow(DiaryBlockGaps gaps, double dy) {
  var gap = 0;
  for (var i = 0; i < gaps.blocks.length; i++) {
    final rect = gaps.blocks[i].rect;
    if (rect == Rect.zero) continue;
    if (rect.top > dy) return i;
    gap = i + 1;
  }
  return gap;
}

af.Node? _hitBlock(Iterable<af.Node> nodes, double dy) {
  for (final node in nodes) {
    final rect = node.rect;
    if (rect == Rect.zero || dy < rect.top || dy >= rect.bottom) continue;
    if (node.type == kDiaryBlockTable) return node;
    return _hitBlock(node.children, dy) ?? node;
  }
  return null;
}

double? _firstVisibleTop(Iterable<af.Node> nodes) {
  for (final node in nodes) {
    final rect = node.rect;
    if (rect != Rect.zero) return rect.top;
  }
  return null;
}

/// 把 [source] 移到 [destination] 之前，挑一个不受这次移动影响的顶层块，
/// 返回它与它的前缘在视口里的比例（0 顶端、1 底端）。
///
/// 为什么需要：上游的长列表（ScrollablePositionedList）以某一项为锚点向上
/// 向下排版，跳转过（如揭示光标）锚点就停在那一项。块移过锚点、或块自己
/// 就是锚点时，锚点上换成了别的块，高度不同整页就会错开——手指下的落点
/// 跟着变，块就上下来回跳。移动后让列表改以这一块为锚点、停在原处，排版
/// 就与普通列表一致。
///
/// 受影响的是两处所在的顶层块及其之间的块；只挑完全在视口里的块
/// （锚点比例必须在 0–1 之间），先找上方的，没有再找下方的。[viewportTop]、
/// [viewportHeight] 是列表视口的全局位置与高度，[itemInset] 是列表项在块
/// 之上的内边距。
(af.Node, double)? diaryBlockDragAnchor(
  af.Node root, {
  required af.Path from,
  required af.Path destination,
  required double viewportTop,
  required double viewportHeight,
  double itemInset = 0,
}) {
  if (viewportHeight <= 0) return null;
  final a = from.first;
  final b = destination.first;
  final low = a < b ? a : b;
  final high = a < b ? b : a;
  (af.Node, double)? below;
  final blocks = root.children.toList();
  for (var i = 0; i < blocks.length; i++) {
    if (i >= low && i <= high) continue;
    final rect = blocks[i].rect;
    if (rect == Rect.zero) continue;
    final leading = rect.top - itemInset - viewportTop;
    if (leading < 0 || rect.bottom > viewportTop + viewportHeight) continue;
    final anchor = (blocks[i], leading / viewportHeight);
    if (i < low) return anchor;
    below ??= anchor;
  }
  return below;
}
