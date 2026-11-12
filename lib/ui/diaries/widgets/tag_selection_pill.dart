import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';

/// 首页标签栏的滑动选中色块。
///
/// 只选中一个标签时，选中底色与标签色描边不由胶囊自己画，而是一块画在所有
/// 胶囊下方的色块：换选另一个标签时它从旧胶囊滑到新胶囊（与底栏指示器同一
/// 种 `springIndicator` 弹簧，途中按速度沿运动方向拉长、略微变扁），颜色从
/// 旧标签的选中色渐变到新标签的；胶囊的未选中底色淡成透明让出它，文字照常
/// 按选中补间。
///
/// 组成：
/// - [TagSelectionPillController]：动画状态（位移弹簧、显隐）与“标签 id →
///   胶囊渲染对象”的登记表，标签栏持有；
/// - [TagPillAnchor]：包在每个标签胶囊外面，挂载时把自己登记进去；
/// - [TagSelectionPillLayer]：叠在横向（收起）或纵向（展开）标签列表下面的
///   绘制层，每次绘制时现量胶囊此刻的位置，随列表滚动重绘、裁切到列表视口。
///
/// 状态：
/// - 未选 → 选一个：在目标胶囊处从 [appearScale] 放大并淡入；
/// - 选一个 → 换另一个：滑过去；起点是此刻画面上的色块（快照，记在内容
///   坐标里，滑动途中列表滚动也跟得上），连点时带着当前速度改道；
/// - 选一个 → 未选或多选：原地缩小淡出（多选时各胶囊自己画选中态）；
/// - 旧胶囊不在视口里（没有画面）或减少动画：不滑动，直接在目标处出现；
/// - 收起 / 展开两种排列切换（换了一个绘制层）：直接落到新排列里的目标，
///   不跨两种坐标系滑动。
///
/// 色块不是玻璃（不加 BackdropFilter）：整条顶栏只有一块启用的模糊。
class TagSelectionPillController extends ChangeNotifier {
  TagSelectionPillController({required TickerProvider vsync})
    : _travel = AnimationController.unbounded(vsync: vsync, value: 1),
      _presence = AnimationController(vsync: vsync) {
    _travel.addListener(notifyListeners);
    _presence.addListener(notifyListeners);
  }

  /// 每 1 像素 / 秒的速度把色块拉长的比例与上限：相邻胶囊之间滑动的峰值
  /// 速度约 1500 像素 / 秒（拉长约 19%），跨得更远时触到上限。
  static const double stretchPerVelocity = 1 / 8000;
  static const double maxStretch = 0.28;

  /// 拉长时高度按拉长比例的这个倍数收窄，与底栏指示器一致。
  static const double squashRatio = 0.3;

  /// 出现 / 消失时的缩放起点。
  static const double appearScale = 0.85;

  /// 描边粗细，与选中胶囊自己画的描边一致。
  static const double borderWidth = 2;

  /// 位移弹簧停稳的阈值：进度以“整段行程”为单位，千分之一不到 0.5 像素。
  static const Tolerance _settleTolerance = Tolerance(
    distance: 0.001,
    velocity: 0.01,
  );

  /// 位移进度：0 在起点快照，1 在目标胶囊；无界（弹簧会越过终点再回落）。
  final AnimationController _travel;

  /// 显隐（已过曲线的值）：0 不画，1 完整显示。
  final AnimationController _presence;

  final Map<int, RenderBox> _anchors = <int, RenderBox>{};
  RenderTagSelectionPill? _layer;

  /// 色块停留 / 滑向的标签；淡出途中仍保留，用来定位。
  int? _targetId;

  /// 目标状态是否为“显示”（与 [_presence] 正在去的方向一致）。
  bool _shown = false;

  /// 起点快照（绘制层坐标）与拍快照时的滚动偏移、颜色；null 表示没有起点
  /// （原地出现或已落定）。
  Rect? _fromRect;
  double _fromScroll = 0;
  TagPillColors? _fromColors;

  /// 色块此刻停留 / 滑向的标签（测试与绘制层读取）。
  int? get targetId => _targetId;

  /// 此刻是否画得出来（显隐大于 0 且有目标）。
  bool get isVisible => _targetId != null && _presence.value > 0;

