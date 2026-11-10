import 'package:flutter/material.dart';

import '../../models/home_bar_style/home_bar_resolved_style.dart';

/// 导航项的颜色与文字样式：取 `HomeBarResolvedStyle` 的前景色与指示器色。
@immutable
class HomeNavColors {
  const HomeNavColors({
    required this.indicator,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.selectedLabel,
    required this.unselectedLabel,
  });

  /// 导航项文字的字重：选中与未选中同一字重，只换颜色——字重一变字宽就
  /// 变，切换时文字会左右抖一下。
  static const FontWeight labelWeight = FontWeight.w600;

  /// 解析导航项颜色（底栏与侧边导航栏共用同一口径）：图标、文字与指示器
  /// 的颜色取 [style]；文字样式由主题的 labelMedium 派生（带着应用字体），
  /// 字号由各自的栏再定。
  factory HomeNavColors.resolve(ThemeData theme, HomeBarResolvedStyle style) {
    final base = (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontWeight: labelWeight,
      letterSpacing: 0.1,
    );
    return HomeNavColors(
      indicator: style.indicatorColor,
      selectedIcon: style.selectedForeground,
      unselectedIcon: style.unselectedForeground,
      selectedLabel: base.copyWith(color: style.selectedForeground),
      unselectedLabel: base.copyWith(color: style.unselectedForeground),
    );
  }

  final Color indicator;
  final Color selectedIcon;
  final Color unselectedIcon;
  final TextStyle selectedLabel;
  final TextStyle unselectedLabel;
}
