import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/display_corners.dart';
import 'container_transform_below_snapshot.dart';
import 'container_transform_gate.dart';
import 'morph_anchor.dart';
import 'morph_landing.dart';
import 'morph_live_target.dart';
import 'morph_transition.dart';

/// 返回时决定候选落点（按优先级）；空列表表示不收回（按主题转场退场，或
/// 从小控件推入的页面原地缩小淡出）。
typedef MorphLandingResolver<T> = List<MorphLanding> Function(T? result);

/// 从小控件（新建按钮）展开成整页、返回时按结果收回到不同落点的页面路由
/// （新建日记用）。
///
/// 两种推入：
/// - 给了 [origin]：从这个小控件展开（容器起点就是控件的形状、底色与样子，
///   见 [MorphTransition]）；
/// - 没给：与 `MaterialPageRoute` 完全相同（主题转场），如编辑页上推入的
///   发布页——它本身不从控件展开，但发表后返回时要落进列表。
///
/// 返回时先问 [landing]（页面经 [bindLanding] 也可以后绑）要候选落点：
/// - 小控件（`MorphAnchorLanding`：草稿箱角标、新建按钮）：下层页面画成
///   快照，整页收成控件、控件的样子在末段淡入，落定后控件回弹一下；
/// - 活卡片（`MorphLiveLanding`：列表里刚发表的新日记）：下层页面实时绘制，
///   列表同时播放让位动画；新卡片排好后拍成图交给容器（`MorphLiveTarget`），
///   容器里页面与卡片图互相渐变，卡片自己落定才露出来；
/// - 都找不到（滑出了屏幕、减少动态效果）：原地缩小淡出；
/// - 没有候选：从控件推入的回到 [origin] 那个控件，否则按主题转场退场。
///
/// 候选在返回那一刻就定下（[MorphLandingSession.begin]，落点一侧据此先做
/// 准备，如角标扣住旧份数），真正落到哪一个等下层页面重新排版之后、按
/// 顺序找第一个露在屏上的（只在 [originRoute] 里找）。时序与“先等几帧再
/// 起步”的理由同 `ContainerTransformPageRoute`：推入时页面首帧排版与第一次
/// 绘制两帧都画完才起步；停稳后返回时下层页面这一帧重新排版（并拍快照），
/// 空等一帧再量落点、起步。
///
/// 曲线：展开为 [ExpressiveMotion.containerSpring]（一按就走、平滑落稳）；
/// 收回为 [ExpressiveMotion.morphLandCurve]（带着余速落进落点），落点接住
/// 余速回弹（[ExpressiveMotion.morphLandBounce]），弹性留在落点上，整页
/// 不在终点前后晃。
///
/// 下层页面（[delegatedTransition]）：画快照时暂停下层动画，实时绘制时照常；
/// 按主题转场推入期间，下层照主题让开（与 `MaterialPageRoute` 相同），开始
/// 收回后原地不动——容器要落进的位置就是它此刻的布局。
class MorphPageRoute<T> extends MaterialPageRoute<T> {
  MorphPageRoute({
    required super.builder,
    required this._originRoute,
    MorphTarget? origin,
    this.backdrop,
    this._landing,
    super.settings,
  }) : _origin = origin,
       _geometry = MorphGeometry(origin),
       _active = ValueNotifier<bool>(origin != null),
       _belowMode = ValueNotifier<_BelowMode>(
         origin != null ? _BelowMode.snapshot : _BelowMode.standard,
       );

  /// 转场途中垫在容器里、页面下面的底，应画得与页面自己的背景一样；null 时
  /// 为主题的 `scaffoldBackgroundColor`。
  final Widget? backdrop;

  final ModalRoute<Object?> _originRoute;
  final MorphTarget? _origin;
  MorphLandingResolver<T>? _landing;
  final MorphGeometry _geometry;

  /// 是否按容器绘制（否则原样交给主题转场）。
  final ValueNotifier<bool> _active;
  final ValueNotifier<_BelowMode> _belowMode;

  final ContainerTransformBelowSnapshotController _belowSnapshot =
      ContainerTransformBelowSnapshotController();

  ContainerTransformGate _gate = ContainerTransformGate.opened();
  MorphLandingSession? _session;

  /// 落向活卡片时最多再等这么多帧，等新卡片排进列表（见 didPop 里的 land）。
  /// 120Hz 下约 100ms，远在闸门的兜底时长（[GatedCurveSimulation.maxHold]）
  /// 之内。
  static const int _maxLiveWaitFrames = 12;

