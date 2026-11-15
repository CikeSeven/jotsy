package com.jotsy.diary.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.util.LruCache
import es.antonborri.home_widget.HomeWidgetFonts
import kotlin.math.roundToInt

/**
 * 用应用自带的字体画小组件上的图标与展示文字（Glance 只能用系统字体）。
 *
 * - 图标：FontAwesome 的字形，字体从 flutter_assets 读（[HomeWidgetFonts.typeface] 按
 *   `FontManifest.json` 找），与应用内的图标是同一个字形；
 * - 展示文字：大号日期数字等，用应用的 HarmonyOS Sans。
 *
 * 都画成白色位图，由 Glance 的 `ColorFilter.tint` 着色：颜色仍然跟着明暗与配色走，切深色
 * 不必重画位图。位图按设备像素密度画，清晰；按内容缓存，同一个字形不重复画。
 */
object WidgetGlyphs {
  /** 缓存上限（字节）：几十个图标与数字，远小于这个量。 */
  private val cache =
    object : LruCache<String, Bitmap>(4 * 1024 * 1024) {
      override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

  /** [ref] 的字形，边长 [sizeDp]；字体或字形读不到时为 null（调用方留出同样的空位）。 */
  fun icon(context: Context, ref: WidgetIconRef?, sizeDp: Float): Bitmap? {
    if (ref == null) return null
    val metrics = context.resources.displayMetrics
    val sizePx = (sizeDp * metrics.density).roundToInt().coerceIn(1, 1024)
    val key = "i|${ref.family}|${ref.codePoint}|$sizePx"
    cache.get(key)?.let { return it }
    val typeface = HomeWidgetFonts.typeface(context, ref.family) ?: return null
    val bitmap = Bitmap.createBitmap(metrics, sizePx, sizePx, Bitmap.Config.ARGB_8888)
    val paint =
      Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
        this.typeface = typeface
        textSize = sizePx.toFloat()
        color = Color.WHITE
      }
    val glyph = String(Character.toChars(ref.codePoint))
    // FontAwesome 有些字形比一个 em 宽（横向的图标）：按墨迹缩进方框，不裁切；再按
    // 墨迹居中（而不是按基线与步进宽度），视觉上才在正中。
    val ink = Rect()
    paint.getTextBounds(glyph, 0, glyph.length, ink)
    val inkSize = maxOf(ink.width(), ink.height())
    if (inkSize > sizePx) {
      paint.textSize = paint.textSize * sizePx / inkSize
      paint.getTextBounds(glyph, 0, glyph.length, ink)
    }
    val x = sizePx / 2f - (ink.left + ink.right) / 2f
    val y = sizePx / 2f - (ink.top + ink.bottom) / 2f
    Canvas(bitmap).drawText(glyph, x, y, paint)
    cache.put(key, bitmap)
    return bitmap
  }

  /** 用 [family] 的 [weight] 字重画一行 [text]（字号 sp，跟随系统字体缩放）。 */
  fun text(
    context: Context,
    family: String?,
    text: String,
    sizeSp: Float,
    weight: Int,
    maxWidthDp: Float,
  ): Bitmap {
    val scale = context.resources.configuration.fontScale
    val key = "t|$family|$weight|$sizeSp|$scale|${maxWidthDp.roundToInt()}|$text"
    cache.get(key)?.let { return it }
    val typeface = family?.let { HomeWidgetFonts.typeface(context, it, weight) }
    val bitmap =
      HomeWidgetFonts.textBitmap(
        context,
        typeface,
        text,
        fontSizeSp = sizeSp,
        maxLines = 1,
        maxWidthDp = maxWidthDp.coerceAtLeast(1f),
      )
    cache.put(key, bitmap)
    return bitmap
  }
}
