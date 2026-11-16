import 'dart:math' as math;
import 'dart:ui';

import '../layout/mind_map_scene.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_frame.dart';

/// 连线的几何（纯函数）：端点由两端节点当前的矩形算出，路径按连线样式生成。
///
/// 画布、缩略图与导出共用。转场途中节点在动，所以端点不存进布局结果，而是
/// 每帧现算。

/// 连线 [edge] 在这一帧的起点与终点；端点所在的节点不在帧里时为 null。
(Offset, Offset)? mindMapEdgeEnds(MindMapSceneEdge edge, MindMapFrame frame) {
  final parent = frame.byId[edge.parentId];
  final child = frame.byId[edge.childId];
  if (parent == null || child == null) return null;
  final p = parent.rect;
  final c = child.rect;
  final pv = parent.scene.visual;
  final cv = child.scene.visual;
  switch (edge.route) {
    case MindMapEdgeRoute.horizontal:
      final right = c.center.dx >= p.center.dx;
      // 曲线时，根节点（实底）的连线从根的中心长出，藏在根下面：分支像
      // 从根里伸出来的一束，而不是贴着边。
      final fromCenter =
          parent.scene.depth == 0 &&
          frame.line == MindMapLineStyle.curve &&
          pv.fill != null &&
          pv.shape.boxed;
      final start = fromCenter
          ? p.center
          : Offset(
              right ? p.right : p.left,
              pv.underline ? p.bottom : p.center.dy,
            );
      final end = Offset(
        right ? c.left : c.right,
        cv.underline ? c.bottom : c.center.dy,
      );
      return (start, end);
    case MindMapEdgeRoute.vertical:
      final down = c.center.dy >= p.center.dy;
      return (
        Offset(p.center.dx, down ? p.bottom : p.top),
        Offset(c.center.dx, down ? c.top : c.bottom),
      );
    case MindMapEdgeRoute.indent:
      final up = c.center.dy < p.center.dy;
      return (
        Offset(p.left + MindMapScene.indentStem, up ? p.top : p.bottom),
        Offset(c.left, cv.underline ? c.bottom : c.center.dy),
      );
    case MindMapEdgeRoute.boneMain:
      final (spine, end) = _bone(c, frame.spineY);
      return (spine, end);
    case MindMapEdgeRoute.boneBranch:
      final (spine, end) = _bone(p, frame.spineY);
      final y = cv.underline ? c.bottom : c.center.dy;
      final span = spine.dy - end.dy;
      final t = span == 0 ? 0.0 : ((y - end.dy) / span).clamp(0.0, 1.0);
      final x = end.dx + (spine.dx - end.dx) * t;
      return (Offset(x, y), Offset(c.right, y));
  }
}

/// 大骨：主骨上的起点与接到一级主题的终点。
(Offset, Offset) _bone(Rect node, double spineY) {
  final top = node.center.dy < spineY;
  final end = Offset(node.center.dx, top ? node.bottom : node.top);
  final rise = (end.dy - spineY).abs();
  return (Offset(end.dx + rise * MindMapScene.boneSlope, spineY), end);
}

