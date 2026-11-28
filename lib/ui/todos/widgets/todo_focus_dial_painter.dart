import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 专注表盘的几何与绘制工具（纯渲染，无业务状态）。
///
/// 视觉层次（全语义色、零渐变）：
/// 1. 最底层为双层交错 Material 3 Expressive 有机花瓣底盘（[focusScallopPath]）：
///    外层极淡反旋回响轮廓 + 主花瓣容器，运行中安静慢转，暂停时两层收拢重合；
/// 2. 进度层为 M3E 动态波形弧（[TodoFocusDialPainter]）：活跃段沿圆周做平滑
///    正弦波动，两端经余弦包络收敛回基准圆，推进端带一枚清晰指示圆珠；与未走
///    轨道之间保留标准 Track Gap，轨道末端画 Stop Indicator 终止圆点；
/// 3. 内侧为 60 格精密腕表刻度环（每 5 格主刻度，剩余区间略亮、已过静默）；
/// 4. 最核心为温润的同心表盘圆面 + 极细微描边，在任意背景图与明暗主题下都保证
///    中心倒计时极佳的可读性与层次感。

/// 在 [bounds] 内生成 [lobes] 瓣有机饼干轮廓，严格内切不越界。
///
/// [amplitude] 为相对半径起伏幅度（0 为正圆）；[rotation] 为顺时针旋转弧度。
Path focusScallopPath(
  Rect bounds, {
  required int lobes,
  required double amplitude,
  double rotation = 0,
}) {
  assert(lobes >= 3);
  assert(amplitude >= 0 && amplitude < 0.35);
  final center = bounds.center;
  final outer = bounds.shortestSide / 2;
  final base = outer / (1 + amplitude);
  final samples = lobes * 24;
  final path = Path();
  for (var i = 0; i <= samples; i++) {
    final theta = 2 * math.pi * i / samples;
    final r = base * (1 + amplitude * math.cos(lobes * theta));
    final angle = theta + rotation - math.pi / 2;
    final point = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// 专注表盘每帧变化的动态参数（由 Ticker 写入，只触发重绘不触发 widget 重建）。
class TodoFocusDialFrame extends ChangeNotifier {
  TodoFocusDialFrame([
    this._fraction = 1,
    this._wavePhase = 0,
    this._orbitAngle = 0,
  ]);

  double _fraction;
  double _wavePhase;
  double _orbitAngle;

  double get fraction => _fraction;
  double get wavePhase => _wavePhase;
  double get orbitAngle => _orbitAngle;

  /// 更新当前帧状态并在任一量变化时通知重绘。
  void update({
    required double fraction,
    required double wavePhase,
    required double orbitAngle,
  }) {
    if (_fraction == fraction &&
        _wavePhase == wavePhase &&
        _orbitAngle == orbitAngle) {
      return;
    }
    _fraction = fraction;
    _wavePhase = wavePhase;
    _orbitAngle = orbitAngle;
    notifyListeners();
  }
}

/// 绘制四层 M3 Expressive 表盘：双层花瓣底盘 → 波形进度弧 → 60 格刻度 → 内盘面。
class TodoFocusDialPainter extends CustomPainter {
  TodoFocusDialPainter({
    required this.frame,
    required this.accentColor,
    required this.trackColor,
    required this.backdropColor,
    required this.backdropEchoColor,
    required this.backdropOutlineColor,
    required this.coreSurfaceColor,
    required this.coreBorderColor,
    required this.tickActiveColor,
    required this.tickInactiveColor,
    required this.stopDotColor,
    required this.waveIntensity,
    required this.scallopAmplitude,
    required this.lobes,
    required this.isPreview,
  }) : super(repaint: frame);

  final TodoFocusDialFrame frame;
  final Color accentColor;
  final Color trackColor;
  final Color backdropColor;
  final Color backdropEchoColor;
  final Color backdropOutlineColor;
  final Color coreSurfaceColor;
  final Color coreBorderColor;
  final Color tickActiveColor;
  final Color tickInactiveColor;
  final Color stopDotColor;

  /// 波形振幅强度（0 = 平直圆弧，1 = 完整流动波浪）。
  final double waveIntensity;

  /// 有机底盘波瓣起伏幅度（0 = 接近正圆，~0.05 = 柔美花瓣）。
  final double scallopAmplitude;

  /// 有机底盘花瓣数（专注 12 瓣，休息 10 瓣）。
  final int lobes;

  /// 空闲预览模式：画完整温和轨道环与静态底盘，不画终止点与推进珠。
  final bool isPreview;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final center = bounds.center;
    final outerRadius = bounds.shortestSide / 2;

    // 1. 双层交错有机花瓣底盘：外圈极淡反旋花瓣 + 主花瓣容器与微边框。
    final primaryBounds = bounds.deflate(outerRadius * 0.028);
    if (waveIntensity > 0.01) {
      final echoPhase = -frame.orbitAngle * 0.7 + math.pi / lobes;
      final echoPath = focusScallopPath(
        bounds,
        lobes: lobes,
        amplitude: scallopAmplitude * 1.05,
        rotation: echoPhase,
      );
      canvas.drawPath(
        echoPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = backdropEchoColor.withValues(
            alpha: backdropEchoColor.a * waveIntensity,
          ),
      );
    }
    final scallop = focusScallopPath(
      primaryBounds,
      lobes: lobes,
      amplitude: scallopAmplitude,
      rotation: frame.orbitAngle,
    );
    canvas.drawPath(
      scallop,
      Paint()
        ..style = PaintingStyle.fill
        ..color = backdropColor,
    );
    canvas.drawPath(
      scallop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = backdropOutlineColor,
    );

    final strokeWidth = (size.shortestSide / 25).clamp(8.5, 13.0);
    final ringRadius = outerRadius * 0.805;
    final fraction = frame.fraction.clamp(0.0, 1.0);

    // 2. 内层同心表盘面（落在刻度内侧，提供极净文字舞台）。
    final outerTickRadius = ringRadius - strokeWidth * 0.96;
    final majorLen = (outerTickRadius * 0.070).clamp(5.0, 7.2);
    final coreRadius = outerTickRadius - majorLen - 6.0;
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = coreSurfaceColor,
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = coreBorderColor,
    );

    // 3. 60 格精密腕表刻度（落在进度环与内表盘面之间的环形沟槽内）。
    _paintTicks(
      canvas,
      center: center,
      outerTickRadius: outerTickRadius,
      majorLen: majorLen,
      fraction: isPreview ? 1.0 : fraction,
    );

    // 4. 轨道与 M3E 波形进度弧。
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);
    if (isPreview) {
      canvas.drawArc(
        ringRect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.72
          ..color = trackColor,
      );
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.34
          ..color = accentColor.withValues(alpha: 0.26),
      );
      canvas.drawCircle(
        Offset(center.dx, center.dy - ringRadius),
        (strokeWidth * 0.36).clamp(3.2, 4.6),
        Paint()..color = accentColor,
      );
      return;
    }

    final activeSweep = math.pi * 2 * fraction;
    const startAngle = -math.pi / 2;
    // M3E 标准端点间隙：保证两个圆头端帽之间仍有 ~5.5dp 清晰净空。
    final gapAngle = (strokeWidth + 5.5) / ringRadius;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.74
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    if (fraction <= 0.001) {
      canvas.drawArc(ringRect, 0, math.pi * 2, false, trackPaint);
    } else if (fraction < 0.999) {
      final trackStart = startAngle + activeSweep + gapAngle;
      final trackSweep = math.pi * 2 - activeSweep - gapAngle * 2;
      if (trackSweep > 0.02) {
        canvas.drawArc(ringRect, trackStart, trackSweep, false, trackPaint);
        final stopAngle = startAngle - gapAngle;
        final stopCenter = Offset(
          center.dx + ringRadius * math.cos(stopAngle),
          center.dy + ringRadius * math.sin(stopAngle),
        );
        canvas.drawCircle(
          stopCenter,
          (strokeWidth * 0.22).clamp(2.2, 3.2),
          Paint()..color = stopDotColor,
        );
      }
    }

    if (fraction <= 0.001) return;
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accentColor;

    if (waveIntensity <= 0.01 || activeSweep < 0.14) {
      canvas.drawArc(ringRect, startAngle, activeSweep, false, activePaint);
    } else {
      final waveAmp =
          (size.shortestSide * 0.013).clamp(2.2, 4.0) * waveIntensity;
      final waveCount = math.max(12, ((2 * math.pi * ringRadius) / 36).round());
      final fullCircle = fraction >= 0.999;
      final path = _buildWavyArcPath(
        center: center,
        radius: ringRadius,
        startAngle: startAngle,
        sweepAngle: fullCircle ? math.pi * 2 : activeSweep,
        waveCount: waveCount,
        amplitude: waveAmp,
        phase: frame.wavePhase,
        closed: fullCircle,
      );
      canvas.drawPath(path, activePaint);
    }

    // 4b. 推进端指示圆珠：运行中随波形强度优雅浮现，暂停时平滑缩回融入弧端。
    if (waveIntensity > 0.05 && fraction > 0.01 && fraction < 0.995) {
      final headAngle = startAngle + activeSweep;
      final headCenter = Offset(
        center.dx + ringRadius * math.cos(headAngle),
        center.dy + ringRadius * math.sin(headAngle),
      );
      final beadRadius = strokeWidth * 0.50 + 1.4 * waveIntensity;
      canvas.drawCircle(
        headCenter,
        beadRadius + 1.6 * waveIntensity,
        Paint()..color = coreSurfaceColor,
      );
      canvas.drawCircle(headCenter, beadRadius, Paint()..color = accentColor);
    }
  }

  void _paintTicks(
    Canvas canvas, {
    required Offset center,
    required double outerTickRadius,
    required double majorLen,
    required double fraction,
  }) {
    const count = 60;
    final minorLen = majorLen * 0.52;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final ratio = i / count;
      final isMajor = i % 5 == 0;
      final isActive = ratio <= fraction;
      final angle = -math.pi / 2 + ratio * math.pi * 2;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final len = isMajor ? majorLen : minorLen;
      final innerR = outerTickRadius - len;
      paint
        ..strokeWidth = isMajor ? 1.6 : 1.0
        ..color = isActive
            ? (isMajor
                  ? tickActiveColor
                  : tickActiveColor.withValues(alpha: tickActiveColor.a * 0.6))
            : tickInactiveColor;
      canvas.drawLine(
        Offset(center.dx + innerR * cosA, center.dy + innerR * sinA),
        Offset(
          center.dx + outerTickRadius * cosA,
          center.dy + outerTickRadius * sinA,
        ),
        paint,
      );
    }
  }

  /// 生成沿圆弧做径向正弦调制的平滑路径；非闭合时两端用平滑包络收敛回基准圆。
  Path _buildWavyArcPath({
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required int waveCount,
    required double amplitude,
    required double phase,
    required bool closed,
  }) {
    final steps = math.max(24, (sweepAngle / (math.pi * 2) * 240).round());
    final taperAngle = math.min(0.24, sweepAngle * 0.22);
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final delta = sweepAngle * t;
      final angle = startAngle + delta;
      var envelope = 1.0;
      if (!closed && taperAngle > 0) {
        final distFromEdge = math.min(delta, sweepAngle - delta);
        if (distFromEdge < taperAngle) {
          final u = (distFromEdge / taperAngle).clamp(0.0, 1.0);
          final s = math.sin(u * math.pi / 2);
          envelope = s * s;
        }
      }
      final r =
          radius + amplitude * envelope * math.sin(waveCount * angle - phase);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (closed) path.close();
    return path;
  }

  @override
  bool shouldRepaint(TodoFocusDialPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.backdropColor != backdropColor ||
      oldDelegate.backdropEchoColor != backdropEchoColor ||
      oldDelegate.backdropOutlineColor != backdropOutlineColor ||
      oldDelegate.coreSurfaceColor != coreSurfaceColor ||
      oldDelegate.coreBorderColor != coreBorderColor ||
      oldDelegate.tickActiveColor != tickActiveColor ||
      oldDelegate.tickInactiveColor != tickInactiveColor ||
      oldDelegate.stopDotColor != stopDotColor ||
      oldDelegate.waveIntensity != waveIntensity ||
      oldDelegate.scallopAmplitude != scallopAmplitude ||
      oldDelegate.lobes != lobes ||
      oldDelegate.isPreview != isPreview;
}
