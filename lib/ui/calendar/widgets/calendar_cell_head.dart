import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 日期格的可见形状（填色底块、热力格、照片或心情底色）相对
/// [CalendarCellHead] 的位置：四边各向外超出多少（[outset]），以及四角的
/// 圆角半径（[radius]）。角标只会靠近上边与左右两边，下边只用来确定形状。
@immutable
class CalendarCellBounds {
  const CalendarCellBounds({
    this.outset = EdgeInsets.zero,
    required this.radius,
  });

  final EdgeInsets outset;
  final double radius;

  /// 下边再往外延 [extra]：数字组之下另有区域（如底部指示物带）时用。
  CalendarCellBounds extendBottom(double extra) => CalendarCellBounds(
    outset: outset.copyWith(bottom: outset.bottom + extra),
    radius: radius,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarCellBounds &&
      other.outset == outset &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(outset, radius);
}

/// 角标排版的结果：左上角位置与在数字组缩放之外再乘的缩放。
typedef CalendarCellBadgePlacement = ({Offset topLeft, double scale});

enum CalendarCellHeadSlot { number, subtitle, leadingBadge, trailingBadge }

/// 日期格里“数字 + 小字 + 两侧角标”这一组的排版，保证角标落在格子的可见
/// 形状之内（#312）。
///
/// 输入：日期数字、可选的小字（农历 / 纪念日）、数字左上与右上的角标，以及
/// 格子可见形状相对本组件的位置 [bounds]；输出这一组的布局与绘制，无副作用。
///
/// 数字与小字的排版等同于 `FittedBox(fit: BoxFit.scaleDown)` 包着与本组件
/// 同宽的 `Column`：两者在本组件宽度内水平居中、上下相距 1dp，整组在本组件
/// 高度内垂直居中；整组高过可用高度（系统大字号）时以本组件水平中线为轴
/// 等比缩小，角标随之缩小。高度不是定值时（心情格只给上限）本组件与缩放后
/// 的整组同高。
///
/// 角标挂在数字外侧、不参与居中：左上角标右缘距数字 1.5dp、顶边高出数字
/// 5dp，右上角标左缘距数字 1.5dp、顶边高出 2dp，槽宽 13dp。手机上的日期格
/// 只有约 37–42dp 宽、四角是 14dp 圆角，数字一宽（两位数、系统字号放大）、
/// 整组一高（显示农历时的三层排版），挂在外侧的角标就落到圆角外甚至格子外，
/// 选中、今天、周末着色这些有底色的格子上图标露出半截。所以把可见形状略微
/// 内缩作为安全区（见 [leadingSafeMargin]），按 [placeBadge] 的顺序处理：
/// 默认位置在安全区内就不动（宽窗口与较宽的手机格子）；否则先保持大小往下
/// 挪，再不够才等比缩小。
/// 角标始终与数字留 1.5dp，不压住数字（DESIGN.md §5.7）；位置只取决于几何，
/// 选中、今天等状态切换不会让角标跳动。
class CalendarCellHead
    extends
        SlottedMultiChildRenderObjectWidget<CalendarCellHeadSlot, RenderBox> {
  const CalendarCellHead({
    super.key,
    required this.number,
    required this.bounds,
    this.subtitle,
    this.leadingBadge,
    this.trailingBadge,
  });

  final Widget number;

  /// 格子可见形状相对本组件的位置。
  final CalendarCellBounds bounds;

  /// 数字下方的小字。
  final Widget? subtitle;

  /// 数字左上方：锁、休/班、纪念日心形、待办或天气（见
  /// `CalendarCellLeadingBadge`）。
  final Widget? leadingBadge;

  /// 数字右上方：篇数上标或心情格的小圆点。
  final Widget? trailingBadge;

  /// 角标槽位宽度：放得下“9+”上标与带底的照片角标（13dp）。
  static const double badgeSlot = 13;

  /// 角标与数字的水平间隙。
  static const double badgeGap = 1.5;

  /// 左上、右上角标的顶边高出数字顶边多少。
  static const double leadingRise = 5;
  static const double trailingRise = 2;

  /// 安全区相对可见形状的内缩。左上是图标（天气、锁、心形等），图形几乎
  /// 铺满外接框，内缩 1dp 才看得出“在色块里”；右上是篇数数字（或小圆点），
  /// 字形本有留白（见 [trailingInkTop]），不再内缩。
  static const double leadingSafeMargin = 1;
  static const double trailingSafeMargin = 0;

  /// 右上角标外接框顶部空着的比例：篇数是行高为 1 的数字，字框顶部约两成
  /// 没有墨迹；心情格的小圆点上方垫了 1dp（5dp 高的两成）。判断是否碰到
  /// 圆角时按墨迹算，否则窄格里的上标会被无谓缩小。
  static const double trailingInkTop = 0.2;

  /// 右上篇数最多往下挪到顶边低于数字框顶边“数字框高度 × 本值”处，约是
  /// 数字字形的顶部：上标再往下就和日期连成“142”了。
  static const double trailingMaxDrop = 0.1;

  /// 放不下时角标最多缩到原大的几倍：再小天气图标就认不出了。到这一档仍
  /// 放不下时不再缩小，尽量往下放（可能略出界），见 [placeBadge]。
  static const double minBadgeScale = 0.6;

  static const double _subtitleGap = 1;

  @override
  Iterable<CalendarCellHeadSlot> get slots => CalendarCellHeadSlot.values;

  @override
  Widget? childForSlot(CalendarCellHeadSlot slot) => switch (slot) {
    CalendarCellHeadSlot.number => number,
    CalendarCellHeadSlot.subtitle => subtitle,
    CalendarCellHeadSlot.leadingBadge => leadingBadge,
    CalendarCellHeadSlot.trailingBadge => trailingBadge,
  };

  @override
  RenderCalendarCellHead createRenderObject(BuildContext context) =>
      RenderCalendarCellHead(bounds: bounds);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarCellHead renderObject,
  ) {
    renderObject.bounds = bounds;
  }

