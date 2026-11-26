package com.jotsy.diary

import android.Manifest
import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import androidx.core.app.AlarmManagerCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/**
 * Native Android scheduler and notification poster for to-do reminders.
 *
 * Uses [AlarmManager.setAlarmClock] when exact alarms are permitted so reminders wake the
 * device and deliver even when the app has been swiped out of Recents, in Doze mode, or on OEM
 * ROMs (HyperOS/MIUI, ColorOS, OriginOS, HarmonyOS) that throttle `setExactAndAllowWhileIdle`.
 * Falls back to `setAndAllowWhileIdle` if exact alarm permission is missing, and never deletes
 * stored reminders when exact permission is temporarily unavailable.
 */
object TodoReminderManager {
  const val CHANNEL_ID = "todo_reminders"
  const val ACTION_FIRE = "com.jotsy.diary.action.FIRE_TODO_REMINDER"
  const val ACTION_COMPLETE = "com.jotsy.diary.action.COMPLETE_TODO_NOTIFICATION"
  const val ACTION_SNOOZE = "com.jotsy.diary.action.SNOOZE_TODO_NOTIFICATION"
  const val SELECT_NOTIFICATION_ACTION = "SELECT_NOTIFICATION"
  const val EXTRA_NOTIFICATION_ID = "notificationId"
  const val EXTRA_ACTION_ID = "actionId"
  const val EXTRA_PAYLOAD = "payload"
  const val EXTRA_REMINDER_ID = "reminder_id"
  const val EXTRA_REMINDER_JSON = "reminder_json"
  const val WATCHDOG_WORK_NAME = "jotsy_todo_reminder_watchdog"
  const val OVERDUE_CATCH_UP_WINDOW_MS = 24L * 60L * 60L * 1000L

