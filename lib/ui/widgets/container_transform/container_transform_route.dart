import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/display_corners.dart';
import 'container_transform_below_snapshot.dart';
import 'container_transform_source.dart';
import 'container_transform_transition.dart';

/// 从列表卡片展开成整页、返回时缩回卡片的页面路由（M3 容器转场）。
///
/// 输入：页面 [builder] 与点按时记下的起点 [ContainerTransformOrigin]（由
/// [ContainerTransformSource.capture] 得到）。画面见
/// [ContainerTransformTransition]：容器全程不透明，起点与终点恰好盖住原
/// 卡片；容器里卡片的样子从下层快照里裁出，与页面互相渐变，原卡片不隐藏、
/// 也不另外截图。
///
/// 时序（为什么要“先等几帧再起步”）：
/// - 推入：页面的首帧（构建、排版整篇正文；Hero 控制器让它 offstage，只排
///   版不绘制）与第二帧（第一次绘制）往往要几十毫秒。普通路由在这之前就
///   开始计时，首帧一卡，下一帧的进度直接跳过一大截——这就是打开时那一下
///   顿挫。这里的进度先停在 0（容器停在卡片上，画的就是快照里的这张卡片，
///   与屏上分毫不差），首帧同时把下层拍成快照，两帧都画完才开始计时，整段
///   曲线一帧不落；
/// - 返回：下层页面此前不在屏上，返回的第一帧要重新排版、绘制它，同样先停
///   在整页上：这一帧把下层拍成快照，再空等一帧让光栅追上，然后按布局量
///   出卡片此刻的位置（内容可能刚改过）并缩回去。展开途中返回时下层
///   一直在屏上、快照也在，当场量完就原路返回。找不到卡片（翻到了别的一
///   篇且它不在屏上、日记已删除、[returnsToOrigin] 说不回）时原地缩小淡出；
/// - 等待最多 [_GatedCurveSimulation.maxHold]，防止哪一帧迟迟不来时卡住。
///
/// 进度由模拟直接给出（已套上 [ExpressiveMotion.containerSpring]），推入、
/// 返回各自从当前进度出发：进入途中返回、返回途中再进入都不跳变。
///
/// 共享元素：转场期间关闭本页的 Hero（[_RouteHeroGate]）——卡片封面与预览
/// 页头图同一个标签，容器本身已经把卡片展开成整页，再让封面单独飞一趟两者
/// 会错开；停稳之后照常开启，从头图、正文图进看图页的飞行不受影响。
///
/// 下层页面画成快照（[delegatedTransition]，见
/// [ContainerTransformBelowSnapshot]）：转场途中下层页面完全静止（只盖一层
/// 遮罩），却仍要逐帧重新光栅化——首页满屏玻璃卡片的背景模糊、动图封面，
/// 一帧就要 8ms 上下，在 120Hz 下光凭它就吃满预算。改画快照后每帧只剩一张
/// 贴图；停稳或归位当帧恢复实时绘制。原卡片不隐藏，快照里照常有它，被容器
/// 盖着；容器里卡片的样子也从这张快照里裁（[ContainerTransformTransition.belowSnapshot]）。
///
/// 被别的普通页面盖住时（预览页进编辑页）按主题转场让开，与
/// `MaterialPageRoute` 一致。
class ContainerTransformPageRoute<T> extends PageRoute<T> {
  ContainerTransformPageRoute({
    required this.builder,
    required ContainerTransformOrigin origin,
    this.backdrop,
    this.returnsToOrigin,
    super.settings,
  }) : _originRoute = origin.route,
       _returnTag = origin.tag,
       _geometry = ContainerTransformGeometry(origin.bounds);

  final WidgetBuilder builder;

  /// 转场途中垫在容器里、页面下面的底，铺满路由（见
  /// [ContainerTransformTransition.backdrop]）。应画得与页面自己的背景一样
  /// （如 `AppPageBackgroundFill` 画页面所在区域的背景）：页面的背景图还在
  /// 解码时也不透出下层。null 时为主题的 `scaffoldBackgroundColor`。
  final Widget? backdrop;

