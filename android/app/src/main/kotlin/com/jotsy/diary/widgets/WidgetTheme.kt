package com.jotsy.diary.widgets

import android.content.Context
import android.os.Build
import androidx.compose.ui.graphics.Color
import androidx.glance.color.ColorProvider
import androidx.glance.unit.ColorProvider
import org.json.JSONObject

/** 一个配色的明暗两套色槽（色槽名 → ARGB），见 home_widget_palette.dart。 */
class WidgetPalettePair(val light: Map<String, Int>, val dark: Map<String, Int>) {
  companion object {
    fun parse(node: JSONObject): WidgetPalettePair? {
      val light = roles(node.optJSONObject("light")) ?: return null
      val dark = roles(node.optJSONObject("dark")) ?: return null
      return WidgetPalettePair(light, dark)
    }

    private fun roles(node: JSONObject?): Map<String, Int>? {
      if (node == null) return null
      val map = HashMap<String, Int>()
      node.keys().forEach { key ->
        val value = node.optLong(key, Long.MIN_VALUE)
        if (value != Long.MIN_VALUE) map[key] = value.toInt()
      }
      return map.ifEmpty { null }
    }

    /**
     * 快照还没到时的兜底：应用默认主题色（海盐蓝）的几个关键色槽，与启动画面同一套
     * （values/colors.xml 的 launch_*）。
     */
    val FALLBACK =
      WidgetPalettePair(
        light =
          mapOf(
            "primary" to 0xFF1E6586.toInt(),
            "onPrimary" to 0xFFFFFFFF.toInt(),
            "primaryContainer" to 0xFFC3E8FF.toInt(),
            "onPrimaryContainer" to 0xFF001E2C.toInt(),
            "surfaceContainerLowest" to 0xFFFFFFFF.toInt(),
            "surfaceContainerHigh" to 0xFFE5E9ED.toInt(),
            "surfaceContainerHighest" to 0xFFDEE3E7.toInt(),
            "onSurface" to 0xFF171C1F.toInt(),
            "onSurfaceVariant" to 0xFF41484D.toInt(),
          ),
        dark =
          mapOf(
            "primary" to 0xFF90CEF4.toInt(),
            "onPrimary" to 0xFF003549.toInt(),
            "primaryContainer" to 0xFF004C68.toInt(),
            "onPrimaryContainer" to 0xFFC3E8FF.toInt(),
            "surfaceContainerLow" to 0xFF171C1F.toInt(),
            "surfaceContainerHigh" to 0xFF252B2E.toInt(),
            "surfaceContainerHighest" to 0xFF303539.toInt(),
            "onSurface" to 0xFFDEE3E7.toInt(),
            "onSurfaceVariant" to 0xFFC0C7CD.toInt(),
          ),
      )
  }
}

/**
 * 一个小组件实际用到的颜色（按外观的配色、明暗、底色、不透明度与强调色算好）。
 *
 * 明暗：跟随系统时每个颜色都是昼夜一对（Glance 在 Android 12+ 交给系统按当前明暗取，
 * 系统切深色不必重画）；固定浅色 / 深色时只取一套。跟随壁纸时用系统动态色资源
 * （[WidgetDynamicColors]），换壁纸后启动器重新解析，也不必重画——只有带透明度的颜色
 * 要读出当前值再乘透明度，这几项要等下一次重画才跟上新壁纸。
 *
 * 底色分四种，内容色随之配对：实色（与应用卡片同层）、色调（强调色的容器色）、浓郁
 * （强调色铺底、内容反白）、透明（直接放在壁纸上，没有底色）。
 */
