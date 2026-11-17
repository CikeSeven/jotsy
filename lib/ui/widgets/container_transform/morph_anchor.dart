import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'morph_landing.dart';

/// 整页展开的起点 / 收回的落点之一：一个小控件（新建按钮、草稿箱角标）。
///
/// 输入：标签 [tag]、控件的圆角 [borderRadius]、不透明底色 [color] 与控件的
/// 样子 [appearance]（路由在容器里原尺寸重画它，见 `MorphTransition`）；
/// 输出：经 [MorphAnchor.capture] / [MorphAnchor.locate] 量出的
/// [MorphTarget]。只量位置，不截图、不隐藏控件：容器的底色与外观与控件
/// 一致，起点与终点恰好盖住它。
///
/// 落定（[MorphLandingPhase.landed] 且落在自己身上）时控件接住整页的余速
/// 回弹一下：先被压小 [landingSquash]、越过原尺寸一点再落稳
/// （[ExpressiveMotion.morphLandBounce]）。缩放施加在 [child] 上，量位置
/// 不受它影响。
class MorphAnchor extends StatefulWidget {
  const MorphAnchor({
    super.key,
    required this.tag,
    required this.borderRadius,
    required this.color,
    required this.child,
    this.appearance,
    this.landingSquash = 0.12,
  });

  final Object tag;
  final double borderRadius;

  /// 控件的不透明底色：玻璃控件给出叠在页面估计色上的近似色。
  final Color color;

  /// 控件里面的内容（不含底色），按控件尺寸布局；为 null 时只有底色。须自带
  /// 颜色与字体，不依赖控件所在处的局部主题：它画在路由的浮层里。
  final Widget? appearance;

  /// 落定回弹时最多被压小的比例（0–1）。
  final double landingSquash;

  final Widget child;

  /// 点按时调用（[context] 在控件所在页面里）：在本页找 [tag] 对应、露在屏
  /// 上的控件，作为展开的起点。系统开启“减少动态效果”或平台不用容器展开
  /// （[AppPlatform.supportsContainerTransform]）时返回 null，调用方按普通
  /// 路由打开。
  static MorphTarget? capture(BuildContext context, Object tag) {
    if (!AppPlatform.supportsContainerTransform ||
        ExpressiveMotion.reduceMotion(context)) {
      return null;
    }
    final route = ModalRoute.of(context);
    return route == null ? null : locate(tag, route: route);
  }

  /// 按 [tag] 找回 [route] 里仍挂在树上、露在屏上的控件，量出位置。找不到
  /// 时返回 null。
  static MorphTarget? locate(Object tag, {required ModalRoute<Object?> route}) {
    final candidates = _MorphAnchorState._registry[tag];
    if (candidates == null) return null;
    for (final state in candidates) {
      if (!state.mounted || !identical(state._route, route)) continue;
      final target = state._measure();
      if (target != null) return target;
    }
    return null;
  }

  @override
  State<MorphAnchor> createState() => _MorphAnchorState();
}

class _MorphAnchorState extends State<MorphAnchor>
    with SingleTickerProviderStateMixin {
  static final Map<Object, Set<_MorphAnchorState>> _registry =
      <Object, Set<_MorphAnchorState>>{};

  /// 露在屏上至少这么高才算看得见（小控件的大半截）。
  static const double _minVisibleExtent = 12;

  ModalRoute<Object?>? _route;
  MorphLandingSession? _session;

  /// 回弹的缩放（静止时为 1）；无界：弹簧会越过 1。
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _register(widget.tag);
    MorphLandingSession.current.addListener(_handleSession);
    _handleSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(MorphAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _unregister(oldWidget.tag);
      _register(widget.tag);
    }
  }

  @override
  void dispose() {
    MorphLandingSession.current.removeListener(_handleSession);
    _session?.phase.removeListener(_handlePhase);
    _unregister(widget.tag);
    _scale.dispose();
    super.dispose();
  }

  void _register(Object tag) {
    _registry.putIfAbsent(tag, () => <_MorphAnchorState>{}).add(this);
  }

  void _unregister(Object tag) {
    final set = _registry[tag];
    if (set == null) return;
    set.remove(this);
    if (set.isEmpty) _registry.remove(tag);
  }

  void _handleSession() {
    final session = MorphLandingSession.current.value;
    if (session == null || identical(session, _session)) return;
    _session?.phase.removeListener(_handlePhase);
    _session = session;
    session.phase.addListener(_handlePhase);
  }

  void _handlePhase() {
    final session = _session;
    if (session == null) return;
    final phase = session.phase.value;
    if (phase == MorphLandingPhase.landed ||
        phase == MorphLandingPhase.cancelled) {
      session.phase.removeListener(_handlePhase);
      _session = null;
    }
    if (phase != MorphLandingPhase.landed ||
        !session.targets(widget.tag) ||
        !identical(session.originRoute, _route) ||
        !mounted) {
      return;
    }
    ExpressiveMotion.springTo(
      context,
      _scale,
      1,
      spring: ExpressiveMotion.morphLandBounce,
      kick: ExpressiveMotion.morphLandKick(widget.landingSquash),
      tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
    );
  }

  MorphTarget? _measure() {
    final rect = measureInNavigator(
      context,
      minVisibleExtent: _minVisibleExtent,
    );
    if (rect == null) return null;
    return MorphTarget.anchor(
      tag: widget.tag,
      rect: rect,
      radius: widget.borderRadius,
      color: widget.color,
      appearance: widget.appearance,
    );
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
