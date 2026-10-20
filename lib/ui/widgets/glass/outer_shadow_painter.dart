import 'package:flutter/material.dart';

/// 画在圆角矩形外侧、略向下偏移的投影；表面内部挖空，不压暗半透明底色。
///
/// 玻璃表面的底色是半透明的，普通 BoxShadow / elevation 会从底下透出来，
/// 把表面中间压暗；这里用偶奇填充把表面本身挖掉，只留下外侧那一圈。
/// 菜单（`ExpressiveMenuSurface`）与 `GlassSurface` 共用。
class OuterShadowPainter extends CustomPainter {
  const OuterShadowPainter({required this.color, required this.borderRadius});

  static const Offset offset = Offset(0, 6);
  static const double blur = 18;

  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final bounds = Offset.zero & size;
    final shape = borderRadius.toRRect(bounds);
    // 偶奇填充：外框减去表面本身，只留下外侧。
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds.inflate(blur * 2 + offset.distance))
      ..addRRect(shape);
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        shape.shift(offset),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            Shadow.convertRadiusToSigma(blur),
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(OuterShadowPainter oldDelegate) =>
      color != oldDelegate.color || borderRadius != oldDelegate.borderRadius;
}
