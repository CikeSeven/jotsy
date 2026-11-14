import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/display_corners.dart';
import 'container_transform_source.dart';
import 'container_transform_transition.dart';

/// 从列表卡片展开成整页、返回时缩回卡片的页面路由（M3 容器转场）。
///
/// 输入：页面 [builder] 与点按时记下的起点 [ContainerTransformOrigin]（由
/// [ContainerTransformSource.capture] 得到，路由接管其中的画面）。画面见
/// [ContainerTransformTransition]。
///
/// 时序（为什么要“先等一帧再起步”）：
/// - 推入：页面的首帧（构建、排版整篇正文；Hero 控制器让它 offstage，只排
///   版不绘制）与第二帧（第一次绘制）往往要几十毫秒。普通路由在这之前就
///   开始计时，首帧一卡，下一帧的进度直接跳过一大截——这就是打开时那一下
///   顿挫。这里的进度先停在 0（画面与屏上的卡片一模一样，看不出在等），两
///   帧都画完、再空等一帧让光栅线程消化下层快照后才开始计时，整段曲线一帧
///   不落；
/// - 返回：下层页面此前不在屏上，返回的第一帧要重新排版、绘制它，同样先停
///   在整页上等这一帧；画完后重新量出卡片位置并截下它此刻的样子（内容可能
///   刚改过），下一帧把下层拍成快照、再空等一帧，然后缩回去。找不到卡片
///   （翻到了别的一篇且它不在屏上、日记已删除、[returnsToOrigin] 说不回）
///   时原地缩小淡出；
/// - 等待最多 [_GatedCurveSimulation.maxHold]，防止哪一帧迟迟不来时卡住。
///
/// 进度由模拟直接给出（已套上 [ExpressiveMotion.containerSpring]），推入、
/// 返回各自从当前进度出发：进入途中返回、返回途中再进入都不跳变。
///
/// 共享元素：转场期间关闭本页的 Hero（[_RouteHeroGate]）——卡片封面与预览
/// 页头图同一个标签，容器本身已经把卡片展开成整页，再让封面单独飞一趟两者
/// 会错开；停稳之后照常开启，从头图、正文图进看图页的飞行不受影响。
///
/// 下层页面画成快照（[delegatedTransition]）：转场途中下层页面完全静止（只盖
/// 一层遮罩），却仍要逐帧重新光栅化——首页满屏玻璃卡片的背景模糊、动图封面，
/// 一帧就要 8ms 上下，在 120Hz 下光凭它就吃满预算，转场一路掉帧。原卡片隐藏
/// 之后，下层页面改为画一张快照（只在开启后的下一帧光栅化一次，这一帧落在起步
/// 之前），每帧只剩一张贴图；停稳或归位当帧恢复实时绘制。必须等原卡片隐藏后
/// 才拍：先拍会把卡片拍进去，展开途中下面多出一张卡片。
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
       _geometry = ContainerTransformGeometry(origin.takeShot());

  final WidgetBuilder builder;

  /// 转场途中垫在容器里、页面下面的底，铺满路由（见
  /// [ContainerTransformTransition.backdrop]）。应画得与页面自己的背景一样
  /// （如 `AppPageBackgroundFill` 画页面所在区域的背景），与页面作为一整层
  /// 淡入淡出，收回末段不在卡片下方留下不透明的底。null 时为主题的
  /// `scaffoldBackgroundColor`。
  final Widget? backdrop;

  /// 按返回值决定返回时是否缩回卡片；null 时总是尝试。如页面里删除了这篇
  /// 日记：卡片随后会从列表里收起，缩回去反而奇怪，改为原地淡出。
  final bool Function(T? result)? returnsToOrigin;

  final ModalRoute<Object?> _originRoute;
  Object _returnTag;
  final ContainerTransformGeometry _geometry;
  _TransitionGate _gate = _TransitionGate.opened();
  VoidCallback? _releaseSource;
  Object? _heldTag;
  bool _disposed = false;

  /// 下层页面的快照开关（见类注释“下层页面画成快照”）。
  final SnapshotController _belowSnapshot = SnapshotController();

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
      child: SnapshotWidget(
        controller: _belowSnapshot,
        // 含平台视图时退回实时绘制，不抛错。
        mode: SnapshotMode.permissive,
        child: child,
      ),
    );
  }

  @override
  void install() {
    super.install();
    // 展开完毕就不再需要起飞时的卡片画面，先释放掉；返回时会重新截。听的是
    // 真正的控制器：[animation] 是代理，推入后的第一帧路由 offstage 时它报告
    // “已完成”。
    controller!.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) {
      // 停稳或归位的这一帧就交还来源，不能等路由销毁后的下一帧，否则
      // 卡片会先消失一帧。来源布局一直保留，恢复绘制不会挤动列表。
      _restoreSource();
      _geometry.replace(null);
      // 下层页面同一帧恢复实时绘制：归位时卡片与列表都是最新的样子；停稳
      // 时下层已经 offstage，不必再留着整屏快照。
      _belowSnapshot.allowSnapshotting = false;
    }
  }

  /// 隐藏要归位 / 起飞的那张卡片，并让下层页面下一帧重拍快照（此时卡片
  /// 已隐藏）。已在画快照时同样要重拍：换了一张卡片隐藏，旧快照里还是旧的。
  void _holdSource(ContainerTransformShot? shot, Object tag) {
    _restoreSource();
    _releaseSource = shot?.holdSource?.call();
    _heldTag = tag;
    if (_belowSnapshot.allowSnapshotting) {
      _belowSnapshot.clear();
    } else {
      _belowSnapshot.allowSnapshotting = true;
    }
  }

  void _restoreSource() {
    _releaseSource?.call();
    _releaseSource = null;
    _heldTag = null;
  }

  @override
  TickerFuture didPush() {
    final gate = _gate = _TransitionGate();
    // 第一帧：Hero 控制器让新路由 offstage，页面只构建、排版；第二帧：页面
    // 第一次绘制（卡片画面盖着，看不见）。首帧必须仍画来源卡片；帧末等
    // Hero 把目的路由移回屏上，下一帧有截图接替时才隐藏来源，否则会闪空位。
    _afterFrames(1, () {
      if (_disposed ||
          !identical(_gate, gate) ||
          controller?.status != AnimationStatus.forward) {
        return;
      }
      _holdSource(_geometry.closed, _returnTag);
    });
    // 第二帧同时把下层拍成快照（光栅线程上十几毫秒），再空等一帧让光栅
    // 追上，第一帧动画才不会被积压的 GPU 工作拖住。三帧都画完才开始计时。
    _afterFrames(3, () {
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
    // 要重新量卡片时（不是进入途中原路返回），下层这一帧必须实时绘制：画
    // 快照时卡片的图层不在场景里，量不到也截不下来。
    if (!(_releaseSource != null && _heldTag == _returnTag)) {
      _belowSnapshot.allowSnapshotting = false;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || controller == null || controller!.isDismissed) return;
      // 下层页面已在这一帧重新排版、绘制：量出卡片此刻的位置与样子。
      // 进入途中返回同一张卡片时来源仍隐藏：沿用已经截好的画面，不能再截
      // 一次空位。翻到别篇时则捕获新目标，只隐藏实际要归位的那张卡片。
      final reuse = _releaseSource != null && _heldTag == _returnTag;
      final shot = !toOrigin || _reduceMotion
          ? null
          : reuse
          ? _geometry.closed
          : locateContainerTransformSource(_returnTag, route: _originRoute);
      final resnapshot = !reuse || shot == null;
      if (resnapshot) _holdSource(shot, _returnTag);
      _geometry.replace(shot);
      void open() => gate.open(
        duration: shot == null
            ? ExpressiveMotion.medium
            : ExpressiveMotion.containerClose,
        curve: shot == null
            ? ExpressiveMotion.effects
            : ExpressiveMotion.containerSpring,
      );
      if (!resnapshot) {
        open();
        return;
      }
      // 下一帧要把下层页面整屏光栅化成快照：仍停在整页上（盖住下层，看不
      // 出在等），并多等一帧让光栅追上，重活不落进曲线。
      _afterFrames(2, () {
        if (_disposed || !identical(_gate, gate)) return;
        open();
      });
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
      backdrop: backdrop ?? ColoredBox(color: theme.scaffoldBackgroundColor),
      child: outgoing,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    controller?.removeStatusListener(_handleStatus);
    _restoreSource();
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
