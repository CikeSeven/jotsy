package com.jotsy.diary

import android.app.Activity
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Native support for LAN sync (docs/lan_sync.md §5.1, §3).
 *
 * - acquireMulticastLock / releaseMulticastLock: most Wi-Fi drivers drop multicast and broadcast
 *   packets not addressed to this device to save power, so discovery beacons from other devices
 *   never reach Dart without a MulticastLock. The lock is not reference counted, so repeated
 *   acquire calls from Dart (start called twice) still need only one release, and it is released
 *   in [dispose] so a destroyed activity never keeps the radio awake.
 * - deviceName: the user-editable device name (Settings.Global.DEVICE_NAME, API 25+), falling back
 *   to Build.MODEL.
 * - noBackupDirectory: Context.noBackupFilesDir, which Auto Backup and device-to-device transfer
 *   skip. The device identity and per-peer sync state live there so a restored or migrated phone
 *   does not impersonate the old one.
 */
class LanSyncChannel(
  activity: Activity,
  messenger: BinaryMessenger,
) {
  private val context: Context = activity.applicationContext
  private val channel = MethodChannel(messenger, "com.jotsy.diary/lan_sync")
  private var multicastLock: WifiManager.MulticastLock? = null

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "acquireMulticastLock" -> result.success(acquireMulticastLock())
        "releaseMulticastLock" -> {
          releaseMulticastLock()
          result.success(null)
        }
        "deviceName" -> result.success(deviceName())
        "noBackupDirectory" -> result.success(context.noBackupFilesDir.absolutePath)
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    releaseMulticastLock()
  }

  private fun acquireMulticastLock(): Boolean {
    return try {
      val lock = multicastLock ?: run {
        val wifi = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
          ?: return false
        wifi.createMulticastLock("jotsy-lan-sync").apply { setReferenceCounted(false) }
          .also { multicastLock = it }
      }
      if (!lock.isHeld) {
        lock.acquire()
      }
      true
    } catch (error: SecurityException) {
      false
    } catch (error: RuntimeException) {
      false
    }
  }

  private fun releaseMulticastLock() {
    try {
      multicastLock?.let { if (it.isHeld) it.release() }
    } catch (error: RuntimeException) {
      // Already released by the system; nothing to do.
    }
  }

  private fun deviceName(): String {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
      val name = try {
        Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
      } catch (error: RuntimeException) {
        null
      }
      if (!name.isNullOrBlank()) {
        return name.trim()
      }
    }
    return Build.MODEL ?: "Android"
  }
}
