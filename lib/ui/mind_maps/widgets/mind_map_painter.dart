import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../layout/mind_map_scene.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_drop_planner.dart';
import '../viewmodels/mind_map_frame.dart';
import '../viewmodels/mind_map_palette.dart';
import 'mind_map_edge_paths.dart';

/// 导图的绘制（画布、卡片缩略图与导出共用同一份代码，画面一致）。
///
/// 输入：一帧 [MindMapFrame]（布局结果或转场中的插值）与 [MindMapPaintOptions]
/// （选中、编辑、拖动等交互态）；在导图坐标系里画，视口变换由调用方先施加
/// 在 canvas 上。[visible] 给出时只画与之相交的节点与连线（大图按视口裁剪）。
/// 绘制顺序：点阵 → 结构装饰线 → 连线 → 节点 → 交互态（拖动中的节点最后画）。

/// 拖动中的节点：它在导图坐标里的位置与当前的落点。
@immutable
final class MindMapDragPaint {
  const MindMapDragPaint({
    required this.id,
    required this.offset,
    required this.target,
  });

  final String id;

  /// 拖动节点相对原位置的位移（导图坐标）。
  final Offset offset;
  final MindMapDropTarget? target;
}

@immutable
final class MindMapPaintOptions {
  const MindMapPaintOptions({
    required this.palette,
    this.selectedIds = const <String>{},
    this.editingId,
    this.hoverId,
    this.drag,
    this.grid = false,
    this.highlightIds = const <String>{},
  });

  final MindMapPalette palette;
  final Set<String> selectedIds;

  /// 正在编辑文字的节点：文字由输入框画，这里只画外框。
  final String? editingId;
  final String? hoverId;
  final MindMapDragPaint? drag;

  /// 画布点阵。
  final bool grid;

  /// 查找命中的节点（淡色高亮）。
  final Set<String> highlightIds;
}

/// 在 [canvas] 上画一帧。[zoom] 为当前缩放（点阵按屏幕像素保持大小）。
void paintMindMap(
  Canvas canvas,
  MindMapFrame frame,
  MindMapPaintOptions options, {
  Rect? visible,
  double zoom = 1,
}) {
  if (options.grid && visible != null) {
    _paintGrid(canvas, visible, options.palette.dot, zoom);
  }
  for (final guide in frame.guides) {
    _paintGuide(canvas, guide);
  }
  final dragId = options.drag?.id;
  for (final edge in frame.edges) {
    final ends = mindMapEdgeEnds(edge, frame);
    if (ends == null) continue;
    final (start, end) = ends;
    if (visible != null &&
        !visible.inflate(40).overlaps(Rect.fromPoints(start, end))) {
      continue;
    }
    final parent = frame.byId[edge.parentId]!;
    final child = frame.byId[edge.childId]!;
    var opacity = math.min(parent.opacity, child.opacity);
    if (dragId != null && edge.childId == dragId) opacity *= 0.3;
    _paintEdge(canvas, edge, frame.line, start, end, opacity);
  }
  MindMapFrameNode? dragged;
  for (final node in frame.nodes) {
    if (node.id == dragId) {
      dragged = node;
      continue;
    }
    if (visible != null && !visible.inflate(24).overlaps(node.rect)) continue;
    _paintNode(canvas, node, options, opacity: node.opacity);
  }
  if (options.drag case final drag?) {
    if (drag.target case final target?) {
      _paintDropTarget(canvas, frame, target, options.palette);
    }
    if (dragged != null) {
      // 原位留一个淡影，拖动的节点跟着手指。
      _paintNode(
        canvas,
        dragged,
        options,
        opacity: 0.28,
        ignoreSelection: true,
      );
      final moved = MindMapFrameNode(
        dragged.scene,
        dragged.rect.shift(drag.offset),
        1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          moved.rect.inflate(2),
          const Radius.circular(14),
        ),
        Paint()
          ..color = options.palette.onSurface.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      _paintNode(canvas, moved, options, opacity: 0.94, ignoreSelection: true);
    }
  }
}

void _paintGrid(Canvas canvas, Rect visible, Color color, double zoom) {
  if (zoom < 0.42) return;
  const spacing = 28.0;
  final left = (visible.left / spacing).floor() * spacing;
  final top = (visible.top / spacing).floor() * spacing;
  final columns = (visible.width / spacing).ceil() + 1;
  final rows = (visible.height / spacing).ceil() + 1;
  if (columns * rows > 9000) return;
  final points = <Offset>[
    for (var c = 0; c < columns; c++)
      for (var r = 0; r < rows; r++)
        Offset(left + c * spacing, top + r * spacing),
  ];
  canvas.drawPoints(
    ui.PointMode.points,
    points,
    Paint()
      ..color = color
      ..strokeWidth = 2.4 / zoom
      ..strokeCap = StrokeCap.round,
  );
}

