import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/home_bar_style/home_bar_style.dart';

/// 首页底栏导航项的几何与“跟随滑动”换算（纯函数 + 布局 delegate）。
///
/// 图标、文字的摆放逐行照搬 Material `NavigationBar` 的
/// `_NavigationDestinationLayoutDelegate`：默认样式要与改版前逐像素一致。
/// 在此之上多了一个指示器子项，由这里统一计算位置：胶囊跟着图标框，
/// 圆角块铺满导航项（四周各缩 [HomeNavGeometry.blockInset]），跟随滑动时
/// 再按页面的小数位置平移到下一项。
abstract final class HomeNavGeometry {
  /// 胶囊指示器尺寸（M3 规格 64×32），也是图标框的最小尺寸。
  static const double capsuleWidth = 64;
  static const double capsuleHeight = 32;

  /// 圆角块与导航项四周的距离、最大宽度。
  static const double blockInset = 6;
  static const double blockMaxWidth = 96;

  /// 文字与图标框之间的距离（M3 的 labelPadding）。
  static const double labelGap = 4;

  /// 选中图标的放大倍数。
  static const double selectedIconScale = 1.12;

  /// 圆角块在 [cell] 里的矩形：水平居中、宽不超过 [blockMaxWidth]，
  /// 上下各缩 [blockInset]。
  static Rect blockRect(Size cell) {
    final width = math.max(
      0.0,
      math.min(cell.width - blockInset * 2, blockMaxWidth),
    );
    final height = math.max(0.0, cell.height - blockInset * 2);
    return Rect.fromCenter(
      center: cell.center(Offset.zero),
      width: width,
      height: height,
    );
  }

  /// 圆角块的圆角：比栏的圆角小一圈（同心），且不超过块高的一半。
  static double blockRadius(double cornerRadius, double barHeight) {
    final blockHeight = barHeight - blockInset * 2;
    return math.max(0.0, math.min(cornerRadius - blockInset, blockHeight / 2));
  }

  /// 页面位置夹到有效范围内（越界回弹时指示器停在两端）。
  static double clampPosition(double position, int count) =>
      position.clamp(0.0, (count - 1).toDouble());

  /// 跟随滑动时第 [index] 项的选中程度：离页面位置一页以上为 0，正对为 1。
  static double followAmount(int index, double position, int count) =>
      (1 - (index - clampPosition(position, count)).abs()).clamp(0.0, 1.0);

  /// 跟随滑动时负责画指示器的一项（页面位置向下取整）。
  static int followAnchor(double position, int count) =>
      clampPosition(position, count).floor();
}

/// 跟随滑动时第 [index] 项的选中程度，包装成 [Animation] 交给
/// FadeTransition 与布局 delegate 监听；只转发值监听，没有方向状态。
///
/// 按 (position, index) 判等：每次 build 新建也不会让监听方重新订阅。
class HomeNavFollowAmount extends Animation<double> {
  HomeNavFollowAmount(this.position, this.index, this.count);

  final ValueListenable<double> position;
  final int index;
  final int count;

  @override
  double get value =>
      HomeNavGeometry.followAmount(index, position.value, count);

  // 跟手没有“正向 / 反向”，状态只按当前值推算，不发状态通知。
  @override
  AnimationStatus get status => switch (value) {
    >= 1 => AnimationStatus.completed,
    <= 0 => AnimationStatus.dismissed,
    _ => AnimationStatus.forward,
  };

  @override
  void addListener(VoidCallback listener) => position.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      position.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  bool operator ==(Object other) =>
      other is HomeNavFollowAmount &&
      other.position == position &&
      other.index == index &&
      other.count == count;

  @override
  int get hashCode => Object.hash(position, index, count);
}

/// 跟随滑动时布局需要的上下文：页面位置、本项序号、总数与文字模式
/// （推算相邻一项的图标高度用）。
@immutable
class HomeNavFollow {
  const HomeNavFollow({
    required this.position,
    required this.index,
    required this.count,
    required this.labelMode,
  });

  final ValueListenable<double> position;
  final int index;
  final int count;
  final HomeBarLabelMode labelMode;

