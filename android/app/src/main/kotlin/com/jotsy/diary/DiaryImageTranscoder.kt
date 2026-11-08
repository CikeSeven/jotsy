package com.jotsy.diary

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.media.ExifInterface
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Re-encodes HEIF-family images (HEIC / HEIF / AVIF) as JPEG, and compresses stored images for
 * the storage manager.
 *
 * Phones save photos as HEIC and Android decodes them, but the desktop builds draw with Flutter's
 * own codecs, which only read JPEG / PNG / GIF / WebP / BMP. A HEIC picked into a diary on the
 * phone therefore shows as "image failed to load" once it reaches a desktop. Dart converts such
 * files here when they enter the app's managed directories and repairs older ones on startup.
 *
 * Decoding goes through [ImageDecoder] (API 28+), which applies the image's rotation, so the JPEG
 * is written upright and its EXIF orientation is reset to normal; capture time, camera and GPS
 * tags are carried over, matching what a JPEG picked from the gallery keeps. The source is only
 * read. Output goes to a temporary sibling that is renamed into place, so a crash never leaves a
 * truncated JPEG at [target]. One background thread does the work so two large photos never
 * compete for memory.
 *
 * `compress` is the same pipeline with a caller-chosen longest side and JPEG quality: the storage
 * manager writes the result to a new file next to the original and rewrites the diary references
 * itself, so the original is never touched here either.
 */
class DiaryImageTranscoder(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/image_transcode")
  private val executor: ExecutorService = Executors.newSingleThreadExecutor()
  private val jpegQuality = 92

  // Roughly a 48 MP sensor. Larger images are scaled down to this many pixels: a full-size
  // ARGB bitmap of a 200 MP photo would need 800 MB.
  private val maxPixels = 50_000_000L

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "toJpeg" -> encode(call.argument("source"), call.argument("target"), null, jpegQuality, result)
        "compress" -> encode(
          call.argument("source"),
          call.argument("target"),
          call.argument<Int>("maxSide"),
          (call.argument<Int>("quality") ?: jpegQuality).coerceIn(30, 100),
          result,
        )
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    executor.shutdown()
  }

  private fun encode(
    source: String?,
    target: String?,
    maxSide: Int?,
    quality: Int,
    result: MethodChannel.Result,
  ) {
    if (source.isNullOrBlank() || target.isNullOrBlank()) {
      result.error("invalid_arguments", "source and target are required.", null)
      return
    }
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
      result.error("unsupported", "Image decoding needs Android 9.", null)
      return
    }
    executor.execute {
      try {
        val size = toJpeg(File(source), File(target), maxSide, quality)
        activity.runOnUiThread { result.success(size) }
      } catch (error: Exception) {
        activity.runOnUiThread { result.error("transcode_failed", error.message, null) }
      } catch (error: OutOfMemoryError) {
        activity.runOnUiThread { result.error("transcode_failed", "Out of memory.", null) }
      }
    }
  }

  @RequiresApi(Build.VERSION_CODES.P)
  private fun toJpeg(source: File, target: File, maxSide: Int?, quality: Int): Map<String, Int> {
    if (!source.isFile) throw IllegalArgumentException("Source is missing.")
    val bitmap = try {
      decode(source, 1.0, maxSide)
    } catch (error: OutOfMemoryError) {
      // Retry once at half the size (a quarter of the memory) rather than failing outright.
      decode(source, 0.5, maxSide)
    }
    val width = bitmap.width
    val height = bitmap.height
    val staging = File(target.parentFile, "${target.name}.tmp-${System.nanoTime()}")
    try {
      try {
        FileOutputStream(staging).use { output ->
          if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)) {
            throw IllegalStateException("JPEG encode failed.")
          }
        }
      } finally {
        bitmap.recycle()
      }
      copyExif(source, staging)
      if (target.exists()) target.delete()
      if (!staging.renameTo(target)) throw IllegalStateException("Cannot move JPEG into place.")
    } catch (error: Throwable) {
      staging.delete()
      throw error
    }
    return mapOf("width" to width, "height" to height)
  }

  /** Decodes [source] upright, scaled down to [maxSide] on its longest side when given. */
  @RequiresApi(Build.VERSION_CODES.P)
  private fun decode(source: File, extraScale: Double, maxSide: Int?): Bitmap =
    ImageDecoder.decodeBitmap(ImageDecoder.createSource(source)) { decoder, info, _ ->
      // Hardware bitmaps cannot be compressed.
      decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
      // The reported size is already rotated, so scaling both sides keeps the aspect ratio.
      val width = info.size.width
      val height = info.size.height
      val pixels = width.toLong() * height
      var scale = if (pixels > maxPixels) sqrt(maxPixels.toDouble() / pixels) else 1.0
      val longest = max(width, height)
      if (maxSide != null && maxSide > 0 && longest > maxSide) {
        scale = minOf(scale, maxSide.toDouble() / longest)
      }
      scale *= extraScale
      if (scale < 1.0) {
        decoder.setTargetSize(
          max(1, (width * scale).roundToInt()),
          max(1, (height * scale).roundToInt()),
        )
      }
    }

  /** Best effort: a photo without its EXIF is still a usable photo. */
  private fun copyExif(source: File, jpeg: File) {
    try {
      val from = ExifInterface(source.path)
      val to = ExifInterface(jpeg.path)
      var copied = false
      for (tag in carriedTags) {
        val value = from.getAttribute(tag) ?: continue
        to.setAttribute(tag, value)
        copied = true
      }
      if (!copied) return
      // The pixels are already upright.
      to.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
      to.saveAttributes()
    } catch (error: Exception) {
      // Keep the JPEG as encoded.
    }
  }

  private val carriedTags = listOf(
    ExifInterface.TAG_DATETIME,
    ExifInterface.TAG_DATETIME_ORIGINAL,
    ExifInterface.TAG_DATETIME_DIGITIZED,
    ExifInterface.TAG_OFFSET_TIME,
    ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
    ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
    ExifInterface.TAG_SUBSEC_TIME,
    ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
    ExifInterface.TAG_SUBSEC_TIME_DIGITIZED,
    ExifInterface.TAG_MAKE,
    ExifInterface.TAG_MODEL,
    // The platform ExifInterface knows these tags but only androidx exposes constants for them.
    "LensMake",
    "LensModel",
    ExifInterface.TAG_EXPOSURE_TIME,
    ExifInterface.TAG_F_NUMBER,
    "PhotographicSensitivity",
    ExifInterface.TAG_FOCAL_LENGTH,
    ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
    ExifInterface.TAG_FLASH,
    ExifInterface.TAG_WHITE_BALANCE,
    ExifInterface.TAG_GPS_LATITUDE,
    ExifInterface.TAG_GPS_LATITUDE_REF,
    ExifInterface.TAG_GPS_LONGITUDE,
    ExifInterface.TAG_GPS_LONGITUDE_REF,
    ExifInterface.TAG_GPS_ALTITUDE,
    ExifInterface.TAG_GPS_ALTITUDE_REF,
    ExifInterface.TAG_GPS_TIMESTAMP,
    ExifInterface.TAG_GPS_DATESTAMP,
    ExifInterface.TAG_GPS_PROCESSING_METHOD,
    ExifInterface.TAG_GPS_IMG_DIRECTION,
    ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
  )
}