  fun ensureChannel(
    context: Context,
    channelName: String,
    channelDescription: String,
  ) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = context.getSystemService(NotificationManager::class.java) ?: return
    val channel = NotificationChannel(
      CHANNEL_ID,
      channelName.ifBlank { "To-do reminders" },
      NotificationManager.IMPORTANCE_HIGH,
    ).apply {
      description = channelDescription
      enableVibration(true)
      enableLights(true)
      setShowBadge(true)
    }
    manager.createNotificationChannel(channel)
  }

  fun canScheduleExactAlarms(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
    val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return false
    return alarmManager.canScheduleExactAlarms()
  }

  fun notificationsEnabled(context: Context): Boolean {
    if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
      return false
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val manager = context.getSystemService(NotificationManager::class.java)
      val channel = manager?.getNotificationChannel(CHANNEL_ID)
      if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
        return false
      }
    }
    return true
  }

  fun isIgnoringBatteryOptimizations(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
    val powerManager = context.getSystemService(PowerManager::class.java) ?: return false
    return powerManager.isIgnoringBatteryOptimizations(context.packageName)
  }

  /**
   * Persists [record] and arms its system alarm.
   *
   * Throws [SecurityException] when [exact] is true and Android denies exact alarms so the Dart
   * gateway can retry with `exact = false` and persist the downgraded payload marker.
   */
  fun schedule(
    context: Context,
    record: TodoReminderRecord,
    exact: Boolean,
    nowMillis: Long = System.currentTimeMillis(),
  ) {
    val appContext = context.applicationContext
    ensureChannel(appContext, record.channelName, record.channelDescription)
    TodoReminderStore.save(appContext, record)
    armAlarm(
      context = appContext,
      record = record,
      exact = exact,
      throwOnExactDenied = true,
      nowMillis = nowMillis,
    )
    syncWatchdog(appContext)
  }

  fun cancel(context: Context, id: Int) {
    val appContext = context.applicationContext
    cancelAlarmOnly(appContext, id)
    NotificationManagerCompat.from(appContext).cancel(id)
    TodoReminderStore.remove(appContext, id)
    syncWatchdog(appContext)
  }

  /** Cancels all pending reminders belonging to [todoId] and [occurrence] (or all when null). */
  fun cancelOccurrence(context: Context, todoId: String, occurrence: String?) {
    val appContext = context.applicationContext
    if (todoId.isEmpty()) return
    for (record in TodoReminderStore.loadAll(appContext)) {
      val identity = resolveIdentity(record)
      if (identity.first == todoId &&
        (occurrence == null || occurrence.isEmpty() || identity.second == occurrence)
      ) {
        cancelAlarmOnly(appContext, record.id)
        NotificationManagerCompat.from(appContext).cancel(record.id)
        TodoReminderStore.remove(appContext, record.id)
      }
    }
    syncWatchdog(appContext)
  }

  fun pendingPayloads(context: Context): List<Map<String, Any>> =
    TodoReminderStore.loadAll(context.applicationContext).map { it.toPendingMap() }

  fun handleAlarmFired(
    context: Context,
    id: Int,
    fallbackJson: String?,
    nowMillis: Long = System.currentTimeMillis(),
  ) {
    val appContext = context.applicationContext
    val stored = if (id >= 0) TodoReminderStore.get(appContext, id) else null
    val record = stored ?: TodoReminderRecord.fromJsonString(fallbackJson) ?: return
    TodoReminderStore.remove(appContext, record.id)
    deliverNotification(appContext, record)
    rearmAllFuture(appContext, nowMillis = nowMillis)
    syncWatchdog(appContext)
  }

  /**
   * Recovers alarms after reboot, app upgrade, clock/timezone shifts, or periodic watchdog runs.
   *
   * Never drops future reminders if exact-alarm permission is absent; falls back to inexact and
   * re-upgrades once permission returns. Overdue reminders within 24h that have never fired are
   * delivered immediately once, and older expired entries are pruned.
   */
  fun recoverAndRearm(
    context: Context,
    recalculateTimezone: Boolean,
    nowMillis: Long = System.currentTimeMillis(),
    zoneId: ZoneId = ZoneId.systemDefault(),
  ) {
    val appContext = context.applicationContext
    val records = TodoReminderStore.loadAll(appContext)
    if (records.isEmpty()) {
      syncWatchdog(appContext)
      return
    }
    val exactAllowed = canScheduleExactAlarms(appContext)
    for (original in records) {
      val record = if (recalculateTimezone && original.localYear > 0) {
        original.recalculateForTimeZone(zoneId).also {
          if (it.fireAtMillis != original.fireAtMillis) {
            TodoReminderStore.save(appContext, it)
          }
        }
      } else {
        original
      }

      if (record.fireAtMillis <= nowMillis) {
        TodoReminderStore.remove(appContext, record.id)
        if (nowMillis - record.fireAtMillis <= OVERDUE_CATCH_UP_WINDOW_MS) {
          deliverNotification(appContext, record)
        }
      } else {
        armAlarm(
          context = appContext,
          record = record,
          exact = exactAllowed,
          throwOnExactDenied = false,
          nowMillis = nowMillis,
        )
      }
    }
    syncWatchdog(appContext)
  }

  private fun rearmAllFuture(context: Context, nowMillis: Long) {
    val exactAllowed = canScheduleExactAlarms(context)
    for (record in TodoReminderStore.loadAll(context)) {
      if (record.fireAtMillis <= nowMillis) {
        if (nowMillis - record.fireAtMillis > OVERDUE_CATCH_UP_WINDOW_MS) {
          TodoReminderStore.remove(context, record.id)
        }
        continue
      }
      armAlarm(
        context = context,
        record = record,
        exact = exactAllowed,
        throwOnExactDenied = false,
        nowMillis = nowMillis,
      )
    }
  }

  private fun armAlarm(
    context: Context,
    record: TodoReminderRecord,
    exact: Boolean,
    throwOnExactDenied: Boolean,
    nowMillis: Long,
  ) {
    val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
    val triggerAt = maxOf(record.fireAtMillis, nowMillis + 500L)
    val operation = buildFirePendingIntent(context, record)
    if (exact) {
      if (!canScheduleExactAlarms(context)) {
        if (throwOnExactDenied) {
          throw SecurityException("exact_alarms_not_permitted")
        }
        AlarmManagerCompat.setAndAllowWhileIdle(
          alarmManager,
          AlarmManager.RTC_WAKEUP,
          triggerAt,
          operation,
        )
        return
      }
      try {
        val showIntent = buildAlarmClockShowPendingIntent(context, record)
        alarmManager.setAlarmClock(
          AlarmManager.AlarmClockInfo(triggerAt, showIntent),
          operation,
        )
        return
      } catch (error: SecurityException) {
        if (throwOnExactDenied) throw error
      }
    }
    AlarmManagerCompat.setAndAllowWhileIdle(
      alarmManager,
      AlarmManager.RTC_WAKEUP,
      triggerAt,
      operation,
    )
  }

  private fun cancelAlarmOnly(context: Context, id: Int) {
    val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
    val intent = Intent(context, TodoReminderReceiver::class.java).apply {
      action = ACTION_FIRE
    }
    val pending = PendingIntent.getBroadcast(
      context,
      id,
      intent,
      PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    )
    if (pending != null) {
      alarmManager.cancel(pending)
      pending.cancel()
    }
  }

  @SuppressLint("MissingPermission")
  fun deliverNotification(context: Context, record: TodoReminderRecord) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
      ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
      PackageManager.PERMISSION_GRANTED
    ) {
      return
    }
    if (!notificationsEnabled(context)) return
    ensureChannel(context, record.channelName, record.channelDescription)
    val notification = buildNotification(context, record)
    NotificationManagerCompat.from(context).notify(record.id, notification)
  }

  fun buildNotification(context: Context, record: TodoReminderRecord): Notification {
    val contentIntent = PendingIntent.getActivity(
      context,
      record.id xor 0x10000000,
      buildLaunchIntent(context, record.id, record.payload),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val completeIntent = buildActionPendingIntent(
      context = context,
      requestCode = record.id xor 0x30000000,
      intentAction = ACTION_COMPLETE,
      notificationId = record.id,
      actionId = "todo.complete",
      payload = record.payload,
    )
    val snoozeIntent = buildActionPendingIntent(
      context = context,
      requestCode = record.id xor 0x40000000,
      intentAction = ACTION_SNOOZE,
      notificationId = record.id,
      actionId = "todo.snooze.${record.snoozeMinutes}",
      payload = record.payload,
    )
    val builder = NotificationCompat.Builder(context, CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_stat_todo)
      .setContentTitle(record.title)
      .setContentText(record.body)
      .setAutoCancel(true)
      .setWhen(record.fireAtMillis)
      .setShowWhen(true)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setCategory(NotificationCompat.CATEGORY_REMINDER)
      .setDefaults(NotificationCompat.DEFAULT_ALL)
      .setVisibility(
        if (record.hideOnLockScreen) {
          NotificationCompat.VISIBILITY_PRIVATE
        } else {
          NotificationCompat.VISIBILITY_PUBLIC
        },
      )
      .setContentIntent(contentIntent)
      .addAction(0, record.completeLabel, completeIntent)
      .addAction(0, record.snoozeLabel, snoozeIntent)
    if (record.body.isNotEmpty()) {
      builder.setStyle(NotificationCompat.BigTextStyle().bigText(record.body))
    }
    return builder.build()
  }

  private fun buildFirePendingIntent(context: Context, record: TodoReminderRecord): PendingIntent {
    val intent = Intent(context, TodoReminderReceiver::class.java).apply {
      action = ACTION_FIRE
      putExtra(EXTRA_REMINDER_ID, record.id)
      putExtra(EXTRA_REMINDER_JSON, record.toJson().toString())
    }
    return PendingIntent.getBroadcast(
      context,
      record.id,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  private fun buildAlarmClockShowPendingIntent(
    context: Context,
    record: TodoReminderRecord,
  ): PendingIntent {
    val intent = buildLaunchIntent(context, record.id, record.payload).apply {
      // Distinct data URI keeps AlarmClock's showIntent separate from notification contentIntent.
      data = Uri.parse("jotsy://todo-alarm/${record.id}")
    }
    return PendingIntent.getActivity(
      context,
      record.id xor 0x20000000,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  private fun buildLaunchIntent(
    context: Context,
    notificationId: Int,
    payload: String,
  ): Intent {
    val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
      ?: Intent(context, MainActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
    return launch.apply {
      action = SELECT_NOTIFICATION_ACTION
      putExtra(EXTRA_NOTIFICATION_ID, notificationId)
      putExtra(EXTRA_PAYLOAD, payload)
    }
  }

  private fun buildActionPendingIntent(
    context: Context,
    requestCode: Int,
    intentAction: String,
    notificationId: Int,
    actionId: String,
    payload: String,
  ): PendingIntent {
    val intent = Intent(context, TodoNotificationActionReceiver::class.java).apply {
      action = intentAction
      putExtra(EXTRA_NOTIFICATION_ID, notificationId)
      putExtra(EXTRA_ACTION_ID, actionId)
      putExtra(EXTRA_PAYLOAD, payload)
    }
    return PendingIntent.getBroadcast(
      context,
      requestCode,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  fun syncWatchdog(context: Context) {
    val hasPending = TodoReminderStore.hasPending(context)
    runCatching {
      val manager = WorkManager.getInstance(context)
      if (hasPending) {
        val request = PeriodicWorkRequestBuilder<TodoReminderWatchdogWorker>(6, TimeUnit.HOURS)
          .build()
        manager.enqueueUniquePeriodicWork(
          WATCHDOG_WORK_NAME,
          ExistingPeriodicWorkPolicy.KEEP,
          request,
        )
      } else {
        manager.cancelUniqueWork(WATCHDOG_WORK_NAME)
      }
    }
  }

  private fun resolveIdentity(record: TodoReminderRecord): Pair<String, String> {
    if (record.todoId.isNotEmpty()) {
      return record.todoId to record.occurrence
    }
    val payload = record.payload
    if (!payload.startsWith("todo:")) return "" to ""
    val body = payload.removePrefix("todo:")
    val bar = body.indexOf('|')
    return runCatching {
      val obj = JSONObject(if (bar < 0) body else body.substring(0, bar))
      obj.optString("t", "") to obj.optString("o", "")
    }.getOrDefault("" to "")
  }
}