  /// 按返回值决定返回时是否缩回卡片；null 时总是尝试。如页面里删除了这篇
  /// 日记：卡片随后会从列表里收起，缩回去反而奇怪，改为原地淡出。
  final bool Function(T? result)? returnsToOrigin;

  final ModalRoute<Object?> _originRoute;
  Object _returnTag;
  final ContainerTransformGeometry _geometry;
  _TransitionGate _gate = _TransitionGate.opened();
  bool _disposed = false;

  /// 下层页面的快照开关（见类注释“下层页面画成快照”）。
  final ContainerTransformBelowSnapshotController _belowSnapshot =
      ContainerTransformBelowSnapshotController();

  /// 返回时要缩回的来源标签：页面里换了内容（预览页左右翻到另一篇）时由
  /// 页面改成那一篇的标签。[context] 不在本路由里时什么都不做。
  static void setReturnTag(BuildContext context, Object tag) {
    final route = ModalRoute.of(context);
    if (route is ContainerTransformPageRoute) {
      route._returnTag = tag;
    }
  }

  @override
  Duration get transitionDuration => ExpressiveMotion.containerOpen;

  @override
  Duration get reverseTransitionDuration => ExpressiveMotion.containerClose;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  /// 交给下层路由包住它自己的页面：转场途中由 [_belowSnapshot] 决定画实时
  /// 页面还是快照。下层路由不支持（不是 Material 页面路由、不允许快照）时它
  /// 照常实时绘制，只是没有这项优化。
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _buildBelow;

  Widget? _buildBelow(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (!allowSnapshotting || child == null) {
      return null;
    }
    // 转场途中（以及本页盖住它期间）下层的动画一律暂停：画面反正是快照，
    // 动图封面若继续逐帧解码、上传纹理并重排列表，只会和转场抢 UI 线程与
    // GPU（真机上返回起步时一次上传就占了 24ms）。归位当帧次级进度归零，
    // 这层包装随之撤掉，动画照常继续。
    return TickerMode(
      enabled: false,
      child: ContainerTransformBelowSnapshot(
        controller: _belowSnapshot,
        child: child,
      ),
    );
  }

