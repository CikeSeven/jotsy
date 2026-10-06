package com.jotsy.diary

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Matches file_picker's image ACTION_PICK gallery route for video-only multi-selection.
 * URI permissions last only for the picker result, so cache streams off the UI thread
 * before returning file paths. Flutter owns copying those files into diary storage.
 */
class DiaryGalleryVideoPicker(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/video_gallery")
  private val requestCode = 7622
  private var pendingResult: MethodChannel.Result? = null
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
    val intent = Intent(Intent.ACTION_PICK).apply {
      setDataAndType(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "video/*")
      putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
      putExtra("multi-pick", true)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    pendingResult = result
    try {
      // Android stores separate defaults for image/* and video/*. Reuse the
      // image picker's gallery package when it also supports video selection,
      // otherwise prefer the system's APP_GALLERY before leaving resolution to Android.
      val imageIntent = Intent(Intent.ACTION_PICK).apply {
        setDataAndType(Uri.parse(Environment.getExternalStorageDirectory().path + "/"), "image/*")
      }
      val packages = listOfNotNull(
        activity.packageManager.resolveActivity(
          imageIntent, PackageManager.MATCH_DEFAULT_ONLY,
        )?.activityInfo?.packageName,
        activity.packageManager.resolveActivity(
          Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_GALLERY),
          PackageManager.MATCH_DEFAULT_ONLY,
        )?.activityInfo?.packageName,
      )
      val handlers = activity.packageManager.queryIntentActivities(
        intent, PackageManager.MATCH_DEFAULT_ONLY,
      ).map { it.activityInfo.packageName }
      packages.firstOrNull { it in handlers }?.let(intent::setPackage)
      activity.startActivityForResult(intent, requestCode)
    } catch (error: Exception) {
      pendingResult = null
      result.error("gallery_unavailable", error.message, null)
    }
  }

  fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
    if (code != requestCode) return false
    val result = pendingResult ?: return true
    if (resultCode != Activity.RESULT_OK) {
      pendingResult = null
      result.success(null)
      return true
    }

    val uris = mutableListOf<Uri>()
    val clipData = data?.clipData
    if (clipData != null) {
      for (index in 0 until clipData.itemCount) {
        uris.add(clipData.getItemAt(index).uri)
      }
    } else {
      data?.data?.let(uris::add)
    }
    if (uris.isEmpty()) {
      pendingResult = null
      result.error("missing_video", "Gallery returned no video URI.", null)
      return true
    }

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
        val files = uris.distinct().mapIndexed { index, uri ->
          if (disposed) throw IOException("Gallery request was cancelled.")
          var name: String? = null
          context.contentResolver.query(
            uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
          )?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) name = cursor.getString(column)
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
            Thread { directory.deleteRecursively() }.start()
          } else {
            pendingResult = null
            result.success(files)
          }
        }
      } catch (error: Exception) {
        batch?.deleteRecursively()
        activity.runOnUiThread {
          if (!disposed && pendingResult === result) {
            pendingResult = null
            result.error("video_copy_failed", error.message, null)
          }
        }
      }
    }.start()
    return true
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
