import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_block.dart';
import 'home_nav_follow.dart';

export 'home_nav_follow.dart';

/// 首页底栏导航项的几何与“跟随滑动”换算（纯函数 + 布局 delegate）。
///
/// 胶囊指示器下，图标、文字的摆放逐行照搬 Material `NavigationBar` 的
/// `_NavigationDestinationLayoutDelegate`：默认样式要与改版前逐像素一致。
/// 圆角块与“无指示器”时图标框收紧为图标大小（留出放大的余量），内容
/// （图标框 + 间距 + 文字）整体竖直居中，圆角块按内容加内边距包住它
/// （见 [blockSize]）。指示器作为额外的子项由这里统一计算位置，跟随滑动时
/// 再按页面的小数位置平移、缩放到下一项。
abstract final class HomeNavGeometry {
  /// 胶囊指示器尺寸（M3 规格 64×32），也是胶囊样式下图标框的最小尺寸。
  static const double capsuleWidth = 64;
  static const double capsuleHeight = 32;

  /// 圆角块的基础宽度规则（改版前的块宽）：导航项左右各缩 [blockInset]，
  /// 且不超过 [blockMaxWidth]；文字更宽时块再按内容加宽。
  static const double blockInset = 6;
  static const double blockMaxWidth = 96;

  /// 圆角块与导航项四边至少留出的距离：块再大也不贴住栏的边缘。
  static const double blockMinMargin = 2;

  /// 选中图标的放大倍数。
  static const double selectedIconScale = 1.12;

  /// 圆角块 / 无指示器时图标框比图标大出的部分：容纳选中时 1.12 倍的放大
  /// （图标最大 28，放大后 31.4，仍在 32 的框内），放大不会压到文字或块边。
  static const double iconSlotExtra = 4;

  /// 圆角块 / 无指示器时图标框的边长。
  static double iconSlot(double iconSize) => iconSize + iconSlotExtra;

  /// 包住 [content] 的圆角块尺寸（[cell] 为导航项大小）：
  /// - 高 = 内容高 + 2 × [padding]，但不超过导航项高 − 2 × [blockMinMargin]；
  /// - 宽取基础宽度规则与内容宽 + 2 × [padding] 中较大的一个，同样不超过
  ///   导航项宽 − 2 × [blockMinMargin]。
  /// 放不下时收窄的是内边距（块不越出栏），内容本身不受影响。
  static Size blockSize(Size cell, Size content, double padding) {
    final maxHeight = math.max(0.0, cell.height - blockMinMargin * 2);
    final maxWidth = math.max(0.0, cell.width - blockMinMargin * 2);
    final base = math.min(cell.width - blockInset * 2, blockMaxWidth);
    return Size(
      math.min(math.max(base, content.width + padding * 2), maxWidth),
      math.min(content.height + padding * 2, maxHeight),
    );
  }

  /// 圆角块的圆角：与栏的圆角同心（栏圆角减去块到栏上下边缘的距离），
  /// 且不超过块高的一半、不小于 0。实色栏同样按 `style.cornerRadius` 算。
  static double blockRadius(
    double cornerRadius,
    double barHeight,
    double blockHeight,
  ) => math.max(
    0.0,
    math.min(cornerRadius - (barHeight - blockHeight) / 2, blockHeight / 2),
  );

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

/// 导航项内部布局：指示器（可选）、图标框、文字，以及圆角块 / 无指示器时
/// 标出本项圆角块位置的空占位（水波纹按它裁切，跟随滑动时指示器平移走了
/// 它也留在原处）。
class HomeNavDestinationLayout extends MultiChildLayoutDelegate {
  HomeNavDestinationLayout({
    required this.labelReveal,
    required this.indicator,
    required this.textDirection,
    required this.labelGap,
    required this.blockPadding,
    this.follow,
  }) : super(
         relayout: follow == null
             ? labelReveal
             : Listenable.merge(<Listenable>[labelReveal, follow.position]),
       );

  static const int indicatorId = 0;
  static const int iconId = 1;
  static const int labelId = 2;
  static const int blockSlotId = 3;

  /// 文字显现程度：0 时图标竖直居中，1 时图标与文字整体居中。
  final Animation<double> labelReveal;
  final HomeBarIndicator indicator;
  final TextDirection textDirection;