  /// 第 [other] 项此刻的文字显现程度（决定它的图标在竖直方向的位置）。
  double labelRevealAt(int other) => switch (labelMode) {
    HomeBarLabelMode.always => 1,
    HomeBarLabelMode.never => 0,
    HomeBarLabelMode.selected => HomeNavGeometry.followAmount(
      other,
      position.value,
      count,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is HomeNavFollow &&
      other.position == position &&
      other.index == index &&
      other.count == count &&
      other.labelMode == labelMode;

  @override
  int get hashCode => Object.hash(position, index, count, labelMode);
}

/// 导航项内部布局：指示器（可选）、图标框、文字。
class HomeNavDestinationLayout extends MultiChildLayoutDelegate {
  HomeNavDestinationLayout({
    required this.labelReveal,
    required this.indicator,
    required this.textDirection,
    this.follow,
  }) : super(
         relayout: follow == null
             ? labelReveal
             : Listenable.merge(<Listenable>[labelReveal, follow.position]),
       );

  static const int indicatorId = 0;
  static const int iconId = 1;
  static const int labelId = 2;

  /// 文字显现程度：0 时图标竖直居中，1 时图标与文字整体居中。
  final Animation<double> labelReveal;
  final HomeBarIndicator indicator;
  final TextDirection textDirection;

  /// 跟随滑动的上下文；null 时指示器固定在本项。
  final HomeNavFollow? follow;

  @override
  void performLayout(Size size) {
    final iconSize = layoutChild(iconId, BoxConstraints.loose(size));
    final labelSize = layoutChild(labelId, BoxConstraints.loose(size));

    // 与 M3 相同：文字隐藏时图标居中，显示时图标 + 文字整体居中，
    // 文字紧贴图标框下方。
    double iconTop(double reveal) {
      final offset = lerpDouble(
        iconSize.height / 2,
        iconSize.height / 2 + labelSize.height / 2,
        reveal,
      )!;
      return size.height / 2 - offset;
    }

    final top = iconTop(labelReveal.value);
    final iconLeft = size.width / 2 - iconSize.width / 2;
    positionChild(iconId, Offset(iconLeft, top));
    positionChild(
      labelId,
      Offset(size.width / 2 - labelSize.width / 2, top + iconSize.height),
    );

    if (!hasChild(indicatorId)) {
      return;
    }
    // 跟随滑动：只有锚点项画指示器，按小数部分平移到下一项（RTL 时下一项
    // 在左边）；其他项的指示器缩放为 0，见 HomeNavIndicator。
    final follow = this.follow;
    var shift = 0.0;
    if (follow != null &&
        HomeNavGeometry.followAnchor(follow.position.value, follow.count) ==
            follow.index) {
      shift =
          HomeNavGeometry.clampPosition(follow.position.value, follow.count) -
          follow.index;
    }
    final dx =
        shift * size.width * (textDirection == TextDirection.rtl ? -1 : 1);
    switch (indicator) {
      case HomeBarIndicator.capsule:
        final capsule = Size(
          math.min(HomeNavGeometry.capsuleWidth, size.width),
          math.min(HomeNavGeometry.capsuleHeight, size.height),
        );
        layoutChild(indicatorId, BoxConstraints.tight(capsule));
        // 胶囊居中在图标框上（与 M3 把指示器放进图标 Stack 的位置逐像素
        // 相同）；跟随滑动时竖直位置在两项的图标之间插值（“只显示选中项
        // 文字”时两项的图标高度不同）。
        var capsuleTop = top + (iconSize.height - capsule.height) / 2;
        if (shift > 0) {
          final nextTop =
              iconTop(follow!.labelRevealAt(follow.index + 1)) +
              (iconSize.height - capsule.height) / 2;
          capsuleTop = lerpDouble(capsuleTop, nextTop, shift)!;
        }
        positionChild(
          indicatorId,
          Offset(
            iconLeft + (iconSize.width - capsule.width) / 2 + dx,
            capsuleTop,
          ),
        );
      case HomeBarIndicator.block:
        final rect = HomeNavGeometry.blockRect(size);
        layoutChild(indicatorId, BoxConstraints.tight(rect.size));
        positionChild(indicatorId, rect.topLeft.translate(dx, 0));
      case HomeBarIndicator.none:
        layoutChild(indicatorId, BoxConstraints.tight(Size.zero));
        positionChild(indicatorId, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(HomeNavDestinationLayout oldDelegate) =>
      oldDelegate.labelReveal != labelReveal ||
      oldDelegate.indicator != indicator ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.follow != follow;
}
