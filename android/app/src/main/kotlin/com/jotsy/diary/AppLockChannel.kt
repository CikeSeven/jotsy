package com.jotsy.diary

import android.app.Activity
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the app lock (docs/rules/app_lock.md), channel `com.jotsy.diary/app_lock`.
 *
 * - `setWatchScreenOff(enabled)`: while enabled, a receiver registered on the activity forwards
 *   every `ACTION_SCREEN_OFF` to Dart as `screenOff`, also while the app is in the background, so
 *   "lock when the screen locks" already covers the app before the user comes back.
 *   `ACTION_SCREEN_OFF` can only be received by a receiver registered at runtime, which is why
 *   this lives here rather than in the manifest.
 * - `setSecureScreen(enabled)`: toggles `FLAG_SECURE` on the window. Screenshots, screen
 *   recordings and the recent-apps thumbnail then show nothing but black.
 * - `leftForOwnActivity()`: whether the app just went to the background because it opened
 *   another screen itself (photo picker, camera, file picker, share sheet, the system's lock
 *   screen credential page) and that screen still sits on top of this app's task. Such a trip
 *   doesn't count as leaving the app. Two conditions must both hold: [MainActivity] started an
 *   activity since it last resumed ([onActivityLaunched], every launch from the activity goes
 *   through `startActivityForResult`), and the top of our task is no longer [MainActivity].
 *   Pressing Home leaves our task with [MainActivity] on top; a browser opened in its own task
 *   leaves it there too, so both still count as leaving. When the task can't be inspected the
 *   answer is false, so the app locks rather than stays open.
 */
class AppLockChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/app_lock")
  private var screenOffReceiver: BroadcastReceiver? = null
  private var launchedSinceResume = false

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "setWatchScreenOff" -> {
          setWatchScreenOff(call.argument<Boolean>("enabled") == true)
          result.success(null)
        }
        "setSecureScreen" -> {
          setSecureScreen(call.argument<Boolean>("enabled") == true)
          result.success(null)
        }
        "leftForOwnActivity" -> result.success(launchedSinceResume && ownTaskCovered())
        else -> result.notImplemented()
      }
    }
  }

  /** Called by [MainActivity] whenever it starts another activity. */
  fun onActivityLaunched() {
    launchedSinceResume = true
  }

  /** Called by [MainActivity] when it is back in front. */
  fun onResumed() {
    launchedSinceResume = false
  }

  private fun setWatchScreenOff(enabled: Boolean) {
    if (enabled == (screenOffReceiver != null)) {
      return
    }
    if (!enabled) {
      unregisterScreenOff()
      return
    }
    val receiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_SCREEN_OFF) {
          channel.invokeMethod("screenOff", null)
        }
      }
    }
    // A system broadcast: no export flag is needed for it, and the receiver is never exported.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      activity.registerReceiver(
        receiver,
        IntentFilter(Intent.ACTION_SCREEN_OFF),
        Context.RECEIVER_NOT_EXPORTED,
      )
    } else {
      activity.registerReceiver(receiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }
    screenOffReceiver = receiver
  }

  private fun unregisterScreenOff() {
    val receiver = screenOffReceiver ?: return
    screenOffReceiver = null
    try {
      activity.unregisterReceiver(receiver)
    } catch (_: IllegalArgumentException) {
      // Already gone with the activity.
    }
  }

  private fun setSecureScreen(enabled: Boolean) {
    if (enabled) {
      activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    } else {
      activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
  }

  private fun ownTaskCovered(): Boolean {
    val manager = activity.getSystemService(ActivityManager::class.java) ?: return false
    val own = activity.componentName
    return try {
      manager.appTasks.any { task ->
        val info = task.taskInfo
        val sameTask = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          info.taskId == activity.taskId
        } else {
          @Suppress("DEPRECATION")
          info.id == activity.taskId
        }
        val top = info.topActivity
        sameTask && top != null && top != own
      }
    } catch (_: Exception) {
      false
    }
  }

  fun dispose() {
    unregisterScreenOff()
    channel.setMethodCallHandler(null)
  }
}
