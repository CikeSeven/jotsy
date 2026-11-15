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
import com.jotsy.diary.widgets.kinds.OnThisDayWidget
import com.jotsy.diary.widgets.kinds.TodayWidget
import com.jotsy.diary.widgets.kinds.TodosWidget
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

/**
 * 桌面上不打开应用就完成的点按（docs/rules/home_widgets.md「桌面上的操作」）。
 *
 * 流程：先改原生这边看得到的状态并立即重画（乐观更新，[WidgetOverlay]），再把
 * `jotsy://widget-action/...` 经 home_widget 的后台广播交给 Dart 写库
 * （`homeWidgetBackgroundCallback`：应用在运行时转交主 isolate，否则后台引擎自己写库
 * 并重建快照）。翻月、翻篇这类只影响显示的操作不经过 Dart。
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

  /** 那年今日翻到上一篇 / 下一篇（[delta] 为 -1 / +1，首尾相接）。 */
  fun shiftEntry(delta: Int): Action =
    actionRunCallback<ShiftEntryAction>(actionParametersOf(DeltaKey to delta))

  private val TodoKey = ActionParameters.Key<String>("todo")
  private val DueKey = ActionParameters.Key<String>("due")

  /** 勾选一条待办的这一次（[due] 为小组件上显示的截止日，没有为空串）。 */
  fun completeTodo(todoId: String, due: String?): Action =
    actionRunCallback<CompleteTodoAction>(actionParametersOf(TodoKey to todoId, DueKey to (due ?: "")))

  /** 把今天完成的一条恢复为未完成。 */
  fun reopenTodo(todoId: String): Action =
    actionRunCallback<ReopenTodoAction>(actionParametersOf(TodoKey to todoId))

  /** 交给 Dart 写库：`jotsy://widget-action/<动作>?参数`（Dart `HomeWidgetAction.parse`）。 */
  private fun sendToDart(context: Context, action: String, params: Map<String, String>) {
    val uri =
      android.net.Uri.Builder().scheme("jotsy").authority("widget-action").appendPath(action).apply {
        params.forEach { (key, value) -> appendQueryParameter(key, value) }
      }.build()
    HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
  }

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
      sendToDart(context, "mood", mapOf("day" to day, "mood" to next))
    }
  }

  class CompleteTodoAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
      val todoId = parameters[TodoKey] ?: return
      val due = parameters[DueKey] ?: ""
      WidgetOverlay.putTodo(context, todoId, done = true)
      WidgetState.redrawAll(context, TodosWidget())
      sendToDart(context, "todo-complete", mapOf("id" to todoId, "due" to due))
    }
  }

  class ReopenTodoAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
      val todoId = parameters[TodoKey] ?: return
      WidgetOverlay.putTodo(context, todoId, done = false)
      WidgetState.redrawAll(context, TodosWidget())
      sendToDart(context, "todo-reopen", mapOf("id" to todoId))
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

  class ShiftEntryAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
      val delta = parameters[DeltaKey] ?: return
      val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
      val today = WidgetDates.key(java.time.LocalDate.now())
      WidgetState.setEntryIndex(context, appWidgetId, today, WidgetState.entryIndex(context, appWidgetId, today) + delta)
      WidgetState.redraw(context, OnThisDayWidget(), glanceId)
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

  /**
   * 那年今日翻到了第几篇（未取模，绘制时按篇数取模）。只在同一天内有效：换了一天
   * 回到第一篇（最近的那一年）。
   */
  fun entryIndex(context: Context, appWidgetId: Int, day: String): Int {
    val raw = own(context).getString("entry.$appWidgetId", null) ?: return 0
    val parts = raw.split('|')
    return if (parts.getOrNull(0) == day) parts.getOrNull(1)?.toIntOrNull() ?: 0 else 0
  }

  fun setEntryIndex(context: Context, appWidgetId: Int, day: String, index: Int) {
    own(context).edit().putString("entry.$appWidgetId", "$day|$index").apply()
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
