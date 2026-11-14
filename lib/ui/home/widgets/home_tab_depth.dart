import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme/app_radii.dart';

/// 首页翻页途中每一页的景深：离视口中心越远，越缩成一张带圆角的卡片并
/// 压暗，落位时铺满。点按切页与手指滑动走同一套效果（都只看页码）。
///
/// 输入：本页在 PageView 中的显示下标 [index]、小数页码 [position]（显示序，
/// 见 `HomeTabPageOrder`）、是否启用 [enabled]（宽窗口与减少动画时关闭）、
/// 舞台色 [stageColor]、压暗色 [scrimColor]、卡片自带的底 [background]、
/// 是否按快照绘制 [snapshot] 与落位后是否继续画快照 [holdSnapshot]；无副作用
/// （快照是本渲染对象自己持有、自己释放的位图）。
///
/// 每页按距离 d = |index − position|（夹到 0…1）：
/// 1. 本页槽位先铺舞台色（[stageColor] 为 null 时不铺）；
/// 2. 卡片 = [background]（有背景图时为本区域的壁纸，与首页背景层静止时画的
///    完全相同）+ 页面，以中心缩放（[HomeTabDepthSpec.scale]）、裁成圆角
///    （[HomeTabDepthSpec.radius]）；
/// 3. 卡片内叠一层压暗（[HomeTabDepthSpec.dim]）。
///
/// 快照（[snapshot] 为 true，窄窗口的正常情况）：卡片开始移动的那一帧把
/// “底 + 页面”拍成一张位图，之后逐帧只画这张位图——一次 `drawRRect`
/// （位图作着色器，圆角、缩放都在这一笔里），不建任何图层。为什么：Impeller
/// 没有光栅缓存，实时绘制时两整页的文字、卡片、顶栏玻璃（每条一次背景回读
/// 与模糊）每帧都要重新编码；真机上两页同屏时光栅均值约 11.6ms，按快照画
/// 降到约 4ms。代价是途中页面内容冻结在起步那一刻（首页同时暂停这页的
/// ticker，见 `home_page_pager.dart`），落位后恢复实时绘制。
///
/// 为什么卡片要自带底：快照里的玻璃（顶栏背景模糊、内容卡片的预模糊取样）
/// 只能对着拍照那一刻卡片自己里面的东西算。把本区域的壁纸画进卡片，玻璃
/// 在卡片里始终正确，静止时（壁纸与首页背景层重合）与实时绘制逐像素一致；
/// 卡片之间露出舞台色。拍照时卡片按“落在正中”的位置摆进图层树，内容玻璃的
/// 取样（`CompositedTransformFollower`）对齐的也是静止时的位置。
///
/// 落位后继续画快照（[holdSnapshot]）：快照阶段 GPU 几乎空闲、频率会降下来，
/// 刚落位就恢复实时绘制，头几帧要等 GPU 爬频（真机上 13–15ms）。底栏指示器、
/// 选中动画等收尾期间仍画快照（d 为 0 时与实时绘制逐像素一致），等首页判定
/// 空闲或手指按下时再换回实时绘制——那一帧画面不变，慢一点也看不出来。
///
/// 不按快照画（[snapshot] 为 false：首页第一次显示的页，内容还在加载、入场
/// 动画要在途中播放）或拍不了照（含平台视图）时实时绘制：变换 + 圆角裁切
/// 图层，底与页面照常实时画在里面。此时内容玻璃的取样仍对着背景层的静止
/// 位置，与随卡片移动的底会有错位，只在这一次切页里出现。
///
/// 为什么不用透明度做“退远”：各 Tab 的顶栏是玻璃（BackdropFilter），放进
/// 透明度层后模糊采不到页面（AGENTS.md §6），这里只用变换、裁切与叠色。
/// d 为 0 且没有保持快照时直接画页面、不画底、不建任何图层，与不包这层逐
/// 像素一致。
class HomeTabDepth extends MultiChildRenderObjectWidget {
  HomeTabDepth({
    super.key,
    required this.index,
    required this.position,
    required this.enabled,
    required this.stageColor,
    required this.scrimColor,
    this.snapshot = false,
    this.holdSnapshot = false,
    Widget? background,
    required Widget child,
  }) : hasBackground = background != null,
       super(
         // 两个槽位始终都在、按 key 对应：开关背景时页面的 State 不受影响。
         children: <Widget>[
           RepaintBoundary(
             key: const ValueKey<String>('HomeTabDepth.background'),
             child: background ?? const SizedBox.shrink(),
           ),
           RepaintBoundary(
             key: const ValueKey<String>('HomeTabDepth.page'),
             child: child,
           ),
         ],
       );

  final int index;
  final ValueListenable<double> position;
  final bool enabled;
  final Color? stageColor;
  final Color scrimColor;

  /// 移动途中是否按快照绘制。
  final bool snapshot;

  /// 落位（d 为 0）后是否继续画移动途中拍的那张快照；没有快照时不起作用。
  final bool holdSnapshot;

