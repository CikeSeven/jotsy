import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_bar_metrics.dart';
import 'home_bar_style.dart';

/// 把 [HomeBarStyle] 落到当前主题下可直接渲染的值。
///
/// 输入：样式、当前 [ColorScheme]（决定明暗与语义色）与系统“高对比度”开关；
/// 输出：不可变的解析结果（玻璃是否半透明、模糊强度、栏与导航项的尺寸、
/// 各处颜色）。纯函数、
/// 无副作用，不依赖 widget 树，方便底栏、四个顶栏与设置页预览共用同一份
/// 结果，并按 `==` 跳过无变化的重建。
///
/// 尺寸：项宽、缝、图标、文字与间距取自样式（渲染层再夹紧一次），格高、
/// 栏高与两处圆角由它们推导（[HomeBarMetrics.itemHeight]）；其余几何是
/// 常量。模糊强度跟着不透明度走（[blurSigma]），饱和度增强是常量；首页
/// 各 Tab 的顶栏恒为同一种玻璃，下缘渐隐或画分隔线（[topBarFadeExtent]）。
///
/// 高对比度时布局不变（悬浮底栏、顶栏结构、FAB 位置），只把底色换成不透明
/// 的 [solidFill] 并关闭模糊（[translucent] 为 false）：半透明底色叠在任意
/// 内容上无法保证对比度。减少动画不影响材质（玻璃本身没有动画）。
@immutable
class HomeBarResolvedStyle {
  const HomeBarResolvedStyle._({
    required this.translucent,
    required this.blurSigma,
    required this.topBarHairline,
    required this.hairlineColor,
    required this.itemWidth,
    required this.itemHeight,
    required this.itemInset,
    required this.roundness,
    required this.iconSize,
    required this.labelSize,
    required this.labelGap,
    required this.fabPlacement,
    required this.labelMode,
    required this.tint,
    required this.tinted,
    required this.solidFill,
    required this.borderColor,
    required this.shadowColor,
    required this.indicatorColor,
    required this.selectedForeground,
    required this.unselectedForeground,
  });

  factory HomeBarResolvedStyle.resolve(
    HomeBarStyle style,
    ColorScheme scheme, {
    bool highContrast = false,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    // 渲染层二次夹紧：直接构造（而非解码）的样式也可能越界。
    final range = HomeBarStyleLimits.tintOpacity;
    final tintOpacity = range.clamp(style.tintOpacity);
    final density = (tintOpacity - range.min) / (range.max - range.min);
    final tint = _tintBase(
      style.tint,
      scheme,
      dark,
    ).withValues(alpha: tintOpacity);
    final iconSize = HomeBarStyleLimits.itemIconSize.clamp(style.itemIconSize);
    final labelSize = HomeBarStyleLimits.itemLabelSize.clamp(
      style.itemLabelSize,
    );
    final labelGap = HomeBarStyleLimits.itemLabelGap.clamp(style.itemLabelGap);
    final labeled = style.labelMode != HomeBarLabelMode.never;
    return HomeBarResolvedStyle._(
      translucent: !highContrast,
      blurSigma:
          HomeBarMetrics.minBlurSigma +
          (HomeBarMetrics.maxBlurSigma - HomeBarMetrics.minBlurSigma) * density,
      topBarHairline: style.topBarHairline,
      hairlineColor: scheme.outlineVariant.withValues(alpha: 0.35),
      itemWidth: HomeBarStyleLimits.itemWidth.clamp(style.itemWidth),
      itemHeight: HomeBarMetrics.itemHeight(
        iconSize: iconSize,
        labelSize: labeled ? labelSize : null,
        labelGap: labelGap,
      ),
      itemInset: HomeBarStyleLimits.itemInset.clamp(style.itemInset),
      roundness: HomeBarStyleLimits.roundness.clamp(style.roundness),
      iconSize: iconSize,
      labelSize: labelSize,
      labelGap: labelGap,
      fabPlacement: style.fabPlacement,
      labelMode: style.labelMode,
      tint: tint,
      tinted: style.tint == HomeBarTint.theme,
      // 玻璃下方的内容未知，不透明的等效色按叠在 surface 上的效果估算。
      solidFill: Color.alphaBlend(tint, scheme.surface),
      // 描边是玻璃边缘的反光而不是轮廓线：灰色描边会把胶囊勾成一块实体
      // 卡片。亮色用最亮的表面色、暗色用 onSurface，都只取一部分不透明度，
      // 叠在透出来的内容上像一圈高光。
      borderColor: dark
          ? scheme.onSurface.withValues(alpha: 0.16)
          : scheme.surfaceContainerLowest.withValues(alpha: 0.80),
      shadowColor: scheme.shadow.withValues(alpha: dark ? 0.32 : 0.12),
      // 指示器铺满一整格，面积大，颜色要比小块时更淡才不显得闷。
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.20 : 0.12),
      selectedForeground: scheme.primary,
      unselectedForeground: scheme.onSurfaceVariant,
    );
  }

  /// 玻璃是否半透明并模糊背景；高对比度时为 false，底色改用 [solidFill]。
  final bool translucent;

  /// 玻璃表面实际的底色：半透明时为 [tint]，否则为 [solidFill]。
  Color get fill => translucent ? tint : solidFill;

  /// 顶栏是否画底部细分隔线，以及它的颜色（已带不透明度；粗细取
  /// GlassSurface 的默认值）。
  final bool topBarHairline;
  final Color hairlineColor;

