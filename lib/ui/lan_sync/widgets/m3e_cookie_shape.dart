// Material 3 Expressive 的“饼干”形（多瓣圆）：设备图标底（九瓣）、同步完成
// 对勾底（十二瓣）共用。
//
// 轮廓按极坐标 r = R·(1 + a·cos(nθ)) 采样：n 为瓣数、a 为起伏幅度。R 取
// 让最外缘恰好贴住外接正方形，形状不会画出给定的盒子；第一瓣朝正上方，
// 九瓣与十二瓣都左右对称。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 在 [bounds] 内按 [lobes] 瓣、[amplitude] 幅度生成饼干形轮廓。
///
/// 每瓣采样 24 点，88dp 的形状在高密度屏上也看不出折线。
Path m3eCookiePath(
  Rect bounds, {
  required int lobes,
  double amplitude = 0.075,
}) {
  assert(lobes >= 3);
  assert(amplitude >= 0 && amplitude < 1);
  final center = bounds.center;
  final outer = bounds.shortestSide / 2;
  final base = outer / (1 + amplitude);
  final samples = lobes * 24;
  final path = Path();
  for (var i = 0; i <= samples; i++) {
    final theta = 2 * math.pi * i / samples;
    final r = base * (1 + amplitude * math.cos(lobes * theta));
    // 减去 π/2：θ = 0 的那一瓣朝上。
    final point = Offset(
      center.dx + r * math.cos(theta - math.pi / 2),
      center.dy + r * math.sin(theta - math.pi / 2),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// 饼干形的 [ShapeBorder]：经 `ShapeDecoration` / `ClipPath.shape` 使用。
@immutable
class M3eCookieBorder extends ShapeBorder {
  const M3eCookieBorder({required this.lobes, this.amplitude = 0.075});

  /// 瓣数：设备图标为 9，同步完成对勾为 12。
  final int lobes;

  /// 起伏幅度（相对半径）。
  final double amplitude;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      m3eCookiePath(rect, lobes: lobes, amplitude: amplitude);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) =>
      other is M3eCookieBorder &&
      other.lobes == lobes &&
      other.amplitude == amplitude;

  @override
  int get hashCode => Object.hash(lobes, amplitude);
}
