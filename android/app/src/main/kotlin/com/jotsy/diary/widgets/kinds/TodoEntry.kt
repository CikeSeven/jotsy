package com.jotsy.diary.widgets.kinds

import com.jotsy.diary.widgets.WidgetOverlay
import com.jotsy.diary.widgets.WidgetScope
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import org.json.JSONArray
import org.json.JSONObject

/**
 * 快照「待办」一节里的一条（home_widget_todos_section.dart），加上桌面上刚勾选 / 取消的
 * 乐观值。
 */
class TodoEntry private constructor(
  val id: String,
  val title: String,
  val due: LocalDate?,
  private val dueLabel: String?,
  val time: String?,
  val list: String?,
  val repeat: Boolean,
  val done: Boolean,
) {
  /**
   * 截止日的说法与是否逾期：昨天 / 今天 / 明天用相对说法，其余为日期；“今天”视图里今天
   * 的不写日期（整个小组件就是今天），只写时刻。没有截止日时只有时刻（或什么都没有）。
   */
  fun dueText(scope: WidgetScope, todayView: Boolean): Pair<String, Boolean>? {
    val snapshot = scope.snapshot
    val date = due
    if (date == null) return time?.let { it to false }
    val days = ChronoUnit.DAYS.between(scope.today, date)
    val day =
      when {
        days == 0L && todayView -> null
        days == 0L -> snapshot.string("todoToday")
        days == 1L -> snapshot.string("todoTomorrow")
        days == -1L -> snapshot.string("todoYesterday")
        else -> dueLabel
      }
    val text = listOfNotNull(day, time).joinToString(" ").ifEmpty { return null }
    return text to (days < 0 && !done)
  }

  companion object {
    /** 未完成的与今天完成的，各自按快照里的顺序；乐观值把条目在两边之间挪动。 */
    fun read(scope: WidgetScope): Pair<List<TodoEntry>, List<TodoEntry>> {
      val section = scope.snapshot.section("todos") ?: return emptyList<TodoEntry>() to emptyList()
      val open = parse(section.optJSONArray("open"), done = false)
      val done = parse(section.optJSONArray("done"), done = true)
      val overlay = scope.overlay
      fun state(entry: TodoEntry) =
        WidgetOverlay.todoDone(overlay, scope.snapshot, entry.id) ?: entry.done
      val nowOpen = (open + done).filter { !state(it) }.map { it.withDone(false) }
      // 刚勾选的排在“今天完成的”最前面，与应用里刚完成的那条位置一致。
      val justDone = open.filter { state(it) }.map { it.withDone(true) }
      val nowDone = justDone + done.filter { state(it) }
      return nowOpen to nowDone
    }

    private fun parse(array: JSONArray?, done: Boolean): List<TodoEntry> {
      if (array == null) return emptyList()
      val entries = ArrayList<TodoEntry>(array.length())
      for (i in 0 until array.length()) {
        val node: JSONObject = array.optJSONObject(i) ?: continue
        val id = node.optString("id").ifEmpty { continue }
        entries +=
          TodoEntry(
            id = id,
            title = node.optString("title"),
            due =
              try {
                node.optString("due").ifEmpty { null }?.let(LocalDate::parse)
              } catch (_: Exception) {
                null
              },
            dueLabel = node.optString("dueLabel").ifEmpty { null },
            time = node.optString("time").ifEmpty { null },
            list = node.optString("list").ifEmpty { null },
            repeat = node.optBoolean("repeat", false),
            done = done,
          )
      }
      return entries
    }
  }

  private fun withDone(value: Boolean) =
    if (value == done) this else TodoEntry(id, title, due, dueLabel, time, list, repeat, value)
}
