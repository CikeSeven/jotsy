import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 圆环进度：`track` 色的整圈轨道上画 `color` 色的圆头弧线（从 12 点顺时针），
/// 中间放 [center]。进度变化以 `medium` + effects 从当前值补间，减少动画时
/// 直接到位；纯色描边，不画渐变。
class TodoProgressRing extends StatelessWidget {
  const TodoProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.track,
    this.size = 56,
    this.strokeWidth = 6,
    this.center,
  });

  /// 0~1。
  final double fraction;
  final Color color;
  final Color track;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fraction.clamp(0, 1)),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, double value, Widget? child) =>
            CustomPaint(
              painter: _RingPainter(
                fraction: value,
                color: color,
                track: track,
                strokeWidth: strokeWidth,
              ),
              child: child,
            ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}

/// 细进度条：`track` 底上画 `color` 段，全圆角；进度变化补间同 [TodoProgressRing]。
class TodoProgressBar extends StatelessWidget {
  const TodoProgressBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.track,
    this.height = 6,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: track,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction.clamp(0, 1)),
            duration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            builder: (BuildContext context, double value, Widget? _) =>
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: radius,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
