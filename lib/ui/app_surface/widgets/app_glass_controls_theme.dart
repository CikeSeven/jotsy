import 'package:flutter/material.dart';

import 'app_glass_scope.dart';

/// 主题里自带底色的小控件（标签式 Chip、输入框、开关轨道）的玻璃材质：归入
/// 组件类别“小控件”（controls）。
///
/// 输入：最近的 `AppGlassScope`（经 [AppGlass.of]）与当前 Theme；输出：
/// “小控件”为玻璃时在子树上覆盖 chipTheme / inputDecorationTheme /
/// switchTheme，经典时原样返回 [child]。无副作用。
///
/// 为什么在主题层：这些控件的不透明底色来自主题默认值（Chip 的
/// surfaceContainerHigh、输入框的填充色、开关未选中轨道的
/// surfaceContainerHighest），全应用有几十处调用。挂在 `MaterialApp.builder`
/// 覆盖一次，页面、面板与对话框里的控件一起换成玻璃底色 + 玻璃描边，与
/// `AppGlassField` 同一口径（不模糊、高对比度时为不透明的等效色），调用方
/// 一行不改。自行指定了底色的控件不受影响，由各自经 `AppGlassField` 处理。
///
/// 只改未选中 / 静止状态：选中的 Chip（secondaryContainer）、打开的开关
/// （primary）与获得焦点的输入框描边（primary）保持强调色，与按钮组的选中
/// 段一致。
class AppGlassControlsTheme extends StatelessWidget {
  const AppGlassControlsTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    if (!glass.isGlass(AppGlassComponent.controls)) return child;
    return Theme(data: themeFor(Theme.of(context), glass), child: child);
  }

  /// 在经典主题 [base] 上换成玻璃的底色与描边；尺寸、圆角、文字样式不变。
  static ThemeData themeFor(ThemeData base, AppGlassResolved glass) {
    final fill = glass.fill;
    final side = glass.border ?? BorderSide.none;
    final input = base.inputDecorationTheme;
    InputBorder? withSide(InputBorder? border) =>
        border is OutlineInputBorder && border.borderSide == BorderSide.none
        ? border.copyWith(borderSide: side)
        : border;
    return base.copyWith(
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: fill,
        side: WidgetStateBorderSide.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ||
                  states.contains(WidgetState.disabled)
              ? BorderSide.none
              : side,
        ),
      ),
      inputDecorationTheme: input.copyWith(
        fillColor: fill,
        border: withSide(input.border),
        enabledBorder: withSide(input.enabledBorder),
      ),
      switchTheme: base.switchTheme.copyWith(
        // 返回 null 时开关回落到自己的默认色：只换未选中、可用时的轨道。
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ||
                  states.contains(WidgetState.disabled)
              ? null
              : fill,
        ),
      ),
    );
  }
}