  /// 标签 [tagId] 的胶囊此刻挂载的渲染对象；没有挂载（横向列表里滚出视口
  /// 未构建）时为 null。
  RenderBox? anchorOf(int tagId) => _anchors[tagId];

  /// 无动画地对齐到 [tagId]（null 为不显示）：首帧与收起 / 展开切换时用。
  void jumpTo(int? tagId) {
    if (tagId != null) {
      _targetId = tagId;
    }
    _shown = tagId != null;
    _fromRect = null;
    _fromColors = null;
    _travel.value = 1;
    _presence.value = _shown ? 1 : 0;
  }

  /// 选中项变为 [tagId]（只选一个时为它，未选或多选时为 null），按上面的
  /// 状态规则开始过渡。
  void select(BuildContext context, int? tagId) {
    final reduceMotion = ExpressiveMotion.reduceMotion(context);
    if (tagId == null) {
      if (!_shown) {
        return;
      }
      _shown = false;
      _setPresence(0, reduceMotion);
      return;
    }
    if (tagId == _targetId && _shown) {
      return;
    }
    final layer = _layer;
    // 只有此刻画面上确实有色块时才从它滑出；淡出途中再选别的、旧胶囊不在
    // 视口里，都直接在目标处出现。
    final visual = _shown && _presence.value > 0.01 ? layer?._visual() : null;
    final targetRect = layer?._rectOf(tagId);
    _targetId = tagId;
    _shown = true;
    if (reduceMotion || layer == null || visual == null || targetRect == null) {
      _fromRect = null;
      _fromColors = null;
      _travel.value = 1;
      if (reduceMotion) {
        _presence.value = 1;
      } else {
        _presence.value = 0;
        _setPresence(1, reduceMotion, appearing: true);
      }
      return;
    }
    _fromRect = visual.rect;
    _fromScroll = layer._scrollOffset;
    _fromColors = visual.colors;
    // 连点时带着色块此刻的速度改道：把像素速度投影到新的行程上，换算成
    // 进度速度，不从零速重新起步。
    final travel = targetRect.center - visual.rect.center;
    final distance2 = travel.distanceSquared;
    final kick = distance2 < 1
        ? 0.0
        : (visual.velocity.dx * travel.dx + visual.velocity.dy * travel.dy) /
              distance2;
    _travel.value = 0;
    ExpressiveMotion.springTo(
      context,
      _travel,
      1,
      spring: ExpressiveMotion.springIndicator,
      tolerance: _settleTolerance,
      kick: kick,
    );
    if (_presence.value < 1) {
      _setPresence(1, reduceMotion, appearing: true);
    }
  }

  void _setPresence(
    double target,
    bool reduceMotion, {
    bool appearing = false,
  }) {
    if (reduceMotion) {
      _presence.value = target;
      return;
    }
    _presence.animateTo(
      target,
      duration: appearing ? ExpressiveMotion.medium : ExpressiveMotion.fast,
      curve: appearing ? ExpressiveMotion.effects : ExpressiveMotion.exit,
    );
  }

  void _attachLayer(RenderTagSelectionPill layer) {
    _layer = layer;
    // 换了一个绘制层（收起 ↔ 展开）：旧的起点快照属于另一种坐标，直接落定。
    _fromRect = null;
    _fromColors = null;
    if (_travel.isAnimating || _travel.value != 1) {
      _travel.stop();
      _travel.value = 1;
    }
  }

  void _detachLayer(RenderTagSelectionPill layer) {
    if (identical(_layer, layer)) {
      _layer = null;
    }
  }

  void _registerAnchor(int tagId, RenderBox box) => _anchors[tagId] = box;

  void _unregisterAnchor(int tagId, RenderBox box) {
    if (identical(_anchors[tagId], box)) {
      _anchors.remove(tagId);
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    _presence.dispose();
    super.dispose();
  }
}

/// 色块的底色与描边色。
@immutable
class TagPillColors {
  const TagPillColors({required this.fill, required this.border});

  final Color fill;
  final Color border;

