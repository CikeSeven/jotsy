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
}
