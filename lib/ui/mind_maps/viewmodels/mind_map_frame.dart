import 'dart:ui';

import '../layout/mind_map_scene.dart';
import '../models/mind_map_options.dart';

/// 画布上某一帧要画的东西：节点当前的矩形与不透明度。
///
/// 静止时就是布局结果（[MindMapFrame.still]）；文档变化后的转场里由新旧两
/// 份布局按节点 id 插值（[MindMapFrame.lerp]）：两边都有的节点从旧位置移到
/// 新位置；新出现的从父节点处长出、淡入；消失的（删除、收起）缩回仍然可见
/// 的最近祖先、淡出。连线的端点按节点当前矩形现算，所以线跟着节点动。
final class MindMapFrameNode {
  const MindMapFrameNode(this.scene, this.rect, this.opacity);

  final MindMapSceneNode scene;
  final Rect rect;

  /// 0–1。
  final double opacity;

  String get id => scene.id;

  /// 文字等内容相对布局尺寸的缩放（长出 / 缩回途中小于 1）。
  double get scale =>
      scene.rect.width <= 0 ? 1 : (rect.width / scene.rect.width);
}

final class MindMapFrame {
  MindMapFrame._({
    required this.nodes,
    required this.edges,
    required this.guides,
    required this.line,
    required this.spineY,
    required this.structure,
  }) : byId = <String, MindMapFrameNode>{for (final n in nodes) n.id: n};

  /// 静止的一帧：直接是布局结果。
  factory MindMapFrame.still(MindMapScene scene) => MindMapFrame._(
    nodes: <MindMapFrameNode>[
      for (final node in scene.nodes) MindMapFrameNode(node, node.rect, 1),
    ],
    edges: scene.edges,
    guides: scene.guides,
    line: scene.line,
    spineY: scene.spineY,
    structure: scene.structure,
  );

  /// [from] 到 [to] 的转场在进度 [t] 处的一帧（弹簧可能略超过 1）。
  factory MindMapFrame.lerp(MindMapScene from, MindMapScene to, double t) {
    final appear = t.clamp(0.0, 1.0);
    final nodes = <MindMapFrameNode>[];
    // 消失的节点先画：缩回父节点时盖在它下面。
    for (final old in from.nodes) {
      if (to.byId.containsKey(old.id)) continue;
      var target = old.parentId;
      while (target != null && !to.byId.containsKey(target)) {
        target = from.byId[target]?.parentId;
      }
      final center = to.byId[target]?.rect.center ?? old.rect.center;
      final end = Rect.fromCenter(
        center: center,
        width: old.rect.width * 0.2,
        height: old.rect.height * 0.2,
      );
      nodes.add(
        MindMapFrameNode(old, Rect.lerp(old.rect, end, appear)!, 1 - appear),
      );
    }
    for (final node in to.nodes) {
      final before = from.byId[node.id];
      if (before != null) {
        nodes.add(
          MindMapFrameNode(node, Rect.lerp(before.rect, node.rect, t)!, 1),
        );
        continue;
      }
      // 新节点从父节点（转场开始时的位置）长出。
      var source = node.parentId;
      while (source != null && !from.byId.containsKey(source)) {
        source = to.byId[source]?.parentId;
      }
      final origin = from.byId[source]?.rect.center ?? node.rect.center;
      final start = Rect.fromCenter(
        center: origin,
        width: node.rect.width * 0.2,
        height: node.rect.height * 0.2,
      );
      nodes.add(
        MindMapFrameNode(node, Rect.lerp(start, node.rect, t)!, appear),
      );
    }
    final edges = <MindMapSceneEdge>[
      for (final edge in from.edges)
        if (!to.byId.containsKey(edge.childId)) edge,
      ...to.edges,
    ];
    return MindMapFrame._(
      nodes: nodes,
      edges: edges,
      guides: to.guides,
      line: to.line,
      spineY: to.spineY,
      structure: to.structure,
    );
  }

  /// 按绘制顺序。
  final List<MindMapFrameNode> nodes;
  final Map<String, MindMapFrameNode> byId;
  final List<MindMapSceneEdge> edges;
  final List<MindMapSceneGuide> guides;
  final MindMapLineStyle line;
  final double spineY;
  final MindMapStructure structure;
}
