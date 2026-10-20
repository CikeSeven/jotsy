import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../diaries/viewmodels/diary_card_colors.dart';
import 'home_bar_style.dart';

/// 把 [HomeBarStyle] 落到当前主题下可直接渲染的值。
///
/// 输入：样式、当前 [ColorScheme]（决定明暗与语义色）与系统“高对比度”开关；
/// 输出：不可变的解析结果（材质是否生效、夹紧后的尺寸、各处颜色）。纯函数、
/// 无副作用，不依赖 widget 树，方便底栏、四个顶栏与设置页预览共用同一份
/// 结果，并按 `==` 跳过无变化的重建。
///
/// 回退规则：
/// - 高对比度时保留用户选的玻璃布局（悬浮底栏、顶栏结构、FAB 位置），只把
///   底色换成不透明的 [solidFill] 并关闭模糊（[translucent] 为 false）：半透明
///   底色叠在任意内容上无法保证对比度，而布局突然变回贴底实色栏同样让人
///   困惑。减少动画不影响材质（玻璃本身没有动画）；
/// - 自定义底色却没有选颜色时按中性色解读（样式里保留原值，不改写）；
/// - 自定义底色可能很深或很浅，导致主题的前景色看不清，此时前景换成
///   onSurface / surface 中对比度更高的一个（见 [_readable]）。
@immutable
class HomeBarResolvedStyle {
  const HomeBarResolvedStyle._({
    required this.isGlass,
    required this.translucent,
    required this.glassTopBars,
    required this.blurSigma,
    required this.tintOpacity,
    required this.barHeight,
    required this.cornerRadius,
    required this.sideMargin,
    required this.bottomGap,
    required this.iconSize,
    required this.labelGap,
    required this.blockPadding,
    required this.border,
    required this.topBarHairline,
    required this.shadow,
    required this.fabPlacement,
    required this.labelMode,
    required this.indicator,
    required this.tint,
    required this.solidFill,
    required this.borderColor,
    required this.hairlineColor,
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
    final isGlass = style.material == HomeBarMaterial.glass;
    // 渲染层二次夹紧：直接构造（而非解码）的样式也可能越界。
    final barHeight = HomeBarStyleLimits.barHeight.clamp(style.barHeight);
    final tintOpacity = HomeBarStyleLimits.tintOpacity.clamp(style.tintOpacity);
    final tint = _tintBase(style, scheme, dark).withValues(alpha: tintOpacity);
    final solidFill = Color.alphaBlend(tint, scheme.surface);
    var selected = scheme.primary;
    var unselected = scheme.onSurfaceVariant;
    if (style.tint == HomeBarTint.custom && style.tintColor != null) {
      // 玻璃下方的内容未知，按叠在 surface 上的效果估算底色；这与退回实色
      // 时的 solidFill 是同一个颜色。
      selected = _readable(selected, solidFill, scheme, 4.5);
      unselected = _readable(unselected, solidFill, scheme, 3.0);
    }
    return HomeBarResolvedStyle._(
      isGlass: isGlass,
      translucent: isGlass && !highContrast,
      glassTopBars: isGlass && style.glassTopBars,
      blurSigma: HomeBarStyleLimits.blurSigma.clamp(style.blurSigma),
      tintOpacity: tintOpacity,
      barHeight: barHeight,
      // 圆角超过高度一半时形状不再变化（已是胶囊），夹住免得阴影与描边
      // 的路径出现畸形。
      cornerRadius: math.min(
        HomeBarStyleLimits.cornerRadius.clamp(style.cornerRadius),
        barHeight / 2,
      ),
      sideMargin: HomeBarStyleLimits.sideMargin.clamp(style.sideMargin),
      bottomGap: HomeBarStyleLimits.bottomGap.clamp(style.bottomGap),
      iconSize: HomeBarStyleLimits.iconSize.clamp(style.iconSize),
      labelGap: HomeBarStyleLimits.labelGap.clamp(style.labelGap),
      blockPadding: HomeBarStyleLimits.blockPadding.clamp(style.blockPadding),
      // 描边、投影与并排的 FAB 只属于悬浮玻璃底栏；实色栏贴底铺满，
      // 这里直接给出“是否画”，渲染层不必再判断材质。
      border: isGlass && style.border,
      // 顶栏分隔线有自己的开关，不跟底栏描边走；glassTopBars 已隐含玻璃材质。
      topBarHairline: isGlass && style.glassTopBars && style.topBarHairline,
      shadow: isGlass && style.shadow,
      fabPlacement: isGlass ? style.fabPlacement : HomeBarFabPlacement.above,
      labelMode: style.labelMode,
      indicator: style.indicator,
      tint: tint,
      solidFill: solidFill,
      borderColor: scheme.outlineVariant.withValues(alpha: dark ? 0.5 : 0.6),
      hairlineColor: scheme.outlineVariant.withValues(alpha: dark ? 0.2 : 0.35),
      shadowColor: scheme.shadow.withValues(alpha: dark ? 0.32 : 0.12),
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
      selectedForeground: selected,
      unselectedForeground: unselected,
    );
  }

  /// 是否选了玻璃材质：决定布局（悬浮底栏、玻璃顶栏结构、FAB 位置），
  /// 高对比度时仍为 true。
  final bool isGlass;

  /// 玻璃是否半透明并模糊背景；高对比度时为 false，底色改用 [solidFill]。
  final bool translucent;

  /// 玻璃表面实际的底色：半透明时为 [tint]，否则为 [solidFill]。
  Color get fill => translucent ? tint : solidFill;

  /// 顶栏是否也用玻璃。
  final bool glassTopBars;
  final double blurSigma;
  final double tintOpacity;
  final double barHeight;

  /// 已夹到 [barHeight] 一半以内的圆角。
  final double cornerRadius;
  final double sideMargin;
  final double bottomGap;
  final double iconSize;

  /// 文字与图标框的间距、圆角块的内边距（已夹到取值范围内；栏太矮放不下
  /// 时布局还会再收窄，见 HomeNavDestinationLayout）。
  final double labelGap;
  final double blockPadding;

  /// 悬浮底栏是否画描边 / 投影（只在玻璃生效时可能为 true）。
  final bool border;
  final bool shadow;

  /// 玻璃顶栏是否画底部细分隔线（顶栏不用玻璃时恒为 false）。与 [border]
  /// 无关，见 `HomeBarStyle.topBarHairline`。
  final bool topBarHairline;

  /// FAB 位置；实色栏一律为 above。
  final HomeBarFabPlacement fabPlacement;
  final HomeBarLabelMode labelMode;
  final HomeBarIndicator indicator;

  /// 玻璃底色（已带 tintOpacity 透明度），叠在模糊后的内容上。
  final Color tint;

  /// 不透明的等效底色：高对比度时玻璃表面改用它。
  final Color solidFill;

  /// 悬浮底栏的描边色。
  final Color borderColor;

  /// 玻璃顶栏底部的细分隔线颜色。
  final Color hairlineColor;
  final Color shadowColor;

  /// 玻璃底栏选中指示器的颜色。
  final Color indicatorColor;

  /// 玻璃底栏选中 / 未选中项的图标与文字颜色。
  final Color selectedForeground;
  final Color unselectedForeground;

  /// 各底色方案在当前明暗下的不透明底色。
  static Color _tintBase(HomeBarStyle style, ColorScheme scheme, bool dark) {
    final neutral = dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    final custom = style.tintColor;
    return switch (style.tint) {
      HomeBarTint.neutral => neutral,
      HomeBarTint.theme => Color.lerp(
        neutral,
        scheme.primaryContainer,
        dark ? 0.30 : 0.35,
      )!,
      HomeBarTint.custom =>
        custom == null
            ? neutral
            : _customBase(custom, style.tintColorDark, dark),
    };
  }

  /// 自定义底色：浅色直接用；深色优先用户指定的深色值，否则按卡片底色
  /// 的口径推导（保持色相、压低明度与饱和度），避免暗色模式下一块刺眼的
  /// 高饱和色带。透明度一律去掉，只由 tintOpacity 表达。
  static Color _customBase(int light, int? darkValue, bool dark) {
    if (!dark) {
      return _opaque(light);
    }
    if (darkValue != null) {
      return _opaque(darkValue);
    }
    return DiaryCardColors.deriveDark(
      _opaque(light),
      DiaryCardColorRole.surface,
    );
  }

  static Color _opaque(int argb) => Color(0xFF000000 | (argb & 0x00FFFFFF));

  /// [preferred] 在 [background] 上的对比度不足 [minRatio] 时，换成
  /// onSurface / surface 中对比度更高的一个（一深一浅，总有一个看得清）。
  static Color _readable(
    Color preferred,
    Color background,
    ColorScheme scheme,
    double minRatio,
  ) {
    if (DiaryCardColors.contrastRatio(preferred, background) >= minRatio) {
      return preferred;
    }
    return DiaryCardColors.bestContrast(<Color>[
      scheme.onSurface,
      scheme.surface,
    ], background);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarResolvedStyle &&
        other.isGlass == isGlass &&
        other.translucent == translucent &&
        other.glassTopBars == glassTopBars &&
        other.blurSigma == blurSigma &&
        other.tintOpacity == tintOpacity &&
        other.barHeight == barHeight &&
        other.cornerRadius == cornerRadius &&
        other.sideMargin == sideMargin &&
        other.bottomGap == bottomGap &&
        other.iconSize == iconSize &&
        other.labelGap == labelGap &&
        other.blockPadding == blockPadding &&
        other.border == border &&
        other.topBarHairline == topBarHairline &&
        other.shadow == shadow &&
        other.fabPlacement == fabPlacement &&
        other.labelMode == labelMode &&
        other.indicator == indicator &&
        other.tint == tint &&
        other.solidFill == solidFill &&
        other.borderColor == borderColor &&
        other.hairlineColor == hairlineColor &&
        other.shadowColor == shadowColor &&
        other.indicatorColor == indicatorColor &&
        other.selectedForeground == selectedForeground &&
        other.unselectedForeground == unselectedForeground;
  }

  @override
  int get hashCode => Object.hashAll(<Object>[
    isGlass,
    translucent,
    glassTopBars,
    blurSigma,
    tintOpacity,
    barHeight,
    cornerRadius,
    sideMargin,
    bottomGap,
    iconSize,
    labelGap,
    blockPadding,
    border,
    topBarHairline,
    shadow,
    fabPlacement,
    labelMode,
    indicator,
    tint,
    solidFill,
    borderColor,
    hairlineColor,
    shadowColor,
    indicatorColor,
    selectedForeground,
    unselectedForeground,
  ]);
}
