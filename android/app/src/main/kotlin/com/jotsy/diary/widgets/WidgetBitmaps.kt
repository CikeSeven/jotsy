package com.jotsy.diary.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.media.ExifInterface
import android.os.Build
import android.util.LruCache
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 小组件上 Glance 画不了的图形，在原生按实际像素画成白色位图，再由 `ColorFilter.tint`
 * 着色（明暗、配色变化不必重画）；以及日记照片的缩略图（[photo]）。
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

  /** 照片缩略图的长边上限（像素）：RemoteViews 里的位图要经 Binder 交给桌面，不能大。 */
  private const val PHOTO_MAX_SIDE = 640

  private val photos =
    object : LruCache<String, Bitmap>(6 * 1024 * 1024) {
      override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

  /**
   * 日记照片按 [widthDp] × [heightDp] 的比例居中裁切、缩到够用的像素（长边不超过
   * [PHOTO_MAX_SIDE]），EXIF 方向转正。Android 12+ 由 `cornerRadius` 裁圆角；更早的系统
   * 没有这个能力，直接把 [radiusDp] 的圆角画进位图。
   *
   * 文件读不到、解不出时返回 null（调用方按没有照片排版）。按路径、修改时间与尺寸缓存。
   */
  fun photo(context: Context, path: String, widthDp: Float, heightDp: Float, radiusDp: Float): Bitmap? {
    val file = File(path)
    if (!file.isFile) return null
    val density = context.resources.displayMetrics.density
    var width = (widthDp * density).roundToInt().coerceAtLeast(1)
    var height = (heightDp * density).roundToInt().coerceAtLeast(1)
    val scale = minOf(1f, PHOTO_MAX_SIDE.toFloat() / max(width, height))
    if (scale < 1f) {
      width = (width * scale).roundToInt().coerceAtLeast(1)
      height = (height * scale).roundToInt().coerceAtLeast(1)
    }
    val radiusPx = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) radiusDp * density * scale else 0f
    val key = "$path|${file.lastModified()}|$width|$height|$radiusPx"
    photos.get(key)?.let { return it }
    val source = decode(file, width, height) ?: return null
    val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    // 居中裁切：按较大的缩放比铺满目标，多出的一边两头裁掉。
    val fill = max(width.toFloat() / source.width, height.toFloat() / source.height)
    val matrix =
      Matrix().apply {
        setScale(fill, fill)
        postTranslate((width - source.width * fill) / 2f, (height - source.height * fill) / 2f)
      }
    val paint =
      Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        shader =
          BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            setLocalMatrix(matrix)
          }
      }
    Canvas(output).drawRoundRect(
      RectF(0f, 0f, width.toFloat(), height.toFloat()),
      radiusPx,
      radiusPx,
      paint,
    )
    source.recycle()
    photos.put(key, output)
    return output
  }

  /** 先只读尺寸挑采样率（解出来不小于目标即可），再解码并按 EXIF 方向转正。 */
  private fun decode(file: File, width: Int, height: Int): Bitmap? =
    try {
      val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
      BitmapFactory.decodeFile(file.path, bounds)
      if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        null
      } else {
        val rotation = rotationOf(file)
        // 转 90° 的照片，解出来的宽高与目标是对调的。
        val (targetW, targetH) = if (rotation % 180 == 0) width to height else height to width
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetW && bounds.outHeight / (sample * 2) >= targetH) {
          sample *= 2
        }
        val decoded =
          BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
        if (decoded == null || rotation == 0) {
          decoded
        } else {
          val rotated =
            Bitmap.createBitmap(
              decoded,
              0,
              0,
              decoded.width,
              decoded.height,
              Matrix().apply { postRotate(rotation.toFloat()) },
              true,
            )
          if (rotated !== decoded) decoded.recycle()
          rotated
        }
      }
    } catch (_: Exception) {
      null
    } catch (_: OutOfMemoryError) {
      null
    }

  private fun rotationOf(file: File): Int =
    try {
      val orientation =
        ExifInterface(file.path)
          .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
      when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> 90
        ExifInterface.ORIENTATION_ROTATE_180 -> 180
        ExifInterface.ORIENTATION_ROTATE_270 -> 270
        else -> 0
      }
    } catch (_: Exception) {
      0
    }
}
