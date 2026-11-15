package com.jotsy.diary.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.LruCache
import kotlin.math.roundToInt

/**
 * 小组件上 Glance 画不了的图形，在原生按实际像素画成白色位图，再由 `ColorFilter.tint`
 * 着色（明暗、配色变化不必重画）。
 */
object WidgetBitmaps {
  private val cache =
    object : LruCache<String, Bitmap>(512 * 1024) {
      override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

  /**
   * 进度环：从 12 点顺时针画到 [fraction]（0–1），圆头。整圈（1）用作轨道。分 100 档缓存，
   * 同样的进度不重复画。
   */
  fun ring(context: Context, sizeDp: Float, strokeDp: Float, fraction: Float): Bitmap {
    val metrics = context.resources.displayMetrics
    val sizePx = (sizeDp * metrics.density).roundToInt().coerceIn(1, 512)
    val step = (fraction.coerceIn(0f, 1f) * 100).roundToInt()
    val key = "ring|$sizePx|$strokeDp|$step"
    cache.get(key)?.let { return it }
    val bitmap = Bitmap.createBitmap(metrics, sizePx, sizePx, Bitmap.Config.ARGB_8888)
    val stroke = strokeDp * metrics.density
    val paint =
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = if (step >= 100) Paint.Cap.BUTT else Paint.Cap.ROUND
      }
    val inset = stroke / 2f
    val bounds = RectF(inset, inset, sizePx - inset, sizePx - inset)
    if (step >= 100) {
      Canvas(bitmap).drawOval(bounds, paint)
    } else if (step > 0) {
      Canvas(bitmap).drawArc(bounds, -90f, 360f * step / 100f, false, paint)
    }
    cache.put(key, bitmap)
    return bitmap
  }
}
