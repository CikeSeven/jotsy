import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_glass_scope.dart';

/// 提示条（SnackBar）的玻璃材质：归入组件类别“小控件”（controls）。
///
/// 输入：最近的 `AppGlassScope`（经 [AppGlass.of]）与当前 Theme；输出：
/// “小控件”为玻璃时在子树上覆盖 `snackBarTheme`，经典时原样返回 [child]。
/// 无副作用。
///
/// 为什么在主题层而不是在 `showTrackedSnackBar` 里构造：全应用的提示都经
/// 主题取色，首页又基于 `Theme.of(context).snackBarTheme` 用 copyWith 改了
/// insetPadding——在 `MaterialApp.builder` 里覆盖一次，所有提示（含首页的
/// 内收边距）自动继承，调用方一行不改，也不会有漏网的入口。
///
/// 为什么不模糊：SDK 的浮动 SnackBar 入场带 FadeTransition，玻璃放进
/// Opacity / FadeTransition 会先闪一块采不到页面的模糊（见 AGENTS.md 玻璃
/// 规则），又改不了 SDK 的入场动画。所以只用玻璃底色，并把不透明度抬到至少
/// [minOpacity]：提示条会叠在任意内容（图片、正文、深色卡片）上，这个下限
/// 保证不靠模糊也读得清。高对比度时用不透明的 `solidFill`。
class AppGlassSnackBarTheme extends StatelessWidget {
  const AppGlassSnackBarTheme({super.key, required this.child});

  final Widget child;

  /// 玻璃提示条底色的最低不透明度：低于它，深色背景图上的浅色玻璃会透出
  /// 太多底下的内容（文字叠文字），截图观感在 0.88 左右既有玻璃的通透又
  /// 不影响阅读。
  static const double minOpacity = 0.88;

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    if (!glass.isGlass(AppGlassComponent.controls)) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        snackBarTheme: themeFor(theme.snackBarTheme, theme, glass),
      ),
      child: child,
    );
  }

  /// 在经典的 [base] 上换成玻璃配色：只改颜色与描边，浮动方式、圆角、
  /// insetPadding 与 elevation 0 沿用经典规格（经典与玻璃尺寸一致）。
  static SnackBarThemeData themeFor(
    SnackBarThemeData base,
    ThemeData theme,
    AppGlassResolved glass,
  ) {
    final scheme = theme.colorScheme;
    final fill = glass.translucent
        ? glass.tint.withValues(alpha: math.max(glass.tint.a, minOpacity))
        : glass.solidFill;
    // 下方内容未知：按页面底色 surface 估计；底色已近乎不透明，估计偏差
    // 对结果影响很小。自定义底色时 onSurface / primary 可能看不清，经
    // readableOn 换成对比度更高的前景（与其他玻璃同一口径）。
    final onFill = glass.readableOn(
      scheme.onSurface,
      fill: fill,
      backdrop: scheme.surface,
    );
    final action = glass.readableOn(
      scheme.primary,
      fill: fill,
      backdrop: scheme.surface,
    );
    final closeIcon = glass.readableOn(
      scheme.onSurfaceVariant,
      fill: fill,
      backdrop: scheme.surface,
      minRatio: 3.0,
    );
    final baseShape = base.shape;
    final shape = baseShape is RoundedRectangleBorder
        ? baseShape.copyWith(side: glass.border ?? BorderSide.none)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: glass.border ?? BorderSide.none,
          );
    return base.copyWith(
      backgroundColor: fill,
      contentTextStyle: (base.contentTextStyle ?? theme.textTheme.bodyMedium)
          ?.copyWith(color: onFill),
      actionTextColor: action,
      // M3 默认关闭图标为 onInverseSurface，在浅色玻璃上会看不见。
      closeIconColor: closeIcon,
      elevation: 0,
      shape: shape,
    );
  }
}
