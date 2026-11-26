package com.jotsy.diary

import android.app.Activity
import android.content.Context
import android.content.res.Resources
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Lets the system splash screen follow the app's theme colour, channel
 * `com.jotsy.diary/launch_splash` (Dart side: `LaunchSplashThemeSync`; slots are defined in
 * lib/app/launch_splash_theme.dart).
 *
 * - `apply({index})`: makes slot `index` of `R.array.launch_splash_themes` the splash theme of every
 *   later launch through `SplashScreen.setSplashScreenTheme`, which the system persists by resource
 *   name. `null` (the default theme colour) or an unknown slot goes back to the manifest's
 *   `LaunchTheme`. Android 13+ only: on 12 and 12L the system can only draw the manifest theme, so
 *   this is a no-op there and Dart's first frame keeps the default colours too.
 * - The applied slot is recorded in `noBackupFilesDir`, and [recordedSlot] hands it to Dart on the
 *   next launch so the first Flutter frame paints the colours the system splash just drew. Not in
 *   backed-up storage: a restore brings back the app's settings but not the system's splash theme,
 *   and a restored record would claim colours the splash never drew.
 * - The record carries the version code: a repeated `apply` is skipped while slot and version are
 *   unchanged (it writes the system's package state), and runs once more after each update in case
 *   the system dropped the theme with the old APK.
 */
class LaunchSplashThemeChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, CHANNEL)

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "apply" -> {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            apply(call.argument<Int>("index"))
          }
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  @RequiresApi(Build.VERSION_CODES.TIRAMISU)
  private fun apply(index: Int?) {
    val themes = activity.resources.obtainTypedArray(R.array.launch_splash_themes)
    val slot: Int
    val themeId: Int
    try {
      slot = index?.takeIf { it in 0 until themes.length() } ?: NO_SLOT
      themeId =
        if (slot == NO_SLOT) Resources.ID_NULL else themes.getResourceId(slot, Resources.ID_NULL)
    } finally {
      themes.recycle()
    }
    val record = "$slot ${BuildConfig.VERSION_CODE}"
    val file = recordFile(activity)
    if (readRecord(file) == record) {
      return
    }
    activity.splashScreen.setSplashScreenTheme(themeId)
    try {
      file.writeText(record)
    } catch (error: IOException) {
      // Without a record the next launch simply starts from the default colours.
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  companion object {
    private const val CHANNEL = "com.jotsy.diary/launch_splash"
    private const val RECORD_FILE = "launch_splash_theme"
    private const val NO_SLOT = -1

    /**
     * The slot the system splash was drawn with on this launch, or `null` for the manifest's
     * `LaunchTheme` (also below Android 13, where no slot is ever applied).
     */
    fun recordedSlot(context: Context): Int? {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        return null
      }
      val slot = readRecord(recordFile(context))?.substringBefore(' ')?.toIntOrNull()
      return slot?.takeIf { it >= 0 }
    }

    private fun recordFile(context: Context) = File(context.noBackupFilesDir, RECORD_FILE)

    private fun readRecord(file: File): String? =
      try {
        if (file.isFile) file.readText() else null
      } catch (error: IOException) {
        null
      }
  }
}