  /// 文字与图标框的间距、圆角块的内边距（已按取值范围夹紧）。
  final double labelGap;
  final double blockPadding;

  /// 跟随滑动的上下文；null 时指示器固定在本项。
  final HomeNavFollow? follow;

  @override
  void performLayout(Size size) {
    final iconSize = layoutChild(iconId, BoxConstraints.loose(size));
    final textSize = layoutChild(labelId, BoxConstraints.loose(size));
    final isCapsule = indicator == HomeBarIndicator.capsule;

    // 间距在内容放不下时先收窄（不让文字越出栏）：胶囊照 M3 以栏高为界；
    // 圆角块与无指示器以块的最大高度为界，块的内边距再由 blockSize 收窄，
    // 内容就始终落在块里。默认参数下远放得下，胶囊仍与 M3 逐像素一致。
    final room = isCapsule
        ? size.height
        : size.height - HomeNavGeometry.blockMinMargin * 2;
    final gap = labelGap.clamp(
      0.0,
      math.max(0.0, room - iconSize.height - textSize.height),
    );
    final labelHeight = gap + textSize.height;

    // 与 M3 相同：文字隐藏时图标居中，显示时图标 + 间距 + 文字整体居中。
    // 写法保持 M3 的 lerp 形式，默认样式的浮点结果与改版前完全相同。
    double contentTop(double reveal) {
      final offset = lerpDouble(
        iconSize.height / 2,
        iconSize.height / 2 + labelHeight / 2,
        reveal,
      )!;
      return size.height / 2 - offset;
    }

    final reveal = labelReveal.value;
    final top = contentTop(reveal);
    final iconLeft = size.width / 2 - iconSize.width / 2;
    positionChild(iconId, Offset(iconLeft, top));
    positionChild(
      labelId,
      Offset(size.width / 2 - textSize.width / 2, top + iconSize.height + gap),
    );

    final follow = this.follow;
    final full = HomeNavContentSize(
      width: math.max(iconSize.width, textSize.width),
      labelHeight: labelHeight,
    );
    follow?.metrics.record(follow.index, full);

    // 本项圆角块：内容的宽高随文字显现插值（“只显示选中项文字”时未选中项
    // 只有图标框），块与内容同心。
    Size blockOf(HomeNavContentSize content, double reveal) =>
        HomeNavGeometry.blockSize(
          size,
          Size(
            lerpDouble(iconSize.width, content.width, reveal)!,
            iconSize.height + content.labelHeight * reveal,
          ),
          blockPadding,
        );
    final ownBlock = blockOf(full, reveal);
    final ownCenter = Offset(
      size.width / 2,
      top + (iconSize.height + labelHeight * reveal) / 2,
    );
    if (hasChild(blockSlotId)) {
      layoutChild(blockSlotId, BoxConstraints.tight(ownBlock));
      positionChild(
        blockSlotId,
        ownCenter - Offset(ownBlock.width / 2, ownBlock.height / 2),
      );
    }

    if (!hasChild(indicatorId)) {
      return;
    }
    // 跟随滑动：只有锚点项画指示器，按小数部分平移到下一项（RTL 时下一项
    // 在左边）；其他项的指示器缩放为 0，见 HomeNavIndicator。
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
              contentTop(follow!.labelRevealAt(follow.index + 1)) +
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
        var block = ownBlock;
        var centerY = ownCenter.dy;
        if (shift > 0) {
          // 平移途中大小与竖直位置在两项的块之间插值：两项的文字宽度、
          // 是否显示文字都可能不同。下一项的内容尺寸取它自己量到的值。
          final next = follow!.index + 1;
          final nextBlock = blockOf(
            follow.metrics.of(next) ?? full,
            follow.labelRevealAt(next),
          );
          block = Size.lerp(ownBlock, nextBlock, shift)!;
          centerY = lerpDouble(centerY, size.height / 2, shift)!;
        }
        layoutChild(indicatorId, BoxConstraints.tight(block));
        positionChild(
          indicatorId,
          Offset(
            ownCenter.dx + dx - block.width / 2,
            centerY - block.height / 2,
          ),
        );
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
      oldDelegate.labelGap != labelGap ||
      oldDelegate.blockPadding != blockPadding ||
      oldDelegate.follow != follow;
}
