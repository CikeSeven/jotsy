import 'dart:ui' show Rect;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

/// 拖动段落的几何判断：手指下的落点，以及预览移动后该停在原处的块。
/// 只读节点的全局矩形（上一帧的布局），不改文档。

/// 找纵坐标 [dy]（全局）所在的块（嵌套时取最内层），按上下半区决定落在它
/// 之前还是之后，返回按当前的树解释的目标路径；落在自身、后代或紧邻的
/// 前后位置（等于没动）时为 null。带子块的块只能落在它之前：它“之后”的
/// 位置由下一个同级块的上沿给出。
///
/// 预览会把块真的挪到落点，挪过去后 [dy] 就落在它自己身上，所以不会来回
/// 跳——前提是 [dy] 在视口里（视口外还建着的缓存块会被命中，块会挪到
/// 看不见的地方），由调用方夹好。
af.Path? resolveDiaryBlockDrop(af.Node root, af.Node source, double dy) {
  final hit = _hitBlock(root.children, dy) ?? _edgeBlock(root, dy);
  if (hit == null || hit == source || source.isParentOf(hit)) return null;
  final rect = hit.rect;
  final ownBottom = hit.children.isEmpty
      ? rect.bottom
      : _firstVisibleTop(hit.children) ?? rect.bottom;
  final after = hit.children.isEmpty && dy >= (rect.top + ownBottom) / 2;
  final destination = after ? hit.path.next : hit.path;
  final sourcePath = source.path;
  if (destination.equals(sourcePath) || destination.equals(sourcePath.next)) {
    return null;
  }
  return destination;
}

af.Node? _hitBlock(Iterable<af.Node> nodes, double dy) {
  for (final node in nodes) {
    final rect = node.rect;
    if (rect == Rect.zero || dy < rect.top || dy >= rect.bottom) continue;
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

/// [dy] 在全部可见块的上方或下方（页头、末尾留白）：落到最近的顶层块。
af.Node? _edgeBlock(af.Node root, double dy) {
  af.Node? first;
  af.Node? last;
  for (final node in root.children) {
    if (node.rect == Rect.zero) continue;
    first ??= node;
    last = node;
  }
  if (first == null || last == null) return null;
  return dy < first.rect.top ? first : last;
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
