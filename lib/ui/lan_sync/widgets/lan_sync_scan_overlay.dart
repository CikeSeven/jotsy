// 扫码页叠在相机画面上的取景层（DESIGN.md §5.28“扫码页”）：66% 遮罩与
// 264dp 36 圆角取景框挖空、四角 44dp / 4dp 圆角括号、框内上下往返的 2dp
// 扫描线。纯装饰，读屏不读。
//
// 颜色取当前主题（扫码页整页套用由种子色推出的暗色主题）：遮罩为
// `surfaceContainerLowest`（暗色色阶最深的一档，与设计稿的 #0A0F12 同为
// 带一点主题色调的近黑），括号与扫描线为 `primary`。
//
// 扫描线一个来回为 `ExpressiveMotion.scanLoop`（2.4s），位置按余弦缓动
// （两端减速），不另造曲线；减少动画时不启动动画，静止在框的正中。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 取景框的几何：在 [size] 里水平居中、略高于正中（给下方说明留位置）。
Rect lanSyncScanFrameRect(Size size) {
  const extent = LanSyncScanOverlay.frameExtent;
  final side = math.min(extent, size.width - 48);
  final top = math.max(96.0, (size.height - side) / 2 - 56);
  return Rect.fromLTWH((size.width - side) / 2, top, side, side);
}

/// 见文件头注释。
class LanSyncScanOverlay extends StatefulWidget {
  const LanSyncScanOverlay({super.key, required this.frame});

  static const double frameExtent = 264;
  static const double frameRadius = 36;

  /// 取景框在本组件坐标系里的位置（见 [lanSyncScanFrameRect]）。
  final Rect frame;

  @override
  State<LanSyncScanOverlay> createState() => _LanSyncScanOverlayState();
}

class _LanSyncScanOverlayState extends State<LanSyncScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.scanLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ExpressiveMotion.reduceMotion(context)) {
      _sweep
        ..stop()
        ..value = 0.25; // 余弦缓动下 0.25 圈恰在正中。
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 不拦点按：取景层只是画在相机上的装饰，点按留给相机画面。
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ScanOverlayPainter(
              frame: widget.frame,
              sweep: _sweep,
              scrim: colors.surfaceContainerLowest.withValues(alpha: 0.66),
              accent: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({
    required this.frame,
    required this.sweep,
    required this.scrim,
    required this.accent,
  }) : super(repaint: sweep);

  final Rect frame;
  final Animation<double> sweep;
  final Color scrim;
  final Color accent;

  static const double _bracket = 44;
  static const double _stroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(LanSyncScanOverlay.frameRadius),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(cutout),
      Paint()..color = scrim,
    );
    _paintBrackets(canvas);
    // 余弦往返：t ∈ [0, 1) 一个来回，0 在顶、0.5 在底。
    final t = sweep.value;
    final travel = (1 - math.cos(2 * math.pi * t)) / 2;
    const inset = 20.0;
    final y = frame.top + inset + (frame.height - 2 * inset) * travel;
    canvas.drawRRect(
      RRect.fromLTRBR(
        frame.left + inset,
        y - 1,
        frame.right - inset,
        y + 1,
        const Radius.circular(1),
      ),
      Paint()..color = accent,
    );
  }

  /// 四角括号：沿取景框圆角走的一段描边，两臂各伸出到 44dp。
  void _paintBrackets(Canvas canvas) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    final r = LanSyncScanOverlay.frameRadius;
    final f = frame.inflate(_stroke / 2 + 2);
    final arm = _bracket - r;
    // 左上
    canvas.drawPath(
      Path()
        ..moveTo(f.left, f.top + r + arm)
        ..lineTo(f.left, f.top + r)
        ..arcToPoint(Offset(f.left + r, f.top), radius: Radius.circular(r))
        ..lineTo(f.left + r + arm, f.top),
      paint,
    );
    // 右上
    canvas.drawPath(
      Path()
        ..moveTo(f.right - r - arm, f.top)
        ..lineTo(f.right - r, f.top)
        ..arcToPoint(Offset(f.right, f.top + r), radius: Radius.circular(r))
        ..lineTo(f.right, f.top + r + arm),
      paint,
    );
    // 右下
    canvas.drawPath(
      Path()
        ..moveTo(f.right, f.bottom - r - arm)
        ..lineTo(f.right, f.bottom - r)
        ..arcToPoint(Offset(f.right - r, f.bottom), radius: Radius.circular(r))
        ..lineTo(f.right - r - arm, f.bottom),
      paint,
    );
    // 左下
    canvas.drawPath(
      Path()
        ..moveTo(f.left + r + arm, f.bottom)
        ..lineTo(f.left + r, f.bottom)
        ..arcToPoint(Offset(f.left, f.bottom - r), radius: Radius.circular(r))
        ..lineTo(f.left, f.bottom - r - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.scrim != scrim ||
      oldDelegate.accent != accent ||
      oldDelegate.sweep != sweep;
}