  /// 是否给了卡片自带的底。
  final bool hasBackground;

  @override
  RenderHomeTabDepth createRenderObject(BuildContext context) =>
      RenderHomeTabDepth(
        index: index,
        position: position,
        enabled: enabled,
        stageColor: stageColor,
        scrimColor: scrimColor,
        snapshot: snapshot,
        holdSnapshot: holdSnapshot,
        hasBackground: hasBackground,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        textDirection: Directionality.of(context),
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
      ..scrimColor = scrimColor
      ..snapshot = snapshot
      ..holdSnapshot = holdSnapshot
      ..hasBackground = hasBackground
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..textDirection = Directionality.of(context);
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

class _DepthParentData extends ContainerBoxParentData<RenderBox> {}

/// [HomeTabDepth] 的渲染对象：第一个子节点是卡片自带的底，第二个是页面。
///
/// 两个子节点按同一尺寸布局；底只在卡片状态（移动途中或保持快照）画，
/// 命中测试与语义只经过页面。
class RenderHomeTabDepth extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DepthParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DepthParentData> {
  RenderHomeTabDepth({
    required this._index,
    required this._position,
    required this._enabled,
    required this._stageColor,
    required this._scrimColor,
    this._snapshot = false,
    this._holdSnapshot = false,
    this._hasBackground = false,
    this._devicePixelRatio = 1,
    this._textDirection = TextDirection.ltr,
  });

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();
  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();

  /// 最近一次读到的距离（已夹到 0…1）。页码变化而距离不变时（如远处的页
  /// 一直是 1）不重绘。
  double _distance = 0;

  /// 移动途中拍的快照及其着色器（位图像素 → 逻辑坐标）；null 表示没有。
  ui.Image? _image;
  ui.ImageShader? _shader;

  /// 拍快照时的尺寸：尺寸变了快照作废。
  Size? _imageSize;

  /// 这一轮移动里拍照失败（含平台视图），改为实时绘制，回到正中后重置。
  bool _snapshotUnsupported = false;

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
    if (!value) _releaseImage();
    markNeedsPaint();
  }

  Color? get stageColor => _stageColor;
  Color? _stageColor;
  set stageColor(Color? value) {
    if (value == _stageColor) return;
    _stageColor = value;
    if (_moving) markNeedsPaint();
  }

  Color get scrimColor => _scrimColor;
  Color _scrimColor;
  set scrimColor(Color value) {
    if (value == _scrimColor) return;
    _scrimColor = value;
    if (_moving) markNeedsPaint();
  }

  bool get snapshot => _snapshot;
  bool _snapshot;
  set snapshot(bool value) {
    if (value == _snapshot) return;
    _snapshot = value;
    _releaseImage();
    markNeedsPaint();
  }

  bool get holdSnapshot => _holdSnapshot;
  bool _holdSnapshot;
  set holdSnapshot(bool value) {
    if (value == _holdSnapshot) return;
    _holdSnapshot = value;
    // 放开保持：回到正中的页这一帧改画实时页面（并释放快照）。
    if (!value && !_moving && _image != null) markNeedsPaint();
  }

  bool get hasBackground => _hasBackground;
  bool _hasBackground;
  set hasBackground(bool value) {
    if (value == _hasBackground) return;
    _hasBackground = value;
    _releaseImage();
    markNeedsPaint();
  }

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _releaseImage();
    markNeedsPaint();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _releaseImage();
    markNeedsPaint();
  }

  RenderBox get _background => firstChild!;
  RenderBox get _page => lastChild!;

  /// 本帧是否在移动（启用且不在正中）。
  bool get _moving => _enabled && _distance > 0;

  /// 测试用：当前的景深参数（未启用或静止时为 identity）。
  @visibleForTesting
  HomeTabDepthSpec get debugSpec =>
      _moving ? HomeTabDepthSpec.at(_distance) : HomeTabDepthSpec.identity;

  /// 测试用：此刻是否持有快照。
  @visibleForTesting
  bool get debugHasSnapshot => _image != null;

  /// 测试用：此刻持有的快照（物理像素）。
  @visibleForTesting
  ui.Image? get debugSnapshot => _image;

  double _readDistance() => (_index - _position.value).abs().clamp(0.0, 1.0);

  void _syncDistance() {
    final next = _readDistance();
    if (next == _distance) return;
    _distance = next;
    // 整页移出视口：PageView 不再画它，快照不会再用到，先放掉这块显存。
    if (next >= 1) _releaseImage();
    if (_enabled) markNeedsPaint();
  }

  void _releaseImage() {
    _shader?.dispose();
    _shader = null;
    _image?.dispose();
    _image = null;
    _imageSize = null;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DepthParentData) {
      child.parentData = _DepthParentData();
    }
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
    _releaseImage();
    _transformLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _page.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _page.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _page.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _page.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _page.getDryLayout(constraints);

  @override
  void performLayout() {
    _page.layout(constraints, parentUsesSize: true);
    size = _page.size;
    _background.layout(BoxConstraints.tight(size));
    if (_imageSize != null && _imageSize != size) _releaseImage();
  }

