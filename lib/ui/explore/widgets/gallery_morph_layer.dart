import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../widgets/long_image/long_image_policy.dart';
import '../controllers/gallery_zoom_driver.dart';
import '../models/gallery_level.dart';
import '../models/gallery_pinch.dart';
import 'gallery_group_header.dart';

/// 换档过渡的画布：把 [morph] 里每张图按 [driver] 当前的进度画在起点档与
/// 终点档位置之间，日期标题随所在组的第一张图移动并交叉淡入淡出。
///
/// 每帧只重画（[driver] 即 repaint 信号），不建组件、不布局：几百张图也
/// 只是几百次 drawImageRect。标题的文字排版在过渡开始时做一次
/// （[GalleryHeaderLabel]），同一组同一层级的标题在连跨几档时复用。
class GalleryMorphLayer extends StatefulWidget {
  const GalleryMorphLayer({
    super.key,
    required this.driver,
    required this.morph,
    required this.headerInset,
  });

  final GalleryZoomDriver driver;
  final GalleryMorph morph;
  final double headerInset;

  @override
  State<GalleryMorphLayer> createState() => _GalleryMorphLayerState();
}

class _GalleryMorphLayerState extends State<GalleryMorphLayer> {
  final Map<(DateTime, GalleryLevel), GalleryHeaderLabel> _labels =
      <(DateTime, GalleryLevel), GalleryHeaderLabel>{};
  double? _labelWidth;

  @override
  void dispose() {
    for (final label in _labels.values) {
      label.dispose();
    }
    super.dispose();
  }

  /// 本段过渡用到的标题排版：已有的沿用，用不到的释放。
  Map<(DateTime, GalleryLevel), GalleryHeaderLabel> _labelsFor(double width) {
    if (_labelWidth != width) {
      for (final label in _labels.values) {
        label.dispose();
      }
      _labels.clear();
      _labelWidth = width;
    }
    final morph = widget.morph;
    final wanted = <(DateTime, GalleryLevel)>{};
    for (final header in morph.plan.headers) {
      final level = header.fromLayer ? morph.from.level : morph.to.level;
      final key = (header.group.key, level);
      wanted.add(key);
      _labels.putIfAbsent(
        key,
        () => GalleryHeaderLabel.of(
          context,
          date: header.group.key,
          level: level,
          count: header.group.items.length,
          inset: widget.headerInset,
          width: width,
        ),
      );
    }
    _labels.removeWhere((key, label) {
      if (wanted.contains(key)) return false;
      label.dispose();
      return true;
    });
    return _labels;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainer;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final labels = _labelsFor(constraints.maxWidth);
        return CustomPaint(
          size: constraints.biggest,
          painter: _GalleryMorphPainter(
            driver: widget.driver,
            morph: widget.morph,
            labels: labels,
            placeholder: placeholder,
          ),
        );
      },
    );
  }
}

class _GalleryMorphPainter extends CustomPainter {
  _GalleryMorphPainter({
    required this.driver,
    required this.morph,
    required this.labels,
    required this.placeholder,
  }) : super(repaint: driver);

  final GalleryZoomDriver driver;
  final GalleryMorph morph;
  final Map<(DateTime, GalleryLevel), GalleryHeaderLabel> labels;
  final Color placeholder;

  @override
  void paint(Canvas canvas, Size size) {
    final plan = morph.plan;
    final t = driver.progress;
    final k = driver.rubberScale;
    final focal = driver.focal;
    final cell = plan.cellAt(t) * k;
    final radius =
        ui.lerpDouble(
          morph.from.cornerRadius,
          morph.to.cornerRadius,
          t.clamp(0.0, 1.0),
        )! *
        k;
    final bounds = Offset.zero & size;
    final placeholderPaint = Paint()..color = placeholder;
    final imagePaint = Paint()..filterQuality = FilterQuality.low;
    Offset place(Offset origin) =>
        k == 1 ? origin : focal + (origin - focal) * k;

    for (final j in plan.drawOrder) {
      final origin = place(plan.originAt(j, t));
      final rect = Rect.fromLTWH(origin.dx, origin.dy, cell, cell);
      if (!rect.overlaps(bounds)) continue;
      final rounded = radius >= 0.5;
      if (rounded) {
        canvas
          ..save()
          ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      }
      final image = driver.imageAt(plan.first + j);
      if (image == null) {
        canvas.drawRect(rect, placeholderPaint);
      } else {
        canvas.drawImageRect(image, _coverSource(image), rect, imagePaint);
      }
      if (rounded) canvas.restore();
    }

    // 同一分组层级之间换档（4 ↔ 5 列都按天）：两档的标题文字相同、跟着
    // 同一张图走，位置始终重合——每组只画一次、一直不透明，不淡出淡入。
    final sameLevel = morph.from.level == morph.to.level;
    final drawn = <DateTime>{};
    for (final header in plan.headers) {
      if (sameLevel) {
        if (!drawn.add(header.group.key)) continue;
      }
      final opacity = sameLevel
          ? 1.0
          : GalleryPinch.headerOpacity(t, fromLayer: header.fromLayer);
      if (opacity <= 0) continue;
      final level = header.fromLayer ? morph.from.level : morph.to.level;
      final label = labels[(header.group.key, level)];
      if (label == null) continue;
      final top = header.topAt(t, scale: k, focal: focal);
      if (top > size.height || top + label.extent < 0) continue;
      label.paint(canvas, Offset(0, top), opacity);
    }
  }

  /// cover 铺满正方形的取图范围：普通图居中，长图取顶部（与网格一致）。
  static Rect _coverSource(ui.Image image) {
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final side = math.min(width, height);
    final long = isLongImageSize(Size(width, height));
    return Rect.fromLTWH(
      (width - side) / 2,
      long ? 0 : (height - side) / 2,
      side,
      side,
    );
  }

  @override
  bool shouldRepaint(_GalleryMorphPainter oldDelegate) =>
      !identical(oldDelegate.morph, morph) ||
      !identical(oldDelegate.labels, labels) ||
      oldDelegate.placeholder != placeholder;
}