/// 按连线样式生成描边路径（锥形曲线另见 [mindMapTaperedCurve]）。
Path mindMapEdgePath(
  MindMapEdgeRoute route,
  MindMapLineStyle style,
  Offset start,
  Offset end,
) {
  final path = Path()..moveTo(start.dx, start.dy);
  switch (route) {
    case MindMapEdgeRoute.boneMain || MindMapEdgeRoute.boneBranch:
      path.lineTo(end.dx, end.dy);
    case MindMapEdgeRoute.indent:
      // 缩进连线一律是竖干 + 圆角横接，与样式无关：直线斜穿列表很乱。
      final radius = style == MindMapLineStyle.elbow
          ? 0.0
          : math.min(
              8.0,
              math.min((end.dy - start.dy).abs(), (end.dx - start.dx).abs()),
            );
      final dirY = end.dy >= start.dy ? 1.0 : -1.0;
      path.lineTo(start.dx, end.dy - dirY * radius);
      if (radius > 0) {
        path.quadraticBezierTo(start.dx, end.dy, start.dx + radius, end.dy);
      }
      path.lineTo(end.dx, end.dy);
    case MindMapEdgeRoute.horizontal:
      final dx = end.dx - start.dx;
      switch (style) {
        case MindMapLineStyle.curve:
          path.cubicTo(
            start.dx + dx * 0.5,
            start.dy,
            start.dx + dx * 0.5,
            end.dy,
            end.dx,
            end.dy,
          );
        case MindMapLineStyle.straight:
          path.lineTo(end.dx, end.dy);
        case MindMapLineStyle.elbow || MindMapLineStyle.rounded:
          final mid = start.dx + dx * 0.5;
          _elbow(
            path,
            start,
            Offset(mid, start.dy),
            Offset(mid, end.dy),
            end,
            style == MindMapLineStyle.rounded,
          );
      }
    case MindMapEdgeRoute.vertical:
      final dy = end.dy - start.dy;
      switch (style) {
        case MindMapLineStyle.curve:
          path.cubicTo(
            start.dx,
            start.dy + dy * 0.5,
            end.dx,
            start.dy + dy * 0.5,
            end.dx,
            end.dy,
          );
        case MindMapLineStyle.straight:
          path.lineTo(end.dx, end.dy);
        case MindMapLineStyle.elbow || MindMapLineStyle.rounded:
          final mid = start.dy + dy * 0.5;
          _elbow(
            path,
            start,
            Offset(start.dx, mid),
            Offset(end.dx, mid),
            end,
            style == MindMapLineStyle.rounded,
          );
      }
  }
  return path;
}

/// 折线 start → a → b → end；[rounded] 时两个拐角带圆角。
void _elbow(
  Path path,
  Offset start,
  Offset a,
  Offset b,
  Offset end,
  bool rounded,
) {
  if (!rounded) {
    path
      ..lineTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(end.dx, end.dy);
    return;
  }
  void corner(Offset from, Offset at, Offset to) {
    final r = math.min(
      10.0,
      math.min((at - from).distance, (to - at).distance) / 2,
    );
    if (r <= 0.5) {
      path.lineTo(at.dx, at.dy);
      return;
    }
    final inDir = (at - from) / (at - from).distance;
    final outDir = (to - at) / (to - at).distance;
    final p1 = at - inDir * r;
    final p2 = at + outDir * r;
    path
      ..lineTo(p1.dx, p1.dy)
      ..quadraticBezierTo(at.dx, at.dy, p2.dx, p2.dy);
  }

  corner(start, a, b);
  corner(a, b, end);
  path.lineTo(end.dx, end.dy);
}

/// 由粗到细的曲线（填充路径）：沿三次贝塞尔取样，按法线向两侧展开，宽度
/// 从 [startWidth] 线性收到 [endWidth]。根部的连线用它，像枝干一样渐细。
Path mindMapTaperedCurve(
  Offset start,
  Offset end, {
  required bool horizontal,
  required double startWidth,
  required double endWidth,
}) {
  final c1 = horizontal
      ? Offset((start.dx + end.dx) / 2, start.dy)
      : Offset(start.dx, (start.dy + end.dy) / 2);
  final c2 = horizontal
      ? Offset((start.dx + end.dx) / 2, end.dy)
      : Offset(end.dx, (start.dy + end.dy) / 2);
  const samples = 22;
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i <= samples; i++) {
    final t = i / samples;
    final mt = 1 - t;
    final point =
        start * (mt * mt * mt) +
        c1 * (3 * mt * mt * t) +
        c2 * (3 * mt * t * t) +
        end * (t * t * t);
    final tangent =
        (c1 - start) * (3 * mt * mt) +
        (c2 - c1) * (6 * mt * t) +
        (end - c2) * (3 * t * t);
    final length = tangent.distance;
    final normal = length == 0
        ? const Offset(0, 1)
        : Offset(-tangent.dy / length, tangent.dx / length);
    final half = (startWidth + (endWidth - startWidth) * t) / 2;
    left.add(point + normal * half);
    right.add(point - normal * half);
  }
  final path = Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}
