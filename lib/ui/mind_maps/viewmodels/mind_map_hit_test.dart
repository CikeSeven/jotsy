import 'dart:ui';

import 'package:flutter/painting.dart' show AxisDirection;

import '../layout/mind_map_scene.dart';
import 'mind_map_frame.dart';

/// 画布上的命中测试与方向键导航（纯函数）。

/// 点中了什么。
sealed class MindMapHit {
  const MindMapHit();
}

/// 点在节点上。
final class MindMapNodeHit extends MindMapHit {
  const MindMapNodeHit(this.id);

  final String id;
}

/// 点在收起 / 展开徽标上。
final class MindMapToggleHit extends MindMapHit {
  const MindMapToggleHit(this.id);

  final String id;
}

/// 空白处。
final class MindMapEmptyHit extends MindMapHit {
  const MindMapEmptyHit();
}

/// 导图坐标 [point] 处点中的东西。徽标优先（它们挨着节点边缘）；[slop] 为
/// 额外的命中余量（触屏更大），按屏幕像素换算后传入。[selectedId] 有子节点
/// 时它的“收起”圆钮也能点。
MindMapHit hitTestMindMap(
  MindMapFrame frame,
  Offset point, {
  double slop = 0,
  String? selectedId,
}) {
  for (final node in frame.nodes.reversed) {
    final scene = node.scene;
    final hasToggle =
        scene.hiddenCount > 0 || (scene.id == selectedId && scene.hasChildren);
    if (!hasToggle) continue;
    final center = scene.toggleCenter + (node.rect.center - scene.rect.center);
    if ((point - center).distance <= 12 + slop) {
      return MindMapToggleHit(scene.id);
    }
  }
  for (final node in frame.nodes.reversed) {
    if (node.opacity < 0.5) continue;
    if (node.rect.inflate(slop).contains(point)) {
      return MindMapNodeHit(node.id);
    }
  }
  return const MindMapEmptyHit();
}

/// 方向键：从 [fromId] 朝 [direction] 走到画面上最合适的下一个节点。
///
/// 只看画面位置，与结构无关：候选是中心落在那个方向的半平面里的节点，
/// 得分 = 沿方向的距离 + 2 × 偏离方向的距离，取最小。没有候选时为 null。
String? mindMapNeighbour(
  MindMapScene scene,
  String fromId,
  AxisDirection direction,
) {
  final from = scene.byId[fromId];
  if (from == null) return null;
  final origin = from.rect.center;
  String? best;
  var bestScore = double.infinity;
  for (final node in scene.nodes) {
    if (node.id == fromId) continue;
    final delta = node.rect.center - origin;
    final (along, across) = switch (direction) {
      AxisDirection.right => (delta.dx, delta.dy.abs()),
      AxisDirection.left => (-delta.dx, delta.dy.abs()),
      AxisDirection.down => (delta.dy, delta.dx.abs()),
      AxisDirection.up => (-delta.dy, delta.dx.abs()),
    };
    if (along <= 1) continue;
    final score = along + across * 2;
    if (score < bestScore) {
      bestScore = score;
      best = node.id;
    }
  }
  return best;
}
