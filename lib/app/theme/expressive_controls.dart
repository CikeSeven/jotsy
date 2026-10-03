import 'package:flutter/material.dart';

import 'expressive_motion.dart';

/// 用原生控件承载 Expressive 的状态形状，保留焦点、键盘、禁用态和语义树。
/// 不覆盖按钮的语义颜色：tonal、危险操作和第三方编辑器仍可使用自己的色彩角色。
abstract final class ExpressiveControls {
  static final shape = WidgetStateProperty.resolveWith<OutlinedBorder>((
    states,
  ) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        states.contains(WidgetState.pressed) ? 12 : 28,
      ),
    );
  });

  static ButtonStyle button(TextTheme text) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    shape: shape,
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    animationDuration: ExpressiveMotion.fast,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  static ThemeData apply(ThemeData theme) {
    final colors = theme.colorScheme;
    final style = button(theme.textTheme);
    final textStyle = style.copyWith(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(style: style),
      elevatedButtonTheme: ElevatedButtonThemeData(style: style),
      outlinedButtonTheme: OutlinedButtonThemeData(style: style),
      textButtonTheme: TextButtonThemeData(style: textStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: shape,
          animationDuration: ExpressiveMotion.fast,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 0,
        focusElevation: 1,
        hoverElevation: 2,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: theme.textTheme.titleMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(style: style),
      sliderTheme: SliderThemeData(
        trackHeight: 16,
        trackGap: 6,
        trackShape: const GappedSliderTrackShape(),
        thumbShape: const HandleThumbShape(),
        thumbSize: WidgetStateProperty.resolveWith(
          (states) => Size(states.contains(WidgetState.pressed) ? 2 : 4, 44),
        ),
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.secondaryContainer,
        thumbColor: colors.primary,
        valueIndicatorColor: colors.inverseSurface,
        valueIndicatorTextStyle: theme.textTheme.labelLarge?.copyWith(
          color: colors.onInverseSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        selectedColor: colors.secondaryContainer,
        disabledColor: colors.onSurface.withValues(alpha: 0.12),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
        ),
        secondaryLabelStyle: theme.textTheme.labelLarge?.copyWith(
          color: colors.onSecondaryContainer,
        ),
        checkmarkColor: colors.onSecondaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineWidth: const WidgetStatePropertyAll(1),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.secondaryContainer,
        circularTrackColor: colors.secondaryContainer,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(8),
        trackGap: 4,
      ),
    );
  }

  /// ThemeData 没有 BuildContext；在应用 builder 中补上系统减少动画偏好，
  /// 而不是停掉整棵树的 ticker（那会连输入光标和业务动画一起冻结）。
  static ThemeData withoutMotion(ThemeData theme) {
    ButtonStyle stop(ButtonStyle? style) => (style ?? const ButtonStyle())
        .copyWith(animationDuration: Duration.zero);
    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: stop(theme.filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: stop(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: stop(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: stop(theme.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: stop(theme.iconButtonTheme.style),
      ),
    );
  }
}
