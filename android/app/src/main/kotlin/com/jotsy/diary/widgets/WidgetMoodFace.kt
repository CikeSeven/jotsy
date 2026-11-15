package com.jotsy.diary.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.LruCache
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * 这天的心情的五张脸，画法逐笔移植自应用里的 `DayMoodFace`（lib/ui/calendar/widgets/
 * day_mood_face.dart）：只画五官、没有外圈，最低一档张嘴大哭带泪。改动那边的画法须同步
 * 这里。
 *
 * 画成白色位图，由 Glance 的 `ColorFilter.tint` 着色（选中时为心情色上的前景色，否则为
 * 次要文字色），明暗与配色变化不必重画。按心情与像素大小缓存。
 */
object WidgetMoodFace {
  /** 由低到高，与 Dart 的 `DayMood` 枚举名一致。 */
  val MOODS = listOf("awful", "bad", "meh", "good", "great")

  private val cache =
    object : LruCache<String, Bitmap>(512 * 1024) {
      override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

  private const val EYE_X = 0.41f
  private const val EYE_RADIUS = 0.14f
  private const val STROKE = 0.16f
  private const val SCALE = 1.25f

  fun bitmap(context: Context, mood: String, sizeDp: Float): Bitmap {
    val metrics = context.resources.displayMetrics
    val sizePx = (sizeDp * metrics.density).roundToInt().coerceIn(1, 512)
    val key = "$mood|$sizePx"
    cache.get(key)?.let { return it }
    val bitmap = Bitmap.createBitmap(metrics, sizePx, sizePx, Bitmap.Config.ARGB_8888)
    draw(Canvas(bitmap), mood, sizePx.toFloat())
    cache.put(key, bitmap)
    return bitmap
  }

  private fun draw(canvas: Canvas, mood: String, size: Float) {
    val r = min(size, size) / 2f * SCALE
    val cx = size / 2f
    val cy = size / 2f - 0.05f * r
    fun x(v: Float) = cx + v * r
    fun y(v: Float) = cy + v * r
    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    val stroke =
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        strokeWidth = STROKE * r
      }

    // 一条二次曲线：起点、控制点、终点（与 Dart 的 curve 同参数）。
    fun curve(x1: Float, y1: Float, cx1: Float, cy1: Float, x2: Float, y2: Float) =
      Path().apply {
        moveTo(x(x1), y(y1))
        quadTo(x(cx1), y(cy1), x(x2), y(y2))
      }

    fun dotEyes(eyeY: Float = -0.2f) {
      canvas.drawCircle(x(-EYE_X), y(eyeY), EYE_RADIUS * r, fill)
      canvas.drawCircle(x(EYE_X), y(eyeY), EYE_RADIUS * r, fill)
    }

    when (mood) {
      "great" -> {
        for (side in listOf(-1f, 1f)) {
          val ex = side * EYE_X
          canvas.drawPath(curve(ex - 0.15f, -0.14f, ex, -0.5f, ex + 0.15f, -0.14f), stroke)
        }
        canvas.drawPath(curve(-0.5f, 0.16f, 0f, 0.82f, 0.5f, 0.16f), stroke)
      }
      "good" -> {
        dotEyes()
        canvas.drawPath(curve(-0.46f, 0.23f, 0f, 0.71f, 0.46f, 0.23f), stroke)
      }
      "meh" -> {
        dotEyes()
        canvas.drawLine(x(-0.34f), y(0.39f), x(0.34f), y(0.39f), stroke)
      }
      "bad" -> {
        dotEyes(-0.14f)
        canvas.drawPath(curve(-0.41f, 0.53f, 0f, 0.16f, 0.41f, 0.53f), stroke)
      }
      else -> {
        // 八字眉 + 哭得闭上的眼睛 + 张嘴 + 一滴泪。
        for (side in listOf(-1f, 1f)) {
          val ex = side * EYE_X
          stroke.strokeWidth = 0.13f * r
          canvas.drawLine(x(side * 0.62f), y(-0.41f), x(side * 0.23f), y(-0.575f), stroke)
          stroke.strokeWidth = 0.14f * r
          canvas.drawPath(curve(ex - 0.17f, -0.18f, ex, 0.07f, ex + 0.17f, -0.18f), stroke)
        }
        val mouth = curve(-0.35f, 0.69f, 0f, 0.115f, 0.35f, 0.69f).apply { close() }
        canvas.drawPath(mouth, fill)
        canvas.drawPath(
          mouth,
          Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeJoin = Paint.Join.ROUND
            strokeWidth = 0.09f * r
          },
        )
        val tear =
          curve(0.48f, 0.07f, 0.67f, 0.37f, 0.48f, 0.41f).apply {
            quadTo(x(0.3f), y(0.37f), x(0.48f), y(0.07f))
          }
        canvas.drawPath(tear, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(191, 255, 255, 255) })
      }
    }
  }
}