  /// 顶栏底缘渐隐区的高度；0 表示不渐隐、下缘是清楚的一条边。
  ///
  /// 默认渐隐（[HomeBarMetrics.topBarFadeExtent]）：顶栏越往下越透明，到
  /// 下缘时玻璃完全消失，滚到栏下的内容是慢慢化进去的，没有一条硬边。
  /// 两种情况不渐隐，三者互斥、不会叠在一起：
  /// - 用户打开了顶栏分隔线（[topBarHairline]）：要的就是一条清楚的下缘，
  ///   细线画在淡没了的玻璃底下只会像悬空的一根线；
  /// - 高对比度（[translucent] 为 false）：底色整片不透明才保证得了栏里
  ///   文字的对比度。
  double get topBarFadeExtent =>
      translucent && !topBarHairline ? HomeBarMetrics.topBarFadeExtent : 0;

  /// 背景模糊半径（底栏与顶栏共用）：不透明度最低时为
  /// [HomeBarMetrics.minBlurSigma]，最高时为 [HomeBarMetrics.maxBlurSigma]，
  /// 中间线性取值——越通透模糊越轻，透出来的内容还看得出轮廓。
  final double blurSigma;

  /// 模糊后背景的饱和度倍数（常量）。
  double get saturation => HomeBarMetrics.saturation;

  /// 每个导航项（与选中指示器）的首选宽度；屏幕放不下时由悬浮栏等比
  /// 收窄。
  final double itemWidth;

  /// 导航项（与选中指示器）的高度：由图标、文字与间距推导（只有图标时
  /// 不算文字），见 [HomeBarMetrics.itemHeight]。
  final double itemHeight;

  /// 导航项与胶囊内壁的缝：指示器四周离胶囊边都是这么宽。
  final double itemInset;

  /// 圆角程度（0 直角 ~ 1 胶囊），见 [cornerRadius]。
  final double roundness;

  /// 导航项的图标大小、文字字号与两者间距。
  final double iconSize;
  final double labelSize;
  final double labelGap;

  /// 图标占的方框边长（比图标大一点，容纳选中时的放大）。
  double get iconBox => HomeBarMetrics.iconBox(iconSize);

  /// 悬浮底栏的高度：格高加上下两道缝。
  double get barHeight => itemHeight + itemInset * 2;

  /// 胶囊的圆角：栏高一半的 [roundness] 倍（1 时两端是完整的半圆）。
  double get cornerRadius => barHeight / 2 * roundness;

  /// 选中指示器的圆角：与胶囊同心（胶囊圆角减去缝），所以缝在四角也一样
  /// 宽；胶囊为完整胶囊时它也是（格高的一半）。不小于 0。
  double get indicatorRadius => math.max(0, cornerRadius - itemInset);

  /// 悬浮底栏与系统手势条之间的距离。
  double get bottomGap => HomeBarMetrics.bottomGap;

  /// 胶囊底缘到屏幕底边的距离（见 [HomeBarMetrics.bottomSpace]）。
  double bottomSpace(double bottomInset) =>
      HomeBarMetrics.bottomSpace(bottomInset);

  /// 新建按钮相对悬浮底栏的位置。
  final HomeBarFabPlacement fabPlacement;
  final HomeBarLabelMode labelMode;

  /// 玻璃底色（已带不透明度），叠在模糊后的内容上。
  final Color tint;

  /// 用户是否给玻璃染了主题色调；中性色调为 false。宽窗口的侧边栏据此
  /// 决定跟随页面底色还是用 [solidFill]。
  final bool tinted;

  /// 不透明的等效底色：高对比度时玻璃表面改用它。
  final Color solidFill;

  /// 悬浮底栏的描边色（已带不透明度）与投影色。
  final Color borderColor;
  final Color shadowColor;

  /// 底栏选中指示器的颜色。
  final Color indicatorColor;

  /// 底栏选中 / 未选中项的图标与文字颜色。
  final Color selectedForeground;
  final Color unselectedForeground;

  /// 各底色方案在当前明暗下的不透明底色。
  static Color _tintBase(HomeBarTint tint, ColorScheme scheme, bool dark) {
    final neutral = dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    return switch (tint) {
      HomeBarTint.neutral => neutral,
      HomeBarTint.theme => Color.lerp(
        neutral,
        scheme.primaryContainer,
        dark ? 0.30 : 0.35,
      )!,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarResolvedStyle &&
        other.translucent == translucent &&
        other.blurSigma == blurSigma &&
        other.topBarHairline == topBarHairline &&
        other.hairlineColor == hairlineColor &&
        other.itemWidth == itemWidth &&
        other.itemHeight == itemHeight &&
        other.itemInset == itemInset &&
        other.roundness == roundness &&
        other.iconSize == iconSize &&
        other.labelSize == labelSize &&
        other.labelGap == labelGap &&
        other.fabPlacement == fabPlacement &&
        other.labelMode == labelMode &&
        other.tint == tint &&
        other.tinted == tinted &&
        other.solidFill == solidFill &&
        other.borderColor == borderColor &&
        other.shadowColor == shadowColor &&
        other.indicatorColor == indicatorColor &&
        other.selectedForeground == selectedForeground &&
        other.unselectedForeground == unselectedForeground;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    translucent,
    blurSigma,
    topBarHairline,
    hairlineColor,
    itemWidth,
    itemHeight,
    itemInset,
    roundness,
    iconSize,
    labelSize,
    labelGap,
    fabPlacement,
    labelMode,
    tint,
    tinted,
    solidFill,
    borderColor,
    shadowColor,
    indicatorColor,
    selectedForeground,
    unselectedForeground,
  ]);
}
