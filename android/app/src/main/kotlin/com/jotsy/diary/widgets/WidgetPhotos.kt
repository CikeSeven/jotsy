package com.jotsy.diary.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
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
 * 小组件上的日记照片：在应用进程里解码、按区域比例居中裁切、缩到够用的像素（RemoteViews
 * 里的位图要经 Binder 交给桌面），不把文件交给桌面进程。预览里的示例照片（`sample:` 路径）
 * 按名字现画。
 */
object WidgetPhotos {
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
  fun load(context: Context, path: String, widthDp: Float, heightDp: Float, radiusDp: Float): Bitmap? {
    if (path.startsWith(SAMPLE_PHOTO)) {
      return samplePhoto(context, path.removePrefix(SAMPLE_PHOTO), widthDp, heightDp, radiusDp)
    }
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

  /** 示例照片的路径前缀（Dart `kHomeWidgetSamplePhotoScheme`）：预览里的示例日记用。 */
  private const val SAMPLE_PHOTO = "sample:"

  /**
   * 预览用的示例“照片”：几块平涂色拼成的小风景（海边黄昏、晨跑的山坡、书店的书架），
   * 不是真的照片文件。圆角规则同 [photo]。
   */
  private fun samplePhoto(
    context: Context,
    name: String,
    widthDp: Float,
    heightDp: Float,
    radiusDp: Float,
  ): Bitmap {
    val density = context.resources.displayMetrics.density
    val scale = minOf(1f, PHOTO_MAX_SIDE / (max(widthDp, heightDp) * density))
    val width = (widthDp * density * scale).roundToInt().coerceAtLeast(1)
    val height = (heightDp * density * scale).roundToInt().coerceAtLeast(1)
    val radius = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) radiusDp * density * scale else 0f
    val key = "sample|$name|$width|$height|$radius"
    photos.get(key)?.let { return it }
    val scene = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(scene)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val w = width.toFloat()
    val h = height.toFloat()
    fun band(color: Long, top: Float, bottom: Float) {
      paint.color = color.toInt()
      canvas.drawRect(0f, top * h, w, bottom * h, paint)
    }
    fun circle(color: Long, x: Float, y: Float, r: Float) {
      paint.color = color.toInt()
      canvas.drawCircle(x * w, y * h, r * minOf(w, h), paint)
    }
    when (name) {
      "run" -> {
        band(0xFFBFE3F2, 0f, 1f)
        circle(0xFFFFF1C9, 0.78f, 0.2f, 0.09f)
        paint.color = 0xFF8DBB7A.toInt()
        canvas.drawOval(-0.3f * w, 0.45f * h, 0.8f * w, 1.4f * h, paint)
        paint.color = 0xFF5E9460.toInt()
        canvas.drawOval(0.25f * w, 0.55f * h, 1.4f * w, 1.5f * h, paint)
      }
      "books" -> {
        band(0xFF6E4A35, 0f, 1f)
        val colors = longArrayOf(0xFFE3B35B, 0xFFB9553F, 0xFF4F7A8C, 0xFFE9D9B8, 0xFF7C9A5E, 0xFFC97D4E)
        for (shelf in 0 until 3) {
          val top = 0.06f + shelf * 0.32f
          var x = 0.05f
          var index = shelf
          while (x < 0.95f) {
            val bookW = 0.05f + (index % 3) * 0.02f
            paint.color = colors[index % colors.size].toInt()
            canvas.drawRect(x * w, (top + (index % 2) * 0.03f) * h, (x + bookW) * w, (top + 0.26f) * h, paint)
            x += bookW + 0.012f
            index += 1
          }
          band(0xFF4A3021, top + 0.26f, top + 0.3f)
        }
      }
      else -> {
        band(0xFFF4B47A, 0f, 0.58f)
        circle(0xFFFFE8B8, 0.68f, 0.42f, 0.12f)
        band(0xFF3E6E96, 0.55f, 0.8f)
        band(0xFFE6D2A8, 0.8f, 1f)
      }
    }
    val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    Canvas(output).drawRoundRect(
      RectF(0f, 0f, w, h),
      radius,
      radius,
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = BitmapShader(scene, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
      },
    )
    scene.recycle()
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
