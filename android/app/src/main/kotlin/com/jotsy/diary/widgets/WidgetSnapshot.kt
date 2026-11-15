package com.jotsy.diary.widgets

import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Dart 写给桌面小组件的快照（home_widget_snapshot_builder.dart，字段说明见
 * docs/rules/home_widgets.md「快照」）。
 *
 * 全部字段容错读取：缺字段、类型不对都回到空值或默认，原生绝不因为快照有问题而让
 * 小组件崩掉——最坏是显示“打开 Jotsy 以更新”。比当前更高的版本号照常按认得的字段绘制。
 */
class WidgetSnapshot private constructor(private val root: JSONObject, val isEmpty: Boolean) {
  val locale: String = root.optString("locale", "zh")
  val redacted: Boolean = root.optBoolean("redacted", false)
  val displayFont: String? = root.optString("displayFont").ifEmpty { null }

  /** 写入时刻（毫秒）；比它新的乐观更新（[WidgetOverlay]）才覆盖快照里的值。 */
  val builtAt: Long = root.optLong("builtAt", 0L)

  private val palettes: JSONObject? = root.optJSONObject("palettes")
  private val strings: JSONObject? = root.optJSONObject("strings")
  private val icons: JSONObject? = root.optJSONObject("icons")
  private val instances: JSONObject? = root.optJSONObject("instances")
  private val defaults: JSONObject? = root.optJSONObject("defaults")

  /** 文案；快照里没有时用 [fallback]（通常是 Android 资源里的兜底文案）。 */
  fun string(key: String, fallback: String = ""): String =
    strings?.optString(key)?.ifEmpty { null } ?: fallback

  /**
   * 带数量的文案：按界面语言的复数规则给 [count] 挑类别（`android.icu.text.PluralRules`），
   * 取 Dart 导出的那一种写法（home_widget_plurals.dart），`%d` 换成数量。找不到该类别时
   * 退回 other。
   */
  fun plural(key: String, count: Long): String {
    val forms = root.optJSONObject("plurals")?.optJSONObject(key) ?: return count.toString()
    val category =
      try {
        android.icu.text.PluralRules.forLocale(java.util.Locale.forLanguageTag(locale))
          .select(count.toDouble())
      } catch (_: Exception) {
        "other"
      }
    val form = forms.optString(category).ifEmpty { forms.optString("other") }
    return form.replace("%d", count.toString())
  }

  /** 图标（字体族 + 码位），没有时为 null。 */
  fun icon(key: String): WidgetIconRef? {
    val node = icons?.optJSONObject(key) ?: return null
    val family = node.optString("f").ifEmpty { return null }
    val codePoint = node.optInt("c", 0)
    return if (codePoint == 0) null else WidgetIconRef(family, codePoint)
  }

  /** 某个配色的明暗两套色槽；没有时为 null。 */
  fun palette(key: String): WidgetPalettePair? =
    palettes?.optJSONObject(key)?.let { WidgetPalettePair.parse(it) }

  /** 一个数据节（如 `today`）；没有时为 null。 */
  fun section(name: String): JSONObject? = root.optJSONObject(name)

  /** 一个列表形式的数据节（如 `anniversaries`）；没有时为 null。 */
  fun array(name: String): org.json.JSONArray? = root.optJSONArray(name)

  /**
   * 某个实例的配置：快照里有这个实例就用它，否则用该种类的默认（刚放到桌面、应用还没
   * 同步过），再没有就是全默认。
   */
  fun instanceFor(appWidgetId: Int?, kind: String): WidgetInstance {
    val stored = appWidgetId?.let { instances?.optJSONObject(it.toString()) }
    if (stored != null && stored.optString("kind") == kind) return WidgetInstance.parse(stored)
    return defaults?.optJSONObject(kind)?.let { WidgetInstance.parse(it) }
      ?: WidgetInstance.fallback(kind)
  }

