import 'package:flutter/material.dart';

import 'app_radii.dart';

/// 为容器、导航、输入与弹层提供同一组 Expressive 表面 token。
/// 只依赖传入的 ColorScheme，因此种子色、暗色与高对比度入口不会分叉。
abstract final class ExpressiveSurfaces {
  /// 卡片纯净表面底色：
  /// - 亮色模式下使用纯白 (surfaceContainerLowest)，彻底消除发灰与脏感；
  /// - 暗色模式下使用温和深灰 (surfaceContainerLow)，与深色底形成舒适层次。
  static Color cardColor(ColorScheme colors) =>
      colors.brightness == Brightness.light
      ? colors.surfaceContainerLowest
      : colors.surfaceContainerLow;

  /// 卡片边框颜色：带有细腻的低不透明度，在明暗主题下均显轻盈精致。
  static Color cardBorderColor(ColorScheme colors) => colors.outlineVariant
      .withValues(alpha: colors.brightness == Brightness.light ? 0.35 : 0.2);

  /// 卡片统一微边框。
  static BorderSide cardBorderSide(ColorScheme colors) =>
      BorderSide(color: cardBorderColor(colors), width: 0.8);

  /// 卡片统一样式。
  static OutlinedBorder cardShape(ColorScheme colors) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.card),
    side: cardBorderSide(colors),
  );

  static ThemeData apply(ThemeData theme) {
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final isLight = colors.brightness == Brightness.light;
    final cardShape = ExpressiveSurfaces.cardShape(colors);
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.dialog),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide.none,
    );
    return theme.copyWith(
      appBarTheme: AppBarThemeData(
        backgroundColor: isLight ? const Color(0xFFF7F9FC) : colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor(colors),
        elevation: 0,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerHigh,
        shape: dialogShape,
        elevation: 0,
        titleTextStyle: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: text.bodyMedium,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16.5,
          color: colors.onSurface,
        ),
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontSize: 13.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerLow,
        modalBackgroundColor: isLight
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.onSurfaceVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isLight
            ? colors.surfaceContainerLow.withValues(alpha: 0.6)
            : colors.surfaceContainerHighest,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: isLight
            ? const Color(0xFFF7F9FC)
            : colors.surfaceContainer,
        elevation: 0,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isLight
            ? const Color(0xFFF7F9FC)
            : colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: const StadiumBorder(),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: isLight
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerLow,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
          shape: WidgetStatePropertyAll(cardShape),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainer,
        shape: cardShape,
        textStyle: text.labelLarge,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyLarge,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
          shape: WidgetStatePropertyAll(cardShape),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
      searchViewTheme: SearchViewThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        shape: dialogShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        headerBackgroundColor: colors.surfaceContainerHigh,
        headerForegroundColor: colors.onSurface,
        shape: dialogShape,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        shape: dialogShape,
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        dividerColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
      ),
    );
  }
}