void _paintGuide(Canvas canvas, MindMapSceneGuide guide) {
  final paint = Paint()
    ..color = guide.color
    ..strokeWidth = guide.width
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(guide.from, guide.to, paint);
  if (guide.arrow) {
    final dir = (guide.to - guide.from);
    final length = dir.distance;
    if (length == 0) return;
    final unit = dir / length;
    final normal = Offset(-unit.dy, unit.dx);
    final tip = guide.to + unit * 4;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (tip - unit * 12 + normal * 7).dx,
        (tip - unit * 12 + normal * 7).dy,
      )
      ..lineTo(
        (tip - unit * 12 - normal * 7).dx,
        (tip - unit * 12 - normal * 7).dy,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = guide.color);
  }
}

void _paintEdge(
  Canvas canvas,
  MindMapSceneEdge edge,
  MindMapLineStyle line,
  Offset start,
  Offset end,
  double opacity,
) {
  if (opacity <= 0.01) return;
  final color = edge.color.withValues(alpha: edge.color.a * opacity);
  final taper =
      edge.taper &&
      line == MindMapLineStyle.curve &&
      (edge.route == MindMapEdgeRoute.horizontal ||
          edge.route == MindMapEdgeRoute.vertical);
  if (taper) {
    canvas.drawPath(
      mindMapTaperedCurve(
        start,
        end,
        horizontal: edge.route == MindMapEdgeRoute.horizontal,
        startWidth: edge.width * 1.7,
        endWidth: edge.width * 0.55,
      ),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    return;
  }
  canvas.drawPath(
    mindMapEdgePath(edge.route, line, start, end),
    Paint()
      ..color = color
      ..strokeWidth = edge.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// 节点的外框路径（选中环、命中测试也用它的外接矩形）。
Path mindMapNodeOutline(Rect rect, MindMapNodeShape shape, double radius) =>
    switch (shape) {
      MindMapNodeShape.ellipse => Path()..addOval(rect),
      _ =>
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
    };

void _paintNode(
  Canvas canvas,
  MindMapFrameNode node,
  MindMapPaintOptions options, {
  required double opacity,
  bool ignoreSelection = false,
}) {
  if (opacity <= 0.01) return;
  final scene = node.scene;
  final visual = scene.visual;
  final rect = node.rect;
  final scale = node.scale;
  final radius = visual.radiusFor(rect.size);
  Color fade(Color color) => color.withValues(alpha: color.a * opacity);

  if (options.highlightIds.contains(scene.id)) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(5), Radius.circular(radius + 5)),
      Paint()..color = fade(options.palette.selection.withValues(alpha: 0.16)),
    );
  }
  if (visual.shape.boxed) {
    final outline = mindMapNodeOutline(rect, visual.shape, radius);
    if (visual.fill case final fill?) {
      canvas.drawPath(outline, Paint()..color = fade(fill));
    }
    if (visual.border case final border?) {
      canvas.drawPath(
        outline,
        Paint()
          ..color = fade(border)
          ..style = PaintingStyle.stroke
          ..strokeWidth = visual.borderWidth,
      );
    }
  } else if (visual.underline) {
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      Paint()
        ..color = fade(visual.branchColor)
        ..strokeWidth = visual.lineWidth
        ..strokeCap = StrokeCap.round,
    );
  }
  if (options.hoverId == scene.id && !options.selectedIds.contains(scene.id)) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(3), Radius.circular(radius + 3)),
      Paint()
        ..color = fade(options.palette.selection.withValues(alpha: 0.45))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }
  if (options.editingId != scene.id) {
    final text = scene.text;
    final dx = visual.textAlign == TextAlign.center
        ? (scene.rect.width - text.width) / 2
        : visual.padding.left;
    final dy =
        (scene.rect.height - text.height) / 2 - (visual.underline ? 1 : 0);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    if (scale != 1) canvas.scale(scale);
    if (opacity < 0.99) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, scene.rect.width, scene.rect.height),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
      text.paint(canvas, Offset(dx, dy));
      canvas.restore();
    } else {
      text.paint(canvas, Offset(dx, dy));
    }
    canvas.restore();
  }
  if (scene.hiddenCount > 0) {
    _paintCollapsedBadge(canvas, node, opacity, options.palette);
  } else if (!ignoreSelection &&
      scene.hasChildren &&
      options.selectedIds.length == 1 &&
      options.selectedIds.contains(scene.id)) {
    _paintCollapseHandle(canvas, node, opacity, options.palette);
  }
  if (!ignoreSelection && options.selectedIds.contains(scene.id)) {
    final ring = rect.inflate(4.5);
    canvas.drawPath(
      mindMapNodeOutline(
        ring,
        visual.shape.boxed ? visual.shape : MindMapNodeShape.rounded,
        visual.shape.boxed ? radius + 4.5 : 9,
      ),
      Paint()
        ..color = fade(options.palette.selection)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }
}

