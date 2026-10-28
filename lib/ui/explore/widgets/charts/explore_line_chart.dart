import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 折线图：等距的点按值连线，没有数据的点断开（不跨过空白日子连线）。
///
/// 只画实色线与圆点（DESIGN 禁用渐变，线下不填充）；[pointColor] 可为每个
/// 点单独着色（心情按分段着色）。[reveal]（0~1）从左到右逐段画出，首次出现
/// 时与其他图表同一节奏；横向几条淡网格线标出值域。读屏只读 [semanticsLabel]。
class ExploreLineChart extends StatelessWidget {
  const ExploreLineChart({
    super.key,
    required this.values,
    required this.min,
    required this.max,
    required this.reveal,
    required this.color,
    this.pointColor,
    this.height = 96,
    this.semanticsLabel,
  });

  final List<double?> values;
  final double min;
  final double max;
  final double reveal;
  final Color color;
  final Color Function(double value)? pointColor;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chart = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          values: values,
          min: min,
          max: max,
          reveal: reveal,
          color: color,
          pointColor: pointColor,
          gridColor: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    );
    final label = semanticsLabel;
    if (label == null) return chart;
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: chart),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.min,
    required this.max,
    required this.reveal,
    required this.color,
    required this.pointColor,
    required this.gridColor,
  });

  final List<double?> values;
  final double min;
  final double max;
  final double reveal;
  final Color color;
  final Color Function(double value)? pointColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = inset + (size.height - 2 * inset) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final span = math.max(max - min, 1e-6);
    final step = values.length <= 1
        ? 0.0
        : (size.width - 2 * inset) / (values.length - 1);
    Offset point(int index, double value) => Offset(
      inset + step * index,
      inset +
          (size.height - 2 * inset) *
              (1 - ((value.clamp(min, max) - min) / span)),
    );
    // 从左到右逐段显现：只画到 reveal 对应的位置。
    final limit = (values.length - 1) * reveal.clamp(0.0, 1.0);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null || i > limit + 1e-9) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        if (i > limit) break;
        continue;
      }
      final p = point(i, value);
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (path != null) canvas.drawPath(path, line);
    final dotRadius = values.length > 45 ? 1.6 : 3.0;
    for (var i = 0; i < values.length && i <= limit + 1e-9; i++) {
      final value = values[i];
      if (value == null) continue;
      canvas.drawCircle(
        point(i, value),
        dotRadius,
        Paint()..color = pointColor?.call(value) ?? color,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.reveal != reveal ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.min != min ||
      oldDelegate.max != max ||
      !_sameValues(oldDelegate.values, values);

  static bool _sameValues(List<double?> a, List<double?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
