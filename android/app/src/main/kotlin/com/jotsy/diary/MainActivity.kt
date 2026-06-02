package com.jotsy.diary

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
  private val configChannelName = "com.jotsy.diary/config"
  private val backupFileSaverChannelName = "com.jotsy.diary/backup_file_saver"
  private val backupFileSaverRequestCode = 7621
  private var predictiveBackCallback: OnBackInvokedCallback? = null
  private var predictiveBackCallbackRegistered = false
  private var pendingBackupSaveResult: MethodChannel.Result? = null
  private var pendingBackupSourcePath: String? = null

  override fun createFlutterFragment(): FlutterFragment {
    val backgroundMode = backgroundMode
    val renderMode = renderMode
    val transparencyMode =
      if (backgroundMode == BackgroundMode.opaque) {
        TransparencyMode.opaque
      } else {
        TransparencyMode.transparent
      }
    val shouldDelayFirstAndroidViewDraw = renderMode == RenderMode.surface
    val shouldAutomaticallyHandleOnBackPressed = true

    cachedEngineId?.let { engineId ->
      return FlutterFragment.CachedEngineFragmentBuilder(
          PredictiveBackFlutterFragment::class.java,
          engineId,
        )
        .renderMode(renderMode)
        .transparencyMode(transparencyMode)
        .handleDeeplinking(shouldHandleDeeplinking())
        .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
        .destroyEngineWithFragment(shouldDestroyEngineWithHost())
        .shouldDelayFirstAndroidViewDraw(shouldDelayFirstAndroidViewDraw)
        .shouldAutomaticallyHandleOnBackPressed(shouldAutomaticallyHandleOnBackPressed)
        .build<PredictiveBackFlutterFragment>()
    }

    cachedEngineGroupId?.let { engineGroupId ->
      return FlutterFragment.NewEngineInGroupFragmentBuilder(
          PredictiveBackFlutterFragment::class.java,
          engineGroupId,
        )
        .dartEntrypoint(dartEntrypointFunctionName)
        .initialRoute(initialRoute)
        .handleDeeplinking(shouldHandleDeeplinking())
        .renderMode(renderMode)
        .transparencyMode(transparencyMode)
        .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
        .shouldDelayFirstAndroidViewDraw(shouldDelayFirstAndroidViewDraw)
        .shouldAutomaticallyHandleOnBackPressed(shouldAutomaticallyHandleOnBackPressed)
        .build<PredictiveBackFlutterFragment>()
    }

    val builder =
      FlutterFragment.NewEngineFragmentBuilder(PredictiveBackFlutterFragment::class.java)
        .dartEntrypoint(dartEntrypointFunctionName)
        .initialRoute(initialRoute)
        .flutterShellArgs(FlutterShellArgs.fromIntent(intent))
        .handleDeeplinking(shouldHandleDeeplinking())
        .renderMode(renderMode)
        .transparencyMode(transparencyMode)
        .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
        .shouldDelayFirstAndroidViewDraw(shouldDelayFirstAndroidViewDraw)
        .shouldAutomaticallyHandleOnBackPressed(shouldAutomaticallyHandleOnBackPressed)

    dartEntrypointLibraryUri?.let { builder.dartLibraryUri(it) }
    dartEntrypointArgs?.let { builder.dartEntrypointArgs(it) }
    appBundlePath?.let { builder.appBundlePath(it) }

    return builder.build<PredictiveBackFlutterFragment>()
  }

  @SuppressLint("NewApi")
  internal fun setPredictiveBackProgressEnabled(enabled: Boolean) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      return
    }
    if (enabled && !predictiveBackCallbackRegistered) {
      val callback = predictiveBackCallback ?: createPredictiveBackCallback().also {
        predictiveBackCallback = it
      }
      onBackInvokedDispatcher.registerOnBackInvokedCallback(
        OnBackInvokedDispatcher.PRIORITY_DEFAULT,
        callback,
      )
      predictiveBackCallbackRegistered = true
      return
    }
    if (!enabled && predictiveBackCallbackRegistered) {
      predictiveBackCallback?.let(onBackInvokedDispatcher::unregisterOnBackInvokedCallback)
      predictiveBackCallbackRegistered = false
    }
  }

  @SuppressLint("NewApi")
  private fun createPredictiveBackCallback(): OnBackInvokedCallback {
    return object : OnBackAnimationCallback {
      override fun onBackStarted(backEvent: BackEvent) {
        flutterEngine?.backGestureChannel?.startBackGesture(backEvent)
      }

      override fun onBackProgressed(backEvent: BackEvent) {
        flutterEngine?.backGestureChannel?.updateBackGestureProgress(backEvent)
      }

      override fun onBackCancelled() {
        flutterEngine?.backGestureChannel?.cancelBackGesture()
      }

      override fun onBackInvoked() {
        flutterEngine?.backGestureChannel?.commitBackGesture()
      }
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, configChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getAmapWebApiKey" -> {
            val key = BuildConfig.AMAP_WEB_API_KEY.trim()
            result.success(if (key.isEmpty()) null else key)
          }
          "getQWeatherCredentialId" -> {
            val value = BuildConfig.QWEATHER_CREDENTIAL_ID.trim()
            result.success(if (value.isEmpty()) null else value)
          }
          "getQWeatherApiKey" -> {
            val value = BuildConfig.QWEATHER_API_KEY.trim()
            result.success(if (value.isEmpty()) null else value)
          }
          "getQWeatherApiHost" -> {
            val value = BuildConfig.QWEATHER_API_HOST.trim()
            result.success(if (value.isEmpty()) null else value)
          }
          else -> result.notImplemented()
        }
      }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupFileSaverChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "saveBackupFile" -> startBackupFileSave(
            sourcePath = call.argument<String>("sourcePath"),
            fileName = call.argument<String>("fileName"),
            mimeType = call.argument<String>("mimeType"),
            result = result,
          )
          else -> result.notImplemented()
        }
      }
  }

  private fun startBackupFileSave(
    sourcePath: String?,
    fileName: String?,
    mimeType: String?,
    result: MethodChannel.Result,
  ) {
    if (pendingBackupSaveResult != null) {
      result.error("already_active", "Another backup save request is already active.", null)
      return
    }
    if (sourcePath.isNullOrBlank()) {
      result.error("missing_source", "Backup source path is empty.", null)
      return
    }
    val sourceFile = File(sourcePath)
    if (!sourceFile.exists() || !sourceFile.isFile) {
      result.error("missing_source", "Backup source file does not exist.", null)
      return
    }

    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
      addCategory(Intent.CATEGORY_OPENABLE)
      type = mimeType?.takeIf { it.isNotBlank() } ?: "application/zip"
      putExtra(Intent.EXTRA_TITLE, fileName?.takeIf { it.isNotBlank() } ?: sourceFile.name)
      addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    }

    pendingBackupSaveResult = result
    pendingBackupSourcePath = sourcePath
    try {
      startActivityForResult(intent, backupFileSaverRequestCode)
    } catch (error: Exception) {
      clearPendingBackupSave()
      result.error("save_unavailable", error.message, null)
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (requestCode != backupFileSaverRequestCode) {
      super.onActivityResult(requestCode, resultCode, data)
      return
    }

    val result = pendingBackupSaveResult
    val sourcePath = pendingBackupSourcePath
    clearPendingBackupSave()

    if (result == null) {
      return
    }
    if (resultCode != Activity.RESULT_OK) {
      result.success(null)
      return
    }

    val targetUri = data?.data
    if (sourcePath == null || targetUri == null) {
      result.error("missing_target", "Backup save target is missing.", null)
      return
    }

    Thread {
      try {
        copyBackupFileToUri(sourcePath, targetUri)
        runOnUiThread { result.success(targetUri.toString()) }
      } catch (error: Exception) {
        runOnUiThread { result.error("copy_failed", error.message, null) }
      }
    }.start()
  }

  private fun copyBackupFileToUri(sourcePath: String, targetUri: Uri) {
    val outputStream = contentResolver.openOutputStream(targetUri)
      ?: throw IOException("Cannot open backup save target.")
    FileInputStream(File(sourcePath)).use { input ->
      outputStream.use { output ->
        val buffer = ByteArray(64 * 1024)
        while (true) {
          val read = input.read(buffer)
          if (read < 0) {
            break
          }
          output.write(buffer, 0, read)
        }
        output.flush()
      }
    }
  }

  private fun clearPendingBackupSave() {
    pendingBackupSaveResult = null
    pendingBackupSourcePath = null
  }

  override fun onDestroy() {
    pendingBackupSaveResult?.success(null)
    clearPendingBackupSave()
    setPredictiveBackProgressEnabled(false)
    super.onDestroy()
  }

  class PredictiveBackFlutterFragment : FlutterFragment() {
    override fun onCreate(savedInstanceState: Bundle?) {
      super.onCreate(savedInstanceState)
      (activity as? MainActivity)?.setPredictiveBackProgressEnabled(backCallbackState)
    }

    override fun setFrameworkHandlesBack(frameworkHandlesBack: Boolean) {
      super.setFrameworkHandlesBack(frameworkHandlesBack)
      (activity as? MainActivity)?.setPredictiveBackProgressEnabled(frameworkHandlesBack)
    }

    override fun onDetach() {
      (activity as? MainActivity)?.setPredictiveBackProgressEnabled(false)
      super.onDetach()
    }
  }
}
