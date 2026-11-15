package com.jotsy.diary.widgets.kinds

import com.jotsy.diary.widgets.WidgetDates
import com.jotsy.diary.widgets.WidgetOverlay
import com.jotsy.diary.widgets.WidgetScope
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.roundToInt
import org.json.JSONObject

/**
 * 今天要显示的内容：从快照的 `today` 一节按本机日期挑出这一天（Dart 预算了之后两周，见
 * home_widget_today_section.dart），再按实例的内容选项（农历、节假日、写作、待办、今年
 * 进度）取舍。
 *
 * 超出预算（应用很久没打开）时只用本机算得出的东西：公历日期与星期（按快照的界面语言
 * 格式化），不显示农历、节假日与待办，写作状态显示“还没写”——这些都不会是错的。
 */
class TodayDay private constructor(
  val dayOfMonth: String,
  val weekday: String,
  val weekdayShort: String,
  val monthDay: String,
  val month: String,
  /** 农历 · 节气 / 节日（方块与一行版式的副标题）。 */
  val almanacLine: String?,
  /** 横幅版式的标题（农历月日）与副标题（节气 / 节日）。 */
  val lunarTitle: String?,
  val almanacDetail: String?,
  val holiday: Holiday?,
  val showWriting: Boolean,
  val writingLabel: String,
  private val todosLabel: String?,
  val showYearProgress: Boolean,
  val yearProgress: Float,
  val yearProgressLabel: String,
  /** 今天的日期键（心情脸记在这一天）。 */
  val key: String,
  /** 显示心情脸（内容选项，放得下时才画）。 */
  val showMood: Boolean,
  /** 今天的心情（含桌面上刚点的乐观值）；没有为 null。 */
  val mood: String?,
) {
  class Holiday(val mark: String, val name: String, val work: Boolean)

  /** 底部状态行（图标键 + 文字），写作在前。 */
  fun statusLines(): List<Pair<String, String>> = buildList {
    if (showWriting) add("words" to writingLabel)
    todosLabel?.let { add("todo" to it) }
  }

  companion object {
    fun of(scope: WidgetScope): TodayDay {
      val snapshot = scope.snapshot
      val options = scope.content
      val today = scope.today
      val key = WidgetDates.key(today)
      val section = snapshot.section("today")
      val entry: JSONObject? = section?.optJSONObject("days")?.optJSONObject(key)
      val locale = Locale.forLanguageTag(snapshot.locale)
      val zh = snapshot.locale.startsWith("zh") || snapshot.locale.startsWith("ja")

      val showLunar = options.optBoolean("lunar", false) && entry != null
      val lunar = entry?.optString("lunar")?.ifEmpty { null }
      val almanac = entry?.optString("almanac")?.ifEmpty { null }
      val holidayNode = entry?.optJSONObject("holiday")
      val holiday =
        if (options.optBoolean("holiday", false) && holidayNode != null) {
          Holiday(
            mark = holidayNode.optString("mark"),
            name = holidayNode.optString("name"),
            work = holidayNode.optBoolean("work", false),
          )
        } else {
          null
        }

      val writingLabel =
        section?.optJSONObject("wordsLabel")?.optString(key)?.ifEmpty { null }
          ?: snapshot.string("todayNotWritten")
      val todosLabel =
        if (options.optBoolean("todos", false)) entry?.optString("todosLabel")?.ifEmpty { null }
        else null

      val progress = today.dayOfYear.toFloat() / today.lengthOfYear()
      val percent = "${(progress * 100).roundToInt()}%"

      return TodayDay(
        dayOfMonth = today.dayOfMonth.toString(),
        weekday =
          entry?.optString("weekday")?.ifEmpty { null }
            ?: today.dayOfWeek.getDisplayName(TextStyle.FULL, locale),
        weekdayShort =
          entry?.optString("weekdayShort")?.ifEmpty { null }
            ?: today.dayOfWeek.getDisplayName(TextStyle.SHORT, locale),
        monthDay =
          entry?.optString("monthDay")?.ifEmpty { null }
            ?: if (zh) "${today.monthValue}月${today.dayOfMonth}日"
            else "${today.month.getDisplayName(TextStyle.SHORT, locale)} ${today.dayOfMonth}",
        month =
          entry?.optString("month")?.ifEmpty { null }
            ?: if (zh) "${today.monthValue}月"
            else today.month.getDisplayName(TextStyle.FULL_STANDALONE, locale),
        almanacLine =
          if (showLunar && lunar != null) listOfNotNull(lunar, almanac).joinToString(" · ")
          else null,
        lunarTitle = if (showLunar) lunar else null,
        almanacDetail = if (showLunar) almanac else null,
        holiday = holiday,
        showWriting = options.optBoolean("writing", true),
        writingLabel = writingLabel,
        todosLabel = todosLabel,
        showYearProgress = options.optBoolean("yearProgress", false),
        yearProgress = progress,
        yearProgressLabel = snapshot.string("yearProgress", "%s").replace("%s", percent),
        key = key,
        showMood = options.optBoolean("mood", true),
        mood = WidgetOverlay.mood(scope.overlay, snapshot, key),
      )
    }
  }
}