  static TagPillColors lerp(TagPillColors a, TagPillColors b, double t) =>
      TagPillColors(
        fill: Color.lerp(a.fill, b.fill, t)!,
        border: Color.lerp(a.border, b.border, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is TagPillColors && other.fill == fill && other.border == border;

  @override
  int get hashCode => Object.hash(fill, border);
}

/// 按标签 id 取色块颜色（与该标签选中时胶囊自己画的颜色相同）；标签已不在
/// 列表里时返回 null。
typedef TagPillColorResolver = TagPillColors? Function(int tagId);

/// 包在标签胶囊外面：挂载时把自己（胶囊的外框）登记到 [controller]，色块
/// 据此量胶囊的位置。不影响布局与绘制。
class TagPillAnchor extends SingleChildRenderObjectWidget {
  const TagPillAnchor({
    super.key,
    required this.controller,
    required this.tagId,
    required super.child,
  });

  final TagSelectionPillController controller;
  final int tagId;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTagPillAnchor(controller, tagId);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTagPillAnchor renderObject,
  ) {
    renderObject.update(controller, tagId);
  }
}

class RenderTagPillAnchor extends RenderProxyBox {
  RenderTagPillAnchor(this._controller, this._tagId);

  TagSelectionPillController _controller;
  int _tagId;

  void update(TagSelectionPillController controller, int tagId) {
    if (identical(controller, _controller) && tagId == _tagId) {
      return;
    }
    if (attached) {
      _controller._unregisterAnchor(_tagId, this);
      controller._registerAnchor(tagId, this);
    }
    _controller = controller;
    _tagId = tagId;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller._registerAnchor(_tagId, this);
  }

  @override
  void detach() {
    _controller._unregisterAnchor(_tagId, this);
    super.detach();
  }
}

/// 色块的绘制层：铺满标签列表的视口、叠在列表下面（放进 Stack 的第一项）。
///
/// [scrollController] 是这层下面那个列表的滚动控制器（收起时横向、展开时
/// 纵向，方向为 [axis]）：滚动时重绘，起点快照按滚动距离平移。绘制裁切到
/// 本层范围，与列表视口一致。不参与命中测试。
class TagSelectionPillLayer extends LeafRenderObjectWidget {
  const TagSelectionPillLayer({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.axis,
    required this.colors,
  });

  final TagSelectionPillController controller;
  final ScrollController scrollController;
  final Axis axis;
  final TagPillColorResolver colors;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTagSelectionPill(controller, scrollController, axis, colors);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTagSelectionPill renderObject,
  ) {
    renderObject
      ..controller = controller
      ..scrollController = scrollController
      ..axis = axis
      ..colors = colors
      // 标签栏每次重建（标签增删、主题、字号、选中变化）都可能让胶囊挪了
      // 位置，而胶囊的布局不会通知这一层：重建时一律重画一次，代价只是
      // 一块色块。
      ..markNeedsPaint();
  }
}

/// 色块此刻在画面上的样子（绘制层坐标）。
class _PillVisual {
  const _PillVisual(this.rect, this.colors, this.velocity);

  final Rect rect;
  final TagPillColors colors;

  /// 色块中心此刻的速度（像素 / 秒）。
  final Offset velocity;
}

class RenderTagSelectionPill extends RenderBox {
  RenderTagSelectionPill(
    this._controller,
    this._scrollController,
    this._axis,
    this._colors,
  );

  TagSelectionPillController _controller;
  set controller(TagSelectionPillController value) {
    if (identical(value, _controller)) {
      return;
    }
    if (attached) {
      _controller.removeListener(markNeedsPaint);
      _controller._detachLayer(this);
      value.addListener(markNeedsPaint);
      value._attachLayer(this);
    }
    _controller = value;
  }

  ScrollController _scrollController;
  set scrollController(ScrollController value) {
    if (identical(value, _scrollController)) {
      return;
    }
    if (attached) {
      _scrollController.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _scrollController = value;
  }

  Axis _axis;
  set axis(Axis value) => _axis = value;

  TagPillColorResolver _colors;
  set colors(TagPillColorResolver value) => _colors = value;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsPaint);
    _controller._attachLayer(this);
    _scrollController.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    _controller._detachLayer(this);
    _scrollController.removeListener(markNeedsPaint);
    super.detach();
  }

  /// 列表此刻的滚动偏移（沿 [_axis]）；还没挂上列表时为 0。
  double get _scrollOffset {
    final controller = _scrollController;
    return controller.hasClients && controller.positions.length == 1
        ? controller.offset
        : 0;
  }

