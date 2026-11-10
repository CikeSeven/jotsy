import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Expressive 的空间运动与颜色过渡分开处理：只有位移/缩放允许弹簧过冲，
/// 颜色、圆角与透明度使用不越界的 effects 曲线。所有新增动效尊重系统减弱动画。
/// 弹簧有两种：固定时长的曲线 [spatial]（配 [duration]，给隐式动画组件用）
/// 与按物理模拟推进的真弹簧（[springSpatial] 等，经 [springTo]，可带速度
/// 改目标）。
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

  /// 循环动画的周期（不是一次过渡的时长）：减少动画时这些循环一律不启动，
  /// 也不经 [duration] 解析。
  /// - [pulseLoop]：雷达波纹一圈（局域网同步英雄卡，三圈各差三分之一周期）；
  /// - [flowLoop]：连线跑道上的圆点走完一程；
  /// - [scanLoop]：扫码页扫描线往返一次。
  static const pulseLoop = Duration(milliseconds: 3600);
  static const flowLoop = Duration(milliseconds: 1800);
  static const scanLoop = Duration(milliseconds: 2400);

  /// 弹出菜单（移植自 NexioSchedule 的 ListPopup / LiquidGlassDropdownMenu），
  /// 与原实现逐值一致；面板的长大与二级菜单的展开是弹簧，见
  /// `ExpressiveMenuMotion`。
  /// - [menuMorphExit] / [menuMorphExitCurve]：收起时锚点迁回触发控件的时长
  ///   与曲线，它跑完即移除浮层；
  /// - [menuHighlightIn] / [menuHighlightOut]：行高亮胶囊的淡入淡出
  ///   （[menuHighlightCurve]），淡出覆盖一路滑到边界项的弹簧行程。
  static const menuMorphExit = Duration(milliseconds: 340);
  static const menuMorphExitCurve = Cubic(0, 0, 0, 1);
  static const menuHighlightIn = Duration(milliseconds: 90);
  static const menuHighlightOut = Duration(milliseconds: 220);

  /// Compose `tween` 的默认曲线 FastOutSlowIn。
  static const menuHighlightCurve = Curves.fastOutSlowIn;

  /// 进场与状态变化：减速收尾，不越界。
  static const effects = Curves.easeOutCubic;

  /// 退场：加速离开，与 [effects] 对称，用于 AnimatedSwitcher.switchOutCurve 等。
  static const exit = Curves.easeInCubic;
  static const spatial = _ExpressiveSpringCurve();

  /// 真弹簧（按物理模拟推进，而不是 [spatial] 那样固定时长的曲线）：只用于
  /// 位移、尺寸与缩放。中途改目标时带着当前速度接着走，不会像补间那样从
  /// 零速重新起步——连点、滚动中途反向时动作才连贯。参数对齐 M3 Expressive
  /// 的 spatial 弹簧（阻尼比 / 刚度），经 [springTo] 驱动。
  /// - [springSpatial]：默认档，过冲约 2%，较大位移（底栏显隐、槽位展开）；
  /// - [springSpatialFast]：快而弹，过冲约 10%，小元素的按压回弹与图标弹出；
  /// - [springIndicator]：选中指示器在导航项之间滑动，过冲约 5%：看得出
  ///   弹性，又不至于冲出相邻一项。
  static final SpringDescription springSpatial =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);
  static final SpringDescription springSpatialFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);
  static final SpringDescription springIndicator =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.7);

  /// 让无界控制器 [controller] 以弹簧 [spring] 从当前值、当前速度奔向
  /// [target]。
  ///
  /// [controller] 必须由 `AnimationController.unbounded` 创建（弹簧会越过
  /// 目标再回落，有界控制器会把过冲截掉）。减少动画时直接到位、不启动模拟；
  /// 已经停在目标上时同样什么都不做，免得白跑一帧。[tolerance] 是判定“停稳”
  /// 的距离与速度阈值，按被驱动的量纲给（像素量用默认值即可）。
  static void springTo(
    BuildContext context,
    AnimationController controller,
    double target, {
    SpringDescription? spring,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }) {
    if (reduceMotion(context)) {
      controller.value = target;
      return;
    }
    if (!controller.isAnimating && controller.value == target) {
      return;
    }
    controller.animateWith(
      SpringSimulation(
        spring ?? springSpatial,
        controller.value,
        target,
        controller.isAnimating ? controller.velocity : 0,
        tolerance: tolerance,
        // 停稳时落在目标值上，而不是差着容差以内的一点：静止后的位置与
        // 尺寸才是整值，不留亚像素的偏差。
        snapToEnd: true,
      ),
    );
  }

  /// 系统是否开启了“减少动态效果”。
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, [Duration value = standard]) =>
      reduceMotion(context) ? Duration.zero : value;

  /// 近似瞬时（1ms），只用于不接受 0 时长的 API，见 [durationNonZero]。
  static const nearInstant = Duration(milliseconds: 1);

  /// 与 [duration] 相同，但减少动画时返回 [nearInstant] 而不是 0。
  ///
  /// 用于不能接受 0 时长的 API：`AnimatedSize` 时长为 0 时，子树尺寸一变就会在
  /// 自己的 performLayout 里同步 forward 并通知监听者，从而重新标脏自身（debug 下
  /// 触发 “mutated in its own performLayout” 断言）。1ms 在视觉上与 0 等价。
  static Duration durationNonZero(
    BuildContext context, [
    Duration value = standard,
  ]) => reduceMotion(context) ? nearInstant : value;
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