  /// 这一次返回是否走容器收回（否则按主题转场退场）。
  bool _landingMode = false;
  bool _disposed = false;

  /// 落点所在的路由（打开新建流程的页面）。
  ModalRoute<Object?> get originRoute => _originRoute;

  /// [context] 所在的路由若是 [MorphPageRoute] 则返回它。
  static MorphPageRoute<Object?>? maybeOf(BuildContext context) {
    final route = ModalRoute.of(context);
    return route is MorphPageRoute<Object?> ? route : null;
  }

  /// 页面绑定（或换掉）返回时的落点决定：页面里才知道结果对应落到哪里
  /// （如编辑页按有没有写东西决定落进草稿箱还是回到新建按钮）。[context]
  /// 不在本类路由里时什么都不做。
  static void bindLanding(
    BuildContext context,
    MorphLandingResolver<Object?> resolver,
  ) {
    maybeOf(context)?._landing = resolver;
  }

  @override
  Duration get transitionDuration => _origin != null
      ? ExpressiveMotion.containerOpen
      : super.transitionDuration;

  @override
  void install() {
    super.install();
    // 听真正的控制器：[animation] 是代理，推入后的第一帧（offstage）报告完成。
    controller!.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) {
      // 停稳或归位当帧恢复下层的实时绘制。
      _belowSnapshot.enabled = false;
    }
    if (status.isDismissed && _landingMode) {
      _session?.finish(landed: _geometry.target != null);
    }
  }

  @override
  TickerFuture didPush() {
    if (_origin != null) {
      final gate = _gate = ContainerTransformGate();
      _belowSnapshot.enabled = true;
      afterContainerTransformFrames(2, () {
        if (_disposed || !identical(_gate, gate)) return;
        gate.open(
          duration: ExpressiveMotion.containerOpen,
          curve: ExpressiveMotion.containerSpring,
        );
      });
    }
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    // 本页的局部历史（抽屉等）先消化返回，路由并不退场。
    if (willHandlePopInternally) return super.didPop(result);
    var candidates = _landing?.call(result) ?? const <MorphLanding>[];
    final origin = _origin;
    if (candidates.isEmpty && origin != null) {
      candidates = <MorphLanding>[MorphAnchorLanding(origin.tag)];
    }
    final pushedByTheme = origin == null;
    // 按主题推入、还没停稳就返回：照主题原路退回，不在半途换成容器。
    if (pushedByTheme &&
        (candidates.isEmpty || !(controller?.isCompleted ?? false))) {
      return super.didPop(result);
    }
    _landingMode = true;
    final gate = _gate = ContainerTransformGate();
    final live = candidates.isNotEmpty && candidates.first is MorphLiveLanding;
    // 展开途中返回：下层一直在屏上（快照也开着），当场量落点。
    final belowOnScreen = _belowSnapshot.enabled;
    _session = MorphLandingSession.begin(
      candidates: candidates,
      originRoute: _originRoute,
    );
    _belowMode.value = live ? _BelowMode.live : _BelowMode.snapshot;
    _belowSnapshot.enabled = !live;
    _active.value = true;

    void land([int attempt = 0]) {
      if (_disposed || !identical(_gate, gate)) return;
      if (controller == null || controller!.isDismissed) return;
      final reduce = _reduceMotion;
      MorphTarget? target;
      MorphLanding? chosen;
      if (!reduce) {
        for (final candidate in candidates) {
          target = switch (candidate) {
            MorphAnchorLanding(:final tag) => MorphAnchor.locate(
              tag,
              route: _originRoute,
            ),
            MorphLiveLanding(:final tag) => MorphLiveTarget.locate(
              tag,
              route: _originRoute,
            ),
          };
          if (target != null) {
            chosen = candidate;
            break;
          }
        }
        // 刚发表的日记可能还没排进列表（列表的数据流在写库之后才重新查询，
        // 返回时直接发表尤其如此）：整页再停几帧等它，等不到才原地退场。
        if (target == null && live && attempt < _maxLiveWaitFrames) {
          afterContainerTransformFrames(1, () => land(attempt + 1));
          return;
        }
      }
      _geometry.target = target;
      // 活卡片拍成了图：容器接管它的样子，卡片在落下途中不画。
      _session?.startLanding(chosen, takesOverTarget: target?.image != null);
      gate.open(
        duration: target == null
            ? ExpressiveMotion.medium
            : ExpressiveMotion.morphLand,
        curve: target == null
            ? ExpressiveMotion.effects
            : ExpressiveMotion.morphLandCurve,
      );
    }

    if (belowOnScreen) {
      land();
    } else {
      // 停稳后返回：下层此前 offstage，这一帧重新排版（列表排进新卡片、
      // 拍快照），下一帧空等光栅追上，之后按此刻的布局量落点。
      afterContainerTransformFrames(2, land);
    }
    return super.didPop(result);
  }

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
    if (forward ? _origin == null : !_landingMode) {
      // 主题转场：按时长线性推进，曲线由主题转场自己施加。
      return null;
    }
    return GatedCurveSimulation(
      from: controller?.value ?? (forward ? 0.0 : 1.0),
      to: forward ? 1 : 0,
      gate: _gate,
      instant: _reduceMotion,
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final page = super.buildContent(context);
    // 从控件展开时关掉转场途中的 Hero（理由同 ContainerTransformPageRoute）。
    return _origin == null
        ? page
        : RouteHeroGate(animation: controller!, child: page);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_active, _geometry]),
      builder: (BuildContext context, Widget? _) {
        final theme = Theme.of(context);
        final active = _active.value;
        // 自己的进出由容器负责时，主题转场的主进度视为已完成（只剩被盖住
        // 时的让开）；否则原样交给主题转场。两种情况组件类型相同，切换不会
        // 重建页面。
        final themed = theme.pageTransitionsTheme.buildTransitions<T>(
          this,
          context,
          active ? kAlwaysCompleteAnimation : animation,
          secondaryAnimation,
          child,
        );
        final appearance = _geometry.target?.appearance;
        return MorphTransition(
          animation: animation,
          active: active,
          geometry: _geometry,
          scrimColor: theme.colorScheme.scrim,
          pageRadius: DisplayCorners.radii,
          backdrop:
              backdrop ?? ColoredBox(color: theme.scaffoldBackgroundColor),
          appearance: appearance == null
              ? null
              : HeroMode(
                  enabled: false,
                  child: IgnorePointer(
                    child: ExcludeSemantics(child: appearance),
                  ),
                ),
          child: themed,
        );
      },
    );
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _buildBelow;

  Widget? _buildBelow(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (child == null) return null;
    return _MorphBelow(
      mode: _belowMode,
      snapshot: _belowSnapshot,
      allowSnapshotting: allowSnapshotting,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    controller?.removeStatusListener(_handleStatus);
    final session = _session;
    if (session != null) {
      session.finishLater();
    }
    _geometry.target?.image?.dispose();
    _geometry.dispose();
    _active.dispose();
    _belowMode.dispose();
    _belowSnapshot.dispose();
    super.dispose();
  }
}

