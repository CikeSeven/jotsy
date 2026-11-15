package com.jotsy.diary.widgets.kinds

import com.jotsy.diary.widgets.WidgetScope
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * 快照「写作统计」一节（home_widget_stats_section.dart）按本机日期读出来的样子：应用不在
 * 运行时日子照样过，构建之后断了的连续记为 0，换了月 / 年的数字记为 0，热力图里构建
 * 之后的日子是空格。
 */
class WritingStats private constructor(
  val streak: Int,
  val wroteToday: Boolean,
  val monthEntries: String,
  val monthWords: String,
  val yearEntries: String,
  private val heatStart: LocalDate?,
  private val levels: String,
) {
  /**
   * 热力图最近 [weeks] 周（最后一列是本周）每格的档位，按列从上到下排：0–4，今天之后的
   * 日子为 -1（不画）。一周从哪天开始跟快照的起点一致（Dart 按日历设置对齐好了）。
   */
  fun heatLevels(today: LocalDate, weeks: Int): IntArray {
    val start = heatStart ?: return IntArray(weeks * 7) { -1 }
    val offset = Math.floorMod(ChronoUnit.DAYS.between(start, today), 7L).toInt()
    val gridStart = today.minusDays(offset.toLong() + 7L * (weeks - 1))
    return IntArray(weeks * 7) { index ->
      val day = gridStart.plusDays(index.toLong())
      if (day.isAfter(today)) {
        -1
      } else {
        // 快照起点之前与构建之后（还没数据）的日子都按没写画。
        val at = ChronoUnit.DAYS.between(start, day)
        if (at >= 0 && at < levels.length) levels[at.toInt()].digitToIntOrNull() ?: 0 else 0
      }
    }
  }

  companion object {
    fun read(scope: WidgetScope): WritingStats? {
      val section = scope.snapshot.section("stats") ?: return null
      val today = scope.today
      val streakEnd = runCatching { LocalDate.parse(section.optString("streakEnd")) }.getOrNull()
      val gap = streakEnd?.let { ChronoUnit.DAYS.between(it, today) }
      // 连续到昨天为止还算连着（今天还没写）；中间空了一整天就断了。
      val streak = if (gap != null && gap in 0L..1L) section.optInt("streak") else 0
      val month = "%04d-%02d".format(java.util.Locale.ROOT, today.year, today.monthValue)
      val sameMonth = section.optString("month") == month
      val sameYear = section.optInt("year") == today.year
      val heat = section.optJSONObject("heat")
      val basis = scope.content.optString("basis", "entries")
      return WritingStats(
        streak = streak,
        wroteToday = gap == 0L && streak > 0,
        monthEntries = if (sameMonth) section.optString("monthEntries", "0") else "0",
        monthWords = if (sameMonth) section.optString("monthWords", "0") else "0",
        yearEntries = if (sameYear) section.optString("yearEntries", "0") else "0",
        heatStart = heat?.let { runCatching { LocalDate.parse(it.optString("start")) }.getOrNull() },
        levels = heat?.optString(if (basis == "words") "words" else "entries").orEmpty(),
      )
    }
  }
}
