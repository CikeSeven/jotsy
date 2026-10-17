import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 下载进度条（Material 3 Expressive 2024 规格：圆角轨道、指示与轨道之间
/// 留缝、末端停止点）。
///
/// 为什么不用 [LinearProgressIndicator]：新规格要靠已弃用的 `year2023`
/// 开关启用，而 CI 把弃用提示也算作失败。这里只画确定进度；进度未知时
/// 由调用方显示 `ExpressiveLoadingIndicator`。进度变化经 `medium` 补间，
/// 减少动画时直接到位。
class AppUpdateProgressBar extends StatelessWidget {
  const AppUpdateProgressBar({super.key, required this.value});

  /// 0–1。
  final double value;

  static const double _height = 8;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, double progress, Widget? child) {
        return CustomPaint(
          size: const Size.fromHeight(_height),
          painter: _ProgressPainter(
            progress: progress,
            indicator: colorScheme.primary,
            track: colorScheme.secondaryContainer,
          ),
        );
      },
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.progress,
    required this.indicator,
    required this.track,
  });

  final double progress;
  final Color indicator;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final radius = Radius.circular(height / 2);
    final filled = size.width * progress;
    final paint = Paint();
    // 轨道从指示末端留出间隙后开始；接近满格时轨道缩没。
    final trackStart = progress <= 0 ? 0.0 : filled + AppUpdateProgressBar._gap;
    if (trackStart < size.width) {
      paint.color = track;
      canvas.drawRRect(
        RRect.fromLTRBR(trackStart, 0, size.width, height, radius),
        paint,
      );
      // 停止点：提示终点位置。
      paint.color = indicator;
      canvas.drawCircle(
        Offset(size.width - height / 2, height / 2),
        height / 4,
        paint,
      );
    }
    if (filled > 0) {
      paint.color = indicator;
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, filled.clamp(height, size.width), height, radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.indicator != indicator ||
      oldDelegate.track != track;
}
