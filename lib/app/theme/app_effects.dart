import 'package:flutter/material.dart';

/// NodeJot 阴影效果常量。
class AppEffects {
  const AppEffects._();

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x1A7D6AB5),
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0D8D79C7),
      offset: Offset(0, 3),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
}
