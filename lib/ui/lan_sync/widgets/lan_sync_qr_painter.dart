// 二维码面板的自绘部分（DESIGN.md §5.28“二维码面板”）：二维码本体与倒计时环。
//
// 二维码：数据模块画成直径 0.84 模块的圆点；三个定位角整体画成圆角描边
// 方框 + 圆角实心内块。设计稿的 16 / 8 圆角按约 6dp 的模块定稿（定位角
// 42dp），实际模块不到 3dp（见 lan_sync_qr_matrix.dart），照搬绝对值会把
// 方框画成圆、扫码器认不出定位角，所以按同样的比例换算：外框圆角 = 外框
// 边长 × 16/42，内块圆角 = 内块边长 × 8/18。中心挖空区不画任何东西，由
// 上层叠放品牌块。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/lan_sync_qr_matrix.dart';

/// 见文件头注释。
class LanSyncQrPainter extends CustomPainter {
  const LanSyncQrPainter({
    required this.matrix,
    required this.dotColor,
    required this.finderColor,
  });

  final LanSyncQrMatrix matrix;
  final Color dotColor;
  final Color finderColor;

  /// 圆点直径占模块边长的比例。
  static const double dotRatio = 0.84;

  @override
  void paint(Canvas canvas, Size size) {
    final count = matrix.moduleCount;
    final module = math.min(size.width, size.height) / count;
    final dots = Paint()..color = dotColor;
    final radius = module * dotRatio / 2;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!matrix.isDark(row, col) || matrix.isFinder(row, col)) continue;
        canvas.drawCircle(
          Offset((col + 0.5) * module, (row + 0.5) * module),
          radius,
          dots,
        );
      }
    }
    const f = LanSyncQrMatrix.finderModules;
    final far = (count - f) * module;
    for (final origin in <Offset>[
      Offset.zero,
      Offset(far, 0),
      Offset(0, far),
    ]) {
      _paintFinder(canvas, origin, module);
    }
  }

  void _paintFinder(Canvas canvas, Offset origin, double module) {
    const f = LanSyncQrMatrix.finderModules;
    final outer = origin & Size.square(f * module);
    final outerRadius = outer.width * 16 / 42;
    final ring = Paint()
      ..color = finderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = module;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outer.deflate(module / 2),
        Radius.circular(math.max(0, outerRadius - module / 2)),
      ),
      ring,
    );
    final inner = Rect.fromLTWH(
      origin.dx + 2 * module,
      origin.dy + 2 * module,
      3 * module,
      3 * module,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.width * 8 / 18)),
      Paint()..color = finderColor,
    );
  }

  @override
  bool shouldRepaint(LanSyncQrPainter oldDelegate) =>
      !identical(oldDelegate.matrix, matrix) ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.finderColor != finderColor;
}

/// 倒计时环：底轨 + 自 12 点钟方向顺时针的剩余比例弧。
class LanSyncCountdownRingPainter extends CustomPainter {
  const LanSyncCountdownRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 2.5,
  });

  /// 剩余比例（1 为刚换码，0 为到期）。
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
    final sweep = math.pi * 2 * progress.clamp(0, 1);
    if (sweep <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = color);
  }

  @override
  bool shouldRepaint(LanSyncCountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
