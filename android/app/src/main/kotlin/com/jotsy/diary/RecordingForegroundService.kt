package com.jotsy.diary

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps microphone capture going while the app is in the background or the screen is off (#251).
 *
 * Since Android 9 an app without a foreground service gets silent buffers from the microphone
 * once it leaves the foreground, and Android 14 additionally requires the service to declare the
 * `microphone` type. While this service runs, the status bar shows an ongoing "recording"
 * notification (with the elapsed time while capturing); tapping it brings the app back.
 *
 * The service only shows the notification; capture itself stays in the `record` plugin. It must
 * be started while the app is in the foreground with RECORD_AUDIO granted (the editor starts it
 * right after the permission check), otherwise Android refuses a microphone foreground service.
 * It never restarts itself ([START_NOT_STICKY]) and stops with the task, because the recording
 * dies with the Flutter engine anyway.
 */
class RecordingForegroundService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val notice = RecordingNotice.fromIntent(intent)
    val notification = notice.build(this)
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(
          NOTIFICATION_ID,
          notification,
          ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
        )
      } else {
        startForeground(NOTIFICATION_ID, notification)
      }
    } catch (error: Exception) {
      // Android 14+ throws here when the microphone type's prerequisites are missing. That must
      // not crash the app: recording in the foreground still works without the service.
      stopSelf()
    }
    return START_NOT_STICKY
  }

  // Swiping the app away from recents destroys the engine and with it the recording: the
  // notification must not linger on its own.
  override fun onTaskRemoved(rootIntent: Intent?) {
    stopSelf()
  }

  override fun onDestroy() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(true)
    }
    super.onDestroy()
  }

  companion object {
    const val NOTIFICATION_ID = 7251
    const val CHANNEL_ID = "diary_recording"
  }
}

/**
 * The notification's texts come from Dart (the in-app language may differ from the system's),
 * together with the recording state: while capturing the notification counts up from the
 * elapsed time, while paused it shows no clock.
 */
private data class RecordingNotice(
  val title: String,
  val text: String,
  val channelName: String,
  val paused: Boolean,
  val elapsedMs: Long,
) {
  fun putInto(intent: Intent): Intent = intent
    .putExtra(EXTRA_TITLE, title)
    .putExtra(EXTRA_TEXT, text)
    .putExtra(EXTRA_CHANNEL, channelName)
    .putExtra(EXTRA_PAUSED, paused)
    .putExtra(EXTRA_ELAPSED, elapsedMs)

  fun build(context: Context): Notification {
    val manager = context.getSystemService(NotificationManager::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      // Re-creating a channel only updates its name, so a changed app language shows up in the
      // system's notification settings the next time a recording starts.
      manager?.createNotificationChannel(
        NotificationChannel(
          RecordingForegroundService.CHANNEL_ID,
          channelName,
          NotificationManager.IMPORTANCE_LOW,
        ).apply { setShowBadge(false) },
      )
    }
    val builder = NotificationCompat.Builder(context, RecordingForegroundService.CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_stat_recording)
      .setContentTitle(title)
      .setContentText(text)
      .setOngoing(true)
      .setSilent(true)
      .setOnlyAlertOnce(true)
      .setCategory(NotificationCompat.CATEGORY_SERVICE)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
    if (paused) {
      builder.setShowWhen(false).setUsesChronometer(false)
    } else {
      builder
        .setWhen(System.currentTimeMillis() - elapsedMs)
        .setShowWhen(true)
        .setUsesChronometer(true)
    }
    openAppIntent(context)?.let { builder.setContentIntent(it) }
    return builder.build()
  }

  /** Brings the existing task to the front, exactly like tapping the launcher icon. */
  private fun openAppIntent(context: Context): PendingIntent? {
    val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
      ?: return null
    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
    return PendingIntent.getActivity(
      context,
      0,
      launch,
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
  }

  companion object {
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_TEXT = "text"
    private const val EXTRA_CHANNEL = "channelName"
    private const val EXTRA_PAUSED = "paused"
    private const val EXTRA_ELAPSED = "elapsedMs"

    fun fromIntent(intent: Intent?) = RecordingNotice(
      title = intent?.getStringExtra(EXTRA_TITLE).orEmpty(),
      text = intent?.getStringExtra(EXTRA_TEXT).orEmpty(),
      channelName = intent?.getStringExtra(EXTRA_CHANNEL)?.ifBlank { null } ?: "Recording",
      paused = intent?.getBooleanExtra(EXTRA_PAUSED, false) ?: false,
      elapsedMs = intent?.getLongExtra(EXTRA_ELAPSED, 0L) ?: 0L,
    )

    fun fromArguments(arguments: Any?): RecordingNotice {
      val map = arguments as? Map<*, *>
      return RecordingNotice(
        title = map?.get("title") as? String ?: "",
        text = map?.get("text") as? String ?: "",
        channelName = (map?.get("channelName") as? String)?.ifBlank { null } ?: "Recording",
        paused = map?.get("paused") as? Boolean ?: false,
        elapsedMs = (map?.get("elapsedMs") as? Number)?.toLong() ?: 0L,
      )
    }
  }
}

/**
 * Channel `com.jotsy.diary/recording_service`, driven by `RecordingKeepAlive` in Dart.
 *
 * - `start(notice)`: starts [RecordingForegroundService]; answers whether it is running, so the
 *   editor knows it may keep capturing in the background. Android refuses a microphone foreground
 *   service when the app is not in front or the permission is missing; the answer is then false
 *   and the editor pauses on leaving the app, as it did before.
 * - `update(notice)`: replaces the notification (recording ↔ paused) of a running service. It
 *   goes through [NotificationManager] rather than restarting the service, which a backgrounded
 *   app might not be allowed to do. Without the notification permission nothing is posted; the
 *   service keeps running regardless.
 * - `stop()`: stops the service. [dispose] (the activity is gone, and with it the engine that
 *   owned the recording) stops it too.
 */
class RecordingServiceChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/recording_service")
  private var running = false

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "start" -> result.success(start(RecordingNotice.fromArguments(call.arguments)))
        "update" -> {
          update(RecordingNotice.fromArguments(call.arguments))
          result.success(null)
        }
        "stop" -> {
          stop()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun start(notice: RecordingNotice): Boolean {
    val intent = notice.putInto(Intent(activity, RecordingForegroundService::class.java))
    return try {
      ContextCompat.startForegroundService(activity, intent)
      running = true
      true
    } catch (error: Exception) {
      // ForegroundServiceStartNotAllowedException (Android 12+), SecurityException (missing
      // microphone permission on Android 14+), IllegalStateException (background start).
      running = false
      false
    }
  }

  private fun update(notice: RecordingNotice) {
    if (!running) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
      ContextCompat.checkSelfPermission(activity, android.Manifest.permission.POST_NOTIFICATIONS) !=
      PackageManager.PERMISSION_GRANTED
    ) {
      return
    }
    activity.getSystemService(NotificationManager::class.java)
      ?.notify(RecordingForegroundService.NOTIFICATION_ID, notice.build(activity))
  }

  private fun stop() {
    if (!running) return
    running = false
    activity.stopService(Intent(activity, RecordingForegroundService::class.java))
  }

  fun dispose() {
    stop()
    channel.setMethodCallHandler(null)
  }
}
