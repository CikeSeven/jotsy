package com.jotsy.diary

import android.Manifest
import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAlarmManager
import java.nio.ByteBuffer
import java.time.LocalDateTime
import java.time.ZoneId

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 33])
class TodoReminderManagerTest {
  private lateinit var context: Application
  private lateinit var alarmManager: AlarmManager
  private lateinit var notificationManager: NotificationManager

  @Before
  fun setUp() {
    context = RuntimeEnvironment.getApplication()
    alarmManager = context.getSystemService(AlarmManager::class.java)
    notificationManager = context.getSystemService(NotificationManager::class.java)
    context.getSharedPreferences("jotsy_todo_reminders", Context.MODE_PRIVATE).edit().clear().commit()
    shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
  }

  @After
  fun tearDown() {
    context.getSharedPreferences("jotsy_todo_reminders", Context.MODE_PRIVATE).edit().clear().commit()
  }

  private fun sampleRecord(
    id: Int = 101,
    todoId: String = "todo-1",
    occurrence: String = "2026-11-27",
    fireAtMillis: Long = 2_000_000_000_000L,
    localYear: Int = 2026,
    localMonth: Int = 11,
    localDay: Int = 27,
    localHour: Int = 9,
    localMinute: Int = 0,
    hideOnLockScreen: Boolean = false,
  ) = TodoReminderRecord(
    id = id,
    todoId = todoId,
    occurrence = occurrence,
    title = "Pay bill",
    body = "Today 09:00",
    payload = "todo:{\"t\":\"$todoId\",\"o\":\"$occurrence\"}|{\"l\":\"en\"}",
    fireAtMillis = fireAtMillis,
    localYear = localYear,
    localMonth = localMonth,
    localDay = localDay,
    localHour = localHour,
    localMinute = localMinute,
    snoozeMinutes = 10,
    hideOnLockScreen = hideOnLockScreen,
    channelName = "To-do reminders",
    channelDescription = "To-do notifications",
    completeLabel = "Complete",
    snoozeLabel = "Snooze",
  )

