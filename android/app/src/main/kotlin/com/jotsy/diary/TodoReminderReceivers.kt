package com.jotsy.diary

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.annotation.Keep
import androidx.core.app.NotificationManagerCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation

/** Fires when a scheduled to-do reminder alarm triggers. */
@Keep
class TodoReminderReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != TodoReminderManager.ACTION_FIRE) return
    val id = intent.getIntExtra(TodoReminderManager.EXTRA_REMINDER_ID, -1)
    val fallbackJson = intent.getStringExtra(TodoReminderManager.EXTRA_REMINDER_JSON)
    TodoReminderManager.handleAlarmFired(context, id, fallbackJson)
  }
}

/**
 * Re-arms persisted to-do alarms across device reboot, app update, clock/timezone adjustments,
 * and exact-alarm permission changes without launching the UI or keeping a background service.
 */
@Keep
class TodoReminderSystemReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_MY_PACKAGE_REPLACED,
      "android.intent.action.QUICKBOOT_POWERON",
      "com.htc.intent.action.QUICKBOOT_POWERON",
      Intent.ACTION_TIME_CHANGED,
      AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
        TodoReminderManager.recoverAndRearm(context, recalculateTimezone = false)
      }
      Intent.ACTION_TIMEZONE_CHANGED -> {
        TodoReminderManager.recoverAndRearm(context, recalculateTimezone = true)
      }
    }
  }
}

/**
 * Periodic WorkManager watchdog that silently heals dropped OEM alarms in pure Kotlin.
 *
 * Uses zero background services or Flutter engines; simply re-arms any pending reminders in
 * [AlarmManager] and catches up missed ones within 24h.
 */
@Keep
class TodoReminderWatchdogWorker(
  context: Context,
  params: WorkerParameters,
) : Worker(context, params) {
  override fun doWork(): Result {
    TodoReminderManager.recoverAndRearm(applicationContext, recalculateTimezone = false)
    return Result.success()
  }
}

/**
 * Handles notification action buttons ("Complete" / "Snooze") without opening the app UI.
 *
 * Uses [BroadcastReceiver.goAsync] so SQLite writes and snooze/repeat rescheduling complete before
 * Android reclaims the background process.
 */
@Keep
class TodoNotificationActionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != TodoReminderManager.ACTION_COMPLETE &&
      intent.action != TodoReminderManager.ACTION_SNOOZE
    ) {
      return
    }
    val notificationId = intent.getIntExtra(TodoReminderManager.EXTRA_NOTIFICATION_ID, -1)
    if (notificationId >= 0) {
      NotificationManagerCompat.from(context).cancel(notificationId)
    }
    val actionId = intent.getStringExtra(TodoReminderManager.EXTRA_ACTION_ID)
    val payload = intent.getStringExtra(TodoReminderManager.EXTRA_PAYLOAD)
    if (actionId.isNullOrBlank() || payload.isNullOrBlank()) return

    val pendingResult = goAsync()
    TodoBackgroundActionCoordinator.dispatch(
      context = context.applicationContext,
      actionId = actionId,
      payload = payload,
      pendingResult = pendingResult,
    )
  }
}

/**
 * Coordinates background notification button execution: forwards directly to the live main engine
 * when available, or spins up a headless engine with [TodoNotificationsChannel] attached.
 */
object TodoBackgroundActionCoordinator {
  private const val FINISH_TIMEOUT_MS = 15_000L
  private val lock = Any()
  private val mainHandler = Handler(Looper.getMainLooper())
  private val queuedActions = ArrayList<Map<String, String>>()
  private val pendingResults = ArrayList<BroadcastReceiver.PendingResult>()
  private var backgroundEngine: FlutterEngine? = null
  private var backgroundChannel: TodoNotificationsChannel? = null
  private var timeoutRunnable: Runnable? = null

  fun dispatch(
    context: Context,
    actionId: String,
    payload: String,
    pendingResult: BroadcastReceiver.PendingResult,
  ) {
    mainHandler.post {
      val deliveredToMain = TodoNotificationsChannel.deliverActionToMainEngine(
        actionId = actionId,
        payload = payload,
        onComplete = { accepted ->
          if (accepted) {
            runCatching { pendingResult.finish() }
          } else {
            enqueueForBackgroundEngine(context, actionId, payload, pendingResult)
          }
        },
      )
      if (!deliveredToMain) {
        enqueueForBackgroundEngine(context, actionId, payload, pendingResult)
      }
    }
  }

