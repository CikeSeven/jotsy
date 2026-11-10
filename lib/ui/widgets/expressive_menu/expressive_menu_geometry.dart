import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 弹出菜单的几何计算（纯函数）：面板落点（NexioSchedule 的
/// liquidDropdownPositionProvider 与 miuix 的 dropdownPositionProvider）、
/// 容器变换中的面板矩形（NexioSchedule ListPopup 的 rectOf）与二级菜单落点。

/// 菜单相对锚点的水平对齐方式，按阅读方向解析（RTL 下左右互换）。
enum ExpressiveMenuPlacement {
  /// 菜单起始边与锚点起始边对齐，向结束方向展开；适合行首的文本入口。
  start,

  /// 菜单结束边与锚点结束边对齐，向起始方向展开；适合顶栏与行尾的 ⋮ 按钮。
  end,
}

/// 菜单最终落在锚点的哪一侧，决定从哪个角长出来。
enum ExpressiveMenuSide {
  /// 向下长：面板的上角贴着起点。
  below,

  /// 向上长：面板的下角贴着起点。
  above,

  /// 上下都放不下、以起点居中。
  middle,
}

/// 面板圆角（NexioSchedule 的 PanelCornerRadius，连续曲线，这里用超椭圆）。
const double kExpressiveMenuRadius = 25;

/// 行高亮胶囊的圆角。
const double kExpressiveMenuRowRadius = 17;

/// 不贴着触发控件长出来时（卡片、指针处）起点小圆的边长（NexioSchedule
/// 没有触发尺寸时的兜底）。
const double kExpressiveMenuSeedFallback = 28;

/// 夹进安全区时左右至少留出的距离（贴着锚点对齐的面板通常碰不到）。
const double kExpressiveMenuScreenMargin = 8;

/// 主菜单的落点：面板矩形、所在侧、贴着起点的是哪条竖边，以及起点矩形
/// （面板从它长出来，浮层坐标）。
@immutable
class ExpressiveMenuPlacementResult {
  const ExpressiveMenuPlacementResult({
    required this.rect,
    required this.side,
    required this.alignRight,
    required this.seed,
  });

  final Rect rect;
  final ExpressiveMenuSide side;
  final bool alignRight;
  final Rect seed;

  /// 面板贴着起点的那个角（浮层坐标）；居中时为那条竖边的中点。主菜单在
  /// 二级菜单打开时以它为原点缩小。
  Offset get pivot =>
      Offset(alignRight ? rect.right : rect.left, switch (side) {
        ExpressiveMenuSide.below => rect.top,
        ExpressiveMenuSide.above => rect.bottom,
        ExpressiveMenuSide.middle => rect.center.dy,
      });
}

/// 面板盖住触发控件、从它本身长出来（NexioSchedule 的下拉与顶栏“更多”）：
/// 面板贴着起点 [seed] 的角——`end` 为结束侧的角、`start` 为起始侧的角；起点
/// 往下放得下就贴上角向下长，否则往上放得下贴下角向上长，都不行以起点居中；
/// 最后夹进 [bounds]（左右留 [kExpressiveMenuScreenMargin]，上下不留）。
ExpressiveMenuPlacementResult placeCoveringMenu({
  required Rect seed,
  required Size size,
  required Rect bounds,
  required ExpressiveMenuPlacement placement,
  required TextDirection textDirection,
}) {
  final endAligned =
      (placement == ExpressiveMenuPlacement.end) ==
      (textDirection == TextDirection.ltr);
  var x = endAligned ? seed.right - size.width : seed.left;
  ExpressiveMenuSide side;
  double y;
  if (bounds.bottom - seed.top >= size.height) {
    side = ExpressiveMenuSide.below;
    y = seed.top;
  } else if (seed.bottom - bounds.top >= size.height) {
    side = ExpressiveMenuSide.above;
    y = seed.bottom - size.height;
  } else {
    side = ExpressiveMenuSide.middle;
    y = seed.center.dy - size.height / 2;
  }
  const margin = kExpressiveMenuScreenMargin;
  x = x.clamp(
    bounds.left + margin,
    math.max(bounds.left + margin, bounds.right - margin - size.width),
  );
  y = y.clamp(bounds.top, math.max(bounds.top, bounds.bottom - size.height));
  final rect = Rect.fromLTWH(x, y, size.width, size.height);
  return ExpressiveMenuPlacementResult(
    rect: rect,
    side: side,
    alignRight: _closerToRight(rect, seed, endAligned),
    seed: seed,
  );
}

