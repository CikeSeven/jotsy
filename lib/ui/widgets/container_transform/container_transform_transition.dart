import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'container_transform_source.dart';

/// 容器展开的起点 / 终点：卡片的位置与画面，或“无处可回”时的原地退场。
///
/// 由路由持有并管理画面的释放：推入时是点按的那张卡片；返回时换成重新量出
/// 并截取的卡片，找不到时为 [fallback]。改动后通知绘制层重画，不重建页面。
class ContainerTransformGeometry extends ChangeNotifier {
  ContainerTransformGeometry(ContainerTransformShot? shot) : _closed = shot;

  ContainerTransformShot? _closed;
  ContainerTransformShot? get closed => _closed;

  /// 没有卡片可回（翻到了列表里看不到的一篇、日记已删除、卡片滑出了屏幕）：
  /// 整页原地缩小一点并淡出。
  bool get fallback => _closed == null;

  /// 换成新的起点 / 终点，并释放旧画面（同一个实例时不释放）。
  void replace(ContainerTransformShot? shot) {
    if (identical(shot, _closed)) {
      return;
    }
    final previous = _closed;
    _closed = shot;
    previous?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    final previous = _closed;
    _closed = null;
    previous?.dispose();
    super.dispose();
  }
}

/// [ContainerTransformTransition] 的两个子节点。
enum ContainerTransformSlot {
  /// 容器的底：与页面自己的背景一样，垫在页面下面。
  backdrop,

  /// 页面本身。
  page,
}