class WidgetColors(
  /** 整块底色；透明时为 null。 */
  val background: ColorProvider?,
  val content: ColorProvider,
  val contentVariant: ColorProvider,
  /** 大数字、图标与主按钮的颜色。 */
  val accent: ColorProvider,
  val onAccent: ColorProvider,
  /** 次要按钮、色块的底色与其上的内容色。 */
  val tile: ColorProvider,
  val onTile: ColorProvider,
  /** 进度条的轨道、细分隔。 */
  val track: ColorProvider,
  /** 法定节假日“休 / 班”的小标签。 */
  val restTag: ColorProvider,
  val onRestTag: ColorProvider,
  val workTag: ColorProvider,
  val onWorkTag: ColorProvider,
  /**
   * 五档心情的整格底色与其上的前景色（由低到高），与应用日历的 `DayMoodColors` 同一套
   * 色槽：error / tertiary 容器、最高层容器、secondary / primary 容器。
   */
  val moodTiles: List<Pair<ColorProvider, ColorProvider>>,
) {
  companion object {
    fun resolve(context: Context, snapshot: WidgetSnapshot, style: WidgetStyle): WidgetColors {
      val source = roleSource(context, snapshot, style)
      val accent = style.accent
      val accentRole = accent
      val onAccentRole = "on" + accent.replaceFirstChar { it.uppercase() }
      val containerRole = accent + "Container"
      val onContainerRole = "on" + accent.replaceFirstChar { it.uppercase() } + "Container"
      val opacity = style.opacity
      val moods =
        listOf(
          "errorContainer" to "onErrorContainer",
          "tertiaryContainer" to "onTertiaryContainer",
          "surfaceContainerHighest" to "onSurfaceVariant",
          "secondaryContainer" to "onSecondaryContainer",
          "primaryContainer" to "onPrimaryContainer",
        ).map { (tile, on) -> source.color(tile) to source.color(on) }
      return when (style.background) {
        "tonal" ->
          WidgetColors(
            background = source.color(containerRole, alpha = opacity),
            content = source.color(onContainerRole),
            contentVariant = source.color(onContainerRole, alpha = 0.74f),
            accent = source.color(accentRole),
            onAccent = source.color(onAccentRole),
            tile = source.color("surfaceContainerLowest", alpha = 0.72f),
            onTile = source.color(onContainerRole),
            track = source.color(onContainerRole, alpha = 0.16f),
            restTag = source.color(accentRole),
            onRestTag = source.color(onAccentRole),
            workTag = source.color("surfaceContainerLowest", alpha = 0.72f),
            onWorkTag = source.color(onContainerRole),
            moodTiles = moods,
          )
        "vivid" ->
          WidgetColors(
            background = source.color(accentRole, alpha = opacity),
            content = source.color(onAccentRole),
            contentVariant = source.color(onAccentRole, alpha = 0.78f),
            accent = source.color(onAccentRole),
            onAccent = source.color(accentRole),
            tile = source.color(onAccentRole, alpha = 0.18f),
            onTile = source.color(onAccentRole),
            track = source.color(onAccentRole, alpha = 0.26f),
            restTag = source.color(onAccentRole),
            onRestTag = source.color(accentRole),
            workTag = source.color(onAccentRole, alpha = 0.22f),
            onWorkTag = source.color(onAccentRole),
            moodTiles = moods,
          )
        "clear" ->
          WidgetColors(
            background = null,
            content = source.color("onSurface"),
            contentVariant = source.color("onSurfaceVariant"),
            accent = source.color(accentRole),
            onAccent = source.color(onAccentRole),
            tile = source.color("surfaceContainerHigh", alpha = 0.7f),
            onTile = source.color("onSurface"),
            track = source.color("onSurface", alpha = 0.18f),
            restTag = source.color(containerRole),
            onRestTag = source.color(onContainerRole),
            workTag = source.color("surfaceContainerHighest", alpha = 0.8f),
            onWorkTag = source.color("onSurfaceVariant"),
            moodTiles = moods,
          )
        else ->
          WidgetColors(
            // 与应用卡片同一层：浅色 surfaceContainerLowest，深色 surfaceContainerLow。
            background = source.dayNight("surfaceContainerLowest", "surfaceContainerLow", opacity),
            content = source.color("onSurface"),
            contentVariant = source.color("onSurfaceVariant"),
            accent = source.color(accentRole),
            onAccent = source.color(onAccentRole),
            tile = source.color(containerRole),
            onTile = source.color(onContainerRole),
            track = source.color("surfaceContainerHighest"),
            restTag = source.color(containerRole),
            onRestTag = source.color(onContainerRole),
            workTag = source.color("surfaceContainerHighest"),
            onWorkTag = source.color("onSurfaceVariant"),
            moodTiles = moods,
          )
      }
    }

    private fun roleSource(
      context: Context,
      snapshot: WidgetSnapshot,
      style: WidgetStyle,
    ): RoleSource {
      if (style.palette == "wallpaper" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        return DynamicRoleSource(context, style.brightness)
      }
      val palette =
        snapshot.palette(style.palette.takeIf { it != "wallpaper" } ?: "app")
          ?: snapshot.palette("app")
          ?: WidgetPalettePair.FALLBACK
      return StaticRoleSource(palette, style.brightness)
    }
  }
}

