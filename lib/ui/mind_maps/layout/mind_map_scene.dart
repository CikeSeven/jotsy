import 'package:flutter/painting.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_visuals.dart';
import 'mind_map_node_content.dart';

/// 布局的产物：每个可见节点的位置与外观、每条连线的走向，以及整体边界。
///
/// 只描述“画在哪里”，不含视口与选中态；画布、缩略图与导出都按它绘制。
/// 坐标为导图坐标（根节点大致在原点附近，单位为逻辑像素，未缩放）。

/// 子节点相对父节点展开的方向，决定连线的起止锚点与收起徽标的位置。
enum MindMapFlow {
  right,
  left,
  down,
  up,

  /// 缩进式（树形目录 / 时间线下挂的列表）：从父节点左下竖直往下再横向接到
  /// 子节点左侧。
  indentDown,

  /// 时间线上方的列表：从父节点左上竖直往上。
  indentUp,
}

/// 一个可见节点。
final class MindMapSceneNode {
  MindMapSceneNode({
    required this.node,
    required this.parentId,
    required this.depth,
    required this.rect,
    required this.visual,
    required this.text,
    required this.placeholder,
    required this.flow,
    required this.hiddenCount,
    required this.content,
  });

  final MindMapNode node;
  final String? parentId;
  final int depth;
  final Rect rect;
  final MindMapNodeVisual visual;

  /// 排好版的文字（没写字时为占位文字，见 [placeholder]）。
  final TextPainter text;
  final bool placeholder;

  /// 它的子节点往哪个方向展开。
  final MindMapFlow flow;

  /// 收起时被藏起来的子孙数；没收起为 0。
  final int hiddenCount;

  /// 节点框里的内容排版（文字、待办框、贴纸、标记、标签的位置）。
  final MindMapNodeContent content;

  String get id => node.id;

  bool get hasChildren => node.children.isNotEmpty;

  /// 同一个节点换到 [other] 处（转场中途再变时，以当前画面为起点）。
  MindMapSceneNode at(Rect other) => MindMapSceneNode(
    node: node,
    parentId: parentId,
    depth: depth,
    rect: other,
    visual: visual,
    text: text,
    placeholder: placeholder,
    flow: flow,
    hiddenCount: hiddenCount,
    content: content,
  );

  /// 收起 / 展开徽标的中心（子节点出去的那一侧）。
  Offset get toggleCenter {
    const gap = 13.0;
    final anchorY = visual.underline ? rect.bottom : rect.center.dy;
    return switch (flow) {
      MindMapFlow.right => Offset(rect.right + gap, anchorY),
      MindMapFlow.left => Offset(rect.left - gap, anchorY),
      MindMapFlow.down => Offset(rect.center.dx, rect.bottom + gap),
      MindMapFlow.up => Offset(rect.center.dx, rect.top - gap),
      MindMapFlow.indentDown => Offset(
        rect.left + MindMapScene.indentStem,
        rect.bottom + gap,
      ),
      MindMapFlow.indentUp => Offset(
        rect.left + MindMapScene.indentStem,
        rect.top - gap,
      ),
    };
  }
}

/// 连线的走向。
enum MindMapEdgeRoute {
  /// 横向：起点在父节点的右 / 左侧，终点在子节点的左 / 右侧。
  horizontal,

  /// 纵向：父节点下 / 上边中点到子节点上 / 下边中点。
  vertical,

  /// 缩进：父节点左下的竖干，横接到子节点左侧。
  indent,

  /// 鱼骨图的大骨：从主骨上的一点斜向接到一级主题（起点由子节点位置与
  /// 主骨推出）。
  boneMain,

  /// 鱼骨图的小骨：从所在大骨上与子节点同高的一点横向接到子节点。
  boneBranch,
}

/// 一条连线（父 → 子）。端点由画的时候按两端节点当前的矩形算出，转场时
/// 节点在动，线跟着动。
final class MindMapSceneEdge {
  const MindMapSceneEdge({
    required this.parentId,
    required this.childId,
    required this.route,
    required this.color,
    required this.width,
    required this.taper,
  });

  final String parentId;
  final String childId;
  final MindMapEdgeRoute route;
  final Color color;
  final double width;

  /// 曲线时是否画成由粗到细的锥形（根部的连线）。
  final bool taper;
}

/// 结构本身的装饰线（时间线的轴、鱼骨图的主骨），在连线之下绘制。
final class MindMapSceneGuide {
  const MindMapSceneGuide({
    required this.from,
    required this.to,
    required this.color,
    required this.width,
    this.arrow = false,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double width;

  /// 终点画箭头（时间线的方向）。
  final bool arrow;
}

/// 一次布局的结果。
final class MindMapScene {
  MindMapScene({
    required this.nodes,
    required this.edges,
    required this.guides,
    required this.structure,
    required this.line,
    this.spineY = 0,
  }) : byId = <String, MindMapSceneNode>{for (final n in nodes) n.id: n},
       bounds = _boundsOf(nodes, guides);

  /// 缩进连线的竖干离节点左边的距离。
  static const double indentStem = 14;

  /// 按绘制顺序（父在子前）。
  final List<MindMapSceneNode> nodes;
  final Map<String, MindMapSceneNode> byId;
  final List<MindMapSceneEdge> edges;
  final List<MindMapSceneGuide> guides;
  final MindMapStructure structure;
  final MindMapLineStyle line;

  /// 鱼骨图主骨的纵坐标。
  final double spineY;

  /// 鱼骨图大骨的斜率（每升高 1 往左偏移多少）：60° 斜骨。
  static const double boneSlope = 0.577;

  /// 全部节点（含收起徽标的位置）的外接矩形。
  final Rect bounds;

  static Rect _boundsOf(
    List<MindMapSceneNode> nodes,
    List<MindMapSceneGuide> guides,
  ) {
    if (nodes.isEmpty) return Rect.zero;
    var rect = nodes.first.rect;
    for (final node in nodes) {
      rect = rect.expandToInclude(node.rect);
      if (node.hiddenCount > 0) {
        rect = rect.expandToInclude(
          Rect.fromCircle(center: node.toggleCenter, radius: 12),
        );
      }
    }
    for (final guide in guides) {
      rect = rect.expandToInclude(Rect.fromPoints(guide.from, guide.to));
    }
    return rect;
  }
}
