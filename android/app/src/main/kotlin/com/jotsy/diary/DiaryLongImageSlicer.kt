package com.jotsy.diary

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Rect
import android.media.ExifInterface
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

/**
 * Cuts a tall image into full-width horizontal tiles so Flutter never has to decode it in one
 * piece. Impeller clamps a decoded image's width and height to the GPU's max texture size
 * separately, which squashes long screenshots; tiles stay far below that limit and the app only
 * decodes the ones on screen.
 *
 * Tiles overlap the next one by [overlap] source pixels so the seams never show a hairline gap
 * when they land on fractional positions. The original file is only read. Tiles go to a temporary
 * directory that is renamed into place after manifest.json is written, so Dart treats a directory
 * with a manifest as complete. One background thread does all slicing, so two requests for the
 * same image (Dart already merges them) or for different images never compete for memory.
 */
class DiaryLongImageSlicer(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/long_image")
  private val executor: ExecutorService = Executors.newSingleThreadExecutor()
  private val overlap = 2
  private val jpegQuality = 92

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "sliceTall" -> {
          val source = call.argument<String>("source")
          val outDir = call.argument<String>("outDir")
          val tileHeight = call.argument<Int>("tileHeight") ?: 0
          if (source.isNullOrBlank() || outDir.isNullOrBlank() || tileHeight <= 0) {
            result.error("invalid_arguments", "source, outDir and tileHeight are required.", null)
          } else {
            executor.execute {
              try {
                val manifest = slice(File(source), File(outDir), tileHeight)
                activity.runOnUiThread { result.success(manifest) }
              } catch (error: Exception) {
                activity.runOnUiThread { result.error("slice_failed", error.message, null) }
              } catch (error: OutOfMemoryError) {
                activity.runOnUiThread { result.error("slice_failed", "Out of memory.", null) }
              }
            }
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    executor.shutdown()
  }

  private fun slice(source: File, outDir: File, tileHeight: Int): Map<String, Any> {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(source.path, bounds)
    val width = bounds.outWidth
    val height = bounds.outHeight
    if (width <= 0 || height <= 0) {
      throw IllegalArgumentException("Unsupported image.")
    }
    // BitmapRegionDecoder ignores EXIF orientation while Flutter honours it, so rotated images
    // would come out sideways; Dart falls back to decoding those whole.
    if (isRotated(source)) {
      throw IllegalArgumentException("Rotated images are not sliced.")
    }
    val lossless = bounds.outMimeType == "image/png" || bounds.outMimeType == "image/webp"
    val format = if (lossless) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
    val extension = if (lossless) "png" else "jpg"

    val parent = outDir.parentFile ?: throw IllegalArgumentException("Invalid output directory.")
    parent.mkdirs()
    val staging = File(parent, "${outDir.name}.tmp-${System.nanoTime()}")
    staging.mkdirs()
    val decoder = newRegionDecoder(source)
    val tiles = JSONArray()
    try {
      // ARGB_8888 even for JPEG: RGB_565 bands the flat backgrounds of screenshots.
      val options = BitmapFactory.Options().apply {
        inPreferredConfig = Bitmap.Config.ARGB_8888
      }
      var top = 0
      var index = 0
      while (top < height) {
        val bottom = minOf(height, top + tileHeight + overlap)
        val bitmap = decoder.decodeRegion(Rect(0, top, width, bottom), options)
          ?: throw IllegalStateException("Region decode failed.")
        val name = "$index.$extension"
        try {
          FileOutputStream(File(staging, name)).use { output ->
            if (!bitmap.compress(format, jpegQuality, output)) {
              throw IllegalStateException("Tile encode failed.")
            }
          }
        } finally {
          bitmap.recycle()
        }
        tiles.put(
          JSONObject()
            .put("file", name)
            .put("top", top)
            .put("height", bottom - top),
        )
        top += tileHeight
        index += 1
      }
    } catch (error: Throwable) {
      staging.deleteRecursively()
      throw error
    } finally {
      decoder.recycle()
    }

    val manifest = JSONObject()
      .put("version", 1)
      .put("source", source.path)
      .put("width", width)
      .put("height", height)
      .put("tiles", tiles)
    File(staging, "manifest.json").writeText(manifest.toString())
    outDir.deleteRecursively()
    if (!staging.renameTo(outDir)) {
      staging.deleteRecursively()
      throw IllegalStateException("Cannot move tiles into place.")
    }

    val tileList = ArrayList<Map<String, Any>>(tiles.length())
    for (i in 0 until tiles.length()) {
      val tile = tiles.getJSONObject(i)
      tileList.add(
        mapOf(
          "file" to tile.getString("file"),
          "top" to tile.getInt("top"),
          "height" to tile.getInt("height"),
        ),
      )
    }
    return mapOf("width" to width, "height" to height, "tiles" to tileList)
  }

  private fun isRotated(source: File): Boolean {
    return try {
      val orientation = ExifInterface(source.path).getAttributeInt(
        ExifInterface.TAG_ORIENTATION,
        ExifInterface.ORIENTATION_NORMAL,
      )
      orientation != ExifInterface.ORIENTATION_NORMAL &&
        orientation != ExifInterface.ORIENTATION_UNDEFINED
    } catch (error: Exception) {
      false
    }
  }

  @Suppress("DEPRECATION")
  private fun newRegionDecoder(source: File): BitmapRegionDecoder {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      BitmapRegionDecoder.newInstance(source.path)
    } else {
      BitmapRegionDecoder.newInstance(source.path, false)
    } ?: throw IllegalArgumentException("Unsupported image.")
  }
}