  private fun enqueueForBackgroundEngine(
    context: Context,
    actionId: String,
    payload: String,
    pendingResult: BroadcastReceiver.PendingResult,
  ) {
    val shouldStartEngine: Boolean
    val existingChannel: TodoNotificationsChannel?
    synchronized(lock) {
      queuedActions.add(mapOf("actionId" to actionId, "payload" to payload))
      pendingResults.add(pendingResult)
      scheduleSafetyTimeoutLocked()
      shouldStartEngine = backgroundEngine == null
      existingChannel = backgroundChannel
    }

    if (shouldStartEngine) {
      startBackgroundEngine(context)
    } else {
      existingChannel?.notifyPendingActions()
    }
  }

  fun takePendingActions(): List<Map<String, String>> {
    synchronized(lock) {
      if (queuedActions.isEmpty()) return emptyList()
      val copy = ArrayList(queuedActions)
      queuedActions.clear()
      return copy
    }
  }

  /** Returns true when no more queued actions remain and all PendingResults were finished. */
  fun finishIfIdle(): Boolean {
    val resultsToFinish: List<BroadcastReceiver.PendingResult>
    synchronized(lock) {
      if (queuedActions.isNotEmpty()) {
        return false
      }
      cancelSafetyTimeoutLocked()
      resultsToFinish = ArrayList(pendingResults)
      pendingResults.clear()
    }
    for (result in resultsToFinish) {
      runCatching { result.finish() }
    }
    mainHandler.post { destroyBackgroundEngineIfIdle() }
    return true
  }

  private fun destroyBackgroundEngineIfIdle() {
    val engineToDestroy: FlutterEngine?
    val channelToDispose: TodoNotificationsChannel?
    synchronized(lock) {
      if (queuedActions.isNotEmpty() || pendingResults.isNotEmpty()) {
        return
      }
      engineToDestroy = backgroundEngine
      channelToDispose = backgroundChannel
      backgroundEngine = null
      backgroundChannel = null
    }
    channelToDispose?.dispose()
    runCatching { engineToDestroy?.destroy() }
  }

  private fun startBackgroundEngine(context: Context) {
    val callbackHandle = TodoReminderStore.getActionCallbackHandle(context)
    if (callbackHandle == 0L) {
      finishAllWithError()
      return
    }
    try {
      val loader = FlutterInjector.instance().flutterLoader()
      loader.startInitialization(context)
      loader.ensureInitializationComplete(context, null)
      val engine = FlutterEngine(context)
      val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
      if (callbackInfo == null) {
        engine.destroy()
        finishAllWithError()
        return
      }
      val channel = TodoNotificationsChannel(
        context = context,
        messenger = engine.dartExecutor.binaryMessenger,
        activityProvider = { null },
      )
      synchronized(lock) {
        backgroundEngine = engine
        backgroundChannel = channel
      }
      engine.dartExecutor.executeDartCallback(
        DartExecutor.DartCallback(context.assets, loader.findAppBundlePath(), callbackInfo),
      )
    } catch (_: Throwable) {
      finishAllWithError()
    }
  }

  private fun scheduleSafetyTimeoutLocked() {
    timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
    val runnable = Runnable { finishAllWithError() }
    timeoutRunnable = runnable
    mainHandler.postDelayed(runnable, FINISH_TIMEOUT_MS)
  }

  private fun cancelSafetyTimeoutLocked() {
    timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
    timeoutRunnable = null
  }

  private fun finishAllWithError() {
    val resultsToFinish: List<BroadcastReceiver.PendingResult>
    synchronized(lock) {
      cancelSafetyTimeoutLocked()
      queuedActions.clear()
      resultsToFinish = ArrayList(pendingResults)
      pendingResults.clear()
    }
    for (result in resultsToFinish) {
      runCatching { result.finish() }
    }
  }
}
