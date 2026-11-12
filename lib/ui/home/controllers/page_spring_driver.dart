import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';

/// 用真弹簧（[ExpressiveMotion.springPage]）把 [PageController] 推到某个像素
/// 位置：首页点按底栏切页。
///
/// 为什么不用 `animateToPage`：它是固定时长 + 曲线，中途改目标只能从零速
/// 重新起步，和底栏指示器的弹簧也对不上落点。这里经公开的
/// `ScrollPosition.beginActivity` 挂一个 [BallisticScrollActivity]（物理
/// 模拟驱动的滚动活动，与松手甩动同一种），模拟换成从当前像素、当前速度
/// 奔向目标的弹簧。
///
/// - 改道：再次调用 [springTo] 时带着上一段的速度起步，连点不卡顿；
/// - 结束：返回的 Future 在这段弹簧停稳、被下一段替换或被手指接住（拖动会
///   换掉滚动活动）时完成——调用方据此结算，不用区分是哪一种；
/// - 滚动通知照常发出（start / update / end），`onPageChanged` 不受影响；
/// - 途中页面内容不响应点按（`shouldIgnorePointer`），与 `animateTo` 一致；
///   PageView 自己的拖动手势在这层之外，仍然可以接住。
///
/// 减少动画由调用方处理（直接 `jumpToPage`），这里不判断。
class PageSpringDriver {
  _PageSpringActivity? _active;

  /// 正在运行的这段弹簧的速度（像素 / 秒）；没有在跑时为 0。
  double get velocity {
    final active = _active;
    return active != null && !active.isDisposed ? active.velocity : 0;
  }

  /// 是否有一段弹簧仍在推动页面。
  bool get isRunning {
    final active = _active;
    return active != null && !active.isDisposed;
  }

  /// 让 [position] 以弹簧从当前像素奔向 [target]（像素）。
  ///
  /// [position] 必须是 PageController 的位置（[ScrollPositionWithSingleContext]）。
  /// 停稳的阈值取滚动物理按屏幕密度给出的容差，最后精确落在 [target] 上
  /// （`snapToEnd`），之后由 PageScrollPhysics 判定已在整页、进入空闲。
  Future<void> springTo(ScrollPosition position, double target) {
    final singleContext = position as ScrollPositionWithSingleContext;
    // 先取速度：beginActivity 会释放上一段活动。
    final initialVelocity = velocity;
    final done = Completer<void>();
    final activity = _PageSpringActivity(
      singleContext,
      SpringSimulation(
        ExpressiveMotion.springPage,
        singleContext.pixels,
        target,
        initialVelocity,
        tolerance: singleContext.physics.toleranceFor(singleContext),
        snapToEnd: true,
      ),
      singleContext.context.vsync,
      done,
      singleContext.viewportDimension,
    );
    _active = activity;
    singleContext.beginActivity(activity);
    return done.future;
  }
}

/// 释放时完成 [_done] 的弹簧滚动活动。
///
/// 滚动活动被替换（新一段弹簧、手指按下、跳页）或自然结束后转入空闲时都会
/// 经过 [dispose]，只在这一处完成即可覆盖所有结束方式。
class _PageSpringActivity extends BallisticScrollActivity {
  _PageSpringActivity(
    ScrollActivityDelegate delegate,
    Simulation simulation,
    TickerProvider vsync,
    this._done,
    this._viewportDimension,
  ) : super(delegate, simulation, vsync, true);

  final Completer<void> _done;

  /// 起步时的视口尺寸，弹簧的终点按它换算成像素。
  final double _viewportDimension;
  bool isDisposed = false;

  /// 尺寸“变化”只在视口真的变了时才交还给翻页物理。
  ///
  /// 切页途中首页会换 PageView 的 physics（跨页折叠时禁止拖动），Scrollable
  /// 随之新建滚动位置、接管本活动，新位置第一次布局也会走到这里。父类在
  /// 这里一律改成吸附到最近一页（甩动途中尺寸变了要重新瞄准），会把刚起步
  /// 的弹簧当场换掉；视口没变时终点仍然有效，继续跑。
  @override
  void applyNewDimensions() {
    final position = delegate;
    if (position is ScrollPositionWithSingleContext &&
        position.hasViewportDimension &&
        position.viewportDimension == _viewportDimension) {
      return;
    }
    super.applyNewDimensions();
  }

  @override
  void dispose() {
    isDisposed = true;
    if (!_done.isCompleted) {
      _done.complete();
    }
    super.dispose();
  }
}

/// 首页的翻页物理：只把松手吸附到页的弹簧换成 [ExpressiveMotion.springPage]，
/// 与点按切页（[PageSpringDriver]）同一手感。
///
/// PageView 会在外面再包一层 [PageScrollPhysics]（按页吸附），它的吸附
/// 弹簧取 `spring`，沿父链读到这里；越界与回弹照旧（本类不改，父链与改版前
/// 传 `const PageScrollPhysics()` 时相同）。
class HomeTabPagePhysics extends ScrollPhysics {
  const HomeTabPagePhysics({super.parent});

  @override
  HomeTabPagePhysics applyTo(ScrollPhysics? ancestor) =>
      HomeTabPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => ExpressiveMotion.springPage;
}