  /// 以中心缩放 [scale] 的变换。
  Matrix4 _transformFor(double scale) {
    final inset = (1 - scale) / 2;
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(size.width * inset, size.height * inset, 0);
  }

  /// 本页此刻相对正中位置的平移（PageView 按页码把它摆在这里）：
  /// 从左到右时第 i 页在 (i − page) 页宽处，从右到左相反。
  Offset get _displacement {
    final pages = _index - _position.value;
    final sign = _textDirection == TextDirection.rtl ? -1.0 : 1.0;
    return Offset(sign * pages * size.width, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final moving = _moving;
    final holding = !moving && _holdSnapshot && _image != null;
    if (!moving && !holding) {
      _releaseImage();
      _snapshotUnsupported = false;
      _transformLayer.layer = null;
      _clipLayer.layer = null;
      context.paintChild(_page, offset);
      return;
    }
    // 离正中整整一页（及以上）：完全在视口之外，什么也看不见。PageView 本就
    // 不画这样的页；这里也不拍照，免得按错误的位置拍下一张没用的快照。
    if (moving && _distance >= 1) {
      _transformLayer.layer = null;
      _clipLayer.layer = null;
      return;
    }
    final spec = moving
        ? HomeTabDepthSpec.at(_distance)
        : HomeTabDepthSpec.identity;
    if (_snapshot && !_snapshotUnsupported) {
      final shader = _shader ?? _capture(context, offset);
      if (shader != null) {
        _transformLayer.layer = null;
        _clipLayer.layer = null;
        _paintSnapshot(context.canvas, offset, shader, spec, moving);
        return;
      }
    }
    _paintLive(context, offset, spec);
  }

  /// 把“底 + 页面”拍成快照，返回画它用的着色器；不能拍时返回 null。
  ///
  /// 拍照的临时图层按卡片落在正中的位置挂进当前图层树（`pushLayer`），拍完
  /// 立即摘掉，这一帧合成时它已不在树上：挂在树上，内容玻璃的取样
  /// （FollowerLayer）才找得到首页背景层上的 Leader，按静止时的相对位置对齐。
  /// 页面的图层随后不在树上，页内的重绘边界会顺延到恢复实时绘制时再画。
  ui.ImageShader? _capture(PaintingContext context, Offset offset) {
    final layer = OffsetLayer(offset: offset - _displacement);
    context.pushLayer(layer, (PaintingContext context, Offset offset) {
      if (_hasBackground) context.paintChild(_background, offset);
      context.paintChild(_page, offset);
    }, Offset.zero);
    ui.Image? image;
    if (layer.supportsRasterization()) {
      image = layer.toImageSync(
        Offset.zero & size,
        pixelRatio: _devicePixelRatio,
      );
    } else {
      _snapshotUnsupported = true;
    }
    // 摘下后没有别的引用，临时图层随之释放，页面图层脱离它（页面自己的
    // LayerHandle 仍持有）。
    layer.remove();
    if (image == null) return null;
    _image = image;
    _imageSize = size;
    final ratio = 1 / _devicePixelRatio;
    return _shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.diagonal3Values(ratio, ratio, 1).storage,
      filterQuality: FilterQuality.low,
    );
  }

  /// 按快照画卡片：舞台色、一笔带圆角的位图、压暗，全在同一张画布上。
  void _paintSnapshot(
    Canvas canvas,
    Offset offset,
    ui.ImageShader shader,
    HomeTabDepthSpec spec,
    bool moving,
  ) {
    final stage = _stageColor;
    if (moving && stage != null) {
      canvas.drawRect(offset & size, Paint()..color = stage);
    }
    final bounds = Offset.zero & size;
    final card = RRect.fromRectAndRadius(bounds, Radius.circular(spec.radius));
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    if (moving) canvas.transform(_transformFor(spec.scale).storage);
    canvas.drawRRect(card, Paint()..shader = shader);
    final scrim = _scrimColor;
    if (spec.dim > 0 && scrim.a > 0) {
      canvas.drawRRect(
        card,
        Paint()..color = scrim.withValues(alpha: scrim.a * spec.dim),
      );
    }
    canvas.restore();
  }

  /// 实时绘制卡片（不按快照、或拍不了快照时）：变换 + 圆角裁切图层。
  void _paintLive(
    PaintingContext context,
    Offset offset,
    HomeTabDepthSpec spec,
  ) {
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
            if (_hasBackground) context.paintChild(_background, offset);
            context.paintChild(_page, offset);
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
    final page = _page;
    final parentData = page.parentData! as _DepthParentData;
    if (!_moving) {
      return result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            page.hitTest(result, position: transformed),
      );
    }
    return result.addWithPaintTransform(
      transform: _transformFor(HomeTabDepthSpec.at(_distance).scale),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          page.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    if (_moving) {
      transform.multiply(_transformFor(HomeTabDepthSpec.at(_distance).scale));
    }
  }

  /// 卡片的底只是画面，不进语义。
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_page);
  }
}
