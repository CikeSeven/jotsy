package com.jotsy.diary

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel `com.jotsy.diary/notifications` shared between [MainActivity] and the headless
 * background engine launched by [TodoNotificationActionReceiver].
 */
class TodoNotificationsChannel(
  private val context: Context,
  messenger: BinaryMessenger,
  private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, CHANNEL_NAME)
  private val isMainEngine: Boolean = activityProvider() != null

  init {
    channel.setMethodCallHandler(this)
    if (isMainEngine) {
      activeMainChannel = channel
    }
  }

  fun notifyPendingActions() {
    channel.invokeMethod("drainPendingActions", null)
  }

  fun dispose() {
    if (activeMainChannel === channel) {
      activeMainChannel = null
    }
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        val channelName = call.argument<String>("channelName") ?: "To-do reminders"
        val channelDescription = call.argument<String>("channelDescription") ?: ""
        val callbackHandle = (call.argument<Number>("actionCallbackHandle"))?.toLong()
        TodoReminderManager.ensureChannel(context, channelName, channelDescription)
        if (callbackHandle != null && callbackHandle != 0L) {
          TodoReminderStore.saveActionCallbackHandle(context, callbackHandle)
        }
        result.success(true)
      }
      "canScheduleExactAlarms" -> {
        result.success(TodoReminderManager.canScheduleExactAlarms(context))
      }
      "notificationsEnabled" -> {
        result.success(TodoReminderManager.notificationsEnabled(context))
      }
      "isIgnoringBatteryOptimizations" -> {
        result.success(TodoReminderManager.isIgnoringBatteryOptimizations(context))
      }
      "getPendingReminders" -> {
        result.success(TodoReminderManager.pendingPayloads(context))
      }
      "scheduleReminder" -> {
        val args = call.arguments as? Map<*, *>
        val record = TodoReminderRecord.fromMethodArguments(args)
        if (record == null) {
          result.error("invalid_arguments", "Missing reminder fields.", null)
          return
        }
        val exact = args?.get("exact") as? Boolean ?: true
        try {
          TodoReminderManager.schedule(context, record, exact)
          result.success(null)
        } catch (error: SecurityException) {
          result.error("exact_alarms_not_permitted", error.message, null)
        }
      }
      "cancelReminder" -> {
        val id = call.argument<Number>("id")?.toInt()
        if (id == null) {
          result.error("invalid_arguments", "Missing reminder id.", null)
          return
        }
        TodoReminderManager.cancel(context, id)
        result.success(null)
      }
      "openNotificationSettings" -> {
        result.success(openNotificationSettings())
      }
      "requestExactAlarmsPermission" -> {
        result.success(requestExactAlarmsPermission())
      }
      "requestIgnoreBatteryOptimizations" -> {
        result.success(requestIgnoreBatteryOptimizations())
      }
      "openAutoStartSettings" -> {
        result.success(OemBackgroundSettings.openAutoStartOrAppSettings(context, activityProvider()))
      }
      "takePendingActions" -> {
        result.success(TodoBackgroundActionCoordinator.takePendingActions())
      }
      "finishBackgroundActions" -> {
        result.success(TodoBackgroundActionCoordinator.finishIfIdle())
      }
      else -> result.notImplemented()
    }
  }

  private fun openNotificationSettings(): Boolean {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
    } else {
      appDetailsIntent(context)
    }
    return launchSettingsIntent(intent)
  }

  private fun requestExactAlarmsPermission(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
    val exactIntent = Intent(
      Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
      Uri.parse("package:${context.packageName}"),
    )
    if (launchSettingsIntent(exactIntent)) return true
    return launchSettingsIntent(appDetailsIntent(context))
  }

  private fun requestIgnoreBatteryOptimizations(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
    val directIntent = Intent(
      Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
      Uri.parse("package:${context.packageName}"),
    )
    if (launchSettingsIntent(directIntent)) return true
    val listIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
    if (launchSettingsIntent(listIntent)) return true
    return launchSettingsIntent(appDetailsIntent(context))
  }

  private fun launchSettingsIntent(intent: Intent): Boolean {
    val activity = activityProvider()
    return try {
      if (activity != null) {
        activity.startActivity(intent)
      } else {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
      }
      true
    } catch (_: Exception) {
      false
    }
  }

  companion object {
    const val CHANNEL_NAME = "com.jotsy.diary/notifications"

    @Volatile
    private var activeMainChannel: MethodChannel? = null

    fun deliverActionToMainEngine(
      actionId: String,
      payload: String,
      onComplete: (Boolean) -> Unit,
    ): Boolean {
      val channel = activeMainChannel ?: return false
      channel.invokeMethod(
        "onNotificationAction",
        mapOf("actionId" to actionId, "payload" to payload),
        object : MethodChannel.Result {
          override fun success(result: Any?) {
            onComplete(result == true)
          }

          override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            onComplete(false)
          }

          override fun notImplemented() {
            onComplete(false)
          }
        },
      )
      return true
    }

    internal fun appDetailsIntent(context: Context): Intent = Intent(
      Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
      Uri.fromParts("package", context.packageName, null),
    )
  }
}

/**
 * Best-effort deep-links into OEM Auto-Start / Background Launch settings, falling back cleanly
 * to the standard App Info screen on unsupported devices or restricted ROM components.
 */
object OemBackgroundSettings {
  private val oemComponents: List<Pair<String, String>> = listOf(
    // Xiaomi / Redmi / POCO (MIUI & HyperOS)
    "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
    "com.miui.securitycenter" to "com.miui.powercenter.PowerSettings",
    // OPPO / OnePlus / Realme (ColorOS)
    "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
    "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
    "com.oplus.safecenter" to "com.oplus.safecenter.startupapp.StartupAppListActivity",
    "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
    // vivo / iQOO (OriginOS & FuntouchOS)
    "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
    "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
    "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManagerActivity",
    // Huawei (HarmonyOS / EMUI) & Honor (MagicOS)
    "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
    "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
    "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
    // Meizu / Samsung / Asus / Lenovo
    "com.meizu.safe" to "com.meizu.safe.security.SHOW_APPSEC",
    "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
    "com.samsung.android.sm" to "com.samsung.android.sm.battery.ui.BatteryActivity",
    "com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity",
    "com.letv.android.letvsafe" to "com.letv.android.letvsafe.AutobootManageActivity",
  )

  fun openAutoStartOrAppSettings(context: Context, activity: Activity?): Boolean {
    for (intent in candidateIntents(context)) {
      val started = try {
        if (activity != null) {
          activity.startActivity(intent)
        } else {
          intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          context.startActivity(intent)
        }
        true
      } catch (_: Exception) {
        false
      }
      if (started) return true
    }
    return false
  }

  internal fun candidateIntents(context: Context): List<Intent> {
    val list = ArrayList<Intent>()
    val pm = context.packageManager
    for ((pkg, cls) in oemComponents) {
      val intent = Intent().setComponent(ComponentName(pkg, cls))
      if (pkg == "com.meizu.safe") {
        intent.putExtra("packageName", context.packageName)
      }
      if (pm.resolveActivity(intent, 0) != null) {
        list.add(intent)
      }
    }
    list.add(TodoNotificationsChannel.appDetailsIntent(context))
    return list
  }
}
