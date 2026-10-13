import 'package:flutter/material.dart';

/// 浮动面板使用单层语义阴影，避免固定紫色阴影在暗色/换色主题中失配。
class AppEffects {
  const AppEffects._();

  static List<BoxShadow> softShadow(ColorScheme colors) => [
    BoxShadow(
      color: colors.shadow.withValues(
        alpha: colors.brightness == Brightness.dark ? 0.24 : 0.12,
      ),
      offset: const Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];

  /// 静止态卡片（设置分组、日历面板、时间线条目、探索卡片）的极淡投影。
  ///
  /// 仅亮色模式使用：暗色模式靠表面层级区分，叠加黑色投影只会发脏。
  /// 颜色取 `colorScheme.shadow` 语义色而非硬编码黑色。
  static List<BoxShadow>? restingCardShadow(ColorScheme colors) =>
      colors.brightness == Brightness.light
      ? <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
      : null;
}
