import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';

/// 弹出菜单的全部动效进度（移植自 miuix 的 ListPopup / CascadingListPopup，
/// 参数逐值照搬），由锚点持有、浮层逐帧读取。
///
/// 菜单本身（[open] / [close]）三条进度彼此独立：
/// - [enter]：缩放与裁切展开，欠阻尼弹簧（阻尼比 0.82、刚度 362.5，约 1% 过冲），
///   收起时沿同一弹簧从当前速度回到 0。缩放为 0.15 + 0.85 × enter，原点是贴着
///   锚点的那个角；裁切按落点方向展开（[enter] 夹到 0…1），见布局。
/// - [alpha]：内容与玻璃的透明度，展开 200ms、收起 150ms（FastOutSlowIn）。
///   收起时它是主时钟：淡完即移除浮层，此时缩放还没缩到底（约 0.26），
///   菜单是“边缩边淡”地消失。
/// - [dim]：铺满屏幕的变暗层，展开 300ms、收起 150ms（SinOut）。
///
/// 二级菜单（[expandSecondary] / [collapseSecondary]）：
/// - [expand]：二级菜单从触发行变形成面板、主菜单缩到 0.95 并盖上半透明遮罩，
///   三者同一条弹簧——展开为 folme(0.99, 0.45)，收起为更快更硬的
///   folme(0.95, 0.2)；收起弹簧落定后经 [onSecondaryCollapsed] 通知锚点卸掉
///   二级菜单。
/// - [arrow]：二级菜单标题行的 › 转向（0 → 1 对应 0° → ∓90°），
///   folme(0.95, 0.2) 展开、folme(0.95, 0.3) 收起（收起时稍拖在面板后面）。
///
/// 所有进度都从当前值与速度接着跑：收起途中重新展开、二级菜单收到一半又点开，
/// 都不会跳变。状态（[status]）与 AnimationController 同义，经
/// [onStatusChanged] 通知锚点。减少动画时用 [snapOpen] / [snapClosed] /
/// [snapSecondary] 瞬时到位。
class ExpressiveMenuMotion extends ChangeNotifier {
  ExpressiveMenuMotion({
    required TickerProvider vsync,
    required this.onStatusChanged,
    this.onSecondaryCollapsed,
  }) : enter = AnimationController.unbounded(vsync: vsync),
       alpha = AnimationController(vsync: vsync),
       dim = AnimationController(vsync: vsync),
       expand = AnimationController.unbounded(vsync: vsync),
       arrow = AnimationController.unbounded(vsync: vsync) {
    for (final controller in <AnimationController>[
      enter,
      alpha,
      dim,
      expand,
      arrow,
    ]) {
      controller.addListener(notifyListeners);
    }
  }

