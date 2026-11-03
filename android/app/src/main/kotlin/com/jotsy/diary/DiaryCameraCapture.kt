package com.jotsy.diary

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/** Separate class so it does not clash with the plugins' own FileProvider entries in the merged manifest. */
class DiaryCameraFileProvider : FileProvider()

/**
 * Takes one photo or video with the system camera app for the diary editor
 * (channel `com.jotsy.diary/camera_capture`, method `capture` with `kind` = `image` | `video`).
 *
 * - Output: the camera app writes straight into cacheDir/diary_camera/<batch>/, the only directory
 *   [DiaryCameraFileProvider] exposes, through a write grant on that one URI. Nothing is added to
 *   the system gallery; Dart copies the file into the diary's private media directory and then
 *   discards this copy (DiaryMediaStorageService.discardPickerCopy).
 * - Permission: the manifest declares CAMERA (for QR scanning), and Android then refuses
 *   ACTION_IMAGE_CAPTURE / ACTION_VIDEO_CAPTURE from apps that hold it ungranted, so it is
 *   requested first. A refusal becomes `camera_permission_denied`.
 * - Results: cancelled → null; captured → a single `{name, path, size}` entry. Camera apps that
 *   ignore EXTRA_OUTPUT for video and return their own content URI are copied into the batch file
 *   off the UI thread. No camera app → `camera_unavailable`; anything else → `capture_failed`.
 * - A process killed while the camera is open loses the pending call; its batch is left behind
 *   and removed when the next capture starts (only one capture can be pending at a time, and the
 *   Dart side finishes with a file before it can start another).
 */
