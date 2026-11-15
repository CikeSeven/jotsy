package com.jotsy.diary.widgets

import com.jotsy.diary.R

/**
 * “跟随壁纸”配色的色槽资源（res/values*-v31、-v34 的 widget_dynamic_colors.xml，见
^ * docs/rules/home_widgets.md）：每个色槽三个资源——随系统明暗切换的、固定浅色的、
 * 固定深色的。色槽名与 Dart 导出的配色（home_widget_palette.dart）一致。
 *
 * 用资源而不是读出颜色值：启动器每次展开小组件时按当前壁纸解析资源，换了壁纸不用等应用
 * 重画就跟着变。
 */
object WidgetDynamicColors {
  /** 色槽名 → (随系统明暗, 固定浅色, 固定深色)。 */
  val ROLES: Map<String, Triple<Int, Int, Int>> =
    mapOf(
      "primary" to Triple(R.color.widget_dyn_primary, R.color.widget_dyn_light_primary, R.color.widget_dyn_dark_primary),
      "onPrimary" to Triple(R.color.widget_dyn_on_primary, R.color.widget_dyn_light_on_primary, R.color.widget_dyn_dark_on_primary),
      "primaryContainer" to Triple(R.color.widget_dyn_primary_container, R.color.widget_dyn_light_primary_container, R.color.widget_dyn_dark_primary_container),
      "onPrimaryContainer" to Triple(R.color.widget_dyn_on_primary_container, R.color.widget_dyn_light_on_primary_container, R.color.widget_dyn_dark_on_primary_container),
      "secondary" to Triple(R.color.widget_dyn_secondary, R.color.widget_dyn_light_secondary, R.color.widget_dyn_dark_secondary),
      "onSecondary" to Triple(R.color.widget_dyn_on_secondary, R.color.widget_dyn_light_on_secondary, R.color.widget_dyn_dark_on_secondary),
      "secondaryContainer" to Triple(R.color.widget_dyn_secondary_container, R.color.widget_dyn_light_secondary_container, R.color.widget_dyn_dark_secondary_container),
      "onSecondaryContainer" to Triple(R.color.widget_dyn_on_secondary_container, R.color.widget_dyn_light_on_secondary_container, R.color.widget_dyn_dark_on_secondary_container),
      "tertiary" to Triple(R.color.widget_dyn_tertiary, R.color.widget_dyn_light_tertiary, R.color.widget_dyn_dark_tertiary),
      "onTertiary" to Triple(R.color.widget_dyn_on_tertiary, R.color.widget_dyn_light_on_tertiary, R.color.widget_dyn_dark_on_tertiary),
      "tertiaryContainer" to Triple(R.color.widget_dyn_tertiary_container, R.color.widget_dyn_light_tertiary_container, R.color.widget_dyn_dark_tertiary_container),
      "onTertiaryContainer" to Triple(R.color.widget_dyn_on_tertiary_container, R.color.widget_dyn_light_on_tertiary_container, R.color.widget_dyn_dark_on_tertiary_container),
      "surface" to Triple(R.color.widget_dyn_surface, R.color.widget_dyn_light_surface, R.color.widget_dyn_dark_surface),
      "onSurface" to Triple(R.color.widget_dyn_on_surface, R.color.widget_dyn_light_on_surface, R.color.widget_dyn_dark_on_surface),
      "onSurfaceVariant" to Triple(R.color.widget_dyn_on_surface_variant, R.color.widget_dyn_light_on_surface_variant, R.color.widget_dyn_dark_on_surface_variant),
      "surfaceContainerLowest" to Triple(R.color.widget_dyn_surface_container_lowest, R.color.widget_dyn_light_surface_container_lowest, R.color.widget_dyn_dark_surface_container_lowest),
      "surfaceContainerLow" to Triple(R.color.widget_dyn_surface_container_low, R.color.widget_dyn_light_surface_container_low, R.color.widget_dyn_dark_surface_container_low),
      "surfaceContainer" to Triple(R.color.widget_dyn_surface_container, R.color.widget_dyn_light_surface_container, R.color.widget_dyn_dark_surface_container),
      "surfaceContainerHigh" to Triple(R.color.widget_dyn_surface_container_high, R.color.widget_dyn_light_surface_container_high, R.color.widget_dyn_dark_surface_container_high),
      "surfaceContainerHighest" to Triple(R.color.widget_dyn_surface_container_highest, R.color.widget_dyn_light_surface_container_highest, R.color.widget_dyn_dark_surface_container_highest),
      "outline" to Triple(R.color.widget_dyn_outline, R.color.widget_dyn_light_outline, R.color.widget_dyn_dark_outline),
      "outlineVariant" to Triple(R.color.widget_dyn_outline_variant, R.color.widget_dyn_light_outline_variant, R.color.widget_dyn_dark_outline_variant),
      "error" to Triple(R.color.widget_dyn_error, R.color.widget_dyn_light_error, R.color.widget_dyn_dark_error),
      "errorContainer" to Triple(R.color.widget_dyn_error_container, R.color.widget_dyn_light_error_container, R.color.widget_dyn_dark_error_container),
      "onErrorContainer" to Triple(R.color.widget_dyn_on_error_container, R.color.widget_dyn_light_on_error_container, R.color.widget_dyn_dark_on_error_container),
    )
}
