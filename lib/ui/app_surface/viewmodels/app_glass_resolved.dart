import 'package:flutter/material.dart';

import '../../diaries/viewmodels/diary_card_colors.dart';
import '../models/app_glass_style.dart';
import '../models/app_surface_enums.dart';
import '../models/app_surface_limits.dart';

/// 把组件材质设置 [AppGlassStyle] 落到当前主题下可直接渲染的值。
///
/// 输入：材质设置、当前 [ColorScheme]（决定明暗与语义色）与系统“高对比度”
/// 开关；输出：不可变的解析结果。纯函数、无副作用，按 `==` 比较，组件可以
/// 据此跳过无变化的重建。界面只经 `AppGlass.of(context)` 取得它（那里按
/// (样式, 配色, 高对比度) 做了小缓存），不要在 build 里自己反复 resolve。
///
/// 口径（与导航栏玻璃 `HomeBarResolvedStyle`、菜单玻璃
/// `ExpressiveMenuSurface` 同源，换一处要同步另两处）：
/// - 底色 [tint]：中性 = 亮 surfaceContainerLowest / 暗 surfaceContainerHigh；
///   主题色 = 中性色向 primaryContainer 插值（亮 0.35 / 暗 0.30）；自定义 =
///   用户色（暗色优先用户给的暗色值，否则经 `DiaryCardColors.deriveDark`
///   推导）。透明度一律只由 `tintOpacity` 表达；
/// - 描边与投影：与菜单的 `borderOf` / `shadowOf` 同口径；
/// - 高对比度：保留“是玻璃”这一布局判断（[isGlass] 照旧），只把底色换成
///   不透明的 [solidFill] 并关闭模糊（[translucent] 为 false）——半透明底色
///   叠在任意背景上无法保证对比度，而组件突然换回经典样式同样让人困惑。
///   减少动画不影响材质（玻璃本身没有动画）。
@immutable
class AppGlassResolved {
  const AppGlassResolved._({
    required this.style,
    required this.translucent,
    required this.tint,
    required this.solidFill,
    required this.blurSigma,
    required this.border,
    required this.hairline,
    required this.shadowColor,
    required this.customTint,
    required this.themeOnSurface,
    required this.themeOnSurfaceVariant,
    required this.themeSurface,
  });

