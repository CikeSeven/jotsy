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
 * 小组件上 Glance 画不了的图形（进度环、热力图），在原生按实际像素画成白色位图，再由
 * `ColorFilter.tint` 着色（明暗、配色变化不必重画）。日记照片见 [WidgetPhotos]。
 */
object WidgetBitmaps {
  private val cache =
    object : LruCache<String, Bitmap>(3 * 1024 * 1024) {
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

  /** 热力图四档的不透明度（与探索页热力图一致）。 */
  private val HEAT_ALPHAS = floatArrayOf(0.3f, 0.5f, 0.72f, 1f)

  /**
   * 写作热力图的一层：[columns] 周 × 7 天的圆角小方格，白色，由调用方着色后叠放。
   * [levels] 为每格的档位（0–4，按列从上到下、从左到右；-1 为不画，即今天之后的日子）。
   * [track] 为 true 时画轨道层（没写的日子，档位 0，着轨道色），否则画档位层（1–4 按
   * [HEAT_ALPHAS] 的不透明度，着强调色）。两层互不重叠：写过的格子直接落在小组件底色上，
   * 浅档不会被轨道色染灰，浓郁底上也分得出档位。
   */
  fun heatmap(
    context: Context,
    levels: IntArray,
    columns: Int,
    cellDp: Float,
    gapDp: Float,
    track: Boolean,
  ): Bitmap {
    val density = context.resources.displayMetrics.density
    val cell = cellDp * density
    val gap = gapDp * density
    val width = (columns * cell + (columns - 1) * gap).roundToInt().coerceAtLeast(1)
    val height = (7 * cell + 6 * gap).roundToInt().coerceAtLeast(1)
    val key = "heat|${levels.contentHashCode()}|$columns|$cellDp|$gapDp|$track|$density"
    cache.get(key)?.let { return it }
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    val radius = cell * 0.28f
    for (index in levels.indices) {
      val level = levels[index]
      if (level < 0) continue
      if (track != (level == 0)) continue
      val alpha = if (track) 1f else HEAT_ALPHAS[(level - 1).coerceIn(0, 3)]
      paint.alpha = (alpha * 255).roundToInt()
      val column = index / 7
      val row = index % 7
      val left = column * (cell + gap)
      val top = row * (cell + gap)
      canvas.drawRoundRect(RectF(left, top, left + cell, top + cell), radius, radius, paint)
    }
    cache.put(key, bitmap)
    return bitmap
  }
}
