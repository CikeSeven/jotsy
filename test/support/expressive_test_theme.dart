import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/theme.dart';

/// 组件回归使用与应用相同的主题装配，避免只在 Flutter 默认主题下验证。
ThemeData expressiveTestTheme(
  Brightness brightness, {
  Color seedColor = const Color(0xff1e6586),
}) =>
    MaterialTheme(
      brightness == Brightness.light
          ? Typography.material2021().black
          : Typography.material2021().white,
    ).theme(
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
    );
