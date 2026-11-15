package com.jotsy.diary.widgets

import android.content.Context
import android.content.SharedPreferences
import androidx.glance.GlanceId
import androidx.glance.action.Action
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import com.jotsy.diary.widgets.kinds.MoodCalendarWidget
import com.jotsy.diary.widgets.kinds.TodayWidget
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

/**
 * 桌面上不打开应用就完成的点按（docs/rules/home_widgets.md「桌面上的操作」）。
 *
 * 流程：先改原生这边看得到的状态并立即重画（乐观更新，[WidgetOverlay]），再把
 * `jotsy://widget-action/...` 经 home_widget 的后台广播交给 Dart 写库
 * （`homeWidgetBackgroundCallback`：应用在运行时转交主 isolate，否则后台引擎自己写库
 * 并重建快照）。翻月这类只影响显示的操作不经过 Dart。
 */
object WidgetActions {
  private val DayKey = ActionParameters.Key<String>("day")
  private val MoodKey = ActionParameters.Key<String>("mood")
  private val DeltaKey = ActionParameters.Key<Int>("delta")

  /** 点某天的一张心情脸：已是这种心情时取消。 */
  fun setMood(day: String, mood: String): Action =
    actionRunCallback<SetMoodAction>(actionParametersOf(DayKey to day, MoodKey to mood))

  /** 心情月历翻月（[delta] 为 -1 / +1）。 */
  fun shiftMonth(delta: Int): Action =
    actionRunCallback<ShiftMonthAction>(actionParametersOf(DeltaKey to delta))

  class SetMoodAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
      val day = parameters[DayKey] ?: return
      val mood = parameters[MoodKey] ?: return
      val preferences = WidgetState.homeWidgetPreferences(context)
      val snapshot = WidgetSnapshot.read(preferences)
      val current = WidgetOverlay.mood(WidgetOverlay.read(preferences), snapshot, day)
      val next = if (current == mood) "" else mood
      WidgetOverlay.putMood(context, day, next)
      WidgetState.redrawAll(context, TodayWidget())
      WidgetState.redrawAll(context, MoodCalendarWidget())
      HomeWidgetBackgroundIntent.getBroadcast(
          context,
          android.net.Uri.Builder()
            .scheme("jotsy")
            .authority("widget-action")
            .appendPath("mood")
            .appendQueryParameter("day", day)
            .appendQueryParameter("mood", next)
            .build(),
        )
        .send()
    }
  }

  class ShiftMonthAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
      val delta = parameters[DeltaKey] ?: return
      val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
      val offset = WidgetState.monthOffset(context, appWidgetId) + delta
      WidgetState.setMonthOffset(context, appWidgetId, offset)
      WidgetState.redraw(context, MoodCalendarWidget(), glanceId)
    }
  }
}

/** 原生自己记的小状态与重画入口。 */
object WidgetState {
  /** 翻月的状态多久后回到这个月：只是临时往回看看，下次看到时应在这个月。 */
  private const val MONTH_OFFSET_LIFETIME_MS = 10 * 60 * 1000L

  fun homeWidgetPreferences(context: Context): SharedPreferences =
    context.getSharedPreferences(HOME_WIDGET_PREFERENCES, Context.MODE_PRIVATE)

  private fun own(context: Context): SharedPreferences =
    context.getSharedPreferences("JotsyWidgetState", Context.MODE_PRIVATE)

  /** 心情月历往回翻了几个月（0 为这个月，负数为之前）；过期后回到 0。 */
  fun monthOffset(context: Context, appWidgetId: Int): Int {
    val raw = own(context).getString("month.$appWidgetId", null) ?: return 0
    val (offset, at) = raw.split('|').let { (it.getOrNull(0)?.toIntOrNull() ?: 0) to (it.getOrNull(1)?.toLongOrNull() ?: 0L) }
    return if (System.currentTimeMillis() - at > MONTH_OFFSET_LIFETIME_MS) 0 else offset
  }

  fun setMonthOffset(context: Context, appWidgetId: Int, offset: Int) {
    own(context).edit().putString("month.$appWidgetId", "$offset|${System.currentTimeMillis()}").apply()
  }

  /** 让某种小组件的全部实例按最新的状态重画。 */
  suspend fun redrawAll(context: Context, widget: GlanceAppWidget) {
    for (id in GlanceAppWidgetManager(context).getGlanceIds(widget.javaClass)) {
      redraw(context, widget, id)
    }
  }

  /** 重画一个实例：先让 Glance 重新读一遍状态（SharedPreferences），再重组。 */
  suspend fun redraw(context: Context, widget: GlanceAppWidget, id: GlanceId) {
    updateAppWidgetState(context, HomeWidgetGlanceStateDefinition(), id) { it }
    widget.update(context, id)
  }

  /** home_widget 存数据的 SharedPreferences（插件里的常量是 internal，这里写同一个名字）。 */
  private const val HOME_WIDGET_PREFERENCES = "HomeWidgetPreferences"
}
