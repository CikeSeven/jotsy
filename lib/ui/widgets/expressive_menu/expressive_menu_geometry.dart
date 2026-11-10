import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 弹出菜单的几何计算（纯函数，移植自 miuix 的 dropdownPositionProvider、
/// rememberListPopupLayoutInfo、popupClipReveal 与 computeSecondaryRect）。

/// 菜单相对锚点的水平对齐方式，按阅读方向解析（RTL 下左右互换）。
enum ExpressiveMenuPlacement {
  /// 菜单起始边与锚点起始边对齐，向结束方向展开；适合行首的文本入口。
  start,

  /// 菜单结束边与锚点结束边对齐，向起始方向展开；适合顶栏与行尾的 ⋮ 按钮。
  end,
}

/// 菜单最终落在锚点的哪一侧，决定缩放原点与裁切展开的方向。
enum ExpressiveMenuSide {
  /// 落在锚点下方：从顶边向下展开。
  below,

  /// 落在锚点上方：从底边向上展开。
  above,

  /// 上下都放不下、居中盖住锚点：从中线向两边展开。
  middle,
}

/// 面板的圆角（超椭圆，与 miuix 的 squircle 同为 16）。
const double kExpressiveMenuRadius = 16;

/// 夹进安全区时左右至少留出的距离：贴着锚点对齐的菜单通常不受影响（锚点
/// 本身离屏幕边缘更远），只有放不下时才会停在离边缘 8dp 处，不贴边。
const double kExpressiveMenuScreenMargin = 8;

/// 主菜单的落点：位置、所在侧与是否贴着锚点的右缘。
@immutable
class ExpressiveMenuPlacementResult {
  const ExpressiveMenuPlacementResult({
    required this.rect,
    required this.side,
    required this.alignRight,
  });

  final Rect rect;
  final ExpressiveMenuSide side;
  final bool alignRight;

  /// 缩放原点（浮层坐标）：贴着锚点的那个角；居中时为那一侧边的中点。
  Offset get pivot =>
      Offset(alignRight ? rect.right : rect.left, switch (side) {
        ExpressiveMenuSide.below => rect.top,
        ExpressiveMenuSide.above => rect.bottom,
        ExpressiveMenuSide.middle => rect.center.dy,
      });
}

/// 按 miuix 的下拉规则放置主菜单：
/// - 水平：`end` 时右缘对齐锚点右缘（RTL 为左缘），`start` 相反，再夹进
///   [bounds] 左右各留 [kExpressiveMenuScreenMargin]；
/// - 竖直：锚点下方放得下就落在下方 [margin] 处，否则上方放得下落在上方，
///   都不行时以锚点中线居中；最后夹进 [bounds] 上下各留 [margin]。
/// - 所在侧按菜单中线与锚点中线的上下关系判断，左右按哪条边离锚点更近判断
///   （夹进安全区后可能已不贴锚点）。
ExpressiveMenuPlacementResult placeExpressiveMenu({
  required Rect anchor,
  required Size size,
  required Rect bounds,
  required ExpressiveMenuPlacement placement,
  required TextDirection textDirection,
  required double margin,
}) {
  final endAligned =
      (placement == ExpressiveMenuPlacement.end) ==
      (textDirection == TextDirection.ltr);
  var x = endAligned ? anchor.right - size.width : anchor.left;
  double y;
  if (bounds.bottom - anchor.bottom > size.height) {
    y = anchor.bottom + margin;
  } else if (anchor.top - bounds.top > size.height) {
    y = anchor.top - size.height - margin;
  } else {
    y = anchor.center.dy - size.height / 2;
  }
  const side = kExpressiveMenuScreenMargin;
  x = x.clamp(
    bounds.left + side,
    math.max(bounds.left + side, bounds.right - side - size.width),
  );
  final maxY = bounds.bottom - size.height - margin;
  y = y.clamp(math.min(bounds.top + margin, maxY), maxY);
  final rect = Rect.fromLTWH(x, y, size.width, size.height);
  final edge = rect.center.dy > anchor.center.dy
      ? ExpressiveMenuSide.below
      : rect.center.dy < anchor.center.dy
      ? ExpressiveMenuSide.above
      : ExpressiveMenuSide.middle;
  final alignRight =
      (rect.right - anchor.right).abs() < (rect.left - anchor.left).abs();
  return ExpressiveMenuPlacementResult(
    rect: rect,
    side: edge,
    alignRight: alignRight,
  );
}

