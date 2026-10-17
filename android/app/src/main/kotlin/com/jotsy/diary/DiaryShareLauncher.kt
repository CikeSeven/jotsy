package com.jotsy.diary

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.ResolveInfo
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Separate class so it does not clash with the plugins' own FileProvider entries in the merged manifest. */
class DiaryShareFileProvider : FileProvider()

/**
 * Sends diary text or images straight to one app (Weibo, WeChat, ...) by package name, which
 * share_plus cannot do. Dart stages images under cacheDir/diary_share/ first; that is the only
 * directory [DiaryShareFileProvider] exposes, and paths outside it are rejected here as well.
 *
 * When the target app has a single matching share activity it is launched directly; apps with
 * several entries (WeChat: send to chat / favorites) get a chooser limited to that package. A
 * target may also name one entry of an app (WeChat Moments), which is then the only one used.
 */
class DiaryShareLauncher(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/share")
  private val authority = "${activity.packageName}.diary_share"
  private val stagingDirectoryName = "diary_share"

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "availableComponents" -> result.success(
          availableComponents(call.argument<List<String>>("components").orEmpty()),
        )
        "shareToPackage" -> shareToPackage(
          packageName = call.argument<String>("packageName"),
          activityName = call.argument<String>("activityName"),
          text = call.argument<String>("text"),
          imagePaths = call.argument<List<String>>("imagePaths").orEmpty(),
          chooserTitle = call.argument<String>("chooserTitle"),
          result = result,
        )
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  /**
   * Targets that are installed and accept a text or image share; an app without a share entry is
   * no use. A target is "package" or "package/activity" (ComponentName's flattened form); for the
   * latter that very entry has to accept the share, so a renamed entry hides the target.
   */
  private fun availableComponents(components: List<String>): List<String> =
    components.filter { component ->
      val packageName = component.substringBefore('/')
      val activityName = component.substringAfter('/', "").ifEmpty { null }
      listOf("text/plain", "image/*").any { mimeType ->
        handlersFor(
          Intent(Intent.ACTION_SEND).setType(mimeType).setPackage(packageName),
          activityName,
        ).isNotEmpty()
      }
    }

  private fun shareToPackage(
    packageName: String?,
    activityName: String?,
    text: String?,
    imagePaths: List<String>,
    chooserTitle: String?,
    result: MethodChannel.Result,
  ) {
    if (packageName.isNullOrBlank()) {
      result.error("invalid_package", "Target package is empty.", null)
      return
    }
    val uris = try {
      imagePaths.map(::stagedUri)
    } catch (error: IllegalArgumentException) {
      result.error("invalid_image", error.message, null)
      return
    }

    val intent = when {
      uris.size > 1 -> Intent(Intent.ACTION_SEND_MULTIPLE).apply {
        type = "image/*"
        putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
      }
      uris.size == 1 -> Intent(Intent.ACTION_SEND).apply {
        type = "image/*"
        putExtra(Intent.EXTRA_STREAM, uris.first())
      }
      else -> Intent(Intent.ACTION_SEND).apply { type = "text/plain" }
    }
    if (!text.isNullOrEmpty()) {
      intent.putExtra(Intent.EXTRA_TEXT, text)
    }
    if (uris.isNotEmpty()) {
      // EXTRA_STREAM alone does not carry the grant for SEND_MULTIPLE on every
      // version; ClipData does, and createChooser copies it to the chooser.
      intent.clipData = ClipData.newRawUri(null, uris.first()).apply {
        uris.drop(1).forEach { addItem(ClipData.Item(it)) }
      }
      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    intent.setPackage(packageName)

    val handlers = handlersFor(intent, activityName)
    if (handlers.isEmpty()) {
      result.success(false)
      return
    }
    try {
      if (handlers.size == 1) {
        val info = handlers.first().activityInfo
        intent.setClassName(info.packageName, info.name)
        activity.startActivity(intent)
      } else {
        activity.startActivity(Intent.createChooser(intent, chooserTitle))
      }
      result.success(true)
    } catch (error: ActivityNotFoundException) {
      result.success(false)
    } catch (error: SecurityException) {
      result.error("launch_failed", error.message, null)
    }
  }

  private fun stagedUri(path: String): Uri {
    val root = File(activity.cacheDir, stagingDirectoryName).canonicalFile
    val file = File(path).canonicalFile
    require(file.isFile && file.path.startsWith(root.path + File.separator)) {
      "Image is not staged for sharing."
    }
    return FileProvider.getUriForFile(activity, authority, file)
  }

  /** Activities that take [intent], narrowed to [activityName] when the target names one. */
  @Suppress("DEPRECATION")
  private fun handlersFor(intent: Intent, activityName: String? = null): List<ResolveInfo> =
    activity.packageManager.queryIntentActivities(intent, 0).filter { handler ->
      activityName == null || handler.activityInfo.name == activityName
    }
}