/// 按路由进度 [animation]（0 = 卡片，1 = 整页）把页面画成从卡片展开的容器。
///
/// 只在绘制阶段逐帧变化：页面按整屏尺寸布局一次，之后每帧只改裁切与缩放，
/// 页面本身既不重建也不重新布局（它在路由的 RepaintBoundary 里，连重绘都
/// 不需要，只是按原尺寸合成进离屏纹理、再整张位图缩放，文字不随缩放重新
/// 栅格化）。进度为 1 时原样绘制页面，不留任何额外图层，[backdrop] 也不再
/// 绘制。
///
/// 每帧自下而上：
/// 1. 下层页面上的遮罩（`scrim`），随进度加深；
/// 2. 容器：圆角矩形，左上角与宽度从卡片插值到整屏，圆角从卡片圆角过渡到
///    [pageRadius]（屏幕自带的圆角，落位时与屏幕的物理圆角重合）；高度见
///    下文“容器形状”。里面依次是
///    - 底（[backdrop]）：按整屏布局、与页面同样缩放贴顶；
///    - 页面：按整屏布局，宽度缩放到容器宽、顶边对齐容器顶边；
///    - 卡片：起飞 / 返回前从页面层截下的卡片画面（[ContainerTransformShot.image]），
///      同样按容器宽度缩放、贴顶，只在 [_cardFade] 区间里与页面互相渐变。
///
/// 容器全程不透明，后面的列表与背景从不透出来：底与页面始终完全不透明，
/// 渐变只发生在容器里面（页面 ↔ 卡片）。进度在 [_cardFade] 之下时容器里
/// 完全是卡片的样子，起点 / 终点与屏上的原卡片逐像素一致；容器接替后原卡片
/// 暂停绘制（保留布局），展开 / 收回露出原位置时只剩页面背景，不再出现第二张
/// 卡片，落位当帧再恢复原卡片绘制，交接不跳。截下的画面连同卡片背后的背景
/// 一起是不透明的，玻璃卡片的模糊也在里面；拍不到画面时（含平台视图）没有
/// 这层，起步与落位直接在卡片与页面之间切换。
///
/// 容器形状：卡片只按宽度等比缩放，若高度照常从卡片高插值到整屏，卡片显出
/// 的那段容器会比卡片高一截、在卡片下方拖出一截页面。所以高度在
/// [_shapeBlend] 区间里从“整屏插值”过渡到“此刻宽度下的卡片比例”，卡片
/// 完全显出（进度到 [_cardFade] 下沿）时容器正好是缩放后的卡片。
///
/// 透明度只按进度取值（不按时间），返回途中再点进入、进入途中返回都不会
/// 跳变。无处可回时（[ContainerTransformGeometry.fallback]）终点是屏幕中央
/// 缩小一点的矩形，底与页面作为一整层按进度淡出——没有卡片可落，只能原地
/// 退场。
class ContainerTransformTransition
    extends
        SlottedMultiChildRenderObjectWidget<ContainerTransformSlot, RenderBox> {
  const ContainerTransformTransition({
    super.key,
    required this.animation,
    required this.geometry,
    required this.scrimColor,
    required this.backdrop,
    required this.child,
    this.pageRadius = BorderRadius.zero,
  });

  final Animation<double> animation;
  final ContainerTransformGeometry geometry;
  final Color scrimColor;

  /// 整页（进度 1）时容器的圆角，应取屏幕自带的圆角（`DisplayCorners`）：
  /// 展开落位时容器的角与屏幕的物理圆角重合，停稳后不再裁切也看不出变化；
  /// 收回时也是从屏幕的形状出发。读不到时为直角。
  final BorderRadius pageRadius;

  /// 容器的底，应与页面自己的背景一致（见类注释）；不参与点按与读屏。
  final Widget backdrop;

  /// 页面。
  final Widget child;

  @override
  Iterable<ContainerTransformSlot> get slots => ContainerTransformSlot.values;

  @override
  Widget? childForSlot(ContainerTransformSlot slot) => switch (slot) {
    ContainerTransformSlot.backdrop => backdrop,
    ContainerTransformSlot.page => child,
  };

  @override
  RenderContainerTransform createRenderObject(BuildContext context) {
    return RenderContainerTransform(
      animation: animation,
      geometry: geometry,
      scrimColor: scrimColor,
      pageRadius: pageRadius,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderContainerTransform renderObject,
  ) {
    renderObject
      ..animation = animation
      ..geometry = geometry
      ..scrimColor = scrimColor
      ..pageRadius = pageRadius;
  }
}

/// 某一帧的容器几何、遮罩与透明度（见 [ContainerTransformTransition]）。
@immutable
class _Frame {
  const _Frame({
    required this.rect,
    required this.radius,
    required this.transform,
    required this.scrimAlpha,
    required this.shadowAlpha,
    required this.groupAlpha,
    required this.cardAlpha,
  });

  final Rect rect;
  final BorderRadius radius;

  /// 页面（整屏布局）到容器的变换：按宽度等比缩放，左上角对齐容器。
  final Matrix4 transform;
  final double scrimAlpha;

  /// 容器外侧投影的强度倍率（0 = 整页无投影，1 = 卡片静止态完整投影）。
  final double shadowAlpha;

  /// 底 + 页面整体的透明度：有卡片可落时恒为 1，只有原地退场时随进度变化。
  final double groupAlpha;

  /// 容器里卡片的透明度（盖在不透明的页面上）。
  final double cardAlpha;
}

/// 布局与页面相同（页面按父级约束布局，底按页面尺寸铺满）；点按、读屏与
/// 停稳后的绘制都只有页面，底只在转场途中画。
class RenderContainerTransform extends RenderBox
    with SlottedContainerRenderObjectMixin<ContainerTransformSlot, RenderBox> {
  RenderContainerTransform({
    required this._animation,
    required this._geometry,
    required this._scrimColor,
    this._pageRadius = BorderRadius.zero,
  });

  /// 下层页面上遮罩的最大不透明度（M3 的遮罩约 32%，这里略轻：容器本身已
  /// 足够醒目，只需把下层压下去一点）。
  static const double _maxScrim = 0.28;

  /// 进度达到这里之后容器里的点按交给页面：展开末段长长的减速里就能开始
  /// 滑动；更早时页面还小，点按一律由容器接住，不会误点到页面或下层列表。
  static const double _interactiveFrom = 0.75;

  /// 容器里卡片 ↔ 页面渐变的进度区间：下沿以下完全是卡片，上沿以上完全是
  /// 页面。返回时约在第 60–120ms、打开时约在第 50–100ms（弹簧曲线前段
  /// 走得快），都发生在容器移动最快的时候。
  static const Interval _cardFade = Interval(0.25, 0.6);

  /// 容器高度从“卡片比例”过渡到“整屏插值”的进度区间：下沿与 [_cardFade]
  /// 对齐（卡片完全显出时正好是卡片的形状），之后平滑长回整屏。
  static const Interval _shapeBlend = Interval(
    0.25,
    1,
    curve: Curves.easeInOut,
  );

  /// 无处可回时终点矩形相对整屏的比例与圆角。
  static const double _fallbackScale = 0.9;
  static const double _fallbackRadius = 28;

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) {
      return;
    }
    if (attached) {
      _animation.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _animation = value;
    markNeedsPaint();
  }

  ContainerTransformGeometry _geometry;
  set geometry(ContainerTransformGeometry value) {
    if (identical(value, _geometry)) {
      return;
    }
    if (attached) {
      _geometry.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _geometry = value;
    markNeedsPaint();
  }

  Color _scrimColor;
  set scrimColor(Color value) {
    if (value == _scrimColor) {
      return;
    }
    _scrimColor = value;
    markNeedsPaint();
  }

  BorderRadius _pageRadius;
  set pageRadius(BorderRadius value) {
    if (value == _pageRadius) {
      return;
    }
    _pageRadius = value;
    markNeedsPaint();
  }

  RenderBox? get _backdrop => childForSlot(ContainerTransformSlot.backdrop);
  RenderBox? get _page => childForSlot(ContainerTransformSlot.page);

  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<OpacityLayer> _groupLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<ImageFilterLayer> _scaleLayer =
      LayerHandle<ImageFilterLayer>();

  /// 进度到 1（整页）时与普通页面完全相同。
  bool get _settled => _animation.value >= 1;

  /// 测试用：此刻容器的位置与尺寸（本地坐标）。
  @visibleForTesting
  Rect get debugContainerRect => _frame().rect;

  @override
  void performLayout() {
    final page = _page;
    if (page == null) {
      size = constraints.smallest;
    } else {
      page.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(page.size);
    }
    // 底与页面同尺寸：缩放、贴顶的方式相同，背景图的取景与页面背景一致。
    _backdrop?.layout(BoxConstraints.tight(size));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final page = _page;
    return page == null
        ? constraints.smallest
        : constraints.constrain(page.getDryLayout(constraints));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _page?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _page?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _page?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _page?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // 底只是转场时的画面，读屏只看页面。
    final page = _page;
    if (page != null) {
      visitor(page);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
    _geometry.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _geometry.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clearLayers();
    super.dispose();
  }

  void _clearLayers() {
    _clipLayer.layer = null;
    _groupLayer.layer = null;
    _scaleLayer.layer = null;
  }

  _Frame _frame() {
    final p = _animation.value.clamp(0.0, 1.0);
    final full = Offset.zero & size;
    final closed = _geometry.closed;
    final Rect closedRect;
    final double closedRadius;
    if (closed == null || closed.rect.isEmpty) {
      closedRect = Rect.fromCenter(
        center: full.center,
        width: full.width * _fallbackScale,
        height: full.height * _fallbackScale,
      );
      closedRadius = _fallbackRadius;
    } else {
      closedRect = closed.rect;
      closedRadius = closed.radius;
    }
    final fallback = closed == null || closed.rect.isEmpty;
    var rect = Rect.lerp(closedRect, full, p)!;
    if (!fallback) {
      // 容器形状（见类注释）：卡片比例的高度与整屏插值的高度之间过渡。
      final cardShaped = rect.width * closedRect.height / closedRect.width;
      rect = Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width,
        lerpDouble(cardShaped, rect.height, _shapeBlend.transform(p))!,
      );
    }
    final scale = full.width <= 0 ? 1.0 : rect.width / full.width;
    final transform = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(rect.left, rect.top, 0);
    return _Frame(
      rect: rect,
      // 圆角与位置尺寸同一条进度：从卡片的角一路长成屏幕的角，途中不会
      // 先变成直角。
      radius: BorderRadius.lerp(
        BorderRadius.circular(closedRadius),
        _pageRadius,
        p,
      )!,
      transform: transform,
      scrimAlpha: _maxScrim * p,
      shadowAlpha: fallback ? 0 : 1 - p,
      groupAlpha: fallback ? p : 1,
      cardAlpha: fallback ? 0 : 1 - _cardFade.transform(p),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = _page;
    if (child == null) {
      return;
    }
    if (_settled) {
      _clearLayers();
      context.paintChild(child, offset);
      return;
    }
    final frame = _frame();
    if (frame.scrimAlpha > 0) {
      context.canvas.drawRect(
        offset & size,
        Paint()
          ..color = _scrimColor.withValues(
            alpha: _scrimColor.a * frame.scrimAlpha,
          ),
      );
    }
    final rrect = frame.radius.toRRect(frame.rect);
    if (frame.shadowAlpha > 0) {
      _paintShadows(context.canvas, offset, rrect, frame.shadowAlpha);
    }
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      frame.rect,
      rrect,
      (PaintingContext context, Offset offset) =>
          _paintContainer(context, offset, frame, child),
      oldLayer: _clipLayer.layer,
    );
  }

  /// 在容器圆角外侧接力绘制卡片投影：起点与终点强度为 1（与隐藏前的原卡片
  /// 逐像素一致），展开到整页途中平滑淡出至 0。容器全程不透明，一律按 normal
  /// 模糊画在容器下面，外侧像素与 `BoxDecoration` / `DiaryCardOuterShadowDecoration`
  /// / `OuterShadowPainter` 一致，同时避开 `BlurStyle.outer` 的内部填色缺陷。
  void _paintShadows(Canvas canvas, Offset offset, RRect rrect, double alpha) {
    final shadows = _geometry.closed?.shadows;
    if (shadows == null || shadows.isEmpty) {
      return;
    }
    final shifted = rrect.shift(offset);
    for (final shadow in shadows) {
      final scaledAlpha = shadow.color.a * alpha;
      if (scaledAlpha <= 0) {
        continue;
      }
      final paint = BoxShadow(
        color: shadow.color.withValues(alpha: scaledAlpha),
        offset: shadow.offset,
        blurRadius: shadow.blurRadius,
        spreadRadius: shadow.spreadRadius,
      ).toPaint();
      canvas.drawRRect(
        shifted.shift(shadow.offset).inflate(shadow.spreadRadius),
        paint,
      );
    }
  }

  void _paintContainer(
    PaintingContext context,
    Offset offset,
    _Frame frame,
    RenderBox child,
  ) {
    final backdrop = _backdrop;
    void paintPage(PaintingContext context, Offset offset) {
      // 缩放以位图方式施加（与 `Transform.filterQuality` 同一路径）：底与
      // 页面先按原尺寸画进一张离屏纹理，再整张缩放贴进容器。直接变换画布
      // 时文字每帧换一个字号，Impeller 要逐帧重建字形图集（真机上每帧
      // 6ms 上下，转场一路掉帧）；按原尺寸画则每帧都命中缓存。底与页面
      // 同在这一层里，页内玻璃仍能采到先画好的页面背景；原地退场时外侧
      // 的透明度直接施加在这张纹理上。
      final matrix = Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..multiply(frame.transform)
        ..translateByDouble(-offset.dx, -offset.dy, 0, 1);
      final layer = _scaleLayer.layer ??= ImageFilterLayer();
      layer.imageFilter = ImageFilter.matrix(
        matrix.storage,
        // 双线性即可：缩放比例在 0.9 上下（卡片宽到整屏宽），末段接近原
        // 尺寸。
        filterQuality: FilterQuality.low,
      );
      context.pushLayer(layer, (PaintingContext context, Offset offset) {
        if (backdrop != null) {
          context.paintChild(backdrop, offset);
        }
        context.paintChild(child, offset);
      }, offset);
    }

    final groupAlpha = (frame.groupAlpha * 255).round();
    if (groupAlpha >= 255) {
      _groupLayer.layer = null;
      paintPage(context, offset);
    } else if (groupAlpha > 0) {
      _groupLayer.layer = context.pushOpacity(
        offset,
        groupAlpha,
        paintPage,
        oldLayer: _groupLayer.layer,
      );
    } else {
      _groupLayer.layer = null;
      _scaleLayer.layer = null;
    }
    if (frame.cardAlpha > 0) {
      // 推过图层之后要重新取画布：PaintingContext 已经换了一段新的录制。
      _paintCard(context.canvas, offset, frame);
    }
  }

  /// 把截下的卡片画面按容器宽度缩放、贴顶画在页面上面。卡片一部分在屏幕
  /// 之外时只画露出的那块（[ContainerTransformShot.imageRect]），位置照常
  /// 对齐。
  void _paintCard(Canvas canvas, Offset offset, _Frame frame) {
    final shot = _geometry.closed;
    final image = shot?.image;
    final imageRect = shot?.imageRect;
    if (shot == null ||
        shot.rect.isEmpty ||
        image == null ||
        imageRect == null ||
        imageRect.isEmpty) {
      return;
    }
    final card = shot.rect;
    final s = frame.rect.width / card.width;
    final target = Rect.fromLTWH(
      frame.rect.left + (imageRect.left - card.left) * s,
      frame.rect.top + (imageRect.top - card.top) * s,
      imageRect.width * s,
      imageRect.height * s,
    );
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      target.shift(offset),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, frame.cardAlpha)
        ..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // 只在停稳后经 [hitTest] 走到这里：底不接点按。
    return _page?.hitTest(result, position: position) ?? false;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_settled) {
      return super.hitTest(result, position: position);
    }
    final child = _page;
    if (!size.contains(position)) {
      return false;
    }
    // 转场途中整屏都由这里接住：展开、收回的途中不会又点开下层列表的另一
    // 篇。容器长到 [_interactiveFrom] 之后，容器内的点按照常交给页面（展开
    // 末段长长的减速里就能开始滑动）；原地退场时页面不再接点按。
    final frame = _frame();
    final interactive =
        !_geometry.fallback && _animation.value >= _interactiveFrom;
    if (interactive && frame.rect.contains(position)) {
      result.addWithPaintTransform(
        transform: frame.transform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) =>
            child?.hitTest(result, position: position) ?? false,
      );
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    // 两个子节点都画在原点；转场途中同样套着容器的变换。
    if (!_settled) {
      transform.multiply(_frame().transform);
    }
  }
}
