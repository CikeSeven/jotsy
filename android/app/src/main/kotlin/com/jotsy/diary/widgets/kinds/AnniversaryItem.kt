package com.jotsy.diary.widgets.kinds

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import org.json.JSONObject

/**
 * 快照里的一个纪念日（home_widget_anniversary_section.dart）加上按本机今天算出的状态。
 *
 * 天数在原生现算：快照只给接下来几次的日子，应用不在运行时日子照样过，零点重画后就对。
 * 接下来几次都已过去（不重复的倒数日到了之后，或应用两三年没打开）时记为“已经 N 天”，
 * 从首次日期算起——这总是对的。
 */
class AnniversaryItem private constructor(
  val id: String,
  val title: String,
  val pinned: Boolean,
  val repeats: Boolean,
  private val base: LocalDate,
  val lunar: String?,
  private val occurrences: List<Occurrence>,
) {
  class Occurrence(
    val date: LocalDate,
    val dateLabel: String,
    val ordinalLabel: String?,
    val todayLabel: String,
  )

  enum class Phase {
    UPCOMING,
    TODAY,
    PAST,
  }

  /** 相对 [today] 的状态。 */
  class State(
    val phase: Phase,
    /** 还有几天 / 已经几天（今天为 0）。 */
    val days: Long,
    /** 下一次（[Phase.PAST] 时为 null）。 */
    val next: Occurrence?,
  )

  fun state(today: LocalDate): State {
    val next = occurrences.firstOrNull { !it.date.isBefore(today) }
    if (next == null) {
      return State(Phase.PAST, ChronoUnit.DAYS.between(base, today).coerceAtLeast(0), null)
    }
    val days = ChronoUnit.DAYS.between(today, next.date)
    return State(if (days == 0L) Phase.TODAY else Phase.UPCOMING, days, next)
  }

  companion object {
    fun listOf(section: org.json.JSONArray?): List<AnniversaryItem> {
      if (section == null) return emptyList()
      val items = ArrayList<AnniversaryItem>()
      for (i in 0 until section.length()) {
        parse(section.optJSONObject(i))?.let(items::add)
      }
      return items
    }

    private fun parse(node: JSONObject?): AnniversaryItem? {
      if (node == null) return null
      val base = date(node.optString("base")) ?: return null
      val occurrences = ArrayList<Occurrence>()
      val raw = node.optJSONArray("occurrences")
      for (i in 0 until (raw?.length() ?: 0)) {
        val occ = raw!!.optJSONObject(i) ?: continue
        val date = date(occ.optString("date")) ?: continue
        occurrences +=
          Occurrence(
            date = date,
            dateLabel = occ.optString("dateLabel"),
            ordinalLabel = occ.optString("ordinalLabel").ifEmpty { null },
            todayLabel = occ.optString("todayLabel"),
          )
      }
      return AnniversaryItem(
        id = node.optString("id"),
        title = node.optString("title"),
        pinned = node.optBoolean("pinned", false),
        repeats = node.optBoolean("repeats", true),
        base = base,
        lunar = node.optString("lunar").ifEmpty { null },
        occurrences = occurrences,
      )
    }

    private fun date(raw: String?): LocalDate? =
      try {
        raw?.takeIf { it.isNotEmpty() }?.let(LocalDate::parse)
      } catch (_: Exception) {
        null
      }

    /**
     * 按今天重新排：置顶在前；再按下一次由近到远；已过去的排最后（最近过去的在前，即
     * 首次日期较晚的在前）；同一天按名称。与应用的纪念日列表同一口径——快照按构建那天
     * 排过，日子过去后要重排。
     */
    fun sorted(items: List<AnniversaryItem>, today: LocalDate): List<Pair<AnniversaryItem, State>> =
      items
        .map { it to it.state(today) }
        .sortedWith(
          compareBy<Pair<AnniversaryItem, State>> { !it.first.pinned }
            .thenBy { if (it.second.next == null) 1 else 0 }
            .thenBy { it.second.next?.date ?: LocalDate.MAX }
            .thenByDescending { if (it.second.next == null) it.first.base else LocalDate.MIN }
            .thenBy { it.first.title },
        )
  }
}
