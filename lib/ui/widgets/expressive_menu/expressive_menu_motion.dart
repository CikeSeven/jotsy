import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';

/// 菜单从哪种触发控件长出来，决定透明度节奏（两种都移植自 NexioSchedule）。
enum ExpressiveMenuMorphStyle {
  /// 图标按钮（LiquidGlassDropdownMenu）：玻璃 f × 5 到位，内容在 f 0.3–0.7
  /// 淡入，按钮图标 f 到 0.4 前淡出；收起时带一下回弹。
  button,

  /// 文字入口、卡片与右键菜单（ListPopup）：展开时玻璃 f × 7、内容 0.22–0.62，
  /// 收起时玻璃 f × 3.6、内容 0.30–0.78（进场早淡入、退场晚淡出），触发控件
  /// 展开 f × 3.2、收起 f × 1.7 淡出；没有回弹。
  dropdown,
}

/// 弹出菜单的全部动效进度（移植自 NexioSchedule 的容器变换，参数逐值照搬），
/// 由锚点持有、浮层逐帧读取。
///
/// 菜单本身（[open] / [close]）：
/// - [fraction]：尺寸，从触发控件长成面板（宽高各自插值，不夹 0…1，保留过冲）。
///   展开为欠阻尼弹簧（阻尼比 0.77、刚度 220，末尾约 2% 回弹），收起为更硬的
///   弹簧（0.85、650）。
/// - [origin]：锚点迁移，比尺寸更快到 1（0.77、420）：面板先从触发控件的角
///   移向自身中心再长大；收起用 340ms 的 Cubic(0, 0, 0, 1)，它跑完即收起结束。
/// - [settle]：只有图标按钮（[ExpressiveMenuMorphStyle.button]）在收起时有的
///   一条欠阻尼弹簧（0.52、220），越过 0 的那段（[settlePulse]）让玻璃沿收回
///   方向冲过头 12dp 以内再弹回。
///
/// 二级菜单（[expandSecondary] / [collapseSecondary]，沿用 miuix 的级联）：
/// - [expand]：触发行的胶囊长成新面板、主菜单缩到 0.95 并盖上遮罩，同一条弹簧：
///   展开 folme(0.95, 0.3)，收起 folme(0.95, 0.2)；收起落定后经
///   [onSecondaryCollapsed] 通知锚点卸掉二级菜单。
/// - [arrow]：标题行 › 的转向（0 → 1 为 0° → ∓90°），folme(0.95, 0.2 / 0.3)。
///
/// 按压形变（[primaryJelly] / [secondaryJelly]）见 [ExpressiveMenuJelly]。
///
/// 所有进度都从当前值与速度接着跑。状态（[status]）与 AnimationController 同义，
/// 经 [onStatusChanged] 通知锚点。减少动画时用 [snapOpen] / [snapClosed] 瞬时到位。
class ExpressiveMenuMotion extends ChangeNotifier {
  ExpressiveMenuMotion({
    required TickerProvider vsync,
    required this.onStatusChanged,
    this.onSecondaryCollapsed,
  }) : fraction = AnimationController.unbounded(vsync: vsync),
       origin = AnimationController.unbounded(vsync: vsync),
       settle = AnimationController.unbounded(vsync: vsync),
       expand = AnimationController.unbounded(vsync: vsync),
       arrow = AnimationController.unbounded(vsync: vsync),
       primaryJelly = ExpressiveMenuJelly(vsync: vsync),
       secondaryJelly = ExpressiveMenuJelly(vsync: vsync) {
    for (final listenable in <Listenable>[
      fraction,
      origin,
      settle,
      expand,
      arrow,
      primaryJelly,
      secondaryJelly,
    ]) {
      listenable.addListener(notifyListeners);
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

  static final SpringDescription openSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: 0.77);
  static final SpringDescription openOriginSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.77);
  static final SpringDescription closeSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 650, ratio: 0.85);
  static final SpringDescription settleSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: 0.52);

  /// 二级菜单展开：miuix 原值 folme(0.99, 0.45) 实机偏慢（约 0.47s 才到位），
  /// 按用户反馈加快到 0.3（约 0.32s），阻尼略降保留一点弹性。
  static final SpringDescription expandSpring = folmeSpring(0.95, 0.3);
  static final SpringDescription collapseSpring = folmeSpring(0.95, 0.2);
  static final SpringDescription arrowExpandSpring = folmeSpring(0.95, 0.2);
  static final SpringDescription arrowCollapseSpring = folmeSpring(0.95, 0.3);

  /// 二级菜单打开时主菜单缩到的比例。
  static const double primaryShrunkScale = 0.95;

  /// 收起回弹的最大位移。
  static const double settleDistance = 12;

  /// 内容在形变中途最模糊时的 sigma（NexioSchedule 的 blur 半径 6dp 换算）。
  static const double maxContentBlurSigma = 3.6;

  /// 菜单展开到这一步后才接管跟手滑选（NexioSchedule 的 DragSelectReadyFraction）。
  static const double dragSelectReady = 0.98;

  static const Tolerance _tolerance = Tolerance(distance: 1e-4, velocity: 1e-3);

  final ValueChanged<AnimationStatus> onStatusChanged;

  /// 二级菜单的收起弹簧落定（不是被重新展开打断）时调用。
  final VoidCallback? onSecondaryCollapsed;

  final AnimationController fraction;
  final AnimationController origin;
  final AnimationController settle;
  final AnimationController expand;
  final AnimationController arrow;
  final ExpressiveMenuJelly primaryJelly;
  final ExpressiveMenuJelly secondaryJelly;

  /// 本次打开的透明度节奏。
  ExpressiveMenuMorphStyle style = ExpressiveMenuMorphStyle.dropdown;

  AnimationStatus get status => _status;
  AnimationStatus _status = AnimationStatus.dismissed;

  /// 展开中或已展开（NexioSchedule 的 isEntering：进场与退场的透明度节奏不同）。
  bool get entering => _status.isForwardOrCompleted;

  /// 二级菜单当前是否以展开为目标。
  bool get secondaryExpanded => _secondaryExpanded;
  bool _secondaryExpanded = false;

  /// 主菜单在二级菜单打开时的额外缩放。
  double get primaryScale => 1 + (primaryShrunkScale - 1) * expand.value;

  /// 收起回弹越过终点的量（0 到约 0.15）。
  double get settlePulse => math.max(0, -settle.value);

  /// 跟手滑选是否可以接管（面板已长到 98%）。
  bool get dragSelectReadyNow => entering && fraction.value >= dragSelectReady;

  /// 玻璃（底色、模糊、投影、描边）的显现。
  double get containerAlpha {
    final f = fraction.value;
    final gain = switch (style) {
      ExpressiveMenuMorphStyle.button => 5.0,
      ExpressiveMenuMorphStyle.dropdown => entering ? 7.0 : 3.6,
    };
    return (f * gain).clamp(0.0, 1.0);
  }

  /// 内容的可见窗口。
  double get contentAlpha {
    final f = fraction.value;
    final (from, to) = switch (style) {
      ExpressiveMenuMorphStyle.button => (0.3, 0.7),
      ExpressiveMenuMorphStyle.dropdown =>
        entering ? (0.22, 0.62) : (0.3, 0.78),
    };
    return ((f - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// 内容模糊：清晰 → 中途最模糊 → 清晰。
  double get contentBlurSigma =>
      maxContentBlurSigma *
      (1 - (2 * fraction.value - 1).abs()).clamp(0.0, 1.0);

  /// 触发控件本身的不透明度：面板盖住它长大时淡出，收回时提早淡入。
  late final Animation<double> triggerOpacity = _MotionValue(fraction, () {
    final k = switch (style) {
      ExpressiveMenuMorphStyle.button => entering ? 2.5 : 1.7,
      ExpressiveMenuMorphStyle.dropdown => entering ? 3.2 : 1.7,
    };
    return 1 - (fraction.value * k).clamp(0.0, 1.0);
  });

  bool get isAnimating =>
      fraction.isAnimating ||
      origin.isAnimating ||
      settle.isAnimating ||
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
    // 回弹量归零（值 1 的越界部分为 0），也停下收起时那条回弹。
    settle.value = 1;
    _spring(origin, openOriginSpring, 1);
    _spring(fraction, openSpring, 1).then((_) {
      if (_status != AnimationStatus.forward) return;
      // 弹簧停在容差内而不是正好 1：落到终点，面板不再需要变换图层。
      fraction.value = 1;
      origin.value = 1;
      _setStatus(AnimationStatus.completed);
    });
  }

  /// 换到新位置（右键菜单换点打开）：从触发控件重新长出来。
  void restart() {
    fraction.value = 0;
    origin.value = 0;
    open();
  }

  /// 收起：二级菜单同时收回触发行；锚点迁移的 tween 跑完即结束（与参照实现
  /// 相同，尺寸弹簧此时已贴近 0）。
  void close() {
    _setStatus(AnimationStatus.reverse);
    if (_secondaryExpanded || expand.value != 0) collapseSecondary();
    if (style == ExpressiveMenuMorphStyle.button) {
      settle.value = 1;
      _spring(settle, settleSpring, 0);
    }
    _spring(fraction, closeSpring, 0);
    origin
        .animateTo(
          0,
          duration: ExpressiveMotion.menuMorphExit,
          curve: ExpressiveMotion.menuMorphExitCurve,
        )
        .then((_) {
          if (_status != AnimationStatus.reverse) return;
          _snapAll(0);
          _setStatus(AnimationStatus.dismissed);
        });
  }

  /// 减少动画：瞬时展开 / 收起。
  void snapOpen() {
    fraction.value = 1;
    origin.value = 1;
    settle.value = 1;
    _setStatus(AnimationStatus.completed);
  }

  void snapClosed() {
    _snapAll(0);
    _setStatus(AnimationStatus.dismissed);
  }

  void _snapAll(double value) {
    fraction.value = value;
    origin.value = value;
    // 展开态 1（越界部分为 0）、收起态 0：都没有回弹。
    settle.value = value;
    if (value == 0) {
      _secondaryExpanded = false;
      expand.value = 0;
      arrow.value = 0;
      primaryJelly.reset();
      secondaryJelly.reset();
    }
  }

  /// 展开二级菜单（从触发行的胶囊长出来）。
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
    secondaryJelly.reset();
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
  void settleNow() {
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
    fraction.dispose();
    origin.dispose();
    settle.dispose();
    expand.dispose();
    arrow.dispose();
    primaryJelly.dispose();
    secondaryJelly.dispose();
    super.dispose();
  }
}

/// 面板的按压形变（NexioSchedule 的 InteractiveHighlight + computeDragTransform，
/// 玻璃档参数）：按下时面板放大 2dp，拖动时沿拖动方向轻微拉伸（系数 0.012）
/// 并以 tanh 阻尼跟手位移（系数 0.032）；松手后按压与位移都以弹簧（阻尼比 0.5、
/// 刚度 300）回到原状。减少动画时不变形。
class ExpressiveMenuJelly extends ChangeNotifier {
  ExpressiveMenuJelly({required TickerProvider vsync})
    : press = AnimationController.unbounded(vsync: vsync),
      dx = AnimationController.unbounded(vsync: vsync),
      dy = AnimationController.unbounded(vsync: vsync) {
    press.addListener(notifyListeners);
    dx.addListener(notifyListeners);
    dy.addListener(notifyListeners);
  }

  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 0.5,
  );
  static const double pressGrow = 2;
  static const double stretchRatio = 0.012;
  static const double translationDamping = 0.032;
  static const double verticalRefScale = 0.6;
  static const double aspectPenaltyFloor = 0.97;
  static const Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  final AnimationController press;
  final AnimationController dx;
  final AnimationController dy;

  Offset get offset => Offset(dx.value, dy.value);

  void _springTo(AnimationController c, double target) => c.animateWith(
    SpringSimulation(
      spring,
      c.value,
      target,
      c.velocity,
      tolerance: _tolerance,
    ),
  );

  void down() {
    dx.value = 0;
    dy.value = 0;
    _springTo(press, 1);
  }

  void move(Offset delta) {
    dx.value = delta.dx;
    dy.value = delta.dy;
  }

  void up() {
    _springTo(press, 0);
    _springTo(dx, 0);
    _springTo(dy, 0);
  }

  void reset() {
    press.value = 0;
    dx.value = 0;
    dy.value = 0;
  }

  /// 面板（[size]）此刻的形变：以中心为原点的缩放与位移。[fraction] 越大，
  /// 竖向拉伸的参考尺寸越小（长成面板后竖向更容易拉伸）。
  Matrix4 transformFor(Size size, double fraction) {
    final p = press.value;
    final o = offset;
    if (p == 0 && o == Offset.zero) return Matrix4.identity();
    final width = size.width;
    final height = math.max(1.0, size.height);
    final minDim = math.max(1.0, math.min(width, height));
    final pressScale = 1 + pressGrow / height * math.max(0, p);
    final refY =
        minDim * (1 - (1 - verticalRefScale) * fraction.clamp(0.0, 1.0));
    final penaltyX = math.min(width / height, aspectPenaltyFloor);
    final penaltyY = math.min(
      height / math.max(1.0, width),
      aspectPenaltyFloor,
    );
    final angle = math.atan2(o.dy, o.dx);
    final sx =
        pressScale +
        stretchRatio * (math.cos(angle) * o.dx / minDim).abs() * penaltyX;
    final sy =
        pressScale +
        stretchRatio * (math.sin(angle) * o.dy / refY).abs() * penaltyY;
    final tx = minDim * _tanh(translationDamping * o.dx / minDim);
    final ty = minDim * _tanh(translationDamping * o.dy / minDim);
    final cx = width / 2;
    final cy = height / 2;
    return Matrix4.diagonal3Values(sx, sy, 1)
      ..setTranslationRaw(cx * (1 - sx) + tx, cy * (1 - sy) + ty, 0);
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x.clamp(-20.0, 20.0));
    return (e - 1) / (e + 1);
  }

  @override
  void dispose() {
    press.dispose();
    dx.dispose();
    dy.dispose();
    super.dispose();
  }
}

/// 由某条进度换算出的值，监听与状态都转给 [parent]。
class _MotionValue extends Animation<double>
    with AnimationWithParentMixin<double> {
  _MotionValue(this.parent, this._compute);

  @override
  final Animation<double> parent;
  final double Function() _compute;

  @override
  double get value => _compute();
}
