import 'dart:ui';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../layout/mind_map_scene.dart';
import '../models/mind_map_options.dart';

/// 拖动节点时的落点（纯函数，无副作用）。
///
/// 规则：指针落在某个节点上（含 6 像素余量）→ 成为它的最后一个子节点；
/// 否则取离指针最近的节点，按指针在它的前后插成它的同级；离所有节点都太
/// 远时没有落点（松手即取消）。拖动的节点及其子树不能作为落点。
final class MindMapDropTarget {
  const MindMapDropTarget({
    required this.parentId,
    required this.index,
    this.indicator,
    this.side,
  });

  /// 新的父节点。
  final String parentId;

  /// 在新父节点里的下标（按拖动节点挪走之后的子列表计）。
  final int index;

  /// 插成同级时画的落点短线（两个端点，导图坐标）；成为子节点时为 null
  /// （改为高亮父节点）。
  final (Offset, Offset)? indicator;

  /// 落到根下时固定的一侧（左右平衡结构）。
  final String? side;
}

/// 指针在导图坐标 [point] 处时，[dragId] 的落点；没有有效落点为 null。
MindMapDropTarget? planMindMapDrop({
  required MindMapScene scene,
  required MindMapDocument document,
  required String dragId,
  required Offset point,
}) {
  final index = document.index;
  if (!index.contains(dragId) || index.parentOf(dragId) == null) return null;
  final rootId = index.root.id;
  final candidates = <MindMapSceneNode>[
    for (final node in scene.nodes)
      if (!index.isSelfOrAncestor(dragId, node.id)) node,
  ];
  if (candidates.isEmpty) return null;

  String? sideFor(String parentId) {
    if (scene.structure != MindMapStructure.mindMap || parentId != rootId) {
      return null;
    }
    final root = scene.byId[rootId];
    if (root == null) return null;
    return point.dx < root.rect.center.dx
        ? kMindMapSideLeft
        : kMindMapSideRight;
  }

  int adjusted(String parentId, int at) {
    // 同一个父节点里往后挪：先挪走自己，后面的下标都少一。
    if (index.parentOf(dragId) == parentId && index.positionOf(dragId) < at) {
      return at - 1;
    }
    return at;
  }

  bool stacksHorizontally(String? parentId) {
    if (parentId == null) return false;
    final parent = scene.byId[parentId];
    if (parent == null) return false;
    return parent.flow == MindMapFlow.down ||
        parent.flow == MindMapFlow.up ||
        (parentId == rootId &&
            (scene.structure == MindMapStructure.timeline ||
                scene.structure == MindMapStructure.fishbone));
  }

  // 1. 落在某个节点上：落在中间一段时成为它的最后一个子节点；落在前后
  //    边缘时插成它的同级（兄弟排列方向上的前四分之一 / 后四分之一）。
  for (final node in candidates.reversed) {
    if (!node.rect.inflate(6).contains(point)) continue;
    final parentId = node.parentId;
    if (parentId != null) {
      final horizontal = stacksHorizontally(parentId);
      final rect = node.rect;
      final edge = horizontal ? rect.width / 4 : rect.height / 4;
      final along = horizontal ? point.dx - rect.left : point.dy - rect.top;
      final length = horizontal ? rect.width : rect.height;
      if (along < edge || along > length - edge) {
        return _sibling(
          node: node,
          after: along > length / 2,
          horizontal: horizontal,
          document: document,
          dragId: dragId,
          side: sideFor(parentId),
        );
      }
    }
    final children = index[node.id]!.children.length;
    final at = adjusted(node.id, children);
    if (index.parentOf(dragId) == node.id && at == index.positionOf(dragId)) {
      return null;
    }
    return MindMapDropTarget(
      parentId: node.id,
      index: at,
      side: sideFor(node.id),
    );
  }

  // 2. 最近的非根节点：插在它前面或后面。
  MindMapSceneNode? nearest;
  var best = double.infinity;
  for (final node in candidates) {
    if (node.id == rootId) continue;
    final distance = _distanceToRect(point, node.rect);
    if (distance < best) {
      best = distance;
      nearest = node;
    }
  }
  if (nearest == null || best > 96) return null;
  final rect = nearest.rect;
  final horizontal = stacksHorizontally(nearest.parentId);
  return _sibling(
    node: nearest,
    after: horizontal ? point.dx > rect.center.dx : point.dy > rect.center.dy,
    horizontal: horizontal,
    document: document,
    dragId: dragId,
    side: sideFor(nearest.parentId!),
  );
}

/// 插成 [node] 的同级（[after] 为真时在它后面），并给出落点短线。位置没
/// 变时为 null。
MindMapDropTarget? _sibling({
  required MindMapSceneNode node,
  required bool after,
  required bool horizontal,
  required MindMapDocument document,
  required String dragId,
  required String? side,
}) {
  final index = document.index;
  final parentId = node.parentId!;
  var at = index.positionOf(node.id) + (after ? 1 : 0);
  if (index.parentOf(dragId) == parentId && index.positionOf(dragId) < at) {
    at -= 1;
  }
  if (index.parentOf(dragId) == parentId && index.positionOf(dragId) == at) {
    return null;
  }
  const gap = 6.0;
  final rect = node.rect;
  final indicator = horizontal
      ? (
          Offset(after ? rect.right + gap : rect.left - gap, rect.top),
          Offset(after ? rect.right + gap : rect.left - gap, rect.bottom),
        )
      : (
          Offset(rect.left, after ? rect.bottom + gap : rect.top - gap),
          Offset(rect.right, after ? rect.bottom + gap : rect.top - gap),
        );
  return MindMapDropTarget(
    parentId: parentId,
    index: at,
    indicator: indicator,
    side: side,
  );
}

double _distanceToRect(Offset point, Rect rect) {
  final dx = point.dx < rect.left
      ? rect.left - point.dx
      : (point.dx > rect.right ? point.dx - rect.right : 0.0);
  final dy = point.dy < rect.top
      ? rect.top - point.dy
      : (point.dy > rect.bottom ? point.dy - rect.bottom : 0.0);
  return Offset(dx, dy).distance;
}
