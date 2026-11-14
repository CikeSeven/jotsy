import 'dart:math' as math;

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

  /// 容器展开（列表卡片 ↔ 整页，见 `ContainerTransformPageRoute`）：
  /// - [containerOpen]：展开（M3 long1，450ms）；
  /// - [containerClose]：收回卡片（M3 medium4，400ms），返回比进入略快；
  /// - [containerSpring]：位置、尺寸、圆角共用的空间曲线，仿手机系统打开
  ///   应用——一按就走、速度平滑地升起又回落、慢慢落稳、不回弹。收回时同
  ///   一条曲线作用在“离开整页的进度”上，同样是立刻离开、轻轻落进卡片。
  ///
  /// 为什么不用 M3 emphasized：它前 ~40ms 几乎不动，随后速度峰值冲到平均
  /// 速度的约 10 倍、100ms 左右就走完八成，剩下的时间只挪最后 2%；挂在进度
  /// 上的交叉淡化也被压进 70ms 左右——看起来是“顿一下、甩一下、闪一下”。
  /// 临界阻尼弹簧的峰值只有平均速度的约 3.3 倍，同样的时长里交叉淡化也拉
  /// 长了约一半。
  static const containerOpen = Duration(milliseconds: 450);
  static const containerClose = Duration(milliseconds: 400);
  static const containerSpring = _CriticallyDampedSpringCurve(9);

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
  /// - [springIndicator]：选中指示器在导航项之间滑动。偏软、过冲约 2.5%：
  ///   起步不猛、落点轻轻越过再收回，配合途中按速度的拉伸，看起来是一滴
  ///   滑过去的水而不是一块弹过去的板。
  /// - [springPage]：首页翻页（点按底栏切页与松手吸附到页）。响应速度与
  ///   [springIndicator] 相近，两者同时落位；阻尼比高，过冲不到千分之二
  ///   （一整屏也不到 1 像素）——整页内容晃动会显得廉价，弹性留给指示器。
  static final SpringDescription springSpatial =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);
  static final SpringDescription springSpatialFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);
  static final SpringDescription springIndicator =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 0.76);
  static final SpringDescription springPage =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 340, ratio: 0.9);

  /// 让无界控制器 [controller] 以弹簧 [spring] 从当前值、当前速度奔向
  /// [target]。
  ///
  /// [controller] 必须由 `AnimationController.unbounded` 创建（弹簧会越过
  /// 目标再回落，有界控制器会把过冲截掉）。减少动画时直接到位、不启动模拟；
  /// 已经停在目标上时同样什么都不做，免得白跑一帧。[tolerance] 是判定“停稳”
  /// 的距离与速度阈值，按被驱动的量纲给（像素量用默认值即可）。
  ///
  /// [kick] 是叠加在当前速度上的初速度（单位 / 秒，与被驱动的量同量纲）：
  /// 给一个朝目标方向的初速度，弹簧会多越过终点一截再落回——图标选中时
  /// “弹一下”用它，不必另起一段动画。有 [kick] 时即使已停在目标上也会
  /// 启动。
  static void springTo(
    BuildContext context,
    AnimationController controller,
    double target, {
    SpringDescription? spring,
    Tolerance tolerance = Tolerance.defaultTolerance,
    double kick = 0,
  }) {
    if (reduceMotion(context)) {
      controller.value = target;
      return;
    }
    if (kick == 0 && !controller.isAnimating && controller.value == target) {
      return;
    }
    controller.animateWith(
      SpringSimulation(
        spring ?? springSpatial,
        controller.value,
        target,
        (controller.isAnimating ? controller.velocity : 0) + kick,
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

/// 临界阻尼弹簧从静止出发、奔向 1 的位移，压进固定时长（见
/// [ExpressiveMotion.containerSpring]）。
///
/// 位移为 `x(u) = 1 − (1 + u)·e^(−u)`（`u = ωt`）：起点速度为 0 但加速度
/// 最大，第一帧就动起来；速度在 `u = 1` 处达到峰值后平滑回落，没有尖峰，
/// 也永远不越过终点。
///
/// 为什么是固定时长的曲线而不是真弹簧（[ExpressiveMotion.springTo]）：转场
/// 的总时长要可控（时长 token 决定），路由的闸门模拟也是按时长计时的。
///
/// 为什么刻意不回弹：路由控制器的进度被夹在 0–1，欠阻尼弹簧的过冲会被截
/// 成一段平台，整页在终点前后来回切换“容器 / 停稳”两种绘制；整页晃动本
/// 身也显得廉价。
class _CriticallyDampedSpringCurve extends Curve {
  const _CriticallyDampedSpringCurve(this.settle);

  /// 时长走完时弹簧走过的 `ωt`。越大越靠前（起步越猛、落稳段越长）。取 9
  /// 时终点处离 1 只差约 0.12%，归一化补上这点差额后，停下那一刻的速度只
  /// 剩平均速度的约 1%，看不出到位的顿挫。
  final double settle;

  static double _raw(double u) => 1 - (1 + u) * math.exp(-u);

  @override
  double transformInternal(double t) => _raw(settle * t) / _raw(settle);
}
