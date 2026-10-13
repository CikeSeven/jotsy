import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Expressive 的空间运动与颜色过渡分开处理：只有位移/缩放允许弹簧过冲，
/// 颜色、圆角与透明度使用不越界的 effects 曲线。所有新增动效尊重系统减弱动画。
///
/// 时长分档（对齐 M3 duration token，UI 层不再手写毫秒数）：
/// - [fast]：微交互，图标/颜色切换、小元素显隐、遮罩淡入淡出；
/// - [medium]：内容切换，列表项进出、区块交叉淡入、面板吸附、翻页；
/// - [standard]：空间过渡，页面级转场、较大位移/形变、FAB 显隐；
/// - [long]：强调型/仪式感动画，如时间胶囊封存。
abstract final class ExpressiveMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 250);
  static const standard = Duration(milliseconds: 350);
  static const long = Duration(milliseconds: 500);

  /// 进场与状态变化：减速收尾，不越界。
  static const effects = Curves.easeOutCubic;

  /// 退场：加速离开，与 [effects] 对称，用于 AnimatedSwitcher.switchOutCurve 等。
  static const exit = Curves.easeInCubic;
  static const spatial = _ExpressiveSpringCurve();

  /// 系统是否开启了“减少动态效果”。
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, [Duration value = standard]) =>
      reduceMotion(context) ? Duration.zero : value;
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