void _paintCollapsedBadge(
  Canvas canvas,
  MindMapFrameNode node,
  double opacity,
  MindMapPalette palette,
) {
  final scene = node.scene;
  final center = scene.toggleCenter + (node.rect.center - scene.rect.center);
  final color = scene.visual.branchColor;
  final label = scene.hiddenCount > 99 ? '99+' : '${scene.hiddenCount}';
  final text = _badgeText(label, _readableOn(color, palette));
  final width = math.max(20.0, text.width + 10);
  final badge = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: width, height: 20),
    const Radius.circular(10),
  );
  canvas.drawRRect(
    badge,
    Paint()..color = color.withValues(alpha: color.a * opacity),
  );
  text.paint(
    canvas,
    Offset(center.dx - text.width / 2, center.dy - text.height / 2),
  );
}

void _paintDropTarget(
  Canvas canvas,
  MindMapFrame frame,
  MindMapDropTarget target,
  MindMapPalette palette,
) {
  final paint = Paint()
    ..color = palette.selection
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  if (target.indicator case (final a, final b)) {
    canvas.drawLine(a, b, paint);
    canvas.drawCircle(a, 4, Paint()..color = palette.selection);
    return;
  }
  final parent = frame.byId[target.parentId];
  if (parent == null) return;
  final radius = parent.scene.visual.radiusFor(parent.rect.size);
  final ring = parent.rect.inflate(6);
  canvas.drawRRect(
    RRect.fromRectAndRadius(ring, Radius.circular(radius + 6)),
    Paint()..color = palette.selection.withValues(alpha: 0.14),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(ring, Radius.circular(radius + 6)),
    paint..strokeWidth = 2.2,
  );
}

/// 选中节点有子节点时，在子节点出去的一侧画一个“收起”小圆钮。
void _paintCollapseHandle(
  Canvas canvas,
  MindMapFrameNode node,
  double opacity,
  MindMapPalette palette,
) {
  final scene = node.scene;
  final center = scene.toggleCenter + (node.rect.center - scene.rect.center);
  final color = scene.visual.branchColor;
  canvas.drawCircle(
    center,
    9,
    Paint()..color = palette.surface.withValues(alpha: opacity),
  );
  canvas.drawCircle(
    center,
    9,
    Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  canvas.drawLine(
    center - const Offset(4, 0),
    center + const Offset(4, 0),
    Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round,
  );
}

/// [background] 上对比更强的文字色（画布文字色或卡片底色）。
Color _readableOn(Color background, MindMapPalette palette) {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  return contrast(palette.onSurface, background) >=
          contrast(palette.surface, background)
      ? palette.onSurface
      : palette.surface;
}

final Map<(String, int), TextPainter> _badgeTexts =
    <(String, int), TextPainter>{};

TextPainter _badgeText(String label, Color color) {
  final key = (label, color.toARGB32());
  final cached = _badgeTexts[key];
  if (cached != null) return cached;
  if (_badgeTexts.length > 64) {
    final first = _badgeTexts.keys.first;
    _badgeTexts.remove(first)!.dispose();
  }
  return _badgeTexts[key] = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
}

/// 画布用的 [CustomPainter]：先施加视口变换，再按可见区域裁剪绘制。
class MindMapCanvasPainter extends CustomPainter {
  MindMapCanvasPainter({
    required this.frame,
    required this.options,
    required this.transform,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final MindMapFrame Function() frame;
  final MindMapPaintOptions Function() options;
  final Matrix4 Function() transform;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = transform();
    final inverse = Matrix4.tryInvert(matrix);
    final visible = inverse == null
        ? null
        : MatrixUtils.transformRect(inverse, Offset.zero & size);
    canvas.save();
    canvas.transform(matrix.storage);
    paintMindMap(
      canvas,
      frame(),
      options(),
      visible: visible,
      zoom: matrix.getMaxScaleOnAxis(),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(MindMapCanvasPainter oldDelegate) => true;
}
