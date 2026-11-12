import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme/app_radii.dart';

/// 首页翻页途中每一页的景深：离视口中心越远，越缩成一张带圆角的卡片并
/// 压暗，落位时铺满。点按切页与手指滑动走同一套效果（都只看页码）。
///
/// 输入：本页在 PageView 中的显示下标 [index]、小数页码 [position]（显示序，
/// 见 `HomeTabPageOrder`）、是否启用 [enabled]（宽窗口与减少动画时关闭）、
/// 舞台色 [stageColor] 与压暗色 [scrimColor]；无副作用。
///
/// 只在绘制阶段起作用：页码变化时 `markNeedsPaint`，不重建、不重新布局；
/// 页面自身包在 [RepaintBoundary] 里，逐帧只重新合成它已缓存的图层。
///
/// 每页一层，按距离 d = |index − position|（夹到 0…1）：
/// 1. 本页槽位先铺舞台色（[stageColor] 为 null 时不铺——有背景图时缝隙里
///    直接露出壁纸）；
/// 2. 以中心缩放（[HomeTabDepthSpec.scale]），裁成圆角卡片
///    （[HomeTabDepthSpec.radius]）；
/// 3. 卡片内叠一层压暗（[HomeTabDepthSpec.dim]）。
///
/// 为什么不用透明度做“退远”：各 Tab 的顶栏是玻璃（BackdropFilter），放进
/// 透明度层后模糊采不到页面（AGENTS.md §6），这里只用变换、裁切与叠色。
/// d 为 0（静止）时直接画子树、不建任何图层，与不包这层逐像素一致。
class HomeTabDepth extends SingleChildRenderObjectWidget {
  HomeTabDepth({
    super.key,
    required this.index,
    required this.position,
    required this.enabled,
    required this.stageColor,
    required this.scrimColor,
    required Widget child,
  }) : super(child: RepaintBoundary(child: child));

  final int index;
  final ValueListenable<double> position;
  final bool enabled;
  final Color? stageColor;
  final Color scrimColor;

  @override
  RenderHomeTabDepth createRenderObject(BuildContext context) =>
      RenderHomeTabDepth(
        index: index,
        position: position,
        enabled: enabled,
        stageColor: stageColor,
        scrimColor: scrimColor,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHomeTabDepth renderObject,
  ) {
    renderObject
      ..index = index
      ..position = position
      ..enabled = enabled
      ..stageColor = stageColor
      ..scrimColor = scrimColor;
  }
}

/// 景深的参数，按页面离视口中心的距离 d（0…1）给出。纯函数，装机调参只改
/// 这里。
///
/// 两种缓动：缩放与压暗用 smoothstep(d)——两端斜率为 0，手指刚开始拖时内容
/// 几乎仍是 1:1 跟手，快到位时也平稳收住；圆角用 smoothstep(2d)，走到半程
/// 已是满圆角，卡片的轮廓尽早成形，不会出现“将圆未圆”的一瞬。
@immutable
class HomeTabDepthSpec {
  const HomeTabDepthSpec._(this.scale, this.radius, this.dim);

  /// 一整页远时缩小的比例：两页各走一半时都在 0.96。与日记预览页“层叠”
  /// 翻页的缩小量同档（`DiaryPagerTransition`）。
  static const double maxScaleDrop = 0.08;

  /// 卡片的满圆角：与底栏指示胶囊同一档。
  static const double maxRadius = AppRadii.nav;

  /// 一整页远时压暗的不透明度（乘在压暗色本身的不透明度上）。
  static const double maxDim = 0.16;

  static const HomeTabDepthSpec identity = HomeTabDepthSpec._(1, 0, 0);

  factory HomeTabDepthSpec.at(double distance) {
    final d = distance.abs().clamp(0.0, 1.0);
    if (d == 0) {
      return identity;
    }
    final eased = _smoothstep(d);
    return HomeTabDepthSpec._(
      1 - maxScaleDrop * eased,
      maxRadius * _smoothstep((d * 2).clamp(0.0, 1.0)),
      maxDim * eased,
    );
  }

  final double scale;
  final double radius;
  final double dim;

  static double _smoothstep(double x) => x * x * (3 - 2 * x);
}

/// [HomeTabDepth] 的渲染对象。
class RenderHomeTabDepth extends RenderProxyBox {
  RenderHomeTabDepth({
    required this._index,
    required this._position,
    required this._enabled,
    required this._stageColor,
    required this._scrimColor,
  });

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();
  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();

  /// 最近一次读到的距离（已夹到 0…1）。页码变化而距离不变时（如远处保活
  /// 的页一直是 1）不重绘。
  double _distance = 0;

  int get index => _index;
  int _index;
  set index(int value) {
    if (value == _index) return;
    _index = value;
    _syncDistance();
  }

  ValueListenable<double> get position => _position;
  ValueListenable<double> _position;
  set position(ValueListenable<double> value) {
    if (identical(value, _position)) return;
    if (attached) {
      _position.removeListener(_syncDistance);
      value.addListener(_syncDistance);
    }
    _position = value;
    _syncDistance();
  }

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markNeedsPaint();
  }

  Color? get stageColor => _stageColor;
  Color? _stageColor;
  set stageColor(Color? value) {
    if (value == _stageColor) return;
    _stageColor = value;
    if (_active) markNeedsPaint();
  }

  Color get scrimColor => _scrimColor;
  Color _scrimColor;
  set scrimColor(Color value) {
    if (value == _scrimColor) return;
    _scrimColor = value;
    if (_active) markNeedsPaint();
  }

  /// 本帧是否画景深（启用且不在正中）。
  bool get _active => _enabled && _distance > 0;

  /// 测试用：当前的景深参数（未启用或静止时为 identity）。
  @visibleForTesting
  HomeTabDepthSpec get debugSpec =>
      _active ? HomeTabDepthSpec.at(_distance) : HomeTabDepthSpec.identity;

  double _readDistance() => (_index - _position.value).abs().clamp(0.0, 1.0);

  void _syncDistance() {
    final next = _readDistance();
    if (next == _distance) return;
    _distance = next;
    if (_enabled) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _distance = _readDistance();
    _position.addListener(_syncDistance);
  }

  @override
  void detach() {
    _position.removeListener(_syncDistance);
    super.detach();
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }

  /// 以中心缩放 [scale] 的变换。
  Matrix4 _transformFor(double scale) {
    final inset = (1 - scale) / 2;
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(size.width * inset, size.height * inset, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !_active) {
      _transformLayer.layer = null;
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final spec = HomeTabDepthSpec.at(_distance);
    final stage = _stageColor;
    if (stage != null) {
      context.canvas.drawRect(offset & size, Paint()..color = stage);
    }
    final bounds = Offset.zero & size;
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transformFor(spec.scale),
      (PaintingContext context, Offset offset) {
        _clipLayer.layer = context.pushClipRRect(
          needsCompositing,
          offset,
          bounds,
          RRect.fromRectAndRadius(bounds, Radius.circular(spec.radius)),
          (PaintingContext context, Offset offset) {
            context.paintChild(child, offset);
            final scrim = _scrimColor;
            if (spec.dim > 0 && scrim.a > 0) {
              context.canvas.drawRect(
                offset & size,
                Paint()..color = scrim.withValues(alpha: scrim.a * spec.dim),
              );
            }
          },
          oldLayer: _clipLayer.layer,
        );
      },
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_active) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: _transformFor(HomeTabDepthSpec.at(_distance).scale),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    if (_active) {
      transform.multiply(_transformFor(HomeTabDepthSpec.at(_distance).scale));
    }
  }
}
