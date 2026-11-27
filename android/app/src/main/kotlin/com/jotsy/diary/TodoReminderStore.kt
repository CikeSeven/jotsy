package com.jotsy.diary

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Persisted descriptor for one scheduled Android to-do reminder.
 *
 * Stored as plain JSON per reminder id (not Gson reflection) so R8 shrinking can never break
 * cold-start deserialization inside BroadcastReceivers or WorkManager workers.
 */
data class TodoReminderRecord(
  val id: Int,
  val todoId: String,
  val occurrence: String,
  val title: String,
  val body: String,
  val payload: String,
  val fireAtMillis: Long,
  val localYear: Int,
  val localMonth: Int,
  val localDay: Int,
  val localHour: Int,
  val localMinute: Int,
  val snoozeMinutes: Int,
  val hideOnLockScreen: Boolean,
  val channelName: String,
  val channelDescription: String,
  val completeLabel: String,
  val snoozeLabel: String,
  /** False for the daily digest: it is not tied to one to-do, so no complete / snooze buttons. */
  val actions: Boolean = true,
) {
  fun toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("todoId", todoId)
    put("occurrence", occurrence)
    put("title", title)
    put("body", body)
    put("payload", payload)
    put("fireAtMillis", fireAtMillis)
    put("localYear", localYear)
    put("localMonth", localMonth)
    put("localDay", localDay)
    put("localHour", localHour)
    put("localMinute", localMinute)
    put("snoozeMinutes", snoozeMinutes)
    put("hideOnLockScreen", hideOnLockScreen)
    put("channelName", channelName)
    put("channelDescription", channelDescription)
    put("completeLabel", completeLabel)
    put("snoozeLabel", snoozeLabel)
    put("actions", actions)
  }

  fun toPendingMap(): Map<String, Any> = mapOf(
    "id" to id,
    "payload" to payload,
  )

  fun recalculateForTimeZone(zoneId: ZoneId = ZoneId.systemDefault()): TodoReminderRecord {
    val recalculated = runCatching {
      LocalDateTime.of(localYear, localMonth, localDay, localHour, localMinute)
        .atZone(zoneId)
        .toInstant()
        .toEpochMilli()
    }.getOrNull() ?: return this
    return copy(fireAtMillis = recalculated)
  }

  companion object {
    fun fromJsonString(raw: String?): TodoReminderRecord? {
      if (raw.isNullOrBlank()) return null
      return runCatching {
        val obj = JSONObject(raw)
        val id = obj.optInt("id", -1)
        val payload = obj.optString("payload", "")
        if (id < 0 || payload.isEmpty()) return null
        val fireAtMillis = obj.optLong("fireAtMillis", -1L)
        if (fireAtMillis <= 0L) return null
        TodoReminderRecord(
          id = id,
          todoId = obj.optString("todoId", ""),
          occurrence = obj.optString("occurrence", ""),
          title = obj.optString("title", ""),
          body = obj.optString("body", ""),
          payload = payload,
          fireAtMillis = fireAtMillis,
          localYear = obj.optInt("localYear", 0),
          localMonth = obj.optInt("localMonth", 0),
          localDay = obj.optInt("localDay", 0),
          localHour = obj.optInt("localHour", 0),
          localMinute = obj.optInt("localMinute", 0),
          snoozeMinutes = obj.optInt("snoozeMinutes", 10).coerceAtLeast(1),
          hideOnLockScreen = obj.optBoolean("hideOnLockScreen", false),
          channelName = obj.optString("channelName", "To-do reminders"),
          channelDescription = obj.optString("channelDescription", ""),
          completeLabel = obj.optString("completeLabel", "Complete"),
          snoozeLabel = obj.optString("snoozeLabel", "Snooze"),
          actions = obj.optBoolean("actions", true),
        )
      }.getOrNull()
    }

    fun fromMethodArguments(args: Map<*, *>?): TodoReminderRecord? {
      if (args == null) return null
      val id = (args["id"] as? Number)?.toInt() ?: return null
      val payload = args["payload"] as? String ?: return null
      val fireAtMillis = (args["fireAtMillis"] as? Number)?.toLong() ?: return null
      return TodoReminderRecord(
        id = id,
        todoId = args["todoId"] as? String ?: "",
        occurrence = args["occurrence"] as? String ?: "",
        title = args["title"] as? String ?: "",
        body = args["body"] as? String ?: "",
        payload = payload,
        fireAtMillis = fireAtMillis,
        localYear = (args["localYear"] as? Number)?.toInt() ?: 0,
        localMonth = (args["localMonth"] as? Number)?.toInt() ?: 0,
        localDay = (args["localDay"] as? Number)?.toInt() ?: 0,
        localHour = (args["localHour"] as? Number)?.toInt() ?: 0,
        localMinute = (args["localMinute"] as? Number)?.toInt() ?: 0,
        snoozeMinutes = ((args["snoozeMinutes"] as? Number)?.toInt() ?: 10).coerceAtLeast(1),
        hideOnLockScreen = args["hideOnLockScreen"] as? Boolean ?: false,
        channelName = (args["channelName"] as? String)?.takeIf { it.isNotBlank() }
          ?: "To-do reminders",
        channelDescription = args["channelDescription"] as? String ?: "",
        completeLabel = (args["completeLabel"] as? String)?.takeIf { it.isNotBlank() }
          ?: "Complete",
        snoozeLabel = (args["snoozeLabel"] as? String)?.takeIf { it.isNotBlank() }
          ?: "Snooze",
        actions = args["actions"] as? Boolean ?: true,
      )
    }
  }
}

/**
 * Atomic SharedPreferences store for pending Android to-do reminders and background callback metadata.
 *
 * Uses [SharedPreferences.Editor.commit] on writes so an immediate process kill after saving a
 * reminder never drops the persisted record.
 */
object TodoReminderStore {
  private const val PREFS_NAME = "jotsy_todo_reminders"
  private const val REMINDER_PREFIX = "reminder_"
  private const val KEY_ACTION_CALLBACK_HANDLE = "meta.action_callback_handle"

  private fun prefs(context: Context): SharedPreferences =
    context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

  private fun keyFor(id: Int): String = "$REMINDER_PREFIX$id"

  fun save(context: Context, record: TodoReminderRecord) {
    prefs(context).edit().putString(keyFor(record.id), record.toJson().toString()).commit()
  }

  fun get(context: Context, id: Int): TodoReminderRecord? =
    TodoReminderRecord.fromJsonString(prefs(context).getString(keyFor(id), null))

  fun remove(context: Context, id: Int) {
    prefs(context).edit().remove(keyFor(id)).commit()
  }

  fun loadAll(context: Context): List<TodoReminderRecord> {
    val all = prefs(context).all
    if (all.isEmpty()) return emptyList()
    val records = ArrayList<TodoReminderRecord>()
    for ((key, value) in all) {
      if (!key.startsWith(REMINDER_PREFIX)) continue
      val record = TodoReminderRecord.fromJsonString(value as? String)
      if (record != null) {
        records.add(record)
      }
    }
    records.sortBy { it.fireAtMillis }
    return records
  }

  fun hasPending(context: Context): Boolean =
    prefs(context).all.keys.any { it.startsWith(REMINDER_PREFIX) }

  fun saveActionCallbackHandle(context: Context, handle: Long) {
    prefs(context).edit().putLong(KEY_ACTION_CALLBACK_HANDLE, handle).commit()
  }

  fun getActionCallbackHandle(context: Context): Long =
    prefs(context).getLong(KEY_ACTION_CALLBACK_HANDLE, 0L)
}