  @Test
  fun `exact schedule uses AlarmClock with Activity showIntent and Receiver operation`() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ShadowAlarmManager.setCanScheduleExactAlarms(true)
    }
    val now = 1_999_999_000_000L
    val record = sampleRecord(fireAtMillis = now + 60_000L)

    TodoReminderManager.schedule(context, record, exact = true, nowMillis = now)

    val scheduled = shadowOf(alarmManager).scheduledAlarms
    assertEquals(1, scheduled.size)
    val alarm = scheduled.single()
    assertNotNull(alarm.showIntent)
    assertTrue(shadowOf(alarm.showIntent).isActivity)
    assertTrue(shadowOf(alarm.operation).isBroadcast)
    assertEquals(
      TodoReminderReceiver::class.java.name,
      shadowOf(alarm.operation).savedIntent.component?.className,
    )
    assertEquals(1, TodoReminderStore.loadAll(context).size)
  }

  @Test
  @Config(sdk = [33])
  fun `denied exact alarm throws SecurityException and allows inexact fallback`() {
    ShadowAlarmManager.setCanScheduleExactAlarms(false)
    val now = 1_999_999_000_000L
    val record = sampleRecord(fireAtMillis = now + 60_000L)

    assertThrows(SecurityException::class.java) {
      TodoReminderManager.schedule(context, record, exact = true, nowMillis = now)
    }

    TodoReminderManager.schedule(context, record, exact = false, nowMillis = now)
    val scheduled = shadowOf(alarmManager).scheduledAlarms
    assertEquals(1, scheduled.size)
    assertNull(scheduled.single().showIntent)
  }

  @Test
  fun `firing alarm posts notification with actions and removes stored entry`() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ShadowAlarmManager.setCanScheduleExactAlarms(true)
    }
    val now = 1_999_999_000_000L
    val first = sampleRecord(id = 101, fireAtMillis = now + 10_000L)
    val second = sampleRecord(id = 102, todoId = "todo-2", fireAtMillis = now + 120_000L)
    TodoReminderManager.schedule(context, first, exact = true, nowMillis = now)
    TodoReminderManager.schedule(context, second, exact = true, nowMillis = now)

    val receiver = TodoReminderReceiver()
    receiver.onReceive(
      context,
      Intent(TodoReminderManager.ACTION_FIRE).putExtra(TodoReminderManager.EXTRA_REMINDER_ID, 101),
    )

    val posted = shadowOf(notificationManager).getNotification(101)
    assertNotNull(posted)
    assertEquals("Pay bill", posted.extras.getString(Notification.EXTRA_TITLE))
    assertEquals(2, posted.actions.size)
    assertEquals("Complete", posted.actions[0].title.toString())
    assertEquals("Snooze", posted.actions[1].title.toString())
    assertNull(TodoReminderStore.get(context, 101))
    assertNotNull(TodoReminderStore.get(context, 102))
  }

  @Test
  fun `daily digest posts without buttons and keeps the flag across restarts`() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ShadowAlarmManager.setCanScheduleExactAlarms(true)
    }
    val now = 1_999_999_000_000L
    val digest = sampleRecord(id = 103, todoId = "", fireAtMillis = now + 10_000L)
      .copy(actions = false)
    TodoReminderManager.schedule(context, digest, exact = true, nowMillis = now)
    assertEquals(false, TodoReminderStore.get(context, 103)?.actions)

    TodoReminderReceiver().onReceive(
      context,
      Intent(TodoReminderManager.ACTION_FIRE).putExtra(TodoReminderManager.EXTRA_REMINDER_ID, 103),
    )

    val posted = shadowOf(notificationManager).getNotification(103)
    assertNotNull(posted)
    assertEquals(0, posted.actions?.size ?: 0)
  }

  @Test
  fun `recovery preserves future alarms without exact permission and catches up within 24h`() {
    val now = 2_000_000_000_000L
    val stale = sampleRecord(id = 1, fireAtMillis = now - 25L * 3600L * 1000L)
    val missedRecent = sampleRecord(id = 2, todoId = "t2", fireAtMillis = now - 10L * 60L * 1000L)
    val future = sampleRecord(id = 3, todoId = "t3", fireAtMillis = now + 60L * 60L * 1000L)
    TodoReminderStore.save(context, stale)
    TodoReminderStore.save(context, missedRecent)
    TodoReminderStore.save(context, future)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ShadowAlarmManager.setCanScheduleExactAlarms(false)
    }

    TodoReminderManager.recoverAndRearm(context, recalculateTimezone = false, nowMillis = now)

    assertNull(shadowOf(notificationManager).getNotification(1))
    assertNotNull(shadowOf(notificationManager).getNotification(2))
    assertNull(TodoReminderStore.get(context, 1))
    assertNull(TodoReminderStore.get(context, 2))
    assertNotNull(TodoReminderStore.get(context, 3))
    assertEquals(1, shadowOf(alarmManager).scheduledAlarms.size)
  }

  @Test
  fun `timezone change recovery recalculates wall-clock trigger timestamp`() {
    val tokyo = ZoneId.of("Asia/Tokyo")
    val utc = ZoneId.of("UTC")
    val initialMillis = LocalDateTime.of(2026, 11, 27, 9, 0).atZone(utc).toInstant().toEpochMilli()
    val expectedTokyoMillis = LocalDateTime.of(2026, 11, 27, 9, 0).atZone(tokyo).toInstant().toEpochMilli()
    val now = expectedTokyoMillis - 3_600_000L

    val record = sampleRecord(id = 44, fireAtMillis = initialMillis)
    TodoReminderStore.save(context, record)

    TodoReminderManager.recoverAndRearm(
      context,
      recalculateTimezone = true,
      nowMillis = now,
      zoneId = tokyo,
    )

    val updated = TodoReminderStore.get(context, 44)!!
    assertEquals(expectedTokyoMillis, updated.fireAtMillis)
  }

  @Test
  fun `cancelOccurrence cancels only matching occurrence`() {
    val now = 1_999_999_000_000L
    val a1 = sampleRecord(id = 10, todoId = "todo-a", occurrence = "2026-11-27", fireAtMillis = now + 60_000L)
    val a2 = sampleRecord(id = 11, todoId = "todo-a", occurrence = "2026-11-28", fireAtMillis = now + 120_000L)
    TodoReminderManager.schedule(context, a1, exact = false, nowMillis = now)
    TodoReminderManager.schedule(context, a2, exact = false, nowMillis = now)

    TodoReminderManager.cancelOccurrence(context, "todo-a", "2026-11-27")

    assertNull(TodoReminderStore.get(context, 10))
    assertNotNull(TodoReminderStore.get(context, 11))
  }

  @Test
  fun `channel handles schedule, pending, cancel, and battery status calls`() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ShadowAlarmManager.setCanScheduleExactAlarms(true)
    }
    val powerManager = context.getSystemService(PowerManager::class.java)
    shadowOf(powerManager).setIgnoringBatteryOptimizations(context.packageName, true)
    val messenger = TestChannelMessenger()
    val channel = TodoNotificationsChannel(context, messenger, activityProvider = { null })
    try {
      assertEquals(true, messenger.call("isIgnoringBatteryOptimizations"))
      assertEquals(true, messenger.call("canScheduleExactAlarms"))

      val futureMillis = System.currentTimeMillis() + 600_000L
      messenger.call(
        "scheduleReminder",
        mapOf(
          "id" to 77,
          "todoId" to "t77",
          "occurrence" to "2026-11-27",
          "title" to "Review",
          "body" to "Today",
          "payload" to "todo:{\"t\":\"t77\",\"o\":\"2026-11-27\"}",
          "fireAtMillis" to futureMillis,
          "localYear" to 2026,
          "localMonth" to 11,
          "localDay" to 27,
          "localHour" to 9,
          "localMinute" to 0,
          "snoozeMinutes" to 10,
          "hideOnLockScreen" to false,
          "exact" to true,
          "channelName" to "Reminders",
          "channelDescription" to "Desc",
          "completeLabel" to "Complete",
          "snoozeLabel" to "Snooze",
        ),
      )

      val pending = messenger.call("getPendingReminders") as List<*>
      assertEquals(1, pending.size)
      messenger.call("cancelReminder", mapOf("id" to 77))
      val pendingAfter = messenger.call("getPendingReminders") as List<*>
      assertTrue(pendingAfter.isEmpty())
    } finally {
      channel.dispose()
    }
  }

  private class TestChannelMessenger : BinaryMessenger {
    private var handler: BinaryMessenger.BinaryMessageHandler? = null

    override fun send(channel: String, message: ByteBuffer?) = Unit
    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
      this.handler = handler
    }

    fun call(method: String, arguments: Any? = null): Any? {
      var decoded: Any? = null
      var failure: FlutterException? = null
      val bytes = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, arguments))
      bytes.flip()
      handler!!.onMessage(bytes) { reply ->
        reply!!.flip()
        try {
          decoded = StandardMethodCodec.INSTANCE.decodeEnvelope(reply)
        } catch (error: FlutterException) {
          failure = error
        }
      }
      failure?.let { throw it }
      return decoded
    }
  }
}