  /// 在安全区（[safe] 矩形、上方两角半径 [radius]）里为一个角标找位置。
  ///
  /// [number] 为数字框，[badge] 为角标原大，[gap]、[rise] 为与数字的水平
  /// 间隙和顶边高出量（都已乘上数字组的缩放）；[leading] 为左上角标，否则
  /// 为右上角标（左右镜像）。返回角标左上角与额外缩放。
  ///
  /// 角标贴着数字的那条边固定在“数字边缘 ± 间隙”，只改变上下位置与大小：
  /// 1. 默认位置（顶边高出数字 [rise]）在安全区内：原样；
  /// 2. 往下挪：角标在数字外侧，往下不会压住数字；越往下圆角让出的宽度
  ///    越多。左上的图标最多挪到与数字框垂直居中；右上的篇数是数字上标，
  ///    最多挪到数字字形顶部（[trailingMaxDrop]），且按墨迹判断（
  ///    [trailingInkTop]）；
  /// 3. 挪到底仍放不下（直边都越过了，或圆角仍挡着）：以贴着数字的一边为
  ///    锚点等比缩小，取放得下的最大倍数（二分查找，最小 [minBadgeScale]）；
  /// 4. 最小倍数仍放不下：按最小倍数、能多往下就多往下，接受略微出界。
  @visibleForTesting
  static CalendarCellBadgePlacement placeBadge({
    required Rect number,
    required Size badge,
    required double gap,
    required double rise,
    required Rect safe,
    required double radius,
    required bool leading,
  }) {
    const epsilon = 0.01;
    final anchor = leading ? number.left - gap : number.right + gap;
    final preferredTop = number.top - rise;
    final cornerX = leading ? safe.left + radius : safe.right - radius;
    final cornerY = safe.top + radius;

    // 远离数字的那条竖边。
    double outerEdge(double scale) =>
        leading ? anchor - badge.width * scale : anchor + badge.width * scale;

    // 最低（不高于默认位置）：左上与数字框垂直居中，右上到数字字形顶部。
    double lowestTop(double scale) => math.max(
      preferredTop,
      leading
          ? number.top + (number.height - badge.height * scale) / 2
          : number.top + number.height * trailingMaxDrop,
    );

    // 最高：墨迹不越过安全区上边，外侧顶角落在圆角范围内时还要在圆弧之下。
    double highestTop(double scale) {
      final inkInset = leading ? 0 : badge.height * scale * trailingInkTop;
      var top = math.max(preferredTop, safe.top - inkInset);
      final intoCorner = leading
          ? cornerX - outerEdge(scale)
          : outerEdge(scale) - cornerX;
      if (intoCorner > 0) {
        final clearance = math.sqrt(
          math.max(0, radius * radius - intoCorner * intoCorner),
        );
        top = math.max(top, cornerY - clearance - inkInset);
      }
      return top;
    }

    bool fits(double scale) {
      final edge = outerEdge(scale);
      final withinSides = leading
          ? edge >= safe.left - epsilon
          : edge <= safe.right + epsilon;
      return withinSides && highestTop(scale) <= lowestTop(scale) + epsilon;
    }

    var scale = 1.0;
    if (!fits(scale)) {
      if (!fits(minBadgeScale)) {
        scale = minBadgeScale;
      } else {
        var low = minBadgeScale;
        var high = 1.0;
        for (var i = 0; i < 12; i++) {
          final middle = (low + high) / 2;
          if (fits(middle)) {
            low = middle;
          } else {
            high = middle;
          }
        }
        scale = low;
      }
    }
    final top = math.min(highestTop(scale), lowestTop(scale));
    final left = leading ? anchor - badge.width * scale : anchor;
    return (topLeft: Offset(left, top), scale: scale);
  }
}

