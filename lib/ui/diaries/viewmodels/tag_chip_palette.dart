import 'package:flutter/material.dart';

import '../../app_surface/widgets/app_glass_scope.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';

/// 首页标签栏里一个标签胶囊的配色（选中与未选中两套）。胶囊自己画选中态
/// 与滑动色块（`TagSelectionPillController`）代画选中态时用同一份，两者
/// 看起来完全一致。
@immutable
class TagChipPalette {
  const TagChipPalette({
    required this.tagColor,
    required this.unselectedBg,
    required this.unselectedBorder,
    required this.unselectedText,
    required this.selectedBg,
    required this.selectedBorder,
    required this.selectedText,
  });

  /// 按 [context] 的主题、“控件”材质与首页顶栏样式解析标签色 [tagColor]
  /// 的胶囊配色。
  ///
  /// “控件”为玻璃时，未选中胶囊的底色换成玻璃底色（半透明的中性色，高
  /// 对比度时为不透明等效色），标签色只留在色点与描边上；选中态在同一块
  /// 玻璃底色上叠标签色浅底，加上满色 2dp 描边，仍一眼可辨。不模糊：标签
  /// 栏挂在刊头下面，那条栏是否模糊由导航栏样式决定，这里再加一层模糊就
  /// 成了同一区域两层模糊（整条顶栏只有一块启用的 BackdropFilter，由测试
  /// 兜底）。
  ///
  /// 首页顶栏自上而下渐变时，标签栏落在玻璃淡出的下半截，背后是滚上来的
  /// 原样内容：胶囊改垫栏自己的颜色、几乎不透明的底（topBarControlFill），
  /// 再按上面的规则叠标签色，否则淡底跟着玻璃一起看不见。
  factory TagChipPalette.resolve(BuildContext context, Color tagColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final appGlass = AppGlass.of(context);
    final glass = appGlass.isGlass(AppGlassComponent.controls)
        ? appGlass
        : null;
    final barStyle = HomeChromeScope.maybeStyleOf(context);
    final Color? base = barStyle != null && barStyle.topBarFades
        ? barStyle.topBarControlFill
        : glass?.fill;
    final classicTint = tagColor.withValues(alpha: isLight ? 0.08 : 0.16);
    final Color unselectedBg;
    if (base == null) {
      unselectedBg = classicTint;
    } else if (glass == null) {
      // 经典控件：保留标签色浅底，只是垫在实底上。
      unselectedBg = Color.alphaBlend(classicTint, base);
    } else {
      unselectedBg = base;
    }
    final tagTint = tagColor.withValues(alpha: isLight ? 0.22 : 0.36);
    return TagChipPalette(
      tagColor: tagColor,
      unselectedBg: unselectedBg,
      unselectedBorder: tagColor.withValues(alpha: isLight ? 0.22 : 0.32),
      unselectedText: colorScheme.onSurface,
      selectedBg: base == null ? tagTint : Color.alphaBlend(tagTint, base),
      selectedBorder: tagColor,
      selectedText: isLight
          ? (ThemeData.estimateBrightnessForColor(tagColor) == Brightness.dark
                ? tagColor
                : colorScheme.onSurface)
          : colorScheme.onSurface,
    );
  }

  final Color tagColor;
  final Color unselectedBg;
  final Color unselectedBorder;
  final Color unselectedText;
  final Color selectedBg;
  final Color selectedBorder;
  final Color selectedText;
}