/** 按色槽名取颜色。 */
private interface RoleSource {
  fun color(role: String, alpha: Float = 1f): ColorProvider

  /** 浅色与深色取不同色槽（实色底：浅色 lowest、深色 low）。 */
  fun dayNight(lightRole: String, darkRole: String, alpha: Float): ColorProvider
}

/** 快照导出的配色（应用主题色或自选种子色）。 */
private class StaticRoleSource(
  private val palette: WidgetPalettePair,
  private val brightness: String,
) : RoleSource {
  private fun light(role: String) =
    palette.light[role] ?: WidgetPalettePair.FALLBACK.light[role] ?: 0xFF000000.toInt()

  private fun dark(role: String) =
    palette.dark[role] ?: WidgetPalettePair.FALLBACK.dark[role] ?: 0xFFFFFFFF.toInt()

  override fun color(role: String, alpha: Float) = dayNight(role, role, alpha)

  override fun dayNight(lightRole: String, darkRole: String, alpha: Float): ColorProvider {
    val day = withAlpha(light(lightRole), alpha)
    val night = withAlpha(dark(darkRole), alpha)
    return when (brightness) {
      "light" -> ColorProvider(day)
      "dark" -> ColorProvider(night)
      else -> ColorProvider(day = day, night = night)
    }
  }
}

/** 系统动态色（跟随壁纸，Android 12+）。 */
private class DynamicRoleSource(
  private val context: Context,
  private val brightness: String,
) : RoleSource {
  override fun color(role: String, alpha: Float) = dayNight(role, role, alpha)

  override fun dayNight(lightRole: String, darkRole: String, alpha: Float): ColorProvider {
    val light = WidgetDynamicColors.ROLES[lightRole] ?: WidgetDynamicColors.ROLES.getValue("onSurface")
    val dark = WidgetDynamicColors.ROLES[darkRole] ?: WidgetDynamicColors.ROLES.getValue("onSurface")
    if (alpha >= 1f && lightRole == darkRole) {
      // 资源本身随明暗切换，启动器展开时解析：换壁纸、切深色都不必重画。
      return when (brightness) {
        "light" -> ColorProvider(light.second)
        "dark" -> ColorProvider(dark.third)
        else -> ColorProvider(light.first)
      }
    }
    // 带透明度（或明暗取不同色槽）时只能读出此刻的值再组合。
    val day = withAlpha(context.getColor(light.second), alpha)
    val night = withAlpha(context.getColor(dark.third), alpha)
    return when (brightness) {
      "light" -> ColorProvider(day)
      "dark" -> ColorProvider(night)
      else -> ColorProvider(day = day, night = night)
    }
  }
}

private fun withAlpha(argb: Int, alpha: Float): Color {
  val base = Color(argb)
  return if (alpha >= 1f) base else base.copy(alpha = base.alpha * alpha.coerceIn(0f, 1f))
}
