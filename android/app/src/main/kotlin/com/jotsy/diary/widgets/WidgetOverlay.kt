package com.jotsy.diary.widgets

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * 桌面上操作的乐观更新：点了心情脸，立刻按新值重画，不等 Dart 写库、重建快照
 * （后台引擎冷启动要一两秒）。
 *
 * 存在 `HomeWidgetPreferences` 的 [KEY]：`{"moods": {"YYYY-MM-DD": {"m": 心情或空串, "at": 毫秒}}}`。
 * 只有比快照构建时刻（[WidgetSnapshot.builtAt]）新的条目才覆盖快照：Dart 写完库、重建
 * 快照后，快照里已经是新值，旧条目自然失效，不需要专门清理（每次写入时顺手删掉过期的）。
 */
object WidgetOverlay {
  const val KEY = "jotsy.widgets.overlay"

  /** 覆盖后的这天的心情：有更新的乐观值时取它（空串为已取消），否则取快照。 */
  fun mood(overlay: JSONObject?, snapshot: WidgetSnapshot, day: String): String? {
    val entry = overlay?.optJSONObject("moods")?.optJSONObject(day)
    if (entry != null && entry.optLong("at") > snapshot.builtAt) {
      return entry.optString("m").ifEmpty { null }
    }
    return snapshot.section("today")?.optJSONObject("moods")?.optString(day)?.ifEmpty { null }
  }

  /** 心情月历上这天的心情段：有更新的乐观值时按它（取消则退回快照里日记的平均）。 */
  fun moodBand(overlay: JSONObject?, snapshot: WidgetSnapshot, day: String, fallback: Int?): Int? {
    val entry = overlay?.optJSONObject("moods")?.optJSONObject(day)
    if (entry == null || entry.optLong("at") <= snapshot.builtAt) return fallback
    val mood = entry.optString("m")
    return if (mood.isEmpty()) fallback else WidgetMoodFace.MOODS.indexOf(mood).takeIf { it >= 0 }
  }

  fun read(preferences: SharedPreferences): JSONObject? =
    try {
      preferences.getString(KEY, null)?.let { JSONObject(it) }
    } catch (_: Exception) {
      null
    }

  /** 记下一次乐观更新（[mood] 为空串表示取消）。 */
  fun putMood(context: Context, day: String, mood: String) {
    val preferences = WidgetState.homeWidgetPreferences(context)
    val snapshot = WidgetSnapshot.read(preferences)
    val root = read(preferences) ?: JSONObject()
    val moods = root.optJSONObject("moods") ?: JSONObject()
    // 顺手删掉已被快照追上的旧条目。
    val stale = moods.keys().asSequence().filter {
      (moods.optJSONObject(it)?.optLong("at") ?: 0L) <= snapshot.builtAt
    }.toList()
    stale.forEach { moods.remove(it) }
    moods.put(day, JSONObject().put("m", mood).put("at", System.currentTimeMillis()))
    root.put("moods", moods)
    preferences.edit().putString(KEY, root.toString()).apply()
  }
}
