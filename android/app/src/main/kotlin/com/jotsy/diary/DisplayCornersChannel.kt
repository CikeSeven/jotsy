package com.jotsy.diary

import android.app.Activity
import android.os.Build
import android.view.RoundedCorner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The screen's own rounded corners where they touch this app's window, channel
 * `com.jotsy.diary/display_corners` (Dart side: `DisplayCorners`).
 *
 * - `radii()`: `[topLeft, topRight, bottomRight, bottomLeft]` in physical pixels, read from the
 *   decor view's root `WindowInsets` (Android 12+). The insets already account for the window's
 *   position, so a corner the window doesn't reach (split screen, freeform) is 0. `null` below
 *   Android 12 or before the window is attached; Dart then keeps square corners.
 *
 * Opening a diary from its card grows the card into the page and ends on these radii, so the page
 * lands exactly on the screen's physical corners instead of turning square on the way.
 */
class DisplayCornersChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/display_corners")

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "radii" -> result.success(radii())
        else -> result.notImplemented()
      }
    }
  }

  private fun radii(): List<Double>? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      return null
    }
    val insets = activity.window?.decorView?.rootWindowInsets ?: return null
    return listOf(
      RoundedCorner.POSITION_TOP_LEFT,
      RoundedCorner.POSITION_TOP_RIGHT,
      RoundedCorner.POSITION_BOTTOM_RIGHT,
      RoundedCorner.POSITION_BOTTOM_LEFT,
    ).map { position -> insets.getRoundedCorner(position)?.radius?.toDouble() ?: 0.0 }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }
}