class DiaryCameraCapture(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private class Pending(val result: MethodChannel.Result, val video: Boolean) {
    var file: File? = null
  }

  private val channel = MethodChannel(messenger, "com.jotsy.diary/camera_capture")
  private val captureRequestCode = 7623
  private val permissionRequestCode = 7624
  private var pending: Pending? = null
  private var copying = false
  @Volatile private var disposed = false

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "capture" -> capture(call.argument<String>("kind"), result)
        else -> result.notImplemented()
      }
    }
  }

  private fun capture(kind: String?, result: MethodChannel.Result) {
    if (disposed) {
      result.success(null)
      return
    }
    if (kind != "image" && kind != "video") {
      result.error("invalid_kind", "Unsupported capture kind: $kind", null)
      return
    }
    if (pending != null) {
      result.error("already_active", "A camera capture is already active.", null)
      return
    }
    if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
      result.error("camera_unavailable", "This device has no camera.", null)
      return
    }
    val request = Pending(result, video = kind == "video")
    pending = request
    if (needsCameraPermission()) {
      ActivityCompat.requestPermissions(
        activity,
        arrayOf(Manifest.permission.CAMERA),
        permissionRequestCode,
      )
    } else {
      launch(request)
    }
  }

  /** Only a declared-but-ungranted CAMERA permission blocks the capture intents. */
  private fun needsCameraPermission(): Boolean {
    val declared = try {
      val info = activity.packageManager.getPackageInfo(
        activity.packageName,
        PackageManager.GET_PERMISSIONS,
      )
      info.requestedPermissions?.contains(Manifest.permission.CAMERA) == true
    } catch (_: Exception) {
      true
    }
    return declared &&
      ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) !=
      PackageManager.PERMISSION_GRANTED
  }

  fun onRequestPermissionsResult(code: Int, grantResults: IntArray): Boolean {
    if (code != permissionRequestCode) return false
    val request = pending ?: return true
    val granted = grantResults.isNotEmpty() &&
      grantResults[0] == PackageManager.PERMISSION_GRANTED
    if (granted) {
      launch(request)
    } else {
      finishWithError(request, "camera_permission_denied", null)
    }
    return true
  }

  private fun launch(request: Pending) {
    try {
      val root = File(activity.cacheDir, "diary_camera")
      // Leftovers of captures whose result never came back (see class comment).
      root.listFiles()?.forEach { it.deleteRecursively() }
      val batch = File(root, UUID.randomUUID().toString())
      if (!batch.mkdirs()) throw IOException("Cannot create camera capture directory.")
      val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
      val file = File(batch, if (request.video) "VID_$stamp.mp4" else "IMG_$stamp.jpg")
      if (!file.createNewFile()) throw IOException("Cannot create camera capture file.")
      request.file = file
      val uri = FileProvider.getUriForFile(
        activity,
        "${activity.packageName}.diary_camera",
        file,
      )
      val intent = Intent(
        if (request.video) MediaStore.ACTION_VIDEO_CAPTURE else MediaStore.ACTION_IMAGE_CAPTURE,
      ).apply {
        putExtra(MediaStore.EXTRA_OUTPUT, uri)
        // The grant flags apply to the URIs in ClipData; EXTRA_OUTPUT alone is not always copied
        // there for ACTION_VIDEO_CAPTURE.
        clipData = ClipData.newRawUri("", uri)
        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
      }
      activity.startActivityForResult(intent, captureRequestCode)
    } catch (error: ActivityNotFoundException) {
      finishWithError(request, "camera_unavailable", error)
    } catch (error: SecurityException) {
      finishWithError(request, "camera_permission_denied", error)
    } catch (error: Exception) {
      finishWithError(request, "capture_failed", error)
    }
  }

  fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
    if (code != captureRequestCode) return false
    val request = pending ?: return true
    if (copying) return true
    val file = request.file
    if (resultCode != Activity.RESULT_OK || file == null) {
      discard(file)
      pending = null
      request.result.success(null)
      return true
    }
    try {
      if (file.length() > 0) {
        succeed(request, file)
        return true
      }
      // Intent extras come from another app; reading them can throw while unparcelling.
      val returned = data?.data
      if (returned == null) throw IOException("Camera returned no media.")
      copying = true
      copyReturned(request, returned, file)
    } catch (error: Exception) {
      finishWithError(request, "capture_failed", error)
    }
    return true
  }

  private fun copyReturned(request: Pending, uri: Uri, file: File) {
    val context = activity.applicationContext
    Thread {
      try {
        val input = context.contentResolver.openInputStream(uri)
          ?: throw IOException("Cannot read captured media.")
        input.use { source ->
          file.outputStream().use { output ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
              if (disposed) throw IOException("Camera capture was cancelled.")
              val read = source.read(buffer)
              if (read < 0) break
              output.write(buffer, 0, read)
            }
            output.flush()
          }
        }
        if (file.length() == 0L) throw IOException("Captured media is empty.")
        activity.runOnUiThread { succeed(request, file) }
      } catch (error: Exception) {
        activity.runOnUiThread { finishWithError(request, "capture_failed", error) }
      }
    }.start()
  }

  private fun succeed(request: Pending, file: File) {
    if (disposed || pending !== request) {
      discard(file)
      return
    }
    copying = false
    pending = null
    request.result.success(
      listOf(mapOf("name" to file.name, "path" to file.path, "size" to file.length())),
    )
  }

  private fun finishWithError(request: Pending, code: String, error: Exception?) {
    Log.w("DiaryCameraCapture", code, error)
    discard(request.file)
    if (disposed || pending !== request) return
    copying = false
    pending = null
    request.result.error(code, error?.message, null)
  }

  /** Removes a capture's batch directory; failures only leave cache behind. */
  private fun discard(file: File?) {
    try {
      file?.parentFile?.deleteRecursively()
    } catch (error: Exception) {
      Log.w("DiaryCameraCapture", "Could not discard camera capture.", error)
    }
  }

  fun dispose() {
    disposed = true
    channel.setMethodCallHandler(null)
    val request = pending
    pending = null
    if (request != null && !copying) discard(request.file)
    request?.result?.success(null)
  }
}
