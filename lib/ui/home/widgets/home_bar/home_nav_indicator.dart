import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'home_nav_geometry.dart';

/// 底栏的选中指示器：整行只有一颗，画在导航项下面，随 [position] 滑动。
///
/// 输入：位置（小数序号，弹簧或页面位置）、可选的速度 [velocity]（弹簧
/// 驱动时给出，非空即按弹性规则拉伸，见 [HomeNavGeometry.indicatorRect]）、
/// 项数、颜色、圆角 [radius] 与首尾可探出的距离 [edgeRoom]；输出：铺满
/// 导航行的一层画布，无副作用。
///
/// 用 CustomPaint 而不是按位置摆放一个子组件：位置每帧都变，只重画这一层
/// （外面包了 RepaintBoundary），不触发布局，导航项的图标与文字也不跟着
/// 重画。圆角取 [radius]（与胶囊同心），但不超过矩形高度的一半：完整的
/// 胶囊被拉长、压扁、挤到内壁时两端始终是完整的半圆，不会画出比高还大的
/// 圆角。
class HomeNavIndicator extends StatelessWidget {
  const HomeNavIndicator({
    super.key,
    required this.position,
    required this.velocity,
    required this.count,
    required this.color,
    required this.radius,
    required this.edgeRoom,
  });

  final ValueListenable<double> position;

  /// 弹簧此刻的速度（项 / 秒）；null 表示位置来自页面，不拉伸也不越界。
  final ValueGetter<double>? velocity;
  final int count;
  final Color color;
  final double radius;
  final double edgeRoom;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _IndicatorPainter(
          position: position,
          velocity: velocity,
          count: count,
          color: color,
          radius: radius,
          edgeRoom: edgeRoom,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.position,
    required this.velocity,
    required this.count,
    required this.color,
    required this.radius,
    required this.edgeRoom,
    required this.rtl,
  }) : super(repaint: position);

  final ValueListenable<double> position;
  final ValueGetter<double>? velocity;
  final int count;
  final Color color;
  final double radius;
  final double edgeRoom;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final velocity = this.velocity;
    final rect = HomeNavGeometry.indicatorRect(
      size: size,
      count: count,
      position: position.value,
      velocity: velocity?.call() ?? 0,
      elastic: velocity != null,
      rtl: rtl,
      edgeRoom: edgeRoom,
    );
    if (rect.isEmpty) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(radius, rect.height / 2)),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter oldDelegate) =>
      oldDelegate.position != position ||
      (oldDelegate.velocity == null) != (velocity == null) ||
      oldDelegate.count != count ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.edgeRoom != edgeRoom ||
      oldDelegate.rtl != rtl;
}
