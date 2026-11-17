import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import 'morph_landing.dart';

/// 整页收回的落点之一：列表里的一张活卡片（刚发表的新日记）。
///
/// 为什么不像卡片展开那样从下层快照里裁卡片：落进列表时列表要同时播放让位
/// 动画，下层页面必须实时绘制，新卡片也不在路由开始返回前的任何快照里。
/// 于是等新卡片排进列表、画过一帧之后（路由量落点时），把它自己拍成一张图
/// （[MorphLiveTarget.locate]，经卡片外面这层 [RepaintBoundary]，图层挂在
/// 树上，玻璃卡片的预模糊取样照常在图里）交给容器：容器全程不透明，里面
/// 页面与这张图互相渐变，与卡片展开同一画法。
///
/// 为什么不让活卡片自己跟着容器变形、页面淡出露出它：页面一淡，容器里就
/// 透出它下面正在让位滑过的别的卡片；卡片又画在列表的绘制顺序里，后面的
/// 卡片会压在它上面。
///
/// 落下途中（这一次 [MorphLandingSession.takesOverTarget] 且落向 [tag]）
/// 卡片自己不画，位置照常占着；落定那一帧露出来——此时容器正好收成它、
/// 画的就是它的图，不跳——随后接住整页的余速回弹一下（先被压小
/// [landingSquash]、越过原尺寸一点再落稳），绕卡片中心缩放。结构恒定，
/// 开始 / 结束落下都不重建卡片。
class MorphLiveTarget extends StatefulWidget {
  const MorphLiveTarget({
    super.key,
    required this.tag,
    required this.borderRadius,
    required this.child,
    this.landingSquash = 0.035,
  });

  final Object tag;
  final double borderRadius;

  /// 落定回弹时最多被压小的比例（0–1）。卡片大，压一点点就看得出。
  final double landingSquash;

  final Widget child;

  /// 按 [tag] 找回 [route] 里仍挂在树上、露在屏上的卡片，量出位置并拍成图
  /// （须在卡片画过一帧之后调用，如帧后回调；拍不了时图为 null）。图归调用
  /// 方所有。
  static MorphTarget? locate(Object tag, {required ModalRoute<Object?> route}) {
    final candidates = _MorphLiveTargetState._registry[tag];
    if (candidates == null) return null;
    for (final state in candidates) {
      if (!state.mounted || !identical(state._route, route)) continue;
      final rect = measureInNavigator(
        state.context,
        minVisibleExtent: _MorphLiveTargetState._minVisibleExtent,
      );
      if (rect != null) {
        return MorphTarget.live(
          tag: tag,
          rect: rect,
          radius: state.widget.borderRadius,
          image: state._capture(),
        );
      }
    }
    return null;
  }

  @override
  State<MorphLiveTarget> createState() => _MorphLiveTargetState();
}

class _MorphLiveTargetState extends State<MorphLiveTarget>
    with SingleTickerProviderStateMixin {
  static final Map<Object, Set<_MorphLiveTargetState>> _registry =
      <Object, Set<_MorphLiveTargetState>>{};

  /// 露在屏上至少这么高才算看得见：落进一条细缝里不如原地退场。
  static const double _minVisibleExtent = 24;

  final GlobalKey _boundaryKey = GlobalKey();
  ModalRoute<Object?>? _route;
  MorphLandingSession? _session;

  /// 容器正替它画着（落下途中）。
  bool _hidden = false;

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _register(widget.tag);
    MorphLandingSession.current.addListener(_handleSession);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    // 新卡片可能在这一次开始之后才挂上（列表在返回第一帧才排进它）。
    _handleSession();
  }

  @override
  void didUpdateWidget(MorphLiveTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _unregister(oldWidget.tag);
      _register(widget.tag);
      _handleSession();
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
    _registry.putIfAbsent(tag, () => <_MorphLiveTargetState>{}).add(this);
  }

  void _unregister(Object tag) {
    final set = _registry[tag];
    if (set == null) return;
    set.remove(this);
    if (set.isEmpty) _registry.remove(tag);
  }

  void _handleSession() {
    final session = MorphLandingSession.current.value;
    if (session == null ||
        identical(session, _session) ||
        !session.involves(widget.tag) ||
        !identical(session.originRoute, _route)) {
      return;
    }
    _session?.phase.removeListener(_handlePhase);
    _session = session;
    session.phase.addListener(_handlePhase);
    _handlePhase();
  }

  void _handlePhase() {
    final session = _session;
    if (session == null) return;
    final phase = session.phase.value;
    final hidden =
        phase == MorphLandingPhase.landing &&
        session.takesOverTarget &&
        session.targets(widget.tag);
    if (hidden != _hidden && mounted) {
      setState(() => _hidden = hidden);
    }
    if (phase != MorphLandingPhase.landed &&
        phase != MorphLandingPhase.cancelled) {
      return;
    }
    session.phase.removeListener(_handlePhase);
    _session = null;
    if (phase == MorphLandingPhase.landed &&
        session.targets(widget.tag) &&
        mounted) {
      ExpressiveMotion.springTo(
        context,
        _scale,
        1,
        spring: ExpressiveMotion.morphLandBounce,
        kick: ExpressiveMotion.morphLandKick(widget.landingSquash),
        tolerance: const Tolerance(distance: 1e-4, velocity: 1e-3),
      );
    }
  }

  /// 把卡片拍成图（图层挂在树上时就地截取）；还没画过或拍不了时为 null。
  ui.Image? _capture() {
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return null;
    }
    try {
      return boundary.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (error) {
      debugPrint('Capturing the landing card failed: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => _MorphLive(
    hidden: _hidden,
    scale: _scale,
    child: RepaintBoundary(key: _boundaryKey, child: widget.child),
  );
}

class _MorphLive extends SingleChildRenderObjectWidget {
  const _MorphLive({
    required this.hidden,
    required this.scale,
    required super.child,
  });

  final bool hidden;
  final Animation<double> scale;

  @override
  _RenderMorphLive createRenderObject(BuildContext context) =>
      _RenderMorphLive(hidden: hidden, scale: scale);

  @override
  void updateRenderObject(BuildContext context, _RenderMorphLive renderObject) {
    renderObject
      ..hidden = hidden
      ..scale = scale;
  }
}

class _RenderMorphLive extends RenderProxyBox {
  _RenderMorphLive({required this._hidden, required this._scale});

  bool _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
  }

  Animation<double> _scale;
  set scale(Animation<double> value) {
    if (identical(value, _scale)) return;
    if (attached) {
      _scale.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _scale = value;
    markNeedsPaint();
  }

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scale.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scale.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _hidden) {
      _transformLayer.layer = null;
      return;
    }
    final s = _scale.value;
    if ((s - 1).abs() < 1e-4) {
      _transformLayer.layer = null;
      context.paintChild(child, offset);
      return;
    }
    // 落定回弹：绕卡片中心缩放。
    final center = size.center(Offset.zero);
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.translationValues(center.dx, center.dy, 0)
        ..scaleByDouble(s, s, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1),
      (PaintingContext context, Offset offset) =>
          context.paintChild(child, offset),
      oldLayer: _transformLayer.layer,
    );
  }
}
