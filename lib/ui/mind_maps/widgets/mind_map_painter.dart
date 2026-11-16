import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../layout/mind_map_scene.dart';
import '../models/mind_map_markers.dart';
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
  // 节点内容按布局尺寸画，缩放与淡入淡出整体施加（转场里长出 / 缩回）。
  canvas.save();
  canvas.translate(rect.left, rect.top);
  if (scale != 1) canvas.scale(scale);
  if (opacity < 0.99) {
    canvas.saveLayer(
      Offset.zero & scene.rect.size,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }
  _paintContent(
    canvas,
    scene,
    options.palette,
    drawText: options.editingId != scene.id,
  );
  if (opacity < 0.99) canvas.restore();
  canvas.restore();
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

/// 节点框里的内容：待办框、贴纸、文字、进度 / 备注 / 链接标记、标签。
/// 坐标相对节点左上角（布局尺寸）。
void _paintContent(
  Canvas canvas,
  MindMapSceneNode scene,
  MindMapPalette palette, {
  required bool drawText,
}) {
  final content = scene.content;
  final visual = scene.visual;
  final ink = visual.textStyle.color ?? palette.onSurface;
  // 有底色的节点上，标记用文字色；没有底色时用分支色，与连线呼应。
  final accent = visual.fill == null ? visual.branchColor : ink;
  if (content.checkbox case final box?) {
    final rrect = RRect.fromRectAndRadius(
      box.deflate(1),
      Radius.circular(box.width * 0.26),
    );
    if (content.taskDone) {
      canvas.drawRRect(rrect, Paint()..color = accent);
      final check = Path()
        ..moveTo(box.left + box.width * 0.27, box.top + box.height * 0.52)
        ..lineTo(box.left + box.width * 0.44, box.top + box.height * 0.68)
        ..lineTo(box.left + box.width * 0.74, box.top + box.height * 0.34);
      canvas.drawPath(
        check,
        Paint()
          ..color = visual.fill ?? palette.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = box.width * 0.13
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, box.width * 0.1),
      );
    }
  }
  for (final (marker, box) in content.markers) {
    _paintMarker(canvas, marker, box, palette, visual.textStyle);
  }
  if (drawText) scene.text.paint(canvas, content.textRect.topLeft);
  if (content.progress case final progress?) {
    final box = progress.rect;
    final center = box.center;
    final radius = box.width / 2 - 1;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = accent.withValues(alpha: accent.a * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.done / progress.total,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }
  if (content.note case final box?) {
    _paintGlyph(
      canvas,
      FontAwesomeIcons.solidNoteSticky,
      box,
      ink.withValues(alpha: ink.a * 0.7),
    );
  }
  if (content.link case final box?) {
    _paintGlyph(
      canvas,
      content.diaryLink ? FontAwesomeIcons.bookOpen : FontAwesomeIcons.link,
      box,
      ink.withValues(alpha: ink.a * 0.7),
    );
  }
  for (final (painter, box) in content.labels) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()..color = accent.withValues(alpha: accent.a * 0.16),
    );
    painter.paint(canvas, Offset(box.left + 6, box.top + 2));
  }
}

void _paintMarker(
  Canvas canvas,
  MindMapMarker marker,
  Rect box,
  MindMapPalette palette,
  TextStyle base,
) {
  switch (marker.look) {
    case MindMapNumberLook(:final number, :final color):
      final colors = palette.marker(color);
      canvas.drawCircle(
        box.center,
        box.width / 2,
        Paint()..color = colors.accent,
      );
      final text = _glyphText(
        '$number',
        TextStyle(
          color: colors.onAccent,
          fontSize: box.width * 0.62,
          fontWeight: FontWeight.w800,
          fontFamily: base.fontFamily,
          fontFamilyFallback: base.fontFamilyFallback,
          height: 1,
        ),
      );
      text.paint(
        canvas,
        Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2),
      );
    case MindMapProgressLook(:final percent):
      final colors = palette.marker(MindMapMarkerColor.blue);
      final radius = box.width / 2;
      canvas.drawCircle(
        box.center,
        radius,
        Paint()..color = colors.accent.withValues(alpha: 0.16),
      );
      if (percent >= 100) {
        canvas.drawCircle(box.center, radius, Paint()..color = colors.accent);
        final check = Path()
          ..moveTo(box.left + box.width * 0.28, box.top + box.height * 0.52)
          ..lineTo(box.left + box.width * 0.44, box.top + box.height * 0.67)
          ..lineTo(box.left + box.width * 0.73, box.top + box.height * 0.36);
        canvas.drawPath(
          check,
          Paint()
            ..color = colors.onAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = box.width * 0.12
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else if (percent > 0) {
        canvas.drawArc(
          box.deflate(box.width * 0.14),
          -math.pi / 2,
          2 * math.pi * percent / 100,
          true,
          Paint()..color = colors.accent,
        );
      }
      canvas.drawCircle(
        box.center,
        radius - 0.6,
        Paint()
          ..color = colors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    case MindMapGlyphLook(:final icon, :final color):
      _paintGlyph(canvas, icon, box, palette.marker(color).accent);
    case MindMapEmojiLook(:final emoji):
      final text = _glyphText(
        emoji,
        TextStyle(
          fontSize: box.width * 0.86,
          fontFamily: base.fontFamily,
          fontFamilyFallback: base.fontFamilyFallback,
          height: 1,
        ),
      );
      text.paint(
        canvas,
        Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2),
      );
  }
}

/// 在 [box] 里居中画一个 Font Awesome 字形。
void _paintGlyph(Canvas canvas, FaIconData icon, Rect box, Color color) {
  final text = _glyphText(
    String.fromCharCode(icon.codePoint),
    TextStyle(
      color: color,
      fontSize: box.width * 0.9,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      height: 1,
    ),
  );
  text.paint(
    canvas,
    Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2),
  );
}

final Map<(String, TextStyle), TextPainter> _glyphTexts =
    <(String, TextStyle), TextPainter>{};

TextPainter _glyphText(String text, TextStyle style) {
  final key = (text, style);
  final cached = _glyphTexts.remove(key);
  if (cached != null) return _glyphTexts[key] = cached;
  while (_glyphTexts.length > 160) {
    _glyphTexts.remove(_glyphTexts.keys.first)!.dispose();
  }
  return _glyphTexts[key] = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
}