/// 二级菜单的落点：起始边对齐触发行的起始边（结束方向放不下时贴到安全区的
/// 结束边，左右同样留 [kExpressiveMenuScreenMargin]），顶边对齐触发行顶边
/// （下方放不下时底边对齐触发行底边，再不行夹进安全区）。
Rect placeExpressiveSubmenu({
  required Rect anchor,
  required Size size,
  required Rect bounds,
  required TextDirection textDirection,
}) {
  final horizontal = Rect.fromLTRB(
    bounds.left + kExpressiveMenuScreenMargin,
    bounds.top,
    math.max(
      bounds.left + kExpressiveMenuScreenMargin,
      bounds.right - kExpressiveMenuScreenMargin,
    ),
    bounds.bottom,
  );
  double left;
  if (textDirection == TextDirection.ltr) {
    if (anchor.left + size.width <= horizontal.right) {
      left = anchor.left;
    } else if (anchor.right - size.width >= horizontal.left) {
      left = horizontal.right - size.width;
    } else {
      left = horizontal.left;
    }
  } else {
    final rightAligned = anchor.right - size.width;
    if (rightAligned >= horizontal.left) {
      left = rightAligned;
    } else if (anchor.left + size.width <= horizontal.right) {
      left = anchor.left;
    } else {
      left = math.max(horizontal.left, horizontal.right - size.width);
    }
  }
  double top;
  if (anchor.top + size.height <= bounds.bottom) {
    top = anchor.top;
  } else if (anchor.bottom - size.height >= bounds.top) {
    top = anchor.bottom - size.height;
  } else {
    top = math.max(bounds.top, bounds.bottom - size.height);
  }
  return Rect.fromLTWH(left, top, size.width, size.height);
}

/// 展开 / 收起时可见的那一段（面板自身坐标）：高度为 [progress] 比例，
/// 落在下方时从顶边长出，上方时从底边，居中时从中线向两边。
Rect expressiveMenuRevealBand(
  Size size,
  double progress,
  ExpressiveMenuSide side,
) {
  final p = progress.clamp(0.0, 1.0);
  final height = size.height * p;
  final top = switch (side) {
    ExpressiveMenuSide.below => 0.0,
    ExpressiveMenuSide.above => size.height - height,
    ExpressiveMenuSide.middle => (size.height - height) / 2,
  };
  return Rect.fromLTWH(0, top, size.width, height);
}

/// 面板形状：[rect] 上的超椭圆，上下两组圆角可以不同（二级菜单从触发行
/// 变形时，顶角从 0 长到 16；触发行是最后一行时底角始终是 16）。
RSuperellipse expressiveMenuShape(
  Rect rect, {
  double topRadius = kExpressiveMenuRadius,
  double bottomRadius = kExpressiveMenuRadius,
}) {
  // 圆角不能超过半高，否则超椭圆会自相交（触发行只有 48 高时也不会，但
  // 展开 / 收起的那一段可能很矮）。
  final limit = math.max(0.0, math.min(rect.width, rect.height) / 2);
  final top = Radius.circular(topRadius.clamp(0.0, limit));
  final bottom = Radius.circular(bottomRadius.clamp(0.0, limit));
  return RSuperellipse.fromRectAndCorners(
    rect,
    topLeft: top,
    topRight: top,
    bottomLeft: bottom,
    bottomRight: bottom,
  );
}

/// 两个矩形之间按 [t] 插值（不夹 t，保留弹簧的过冲）。
Rect lerpExpressiveRect(Rect a, Rect b, double t) => Rect.fromLTRB(
  lerpDouble(a.left, b.left, t)!,
  lerpDouble(a.top, b.top, t)!,
  lerpDouble(a.right, b.right, t)!,
  lerpDouble(a.bottom, b.bottom, t)!,
);