class _CellHeadParentData extends BoxParentData {
  /// 子项绘制时的缩放（以其左上角为原点）。
  double scale = 1;

  /// 需要合成时的变换层；不合成时为 null（直接在画布上变换）。
  final LayerHandle<TransformLayer> transformLayer =
      LayerHandle<TransformLayer>();

  Matrix4 get paintTransform =>
      Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..scaleByDouble(scale, scale, 1, 1);

  @override
  void detach() {
    transformLayer.layer = null;
    super.detach();
  }
}

/// [CalendarCellHead] 的渲染对象：每个子项记一个偏移与缩放。
class RenderCalendarCellHead extends RenderBox
    with SlottedContainerRenderObjectMixin<CalendarCellHeadSlot, RenderBox> {
  RenderCalendarCellHead({required this._bounds});

  CalendarCellBounds get bounds => _bounds;
  CalendarCellBounds _bounds;
  set bounds(CalendarCellBounds value) {
    if (value == _bounds) {
      return;
    }
    _bounds = value;
    markNeedsLayout();
  }

  RenderBox? get _number => childForSlot(CalendarCellHeadSlot.number);
  RenderBox? get _subtitle => childForSlot(CalendarCellHeadSlot.subtitle);
  RenderBox? get _leading => childForSlot(CalendarCellHeadSlot.leadingBadge);
  RenderBox? get _trailing => childForSlot(CalendarCellHeadSlot.trailingBadge);

  /// 绘制与命中测试的顺序：数字、小字、左上、右上（与原先的 Column / Stack
  /// 一致，彼此不重叠，顺序只影响调试输出）。
  Iterable<RenderBox> get _orderedChildren => <RenderBox?>[
    _number,
    _subtitle,
    _leading,
    _trailing,
  ].whereType<RenderBox>();

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _CellHeadParentData) {
      child.parentData = _CellHeadParentData();
    }
  }

  @override
  void dispose() {
    for (final child in _orderedChildren) {
      (child.parentData! as _CellHeadParentData).transformLayer.layer = null;
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 尺寸
  // ---------------------------------------------------------------------------

  /// 数字组未缩放的高度：数字 + 间隙 + 小字。
  static double _groupHeight(Size number, Size? subtitle) =>
      number.height +
      (subtitle == null ? 0 : CalendarCellHead._subtitleGap + subtitle.height);

  /// 整组超高时的缩放（与 `FittedBox(fit: BoxFit.scaleDown)` 相同）。
  static double _groupScale(double groupHeight, BoxConstraints constraints) {
    if (!constraints.hasBoundedHeight ||
        groupHeight <= constraints.maxHeight ||
        groupHeight <= 0) {
      return 1;
    }
    return constraints.maxHeight / groupHeight;
  }

  double _widthFor(BoxConstraints constraints, Size number, Size? subtitle) =>
      constraints.hasBoundedWidth
      ? constraints.maxWidth
      : math.max(number.width, subtitle?.width ?? 0);

  Size _sizeFor(BoxConstraints constraints, Size number, Size? subtitle) {
    final groupHeight = _groupHeight(number, subtitle);
    final scale = _groupScale(groupHeight, constraints);
    return constraints.constrain(
      Size(_widthFor(constraints, number, subtitle), groupHeight * scale),
    );
  }

  /// 数字与小字的约束：宽度上限为本组件宽度（小字的 FittedBox 拿得到上限，
  /// 过长只缩小自己），高度不限。
  static BoxConstraints _contentConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final number = _number;
    if (number == null) {
      return constraints.smallest;
    }
    final inner = _contentConstraints(constraints);
    return _sizeFor(
      constraints,
      number.getDryLayout(inner),
      _subtitle?.getDryLayout(inner),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _number?.getMinIntrinsicWidth(double.infinity) ?? 0,
    _subtitle?.getMinIntrinsicWidth(double.infinity) ?? 0,
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _number?.getMaxIntrinsicWidth(double.infinity) ?? 0,
    _subtitle?.getMaxIntrinsicWidth(double.infinity) ?? 0,
  );

  @override
  double computeMinIntrinsicHeight(double width) {
    final subtitle = _subtitle;
    return (_number?.getMinIntrinsicHeight(width) ?? 0) +
        (subtitle == null
            ? 0
            : CalendarCellHead._subtitleGap +
                  subtitle.getMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final subtitle = _subtitle;
    return (_number?.getMaxIntrinsicHeight(width) ?? 0) +
        (subtitle == null
            ? 0
            : CalendarCellHead._subtitleGap +
                  subtitle.getMaxIntrinsicHeight(width));
  }

  // ---------------------------------------------------------------------------
  // 布局
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final number = _number;
    if (number == null) {
      size = constraints.smallest;
      return;
    }
    final subtitle = _subtitle;
    final inner = _contentConstraints(constraints);
    number.layout(inner, parentUsesSize: true);
    subtitle?.layout(inner, parentUsesSize: true);

    final groupHeight = _groupHeight(number.size, subtitle?.size);
    final scale = _groupScale(groupHeight, constraints);
    size = _sizeFor(constraints, number.size, subtitle?.size);

    // 整组以水平中线为轴缩放，在本组件高度内垂直居中。
    final centerX = size.width / 2;
    final top = (size.height - groupHeight * scale) / 2;
    final numberRect = Rect.fromLTWH(
      centerX - number.size.width * scale / 2,
      top,
      number.size.width * scale,
      number.size.height * scale,
    );
    _position(number, numberRect.topLeft, scale);
    if (subtitle != null) {
      _position(
        subtitle,
        Offset(
          centerX - subtitle.size.width * scale / 2,
          top + (number.size.height + CalendarCellHead._subtitleGap) * scale,
        ),
        scale,
      );
    }

    final shape = Rect.fromLTRB(
      -bounds.outset.left,
      -bounds.outset.top,
      size.width + bounds.outset.right,
      size.height + bounds.outset.bottom,
    );
    for (final (badge, leading) in <(RenderBox?, bool)>[
      (_leading, true),
      (_trailing, false),
    ]) {
      if (badge == null) {
        continue;
      }
      final margin = leading
          ? CalendarCellHead.leadingSafeMargin
          : CalendarCellHead.trailingSafeMargin;
      badge.layout(
        const BoxConstraints(maxWidth: CalendarCellHead.badgeSlot),
        parentUsesSize: true,
      );
      final placement = CalendarCellHead.placeBadge(
        number: numberRect,
        badge: badge.size * scale,
        gap: CalendarCellHead.badgeGap * scale,
        rise:
            (leading
                ? CalendarCellHead.leadingRise
                : CalendarCellHead.trailingRise) *
            scale,
        safe: shape.deflate(margin),
        radius: math.max(0, bounds.radius - margin),
        leading: leading,
      );
      _position(badge, placement.topLeft, scale * placement.scale);
    }
  }

  static void _position(RenderBox child, Offset offset, double scale) {
    final data = child.parentData! as _CellHeadParentData;
    data
      ..offset = offset
      ..scale = scale;
  }

  // ---------------------------------------------------------------------------
  // 绘制与命中
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _orderedChildren) {
      final data = child.parentData! as _CellHeadParentData;
      final origin = offset + data.offset;
      if (data.scale == 1) {
        data.transformLayer.layer = null;
        context.paintChild(child, origin);
        continue;
      }
      // pushTransform 以 origin 为原点变换，子项也画在 origin：即以子项
      // 左上角为原点缩放。
      data.transformLayer.layer = context.pushTransform(
        needsCompositing,
        origin,
        Matrix4.diagonal3Values(data.scale, data.scale, 1),
        (PaintingContext context, Offset offset) =>
            context.paintChild(child, offset),
        oldLayer: data.transformLayer.layer,
      );
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(
      (child.parentData! as _CellHeadParentData).paintTransform,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _orderedChildren.toList().reversed) {
      final data = child.parentData! as _CellHeadParentData;
      final hit = result.addWithPaintTransform(
        transform: data.paintTransform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) {
        return true;
      }
    }
    return false;
  }
}