/// 下层页面此刻的画法。
enum _BelowMode {
  /// 本页按主题转场推入：下层照主题让开、动画照常。
  standard,

  /// 容器展开 / 收回到小控件：下层画成快照（静止、暂停动画）。
  snapshot,

  /// 收回到活卡片：下层实时绘制、动画照常（列表要播放让位动画），但不再
  /// 随本页移动。
  live,
}

/// 下层页面的包装（见 [MorphPageRoute.delegatedTransition]）。三种画法共用
/// 同一结构，只换参数：切换时下层页面不重建。
class _MorphBelow extends StatelessWidget {
  const _MorphBelow({
    required this.mode,
    required this.snapshot,
    required this.allowSnapshotting,
    required this.secondaryAnimation,
    required this.child,
  });

  final ValueNotifier<_BelowMode> mode;
  final ContainerTransformBelowSnapshotController snapshot;
  final bool allowSnapshotting;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final below = ModalRoute.of(context);
    return ValueListenableBuilder<_BelowMode>(
      valueListenable: mode,
      child: child,
      builder: (BuildContext context, _BelowMode mode, Widget? child) {
        var content = child!;
        if (below is PageRoute<Object?>) {
          // 下层自己的被盖住转场已被框架换成静止进度（见
          // `ModalRoute._buildFlexibleTransitions`）：按主题转场推入期间
          // 在这里照主题补上让开，与 MaterialPageRoute 相同；容器转场期间
          // 不动。
          content = Theme.of(context).pageTransitionsTheme.buildTransitions(
            below,
            context,
            kAlwaysCompleteAnimation,
            mode == _BelowMode.standard
                ? secondaryAnimation
                : kAlwaysDismissedAnimation,
            content,
          );
        }
        if (allowSnapshotting) {
          content = ContainerTransformBelowSnapshot(
            controller: snapshot,
            child: content,
          );
        }
        return TickerMode(enabled: mode != _BelowMode.snapshot, child: content);
      },
    );
  }
}
