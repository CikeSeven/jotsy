package com.jotsy.diary.widgets.kinds

import com.jotsy.diary.widgets.WidgetDates
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetSnapshot
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import org.json.JSONArray

/**
 * 快照 `diaries` 一节里的一篇日记（home_widget_diary_sections.dart），那年今日与最近日记
 * 共用。[label] 是那年今日这一天给它的说法（“3 年前的今天”或日期）。
 *
 * 应用锁开着时快照里没有这一节（小组件先显示锁定占位，不会走到这里）。
 */
class DiaryEntry private constructor(
  val id: String,
  private val title: String,
  private val excerpt: String,
  val created: LocalDate?,
  val day: Int,
  val month: String,
  private val monthDay: String,
  val date: String,
  val mood: String?,
  val photo: String?,
  val label: String?,
) {
  /** 大字那一行：标题；没有标题时用正文开头，都没有时“记录了一则内容”。 */
  fun headline(snapshot: WidgetSnapshot): String =
    title.ifEmpty { excerpt.ifEmpty { snapshot.string("untitled") } }

  /** 标题下面的摘要：没有标题时正文已经当了标题，不再重复。 */
  val body: String?
    get() = if (title.isEmpty()) null else excerpt.ifEmpty { null }

  /** 最近日记里的日期说法：今天 / 昨天，今年的写月日，往年的写完整日期。 */
  fun relativeDate(scope: WidgetScope): String {
    val created = created ?: return monthDay
    return when (ChronoUnit.DAYS.between(created, scope.today)) {
      0L -> scope.snapshot.string("todoToday", monthDay)
      1L -> scope.snapshot.string("todoYesterday", monthDay)
      else -> if (created.year == scope.today.year) monthDay else date
    }
  }

  companion object {
    private fun read(snapshot: WidgetSnapshot, id: String, label: String?): DiaryEntry? {
      val node = snapshot.section("diaries")?.optJSONObject(id) ?: return null
      return DiaryEntry(
        id = id,
        title = node.optString("title"),
        excerpt = node.optString("excerpt"),
        created = runCatching { LocalDate.parse(node.optString("created")) }.getOrNull(),
        day = node.optInt("day"),
        month = node.optString("month"),
        monthDay = node.optString("monthDay"),
        date = node.optString("date"),
        mood = node.optString("mood").ifEmpty { null },
        photo = node.optString("photo").ifEmpty { null },
        label = label?.ifEmpty { null },
      )
    }

    /**
     * 那年今日这一天按实例的匹配口径选出的日记（快照里的顺序：最近的年份在前）。今天超出
     * 快照预算的天数（应用很久没打开）时为 null：不显示可能过期的内容。
     */
    fun onThisDay(
      scope: WidgetScope,
      match: String = scope.content.optString("match", "sameDay"),
    ): List<DiaryEntry>? {
      val days = scope.snapshot.section("onThisDay")?.optJSONObject("days") ?: return null
      val day = days.optJSONObject(WidgetDates.key(scope.today)) ?: return null
      val list = day.optJSONArray(match) ?: day.optJSONArray("sameDay") ?: JSONArray()
      return (0 until list.length()).mapNotNull { index ->
        val item = list.optJSONObject(index) ?: return@mapNotNull null
        read(scope.snapshot, item.optString("id"), item.optString("label"))
      }
    }

    /** 按 id 取一篇（照片回忆的候选只存 id）；快照里没有时为 null。 */
    fun byId(snapshot: WidgetSnapshot, id: String): DiaryEntry? = read(snapshot, id, null)

    /** 最近日记这个实例的来源下的日记（从新到旧）。 */
    fun recent(scope: WidgetScope): List<DiaryEntry> {
      val recent = scope.snapshot.section("recent") ?: return emptyList()
      val list =
        recent.optJSONArray(scope.content.optString("source", "all")) ?: recent.optJSONArray("all")
          ?: return emptyList()
      return (0 until list.length()).mapNotNull { read(scope.snapshot, list.optString(it), null) }
    }
  }
}
