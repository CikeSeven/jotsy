import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 手机文字选区胶囊的定位几何（纯函数，不依赖 BuildContext，可单测）。
///
/// 输入：覆盖层尺寸、安全区（系统栏 + 键盘）、选区锚点
/// （[primaryAnchor] 为选区首个矩形的上沿中点，[secondaryAnchor] 为末个矩形的
/// 下沿中点）。坐标都在覆盖层里——胶囊铺满从屏幕原点开始的覆盖层，与 Flutter
/// 自带工具栏同一假设，所以全局坐标即可直接使用。
///
/// 规则：
/// - 默认放在选区上方：菜单底边 = [primaryAnchor] 上方 [gapAbove]；
/// - 上方放不下（顶边会高于安全区上沿 + [margin]）时翻到下方：菜单顶边 =
///   [secondaryAnchor] 下方 [gapBelow]，留出选区把手（Material 的
///   `_kHandleSize - 2`）；
/// - 仍放不下时夹进屏幕（会盖住选区一部分，但不出屏）；
/// - 水平居中于所在一侧的锚点，夹进 [安全区左 + margin, 宽 − 安全区右 − margin]。
///
/// 放在哪一侧只按收起时的高度判断（[collapsedHeight]），展开不会让胶囊换边：
/// 展开后的次要区长在远离选区的一侧，高度另由 [availableHeight] 限制。
class AppTextToolbarGeometry {
  const AppTextToolbarGeometry({
    required this.overlaySize,
    required this.safePadding,
    required this.primaryAnchor,
    this.secondaryAnchor,
    required this.collapsedHeight,
  });

  /// 菜单到安全区边缘的最小距离。
  static const double margin = 8;

  /// 在选区上方时菜单与选区的间距。
  static const double gapAbove = 8;

  /// 在选区下方时菜单与选区的间距：让出选区把手（Material `_kHandleSize - 2`）。
  static const double gapBelow = 20;

  final Size overlaySize;

  /// 系统栏与键盘占去的部分（`padding` + `viewInsets`）。
  final EdgeInsets safePadding;
  final Offset primaryAnchor;

  /// 为 null 时与 [primaryAnchor] 相同（如只有一个插入点）。
  final Offset? secondaryAnchor;

  /// 收起时（只有主行）的菜单高度。
  final double collapsedHeight;

  Offset get _below => secondaryAnchor ?? primaryAnchor;

  double get _top => safePadding.top + margin;
  double get _bottom => overlaySize.height - safePadding.bottom - margin;
  double get _left => safePadding.left + margin;
  double get _right => overlaySize.width - safePadding.right - margin;

  /// 菜单可用的最大宽度。
  double get availableWidth => math.max(0, _right - _left);

  /// 菜单放在选区上方还是下方。
  bool get above => primaryAnchor.dy - gapAbove - collapsedHeight >= _top;

  /// 所在一侧留给菜单的高度（展开后整张卡片不超过它）。
  double get availableHeight => math.max(
    0,
    above ? primaryAnchor.dy - gapAbove - _top : _bottom - _anchorTopBelow,
  );

  /// 在下方时菜单顶边的位置（未夹取）。
  double get _anchorTopBelow => _below.dy + gapBelow;

  /// 尺寸为 [size] 的菜单左上角（覆盖层坐标）。
  Offset offsetFor(Size size) {
    final anchorX = above ? primaryAnchor.dx : _below.dx;
    final x = (anchorX - size.width / 2)
        .clamp(_left, math.max(_left, _right - size.width))
        .toDouble();
    // 在上方时底边贴着锚点、向上长；在下方时顶边贴着锚点、向下长。
    final y = above
        ? primaryAnchor.dy - gapAbove - size.height
        : _anchorTopBelow;
    return Offset(
      x,
      y.clamp(_top, math.max(_top, _bottom - size.height)).toDouble(),
    );
  }
}

/// 按 [AppTextToolbarGeometry] 摆放菜单：子组件在可用宽高内取自己的尺寸，
/// 尺寸变化（展开 / 收起的 AnimatedSize 每一帧）都会重新定位，所以在上方时
/// 底边、在下方时顶边始终贴着选区。
class AppTextSelectionLayoutDelegate extends SingleChildLayoutDelegate {
  AppTextSelectionLayoutDelegate(this.geometry);

  final AppTextToolbarGeometry geometry;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          geometry.availableWidth,
          math.max(geometry.availableHeight, geometry.collapsedHeight),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      geometry.offsetFor(childSize);

  @override
  bool shouldRelayout(AppTextSelectionLayoutDelegate oldDelegate) {
    final a = geometry;
    final b = oldDelegate.geometry;
    return a.overlaySize != b.overlaySize ||
        a.safePadding != b.safePadding ||
        a.primaryAnchor != b.primaryAnchor ||
        a.secondaryAnchor != b.secondaryAnchor ||
        a.collapsedHeight != b.collapsedHeight;
  }
}

/// 主行按钮的分配结果：留在主行的项与挪进次要区最前面的项（原顺序）。
class AppTextToolbarRowFit<T> {
  const AppTextToolbarRowFit(this.row, this.overflow);

  final List<T> row;
  final List<T> overflow;
}

/// 主行放不下时从末尾把项挪进次要区（纯函数）。
///
/// [widths] 与 [items] 一一对应；[moreWidth] 是「更多」按钮的宽度，
/// [hasSecondary] 表示本来就有次要项（那时「更多」一定在）。[available] 已扣掉
/// 胶囊的左右内边距 [chrome]。至少保留一项在主行，避免主行只剩「更多」。
AppTextToolbarRowFit<T> fitAppTextToolbarRow<T>({
  required List<T> items,
  required List<double> widths,
  required double moreWidth,
  required bool hasSecondary,
  required double available,
  double chrome = 0,
}) {
  assert(items.length == widths.length);
  double total(int count, {required bool withMore}) {
    var sum = chrome + (withMore ? moreWidth : 0);
    for (var i = 0; i < count; i++) {
      sum += widths[i];
    }
    return sum;
  }

  var count = items.length;
  if (total(count, withMore: hasSecondary) <= available) {
    return AppTextToolbarRowFit<T>(List<T>.of(items), <T>[]);
  }
  // 一旦有项挪出去，「更多」就必须出现。
  while (count > 1 && total(count, withMore: true) > available) {
    count--;
  }
  return AppTextToolbarRowFit<T>(items.sublist(0, count), items.sublist(count));
}