/// 面板放在锚点旁边（卡片长按、指针处右键）：miuix 的下拉规则——下方放得下
/// 落在下方 [gap] 处，否则上方，都不行以锚点居中；左右夹进 [bounds] 留
/// [kExpressiveMenuScreenMargin]、上下留 [gap]。起点是贴着锚点那个角上的
/// [kExpressiveMenuSeedFallback] 小圆。
ExpressiveMenuPlacementResult placeOutsideMenu({
  required Rect anchor,
  required Size size,
  required Rect bounds,
  required ExpressiveMenuPlacement placement,
  required TextDirection textDirection,
  required double gap,
}) {
  final endAligned =
      (placement == ExpressiveMenuPlacement.end) ==
      (textDirection == TextDirection.ltr);
  var x = endAligned ? anchor.right - size.width : anchor.left;
  double y;
  if (bounds.bottom - anchor.bottom > size.height) {
    y = anchor.bottom + gap;
  } else if (anchor.top - bounds.top > size.height) {
    y = anchor.top - size.height - gap;
  } else {
    y = anchor.center.dy - size.height / 2;
  }
  const margin = kExpressiveMenuScreenMargin;
  x = x.clamp(
    bounds.left + margin,
    math.max(bounds.left + margin, bounds.right - margin - size.width),
  );
  final maxY = bounds.bottom - size.height - gap;
  y = y.clamp(math.min(bounds.top + gap, maxY), maxY);
  final rect = Rect.fromLTWH(x, y, size.width, size.height);
  final side = rect.center.dy > anchor.center.dy
      ? ExpressiveMenuSide.below
      : rect.center.dy < anchor.center.dy
      ? ExpressiveMenuSide.above
      : ExpressiveMenuSide.middle;
  final alignRight = _closerToRight(rect, anchor, endAligned);
  const s = kExpressiveMenuSeedFallback;
  final seedLeft = alignRight ? rect.right - s : rect.left;
  final seedTop = switch (side) {
    ExpressiveMenuSide.below => rect.top,
    ExpressiveMenuSide.above => rect.bottom - s,
    ExpressiveMenuSide.middle => rect.center.dy - s / 2,
  };
  return ExpressiveMenuPlacementResult(
    rect: rect,
    side: side,
    alignRight: alignRight,
    seed: Rect.fromLTWH(seedLeft, seedTop, s, s),
  );
}

/// 夹进安全区后面板可能不再贴着起点：按哪条竖边离起点更近判断。
bool _closerToRight(Rect rect, Rect seed, bool endAligned) {
  if (rect.width <= 0) return endAligned;
  final left = (rect.left - seed.left).abs();
  final right = (rect.right - seed.right).abs();
  return left == right ? endAligned : right < left;
}

/// 容器变换中此刻的面板矩形（面板自身坐标）：宽高各自从起点插值到面板
/// （[fraction]，不夹，保留过冲）；位置从“贴着起点的角”迁向面板中心
/// （[origin]）。两者都为 0 时就是起点，都为 1 时就是整块面板。
///
/// 与 NexioSchedule 的 rectOf 等价：那里的迁移量 W·0.5·p·(1 − w/W) 正是把
/// 贴角时的中心插值到面板中心。
Rect expressiveMenuMorphRect({
  required Size size,
  required Rect seed,
  required double fraction,
  required double origin,
  required ExpressiveMenuSide side,
  required bool alignRight,
}) {
  final w = math.max(0.0, lerpDouble(seed.width, size.width, fraction)!);
  final h = math.max(0.0, lerpDouble(seed.height, size.height, fraction)!);
  final cornerX = alignRight ? seed.right - w / 2 : seed.left + w / 2;
  final cornerY = switch (side) {
    ExpressiveMenuSide.below => seed.top + h / 2,
    ExpressiveMenuSide.above => seed.bottom - h / 2,
    ExpressiveMenuSide.middle => seed.center.dy,
  };
  final cx = lerpDouble(cornerX, size.width / 2, origin)!;
  final cy = lerpDouble(cornerY, size.height / 2, origin)!;
  return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
}

/// 二级菜单的落点：标题行与触发行的胶囊 [pill] 重合（面板左上角在胶囊左上
/// 往外 [inset]），结束方向放不下时贴安全区的结束边（留
/// [kExpressiveMenuScreenMargin]），下方放不下时底边对齐触发行下方 [inset]，
/// 再不行夹进安全区。
Rect placeExpressiveSubmenu({
  required Rect pill,
  required Size size,
  required Rect bounds,
  required TextDirection textDirection,
  required double inset,
}) {
  const margin = kExpressiveMenuScreenMargin;
  final minLeft = bounds.left + margin;
  final maxLeft = math.max(minLeft, bounds.right - margin - size.width);
  final left = textDirection == TextDirection.ltr
      ? (pill.left - inset).clamp(minLeft, maxLeft)
      : (pill.right + inset - size.width).clamp(minLeft, maxLeft);
  var top = pill.top - inset;
  if (top + size.height > bounds.bottom) {
    top = pill.bottom + inset - size.height;
  }
  top = top.clamp(
    bounds.top,
    math.max(bounds.top, bounds.bottom - size.height),
  );
  return Rect.fromLTWH(left, top, size.width, size.height);
}

/// [rect] 上的超椭圆，圆角不超过短边的一半（起点那颗小圆就是正圆）。
RSuperellipse expressiveMenuShape(Rect rect, double radius) {
  final r = math.min(radius, math.max(0.0, rect.shortestSide / 2));
  return RSuperellipse.fromRectAndRadius(rect, Radius.circular(r));
}

/// 两个矩形之间按 [t] 插值（不夹 t，保留弹簧的过冲）。
Rect lerpExpressiveRect(Rect a, Rect b, double t) => Rect.fromLTRB(
  lerpDouble(a.left, b.left, t)!,
  lerpDouble(a.top, b.top, t)!,
  lerpDouble(a.right, b.right, t)!,
  lerpDouble(a.bottom, b.bottom, t)!,
);
