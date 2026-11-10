import 'package:flutter/material.dart';

import '../../models/home_bar_style/home_bar_resolved_style.dart';

/// 导航项的颜色：取 `HomeBarResolvedStyle` 的前景色与指示器色。
@immutable
class HomeNavColors {
  const HomeNavColors({
    required this.indicator,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.selectedLabel,
    required this.unselectedLabel,
  });

  /// 解析导航项颜色（底栏与侧边导航栏共用同一口径）：图标、文字与指示器
  /// 的颜色取 [style]，文字的字号与字重沿用主题的 navigationBarTheme。
  factory HomeNavColors.resolve(ThemeData theme, HomeBarResolvedStyle style) {
    final scheme = theme.colorScheme;
    final labelTheme = theme.navigationBarTheme.labelTextStyle;
    final base = theme.textTheme.labelMedium ?? const TextStyle();
    // 与 M3 NavigationBar 取文字样式的顺序一致：主题优先，缺省用 M3 默认。
    final selectedLabel =
        labelTheme?.resolve(const <WidgetState>{WidgetState.selected}) ??
        base.apply(color: scheme.onSurface);
    final unselectedLabel =
        labelTheme?.resolve(const <WidgetState>{}) ??
        base.apply(color: scheme.onSurfaceVariant);
    return HomeNavColors(
      indicator: style.indicatorColor,
      selectedIcon: style.selectedForeground,
      unselectedIcon: style.unselectedForeground,
      selectedLabel: selectedLabel.copyWith(color: style.selectedForeground),
      unselectedLabel: unselectedLabel.copyWith(
        color: style.unselectedForeground,
      ),
    );
  }

  final Color indicator;
  final Color selectedIcon;
  final Color unselectedIcon;
  final TextStyle selectedLabel;
  final TextStyle unselectedLabel;
}
