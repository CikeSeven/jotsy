package com.jotsy.diary

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.webkit.CookieManager
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
  private val configChannelName = "com.jotsy.diary/config"
  private val backupFileSaverChannelName = "com.jotsy.diary/backup_file_saver"
  private val webCookiesChannelName = "com.jotsy.diary/web_cookies"
  private val notificationsChannelName = "com.jotsy.diary/notifications"
  private val backupFileSaverRequestCode = 7621
  private var pendingBackupSaveResult: MethodChannel.Result? = null
  private var pendingBackupSourcePath: String? = null
  private var galleryVideoPicker: DiaryGalleryVideoPicker? = null
  private var cameraCapture: DiaryCameraCapture? = null
  private var shareLauncher: DiaryShareLauncher? = null
  private var longImageSlicer: DiaryLongImageSlicer? = null
  private var imageTranscoder: DiaryImageTranscoder? = null
  private var videoTools: DiaryVideoTools? = null
  private var appUpdateInstaller: AppUpdateInstaller? = null
  private var lanSyncChannel: LanSyncChannel? = null
  private var appLockChannel: AppLockChannel? = null
  // Must match launchBrandMarkEntrypointArg in lib/app/launch_brand_mark.dart.
  private val launchBrandMarkArg = "--launch-brand-mark"

  override fun onCreate(savedInstanceState: Bundle?) {
    handOffSplashScreenToFlutter()
    // Registered before super.onCreate so it sits below FlutterFragment's callback; see
    // [leaveToHomeScreen].
    onBackPressedDispatcher.addCallback(leaveToHomeScreen)
    super.onCreate(savedInstanceState)
  }

  /**
   * Back on the first Flutter route (nothing left for Dart to pop) sends the app to the home
   * screen instead of finishing the activity, like pressing Home: the engine, the Dart state and
   * the screen the user was on (the notebook they were reading) stay as they were (#196).
   *
   * How a root back gets here: [FlutterFragmentActivity.onBackPressed] hands every back press to
   * Dart; when Dart has nothing to pop it calls `SystemNavigator.pop`, and FlutterFragment
   * disables its own callback and re-dispatches through [onBackPressedDispatcher]. With no other
   * callback the dispatcher's fallback is [Activity.onBackPressed], which finishes the activity
   * (and with it the engine) on Android 11 and below and on some vendor builds of newer versions.
   * This callback is the lowest-priority one, so it only ever sees that re-dispatch.
   *
   * Only when this activity is the root of its task: moving the task would otherwise also hide
   * whichever app started us, so then the default (finish, back to that app) runs instead.
   */
  private val leaveToHomeScreen = object : OnBackPressedCallback(true) {
    override fun handleOnBackPressed() {
      if (isTaskRoot) {
        moveTaskToBack(true)
        return
      }
      isEnabled = false
      onBackPressedDispatcher.onBackPressed()
      isEnabled = true
    }
  }

  /**
   * Android 12+: hands the system splash screen over to the first Flutter frame, which paints the
   * same background and brand mark in the same place (Flutter's documented approach).
   *
   * - Lay the window out edge-to-edge so the Flutter view and the splash screen share the whole
   *   screen as their frame and centre the mark at the same point; Android 15+ enforces this
   *   anyway, so 12-14 now match it.
   * - Without a listener the system plays its own exit (icon fade, radial reveal and a 20dp
   *   slide-up of the app window), dragging Flutter's copy of the mark while the native one fades,
   *   which reads as a ghosted double. Removing the splash at once lets Flutter continue the same
   *   picture in the same frame; Dart then runs the whole reveal.
   * - SplashScreenView.remove() resets the system bars to their pre-Dart values, so the style
   *   Dart has set is applied again afterwards.
   */
  @SuppressLint("NewApi")
  private fun handOffSplashScreenToFlutter() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      return
    }
    window.setDecorFitsSystemWindows(false)
    splashScreen.setOnExitAnimationListener { splashScreenView ->
      splashScreenView.remove()
      supportFragmentManager.fragments
        .filterIsInstance<FlutterFragment>()
        .firstOrNull()
        ?.updateSystemUiOverlays()
    }
  }

  /** Tells Dart the native launch screen shows the brand mark, so its first frame continues it. */
  private fun launchEntrypointArgs(): List<String> =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) listOf(launchBrandMarkArg) else emptyList()

  /**
   * Appends the launch-screen flag to whatever entrypoint arguments the intent carries; the
   * default createFlutterFragment passes this list to the new engine.
   */
  override fun getDartEntrypointArgs(): List<String>? =
    (super.getDartEntrypointArgs().orEmpty() + launchEntrypointArgs()).ifEmpty { null }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    galleryVideoPicker?.dispose()
    galleryVideoPicker = DiaryGalleryVideoPicker(
      this,
      flutterEngine.dartExecutor.binaryMessenger,
    )
    cameraCapture?.dispose()
    cameraCapture = DiaryCameraCapture(this, flutterEngine.dartExecutor.binaryMessenger)
    shareLauncher?.dispose()
    shareLauncher = DiaryShareLauncher(this, flutterEngine.dartExecutor.binaryMessenger)
    longImageSlicer?.dispose()
    longImageSlicer = DiaryLongImageSlicer(this, flutterEngine.dartExecutor.binaryMessenger)
    imageTranscoder?.dispose()
    imageTranscoder = DiaryImageTranscoder(this, flutterEngine.dartExecutor.binaryMessenger)
    videoTools?.dispose()
    videoTools = DiaryVideoTools(this, flutterEngine.dartExecutor.binaryMessenger)
    appUpdateInstaller?.dispose()
    appUpdateInstaller = AppUpdateInstaller(this, flutterEngine.dartExecutor.binaryMessenger)
    lanSyncChannel?.dispose()
    lanSyncChannel = LanSyncChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    appLockChannel?.dispose()
    appLockChannel = AppLockChannel(this, flutterEngine.dartExecutor.binaryMessenger)
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
    // 待办提醒：定时通知要按本机时区排（夏令时切换后仍是墙上时钟的那一刻），
    // 时区名只有原生知道；权限被拒后从设置页跳到系统的应用通知设置。
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "timeZone" -> result.success(java.util.TimeZone.getDefault().id)
          "openNotificationSettings" -> result.success(openNotificationSettings())
          else -> result.notImplemented()
        }
      }
    // 云端笔记导入：读取网页视图中登录后的 Cookie（含 HttpOnly），只返回给
    // 调用方请求的那个地址。webview_flutter 只提供设置与清除，没有读取接口。
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, webCookiesChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getCookies" -> {
            val url = call.argument<String>("url")
            if (url.isNullOrBlank() || !url.startsWith("https://")) {
              result.error("invalid_url", "Only https URLs are supported.", null)
            } else {
              result.success(CookieManager.getInstance().getCookie(url))
            }
          }
          "flush" -> {
            CookieManager.getInstance().flush()
            result.success(null)
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

  /**
   * Every activity this app starts (plugins' pickers, the camera, share sheets, `startActivity`)
   * ends up here; the app lock uses it to tell such trips apart from the user leaving the app.
   */
  @Deprecated("Deprecated in Java")
  override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
    appLockChannel?.onActivityLaunched()
    @Suppress("DEPRECATION")
    super.startActivityForResult(intent, requestCode, options)
  }

  override fun onResume() {
    super.onResume()
    appLockChannel?.onResumed()
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (galleryVideoPicker?.onActivityResult(requestCode, resultCode, data) == true) {
      return
    }
    if (cameraCapture?.onActivityResult(requestCode, resultCode, data) == true) {
      return
    }
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

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<String>,
    grantResults: IntArray,
  ) {
    if (cameraCapture?.onRequestPermissionsResult(requestCode, grantResults) == true) {
      return
    }
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
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
    galleryVideoPicker?.dispose()
    galleryVideoPicker = null
    cameraCapture?.dispose()
    cameraCapture = null
    shareLauncher?.dispose()
    shareLauncher = null
    longImageSlicer?.dispose()
    longImageSlicer = null
    imageTranscoder?.dispose()
    imageTranscoder = null
    videoTools?.dispose()
    videoTools = null
    appUpdateInstaller?.dispose()
    appUpdateInstaller = null
    lanSyncChannel?.dispose()
    lanSyncChannel = null
    appLockChannel?.dispose()
    appLockChannel = null
    pendingBackupSaveResult?.success(null)
    clearPendingBackupSave()
    super.onDestroy()
  }

  /// 打开系统里本应用的通知设置（Android 8+ 直达通知页，更早的系统打开应用
  /// 详情页）。经 startActivity → startActivityForResult，应用锁把它当作
  /// 应用自己打开的页面，回来时不上锁。
  private fun openNotificationSettings(): Boolean {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
    } else {
      Intent(
        android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.fromParts("package", packageName, null),
      )
    }
    return try {
      startActivity(intent)
      true
    } catch (_: Exception) {
      false
    }
  }
}