  /// miuix 的 folmeSpring：用阻尼比与“响应时间”（秒）描述弹簧，
  /// 刚度 = (2π / response)²，质量 1。
  static SpringDescription folmeSpring(double damping, double response) {
    final omega = 2 * math.pi / response;
    return SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: omega * omega,
      ratio: damping,
    );
  }

  static final SpringDescription enterSpring =
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 362.5,
        ratio: 0.82,
      );
  static final SpringDescription expandSpring = folmeSpring(0.99, 0.45);
  static final SpringDescription collapseSpring = folmeSpring(0.95, 0.2);
  static final SpringDescription arrowExpandSpring = folmeSpring(0.95, 0.2);
  static final SpringDescription arrowCollapseSpring = folmeSpring(0.95, 0.3);

  /// 展开起点的缩放：0.15 + 0.85 × [enter]。
  static const double enterScaleFrom = 0.15;

  /// 二级菜单打开时主菜单缩到的比例。
  static const double primaryShrunkScale = 0.95;

  /// miuix 的 visibilityThreshold 0.0001。
  static const Tolerance _tolerance = Tolerance(distance: 1e-4, velocity: 1e-3);

  final ValueChanged<AnimationStatus> onStatusChanged;

  /// 二级菜单的收起弹簧落定（不是被重新展开打断）时调用。
  final VoidCallback? onSecondaryCollapsed;

  final AnimationController enter;
  final AnimationController alpha;
  final AnimationController dim;
  final AnimationController expand;
  final AnimationController arrow;

  AnimationStatus get status => _status;
  AnimationStatus _status = AnimationStatus.dismissed;

  /// 二级菜单当前是否以展开为目标。
  bool get secondaryExpanded => _secondaryExpanded;
  bool _secondaryExpanded = false;

  /// 菜单整体的缩放（含弹簧过冲）。
  double get enterScale => enterScaleFrom + (1 - enterScaleFrom) * enter.value;

  /// 主菜单在二级菜单打开时的额外缩放。
  double get primaryScale => 1 + (primaryShrunkScale - 1) * expand.value;

  bool get isAnimating =>
      enter.isAnimating ||
      alpha.isAnimating ||
      dim.isAnimating ||
      expand.isAnimating ||
      arrow.isAnimating;

  void _setStatus(AnimationStatus value) {
    if (value == _status) return;
    _status = value;
    onStatusChanged(value);
  }

  TickerFuture _spring(
    AnimationController controller,
    SpringDescription spring,
    double target,
  ) => controller.animateWith(
    SpringSimulation(
      spring,
      controller.value,
      target,
      controller.velocity,
      tolerance: _tolerance,
    ),
  );

  /// 展开（收起途中调用时接着当前进度与速度）。
  void open() {
    _setStatus(AnimationStatus.forward);
    dim.animateTo(
      1,
      duration: ExpressiveMotion.popupDimIn,
      curve: ExpressiveMotion.popupDim,
    );
    alpha.animateTo(
      1,
      duration: ExpressiveMotion.popupFadeIn,
      curve: ExpressiveMotion.popupFade,
    );
    _spring(enter, enterSpring, 1).then((_) {
      if (_status != AnimationStatus.forward) return;
      // 弹簧停在容差内而不是正好 1：落到终点，面板不再需要缩放图层。
      enter.value = 1;
      _setStatus(AnimationStatus.completed);
    });
  }

  /// 换到新位置（右键菜单换点打开）：从头重新展开。
  void restart() {
    enter.value = 0;
    alpha.value = 0;
    open();
  }

  /// 收起：二级菜单同时收回触发行，透明度淡完即结束。
  void close() {
    _setStatus(AnimationStatus.reverse);
    if (_secondaryExpanded || expand.value != 0) collapseSecondary();
    _spring(enter, enterSpring, 0);
    dim.animateTo(
      0,
      duration: ExpressiveMotion.popupDimOut,
      curve: ExpressiveMotion.popupDim,
    );
    alpha
        .animateTo(
          0,
          duration: ExpressiveMotion.popupFadeOut,
          curve: ExpressiveMotion.popupFade,
        )
        .then((_) {
          if (_status != AnimationStatus.reverse) return;
          _snapAll(0);
          _setStatus(AnimationStatus.dismissed);
        });
  }

  /// 减少动画：瞬时展开 / 收起。
  void snapOpen() {
    enter.value = 1;
    alpha.value = 1;
    dim.value = 1;
    _setStatus(AnimationStatus.completed);
  }

  void snapClosed() {
    _snapAll(0);
    _setStatus(AnimationStatus.dismissed);
  }

  void _snapAll(double value) {
    enter.value = value;
    alpha.value = value;
    dim.value = value;
    if (value == 0) {
      _secondaryExpanded = false;
      expand.value = 0;
      arrow.value = 0;
    }
  }

  /// 展开二级菜单（从触发行变形出来）。
  void expandSecondary({required bool reduced}) {
    _secondaryExpanded = true;
    if (reduced) {
      expand.value = 1;
      arrow.value = 1;
      return;
    }
    _spring(expand, expandSpring, 1);
    _spring(arrow, arrowExpandSpring, 1);
  }

  /// 收回二级菜单；落定后经 [onSecondaryCollapsed] 卸掉它。
  void collapseSecondary({bool reduced = false}) {
    _secondaryExpanded = false;
    if (reduced) {
      expand.value = 0;
      arrow.value = 0;
      onSecondaryCollapsed?.call();
      return;
    }
    _spring(arrow, arrowCollapseSpring, 0);
    _spring(expand, collapseSpring, 0).then((_) {
      if (_secondaryExpanded) return;
      expand.value = 0;
      onSecondaryCollapsed?.call();
    });
  }

  /// 菜单开着时切换到减少动画：正在跑的进度直接落到终点。
  void settle() {
    if (_status == AnimationStatus.forward) {
      snapOpen();
    } else if (_status == AnimationStatus.reverse) {
      snapClosed();
    }
    if (expand.isAnimating || arrow.isAnimating) {
      if (_secondaryExpanded) {
        expandSecondary(reduced: true);
      } else {
        collapseSecondary(reduced: true);
      }
    }
  }

  @override
  void dispose() {
    enter.dispose();
    alpha.dispose();
    dim.dispose();
    expand.dispose();
    arrow.dispose();
    super.dispose();
  }
}