  @override
  void install() {
    super.install();
    // 听的是真正的控制器：[animation] 是代理，推入后的第一帧路由 offstage
    // 时它报告“已完成”。
    controller!.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) {
      // 下层页面同一帧恢复实时绘制：归位时卡片与列表都是最新的样子；停稳
      // 时下层已经 offstage，不必再留着整屏快照。
      _belowSnapshot.enabled = false;
    }
  }

  @override
  TickerFuture didPush() {
    final gate = _gate = _TransitionGate();
    // 第一帧：Hero 控制器让新路由 offstage，页面只构建、排版，下层这一帧
    // 就拍成快照（原卡片照常在里面，之后被容器盖住）；第二帧：页面第一次
    // 绘制，容器停在卡片上。两帧的重活分开，都画完才开始计时。
    _belowSnapshot.enabled = true;
    _afterFrames(2, () {
      if (_disposed || !identical(_gate, gate)) return;
      gate.open(
        duration: ExpressiveMotion.containerOpen,
        curve: ExpressiveMotion.containerSpring,
      );
    });
    return super.didPush();
  }

  /// [count] 帧画完之后执行 [callback]（转场在动，后面的帧一定会来）。
  static void _afterFrames(int count, VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (count <= 1) {
        callback();
      } else {
        _afterFrames(count - 1, callback);
      }
    });
  }

  @override
  bool didPop(T? result) {
    final gate = _gate = _TransitionGate();
    final toOrigin = returnsToOrigin?.call(result) ?? true;
    // 展开途中返回：下层一直在屏上（布局就是此刻的），快照也还开着。
    final belowOnScreen = _belowSnapshot.enabled;
    _belowSnapshot.enabled = true;
    void land() {
      final bounds = !toOrigin || _reduceMotion
          ? null
          : locateContainerTransformSource(_returnTag, route: _originRoute);
      _geometry.replace(bounds);
      gate.open(
        duration: bounds == null
            ? ExpressiveMotion.medium
            : ExpressiveMotion.containerClose,
        curve: bounds == null
            ? ExpressiveMotion.effects
            : ExpressiveMotion.containerSpring,
      );
    }

    if (belowOnScreen) {
      land();
      return super.didPop(result);
    }
    // 停稳后返回：下层此前 offstage，这一帧重新排版并拍成快照（仍停在整页
    // 上，看不出在等），下一帧空等光栅追上，重活不落进曲线；之后按此刻的
    // 布局量出卡片并起步。
    _afterFrames(2, () {
      if (_disposed || !identical(_gate, gate)) return;
      if (controller == null || controller!.isDismissed) return;
      land();
    });
    return super.didPop(result);
  }

  /// 系统是否开启了“减少动态效果”。只读一次、不登记依赖（这里不在构建
  /// 阶段，也不需要随它变化重建导航器）。
  bool get _reduceMotion {
    final context = navigator?.context;
    return context
            ?.getInheritedWidgetOfExactType<MediaQuery>()
            ?.data
            .disableAnimations ??
        false;
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    final from = controller?.value ?? (forward ? 0.0 : 1.0);
    return _GatedCurveSimulation(
      from: from,
      to: forward ? 1 : 0,
      gate: _gate,
      // 期间系统打开了“减少动态效果”：不等、不动，直接到位。
      instant: _reduceMotion,
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // 与 MaterialPageRoute 相同：只为同类页面让开，全屏对话框不让。
    final notFullscreen =
        nextRoute is! PageRoute || !nextRoute.fullscreenDialog;
    final delegated =
        nextRoute is ModalRoute && nextRoute.delegatedTransition != null;
    return notFullscreen &&
        (nextRoute is MaterialRouteTransitionMixin || delegated);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // 闸门看真正的控制器：[animation] 是代理，推入后的第一帧（offstage）它
    // 报告“已完成”，Hero 控制器恰好在那一帧之后收集两端的 Hero。
    return _RouteHeroGate(
      animation: controller!,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: builder(context),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final theme = Theme.of(context);
    // 自己的进出由容器负责；被盖住时的让开照主题转场（主进度视为已完成）。
    final outgoing = theme.pageTransitionsTheme.buildTransitions<T>(
      this,
      context,
      kAlwaysCompleteAnimation,
      secondaryAnimation,
      child,
    );
    return ContainerTransformTransition(
      animation: animation,
      geometry: _geometry,
      scrimColor: theme.colorScheme.scrim,
      // 整页的圆角取屏幕自带的圆角：卡片一路长成屏幕的形状，落位与物理
      // 圆角重合（读不到时为直角）。
      pageRadius: DisplayCorners.radii,
      belowSnapshot: _belowSnapshot,
      backdrop: backdrop ?? ColoredBox(color: theme.scaffoldBackgroundColor),
      child: outgoing,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    controller?.removeStatusListener(_handleStatus);
    _geometry.dispose();
    // 下层路由此时已不再包快照（下层的次级进度已归零，见
    // `ModalRoute._buildFlexibleTransitions`），不会再用到它。
    _belowSnapshot.dispose();
    super.dispose();
  }
}

/// 转场起步的闸门：关着时进度停在起点，打开时带上这一段的时长与曲线。
class _TransitionGate {
  _TransitionGate();

  _TransitionGate.opened() : _open = true;

  bool _open = false;
  Duration duration = ExpressiveMotion.containerOpen;
  Curve curve = ExpressiveMotion.containerSpring;

  bool get isOpen => _open;

  void open({required Duration duration, required Curve curve}) {
    this.duration = duration;
    this.curve = curve;
    _open = true;
  }
}

/// 从 [from] 按曲线走到 [to]，但闸门打开之后才开始计时。
///
/// 计时起点是闸门打开后的第一次取值（下一帧），于是之前那一帧花多久都不会
/// 让进度跳一截。闸门迟迟不开时最多等 [maxHold]。
class _GatedCurveSimulation extends Simulation {
  _GatedCurveSimulation({
    required this.from,
    required this.to,
    required this.gate,
    this.instant = false,
  });

  /// 闸门最多等这么久（秒）：正常两帧就开，这只是防止哪一帧迟迟不来时
  /// 卡在起点的兜底。
  static const double maxHold = 1;

  /// 起步后的第一步隔了超过这么久（秒），就从这一帧重新起算。
  ///
  /// 为什么：起步帧之前刚把下层整屏拍成快照，GPU 可能还压着几十毫秒的活，
  /// 起步帧（进度仍在起点）被拖到很晚才上屏，下一帧按真实时间算进度，第
  /// 一眼就跳过一大截（真机返回时 34ms，一帧缩掉近两成）。从这一帧重新起
  /// 算，只是晚一两帧起步，看不出在等。正常帧间隔 120Hz 约 8ms、60Hz 约
  /// 17ms，都在阈值以内；只纠正一次，中途掉帧照常按真实时间追上，测试里
  /// `pumpAndSettle` 的 100ms 步长也不会一直卡在起点。
  static const double maxFirstStep = 0.02;

  final double from;
  final double to;
  final _TransitionGate gate;
  final bool instant;

  double? _start;

  /// 第一步是否已经走过（之后不再重新起算）。
  bool _stepped = false;

  double get _seconds =>
      gate.duration.inMicroseconds / Duration.microsecondsPerSecond;

  /// 已走过的时间比例（0–1）；还在等闸门时为 null。
  double? _progress(double time) {
    var start = _start;
    if (start == null) {
      if (!gate.isOpen && time < maxHold) {
        return null;
      }
      start = _start = time;
    } else if (!_stepped && time > start) {
      _stepped = true;
      if (time - start > maxFirstStep) {
        start = _start = time;
      }
    }
    final seconds = _seconds;
    return seconds <= 0 ? 1 : ((time - start) / seconds).clamp(0.0, 1.0);
  }

  bool get _still => instant || from == to;

  @override
  double x(double time) {
    if (_still) {
      return to;
    }
    final t = _progress(time);
    if (t == null) {
      return from;
    }
    return from + (to - from) * gate.curve.transform(t);
  }

  @override
  double dx(double time) {
    final start = _start;
    if (_still || start == null) {
      return 0;
    }
    final seconds = _seconds;
    if (seconds <= 0) {
      return 0;
    }
    final t = ((time - start) / seconds).clamp(0.0, 1.0);
    if (t >= 1) {
      return 0;
    }
    const h = 1e-3;
    final a = gate.curve.transform(t);
    final b = gate.curve.transform((t + h).clamp(0.0, 1.0));
    return (to - from) * (b - a) / (h * seconds);
  }

  @override
  bool isDone(double time) {
    if (_still) {
      return true;
    }
    final start = _start;
    return start != null && time - start >= _seconds;
  }
}

/// 只在路由停稳（进度为 1 且不在动）时开启本页的 Hero。
///
/// 切换开关只重建 [HeroMode] 自己，页面子树不重建。Hero 控制器在路由变化
/// 后的下一帧末尾才收集两端的 Hero，那时开关已随路由状态更新（推入时页面
/// 首次构建就是关着的）。
class _RouteHeroGate extends StatefulWidget {
  const _RouteHeroGate({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_RouteHeroGate> createState() => _RouteHeroGateState();
}

class _RouteHeroGateState extends State<_RouteHeroGate> {
  late bool _enabled = widget.animation.isCompleted;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(_RouteHeroGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
      _enabled = widget.animation.isCompleted;
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    final enabled = status.isCompleted;
    if (enabled != _enabled && mounted) {
      setState(() => _enabled = enabled);
    }
  }

  @override
  Widget build(BuildContext context) =>
      HeroMode(enabled: _enabled, child: widget.child);
}