  /** 预览：把草稿里新选的配色并进来，其余照旧。 */
  fun withPalettes(extra: JSONObject?): WidgetSnapshot {
    if (extra == null || extra.length() == 0 || isEmpty) return this
    val copy = JSONObject(root.toString())
    val merged = copy.optJSONObject("palettes") ?: JSONObject().also { copy.put("palettes", it) }
    extra.keys().forEach { key -> merged.put(key, extra.get(key)) }
    return WidgetSnapshot(copy, false)
  }

  companion object {
    /** 快照在 `HomeWidgetPreferences` 里的键（Dart `kHomeWidgetSnapshotKey`）。 */
    const val KEY = "jotsy.widgets.snapshot"

    val EMPTY = WidgetSnapshot(JSONObject(), true)

    @Volatile private var cachedRaw: String? = null
    @Volatile private var cached: WidgetSnapshot = EMPTY

    /** 读最新的快照；原文没变时复用上次解析的结果（每次绘制都会读）。 */
    fun read(preferences: SharedPreferences): WidgetSnapshot {
      val raw = preferences.getString(KEY, null) ?: return EMPTY
      if (raw == cachedRaw) return cached
      val parsed =
        try {
          WidgetSnapshot(JSONObject(raw), false)
        } catch (_: Exception) {
          EMPTY
        }
      cachedRaw = raw
      cached = parsed
      return parsed
    }

    /** 预览用的示例快照（[WidgetPreviews]，Dart `buildHomeWidgetSampleSnapshot`）；没有时为 [EMPTY]。 */
    fun readSample(preferences: SharedPreferences): WidgetSnapshot {
      val raw = preferences.getString(WidgetPreviews.SAMPLE_KEY, null) ?: return EMPTY
      return try {
        WidgetSnapshot(JSONObject(raw), false)
      } catch (_: Exception) {
        EMPTY
      }
    }
  }
}

/** 一个图标：`FontManifest.json` 里的字体族键与码位。 */
data class WidgetIconRef(val family: String, val codePoint: Int)

/** 一个实例（或默认）的原生口径配置，见 home_widget_native_config.dart。 */
class WidgetInstance(
  val kind: String,
  val disabled: Boolean,
  val style: WidgetStyle,
  val content: JSONObject,
) {
  companion object {
    fun parse(node: JSONObject) =
      WidgetInstance(
        kind = node.optString("kind"),
        disabled = node.optBoolean("disabled", false),
        style = WidgetStyle.parse(node.optJSONObject("style")),
        content = node.optJSONObject("content") ?: JSONObject(),
      )

    fun fallback(kind: String) =
      WidgetInstance(kind, disabled = false, style = WidgetStyle.DEFAULT, content = JSONObject())
  }
}

/** 外观，见 home_widget_style.dart 的 `toNative`。 */
data class WidgetStyle(
  /** `app`、`wallpaper` 或 `seed:AARRGGBB`。 */
  val palette: String,
  /** `system`、`light` 或 `dark`。 */
  val brightness: String,
  /** `surface`、`tonal`、`vivid` 或 `clear`。 */
  val background: String,
  val opacity: Float,
  /** dp；小于 0 为跟随系统。 */
  val radius: Float,
  val textScale: Float,
  /** `compact`、`standard` 或 `roomy`。 */
  val density: String,
  /** `primary`、`secondary` 或 `tertiary`。 */
  val accent: String,
) {
  companion object {
    val DEFAULT = WidgetStyle("app", "system", "surface", 1f, -1f, 1f, "standard", "primary")

    fun parse(node: JSONObject?): WidgetStyle {
      if (node == null) return DEFAULT
      return WidgetStyle(
        palette = node.optString("palette", DEFAULT.palette),
        brightness = node.optString("brightness", DEFAULT.brightness),
        background = node.optString("background", DEFAULT.background),
        opacity = node.optDouble("opacity", 1.0).toFloat().coerceIn(0f, 1f),
        radius = node.optDouble("radius", -1.0).toFloat(),
        textScale = node.optDouble("textScale", 1.0).toFloat().coerceIn(0.5f, 2f),
        density = node.optString("density", DEFAULT.density),
        accent = node.optString("accent", DEFAULT.accent),
      )
    }
  }
}