  factory AppGlassResolved.resolve(
    AppGlassStyle style,
    ColorScheme scheme, {
    required bool highContrast,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    // 渲染层二次夹紧：直接构造（而非解码）的样式也可能越界。
    final opacity = AppSurfaceLimits.glassTintOpacity.clamp(style.tintOpacity);
    final tint = _tintBase(style, scheme, dark).withValues(alpha: opacity);
    final light = !dark;
    return AppGlassResolved._(
      style: style,
      translucent: !highContrast,
      tint: tint,
      solidFill: Color.alphaBlend(tint, scheme.surface),
      blurSigma: AppSurfaceLimits.glassBlurSigma.clamp(style.blurSigma),
      border: style.border
          ? BorderSide(
              color: scheme.outlineVariant.withValues(alpha: light ? 0.6 : 0.5),
            )
          : null,
      // 铺满整宽的顶栏用更淡的分隔线（与导航栏 topBarLine 的默认 35% 一致），
      // 菜单那样 60% 的描边横贯整屏会显得生硬。
      hairline: style.border
          ? scheme.outlineVariant.withValues(alpha: 0.35)
          : null,
      shadowColor: scheme.shadow.withValues(alpha: light ? 0.12 : 0.32),
      customTint: style.tint == AppGlassTint.custom && style.tintColor != null,
      themeOnSurface: scheme.onSurface,
      themeOnSurfaceVariant: scheme.onSurfaceVariant,
      themeSurface: scheme.surface,
    );
  }

  /// 解析所依据的材质设置（只用于 [isGlass]）。
  final AppGlassStyle style;

  /// 玻璃是否半透明并模糊背景；高对比度时为 false，底色改用 [solidFill]。
  final bool translucent;

  /// 玻璃底色（已带 tintOpacity 透明度），叠在背景上。
  final Color tint;

  /// 不透明的等效底色（[tint] 叠在 surface 上）：高对比度时玻璃改用它。
  final Color solidFill;

  /// 夹紧后的模糊半径；0 即只有半透明底色。
  final double blurSigma;

  /// 卡片、面板等带圆角玻璃的四周描边；设置关闭描边时为 null。
  final BorderSide? border;

  /// 铺满整宽的玻璃（顶栏）底缘细线颜色；设置关闭描边时为 null。
  final Color? hairline;

  /// 外侧投影颜色（只画在表面外侧，见 `OuterShadowPainter`）。
  final Color shadowColor;

  /// 是否用了自定义底色（且选了颜色）：只有这时主题前景可能看不清，玻璃
  /// 表面才需要按实际背景做前景兜底（见 [foregroundFor]）。
  final bool customTint;

  /// 解析时主题的前景 / 表面色：前景兜底以它们为准（见 [foregroundFor]）。
  final Color themeOnSurface;
  final Color themeOnSurfaceVariant;
  final Color themeSurface;

  /// 玻璃表面实际的底色：半透明时为 [tint]，否则为 [solidFill]。
  Color get fill => translucent ? tint : solidFill;

  /// 是否模糊背景：高对比度或模糊半径为 0 时不模糊。具体某块玻璃还要看
  /// 它下面有没有值得模糊的东西（见 `AppGlassBlur`）。
  bool get canBlur => translucent && blurSigma > 0;

  /// 某类组件是否用玻璃（布局级判断，高对比度时仍按设置）。调用方据此在
  /// 经典与玻璃两种画法之间选一种。
  bool isGlass(AppGlassComponent component) => style.isGlass(component);

  /// [fill] 叠在 [backdrop]（玻璃下方内容的估计颜色，通常取
  /// `AppPageBackdrop.estimatedColor`）上之后，主题的 onSurface /
  /// onSurfaceVariant 是否仍看得清（4.5 / 3.0）。都看得清时返回 null（沿用
  /// 主题）；否则把看不清的那一个换成 onSurface / surface 中对比度更高的
  /// 一个（一深一浅，总有一个看得清），与导航栏玻璃的前景兜底同一口径。
  AppGlassForeground? foregroundFor(Color backdrop) {
    // 估计色本身可能带透明度（理论上不会），先垫在 surface 上取得不透明色，
    // 对比度只对不透明色有意义。
    final under = Color.alphaBlend(backdrop, themeSurface);
    final effective = Color.alphaBlend(fill, under);
    final onSurface = _readable(themeOnSurface, effective, 4.5);
    final onSurfaceVariant = _readable(themeOnSurfaceVariant, effective, 3.0);
    if (onSurface == themeOnSurface &&
        onSurfaceVariant == themeOnSurfaceVariant) {
      return null;
    }
    return AppGlassForeground(
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
    );
  }

  Color _readable(Color preferred, Color background, double minRatio) {
    if (DiaryCardColors.contrastRatio(preferred, background) >= minRatio) {
      return preferred;
    }
    return DiaryCardColors.bestContrast(<Color>[
      themeOnSurface,
      themeSurface,
    ], background);
  }

  /// 各底色方案在当前明暗下的不透明底色（口径见类注释）。
  static Color _tintBase(AppGlassStyle style, ColorScheme scheme, bool dark) {
    final neutral = dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    final custom = style.tintColor;
    return switch (style.tint) {
      AppGlassTint.neutral => neutral,
      AppGlassTint.theme => Color.lerp(
        neutral,
        scheme.primaryContainer,
        dark ? 0.30 : 0.35,
      )!,
      // 自定义却没选颜色时按中性色解读（样式里保留原值，不改写）。
      AppGlassTint.custom =>
        custom == null
            ? neutral
            : _customBase(custom, style.tintColorDark, dark),
    };
  }

  /// 自定义底色：浅色直接用；深色优先用户指定的深色值，否则按卡片底色的
  /// 口径推导（保持色相、压低明度与饱和度），避免暗色模式下一大片刺眼的
  /// 高饱和色。透明度一律去掉，只由 tintOpacity 表达。
  static Color _customBase(int light, int? darkValue, bool dark) {
    if (!dark) return _opaque(light);
    if (darkValue != null) return _opaque(darkValue);
    return DiaryCardColors.deriveDark(
      _opaque(light),
      DiaryCardColorRole.surface,
    );
  }

  static Color _opaque(int argb) => Color(0xFF000000 | (argb & 0x00FFFFFF));

  @override
  bool operator ==(Object other) {
    return other is AppGlassResolved &&
        other.style == style &&
        other.translucent == translucent &&
        other.tint == tint &&
        other.solidFill == solidFill &&
        other.blurSigma == blurSigma &&
        other.border == border &&
        other.hairline == hairline &&
        other.shadowColor == shadowColor &&
        other.customTint == customTint &&
        other.themeOnSurface == themeOnSurface &&
        other.themeOnSurfaceVariant == themeOnSurfaceVariant &&
        other.themeSurface == themeSurface;
  }

  @override
  int get hashCode => Object.hash(
    style,
    translucent,
    tint,
    solidFill,
    blurSigma,
    border,
    hairline,
    shadowColor,
    customTint,
    themeOnSurface,
    themeOnSurfaceVariant,
    themeSurface,
  );
}

/// 玻璃上换用的前景色（见 [AppGlassResolved.foregroundFor]）。
@immutable
class AppGlassForeground {
  const AppGlassForeground({
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  bool operator ==(Object other) =>
      other is AppGlassForeground &&
      other.onSurface == onSurface &&
      other.onSurfaceVariant == onSurfaceVariant;

  @override
  int get hashCode => Object.hash(onSurface, onSurfaceVariant);
}