  /// 标签 [tagId] 的胶囊此刻在本层坐标里的外框；没有挂载或量不出来时为 null。
  Rect? _rectOf(int tagId) {
    final anchor = _controller._anchors[tagId];
    if (anchor == null || !anchor.attached || !anchor.hasSize || !attached) {
      return null;
    }
    final transform = anchor.getTransformTo(this);
    if (transform.determinant() == 0) {
      return null;
    }
    return MatrixUtils.transformRect(transform, Offset.zero & anchor.size);
  }

  /// 起点快照换算到此刻：列表滚了多少，快照就反向平移多少。
  Rect? _fromRect() {
    final from = _controller._fromRect;
    if (from == null) {
      return null;
    }
    final scrolled = _scrollOffset - _controller._fromScroll;
    return from.shift(
      _axis == Axis.horizontal ? Offset(-scrolled, 0) : Offset(0, -scrolled),
    );
  }

  /// 色块此刻（未按显隐缩放）的外框、颜色与速度；画不出来时为 null。
  _PillVisual? _visual() {
    final targetId = _controller._targetId;
    if (targetId == null) {
      return null;
    }
    final to = _rectOf(targetId);
    final toColors = _colors(targetId);
    if (to == null || toColors == null) {
      return null;
    }
    final from = _fromRect();
    final fromColors = _controller._fromColors;
    final travel = _controller._travel;
    final t = travel.value;
    if (from == null || fromColors == null || (t == 1 && !travel.isAnimating)) {
      return _PillVisual(to, toColors, Offset.zero);
    }
    final velocity = travel.isAnimating ? travel.velocity : 0.0;
    final path = to.center - from.center;
    final centerVelocity = path * velocity;
    // 中心与尺寸按进度插值（弹簧越过终点时同样外推，落点轻轻越过再收回），
    // 再按速度沿运动方向拉长、垂直方向略微收窄。
    final center = Offset.lerp(from.center, to.center, t)!;
    final base = Size.lerp(from.size, to.size, t.clamp(0.0, 1.0))!;
    final stretch = math.min(
      centerVelocity.distance * TagSelectionPillController.stretchPerVelocity,
      TagSelectionPillController.maxStretch,
    );
    final horizontal = path.dx.abs() >= path.dy.abs();
    final size = horizontal
        ? Size(
            base.width * (1 + stretch),
            base.height *
                (1 - stretch * TagSelectionPillController.squashRatio),
          )
        : Size(
            base.width * (1 - stretch * TagSelectionPillController.squashRatio),
            base.height * (1 + stretch),
          );
    return _PillVisual(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      TagPillColors.lerp(fromColors, toColors, t.clamp(0.0, 1.0)),
      centerVelocity,
    );
  }

  /// 色块此刻画出来的外框（本层坐标，已按显隐缩放）；不画时为 null。
  @visibleForTesting
  Rect? get debugPaintedRect => _painted()?.$1;

  /// 色块此刻画出来的外框与样子；不画时为 null。
  (Rect, _PillVisual, double)? _painted() {
    final presence = _controller._presence.value;
    if (presence <= 0) {
      return null;
    }
    final visual = _visual();
    if (visual == null) {
      return null;
    }
    final scale =
        TagSelectionPillController.appearScale +
        (1 - TagSelectionPillController.appearScale) * presence;
    final rect = Rect.fromCenter(
      center: visual.rect.center,
      width: visual.rect.width * scale,
      height: visual.rect.height * scale,
    );
    return (rect, visual, presence.clamp(0.0, 1.0));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final painted = _painted();
    if (painted == null) {
      return;
    }
    final (local, visual, opacity) = painted;
    final rect = local.shift(offset);
    final radius = Radius.circular(rect.shortestSide / 2);
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = visual.colors.fill.withValues(
          alpha: visual.colors.fill.a * opacity,
        ),
    );
    const inset = TagSelectionPillController.borderWidth / 2;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(math.max(0, radius.x - inset)),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = TagSelectionPillController.borderWidth
          ..color = visual.colors.border.withValues(
            alpha: visual.colors.border.a * opacity,
          ),
      )
      ..restore();
  }
}
