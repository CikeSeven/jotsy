package com.jotsy.diary

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Selects videos through the system photo picker or Storage Access Framework. These
 * contracts grant access to the selected URIs without permission to read the video library;
 * forcing an OEM ACTION_PICK gallery does not provide the same reliable grant contract.
 * Copies URI streams off the UI thread before returning paths to Flutter. All picker-result
 * parsing and provider failures must become channel errors, never uncaught Android callbacks.
 */
class DiaryGalleryVideoPicker(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/video_gallery")
  private val requestCode = 7622
  private var pendingResult: MethodChannel.Result? = null
  private var copying = false
  @Volatile private var disposed = false

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "pickVideos" -> pickVideos(result)
        else -> result.notImplemented()
      }
    }
  }

  private fun pickVideos(result: MethodChannel.Result) {
    if (disposed) {
      result.success(null)
      return
    }
    if (pendingResult != null) {
      result.error("already_active", "Video gallery is already active.", null)
      return
    }
    pendingResult = result
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val intent = Intent(MediaStore.ACTION_PICK_IMAGES).apply {
          type = "video/*"
          putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, MediaStore.getPickImagesMaxLimit())
          addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
          activity.startActivityForResult(intent, requestCode)
          return
        } catch (_: ActivityNotFoundException) {
          // Some Android distributions omit/disable the photo picker module.
        } catch (_: SecurityException) {
          // A restricted picker must not prevent using the system documents UI.
        }
      }
      activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = "video/*"
        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      }, requestCode)
    } catch (error: SecurityException) {
      fail(result, "permission_denied", error)
    } catch (error: Exception) {
      fail(result, "gallery_unavailable", error)
    }
  }

  fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
    if (code != requestCode) return false
    val result = pendingResult ?: return true
    if (copying) return true
    if (resultCode != Activity.RESULT_OK) {
      pendingResult = null
      result.success(null)
      return true
    }

    try {
      // Intent/ClipData are supplied by another app. Even reading these fields
      // can throw while Android unparcels a malformed result, before any I/O starts.
      val uris = mutableListOf<Uri>()
      data?.clipData?.let { clipData ->
        for (index in 0 until clipData.itemCount) {
          clipData.getItemAt(index).uri?.let(uris::add)
        }
      }
      data?.data?.let(uris::add)
      if (uris.isEmpty()) {
        throw IOException("Picker returned no video URI.")
      }
      copying = true
      cacheVideos(uris.distinct(), result)
    } catch (error: SecurityException) {
      fail(result, "permission_denied", error)
    } catch (error: Exception) {
      fail(result, "video_copy_failed", error)
    }
    return true
  }

  private fun cacheVideos(uris: List<Uri>, result: MethodChannel.Result) {
    val context = activity.applicationContext
    Thread {
      var batch: File? = null
      try {
        val cacheRoot = File(context.cacheDir, "diary_video_gallery")
        if (!cacheRoot.isDirectory && !cacheRoot.mkdirs()) {
          throw IOException("Cannot create video cache directory.")
        }
        val directory = File.createTempFile("selection_", "", cacheRoot)
        batch = directory
        if (!directory.delete() || !directory.mkdir()) {
          throw IOException("Cannot create video selection directory.")
        }
        val files = uris.mapIndexed { index, uri ->
          if (disposed) throw IOException("Gallery request was cancelled.")
          var name: String? = null
          try {
            context.contentResolver.query(
              uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
            )?.use { cursor ->
              val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
              if (column >= 0 && cursor.moveToFirst()) name = cursor.getString(column)
            }
          } catch (_: Exception) {
            // Some providers permit reading the stream but not querying metadata.
            // A missing display name must not turn an otherwise readable video into a failure.
          }
          val child = File(directory, index.toString())
          if (!child.mkdir()) throw IOException("Cannot create video cache target.")
          val file = File(child, safeName(name))
          val input = context.contentResolver.openInputStream(uri)
            ?: throw IOException("Cannot read selected video.")
          input.use { source ->
            file.outputStream().use { output ->
              val buffer = ByteArray(64 * 1024)
              while (true) {
                if (disposed) throw IOException("Gallery request was cancelled.")
                val read = source.read(buffer)
                if (read < 0) break
                output.write(buffer, 0, read)
              }
              output.flush()
            }
          }
          mapOf("name" to (name ?: file.name), "path" to file.path, "size" to file.length())
        }
        activity.runOnUiThread {
          if (disposed || pendingResult !== result) {
            Thread { discard(directory) }.start()
          } else {
            copying = false
            pendingResult = null
            result.success(files)
          }
        }
      } catch (error: Exception) {
        // Cleanup must not mask the original permission/I/O error or throw out
        // of this worker thread and terminate the process.
        discard(batch)
        activity.runOnUiThread {
          fail(result, if (error is SecurityException) "permission_denied" else "video_copy_failed", error)
        }
      }
    }.start()
  }

  private fun fail(result: MethodChannel.Result, code: String, error: Exception) {
    Log.w("DiaryVideoPicker", code, error)
    if (disposed || pendingResult !== result) return
    copying = false
    pendingResult = null
    result.error(code, error.message, null)
  }

  private fun discard(directory: File?) {
    try {
      directory?.deleteRecursively()
    } catch (error: Exception) {
      Log.w("DiaryVideoPicker", "Could not discard video picker cache.", error)
    }
  }

  private fun safeName(raw: String?): String {
    var name = raw.orEmpty().replace('\\', '/').substringAfterLast('/')
      .replace(Regex("[<>:\"/\\\\|?*\\x00-\\x1F]"), "_").trim()
    if (name.isEmpty() || name == "." || name == "..") return "video.mp4"
    // Leave room for UTF-8 filenames while preserving a video decoder's extension.
    val extension = name.substringAfterLast('.', "").let { if (it.isEmpty()) "" else ".$it" }
    var stem = if (extension.isEmpty()) name else name.dropLast(extension.length)
    while ((stem + extension).toByteArray(Charsets.UTF_8).size > 240 && stem.isNotEmpty()) {
      stem = stem.dropLast(1)
    }
    name = stem + extension
    return if (name.toByteArray(Charsets.UTF_8).size <= 240) name else "video.mp4"
  }

  fun dispose() {
    disposed = true
    channel.setMethodCallHandler(null)
    pendingResult?.success(null)
    pendingResult = null
  }
}
