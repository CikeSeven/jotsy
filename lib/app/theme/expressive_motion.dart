import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Expressive 的空间运动与颜色过渡分开处理：只有位移/缩放允许弹簧过冲，
/// 颜色、圆角与透明度使用不越界的 effects 曲线。所有新增动效尊重系统减弱动画。
abstract final class ExpressiveMotion {
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 350);
  static const effects = Curves.easeOutCubic;
  static const spatial = _ExpressiveSpringCurve();

  static Duration duration(BuildContext context, [Duration value = standard]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

class _ExpressiveSpringCurve extends Curve {
  const _ExpressiveSpringCurve();

  static final _spring = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 500, damping: 30),
    0,
    1,
    0,
  );

  @override
  double transformInternal(double t) => _spring.x(t * 0.6);
}
