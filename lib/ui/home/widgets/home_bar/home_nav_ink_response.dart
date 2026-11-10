import 'package:flutter/material.dart';

/// 水波纹与焦点高亮只画在 [rectOf] 给出的矩形里（指示器或圆角块的位置），
/// 而不是整个导航项。底栏与宽窗口的侧边导航栏共用；侧边栏另给悬停与焦点
/// 的状态层颜色（底栏不传，沿用主题）。
class HomeNavIndicatorInkResponse extends InkResponse {
  const HomeNavIndicatorInkResponse({
    super.key,
    required this.rectOf,
    super.customBorder,
    super.onTap,
    super.hoverColor,
    super.focusColor,
    super.focusNode,
    super.mouseCursor,
    super.child,
  }) : super(containedInkWell: true, highlightColor: Colors.transparent);

  final Rect Function(RenderBox referenceBox) rectOf;

  @override
  RectCallback? getRectCallback(RenderBox referenceBox) =>
      () => rectOf(referenceBox);
}
