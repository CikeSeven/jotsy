package com.jotsy.diary.widgets.kinds

import androidx.glance.action.Action
import com.jotsy.diary.widgets.WidgetDates
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetScope

// 快速记录（QuickCaptureWidget.kt）的数据部分：动作清单与它们的链接、问候与眉标日期。

/** 一个动作：图标键、文字与点按打开的链接。 */
internal class QuickAction(val icon: String, val label: String, val action: Action) {
  companion object {
    fun listOf(scope: WidgetScope): List<QuickAction> {
      val snapshot = scope.snapshot
      val names = scope.content.optJSONArray("actions")
      val notebook = scope.content.optString("notebook").ifEmpty { null }
      val result = ArrayList<QuickAction>()
      for (index in 0 until (names?.length() ?: 0)) {
        when (names!!.optString(index)) {
          "write" ->
            result += QuickAction(
              "write",
              snapshot.string("actionWrite"),
              WidgetLaunch.action(scope.context, "write", mapOf("notebook" to notebook)),
            )
          "todo" ->
            result += QuickAction(
              "todo",
              snapshot.string("actionTodo"),
              WidgetLaunch.action(scope.context, "todo-new"),
            )
          "calendar" ->
            result += QuickAction(
              "calendar",
              snapshot.string("actionCalendar"),
              WidgetLaunch.action(
                scope.context,
                "calendar",
                mapOf("day" to WidgetDates.key(scope.today)),
              ),
            )
          "search" ->
            result += QuickAction(
              "search",
              snapshot.string("actionSearch"),
              WidgetLaunch.action(scope.context, "search"),
            )
        }
      }
      if (result.isEmpty()) {
        result += QuickAction(
          "write",
          snapshot.string("actionWrite"),
          WidgetLaunch.action(scope.context, "write"),
        )
      }
      return result
    }
  }
}

internal fun WidgetScope.showLabels() = content.optBoolean("labels", true)

internal fun WidgetScope.showGreeting() = content.optBoolean("greeting", true)

/** 此刻的问候：5–11 点早上，11–18 点下午，18–23 点晚上，其余深夜。 */
internal fun WidgetScope.greeting(): String =
  when (now.hour) {
    in 5..10 -> snapshot.string("greetingMorning")
    in 11..17 -> snapshot.string("greetingAfternoon")
    in 18..22 -> snapshot.string("greetingEvening")
    else -> snapshot.string("greetingNight")
  }

/** 眉标日期：“11月15日 · 周六”。 */
internal fun WidgetScope.eyebrow(): String {
  val entry =
    snapshot.section("today")?.optJSONObject("days")?.optJSONObject(WidgetDates.key(today))
  val monthDay = entry?.optString("monthDay")?.ifEmpty { null }
  val weekday = entry?.optString("weekdayShort")?.ifEmpty { null }
  return listOfNotNull(monthDay, weekday).joinToString(" · ").ifEmpty {
    "${today.monthValue}/${today.dayOfMonth}"
  }
}
