package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import androidx.glance.unit.ColorProvider
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetActions
import com.jotsy.diary.widgets.WidgetDates
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetOverlay
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetState
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import org.json.JSONObject

/**
 * 心情月历：这个月的日期网格，每格按这天的心情着色（这天的心情优先，其次是当天日记的
 * 平均心情，与日历年视图同一口径，五档配色与应用日历的 `DayMoodColors` 一致），写过日记
 * 的日子在数字下方打点，今天加粗并画一道强调色短线，法定节假日在右上角标“休 / 班”。
 *
 * 表头是月份与“写了 N 天”，右侧可往回翻两个月（只是临时看看，十分钟后回到这个月，见
 * [WidgetState.monthOffset]）。一周从哪天开始跟随日历设置。点某天打开日历的那一天。
 *
 * 跨月零点后快照里还没有新的一个月时，只画日期（不画心情与打点），等应用下次同步。
 */
class MoodCalendarWidget : JotsyGlanceWidget(KIND, setOf(SMALL, MEDIUM, WIDE, LARGE)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val section = scope.snapshot.section("calendar")
    val offset =
      scope.appWidgetId?.let { WidgetState.monthOffset(scope.context, it) }?.coerceIn(-MONTHS_BACK, 0) ?: 0
    val month = scope.today.withDayOfMonth(1).plusMonths(offset.toLong())
    val data = section?.optJSONObject("months")?.optJSONObject("%04d-%02d".format(Locale.ROOT, month.year, month.monthValue))
    // 宽或高任一不足中等尺寸就用紧凑字号：4×2 的高度放 6 行日期很紧。
    val compact = scope.size.width < MEDIUM.width || scope.size.height < MEDIUM.height
    WidgetFrame(scope, null) {
      Column(modifier = GlanceModifier.fillMaxSize()) {
        Header(scope, month, data, offset, compact)
        Spacer(GlanceModifier.height(if (compact) 2.dp else 6.dp))
        Grid(scope, month, data, section, compact)
      }
    }
  }

  companion object {
    const val KIND = "mood_calendar"
    /** 能往回翻几个月，与 Dart `kHomeWidgetMonthsBack` 一致。 */
    const val MONTHS_BACK = 2
    val SMALL = DpSize(110.dp, 110.dp)
    val MEDIUM = DpSize(180.dp, 180.dp)
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)
  }
}

class MoodCalendarWidgetReceiver : HomeWidgetGlanceWidgetReceiver<MoodCalendarWidget>() {
  override val glanceAppWidget = MoodCalendarWidget()
}

@Composable
private fun Header(
  scope: WidgetScope,
  month: LocalDate,
  data: JSONObject?,
  offset: Int,
  compact: Boolean,
) {
  val colors = scope.colors
  val title = data?.optString("title")?.ifEmpty { null } ?: monthTitle(scope, month)
  Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
    Row(
      modifier =
        GlanceModifier.defaultWeight()
          .clickable(
            WidgetLaunch.action(scope.context, "calendar", mapOf("day" to WidgetDates.key(scope.today))),
          ),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      WidgetText(scope, title, if (compact) 12f else 14f, colors.content, FontWeight.Bold)
      if (!compact) {
        data?.optString("writtenLabel")?.ifEmpty { null }?.let {
          Spacer(GlanceModifier.width(8.dp))
          WidgetText(scope, it, 11f, colors.contentVariant)
        }
      }
    }
    val canBack = offset > -MoodCalendarWidget.MONTHS_BACK
    val canForward = offset < 0
    Arrow(scope, "previous", canBack, -1, compact)
    Arrow(scope, "next", canForward, 1, compact)
  }
}

@Composable
private fun Arrow(scope: WidgetScope, icon: String, enabled: Boolean, delta: Int, compact: Boolean) {
  val size = if (compact) 22.dp else 28.dp
  var modifier = GlanceModifier.size(size)
  if (enabled) modifier = modifier.clickable(WidgetActions.shiftMonth(delta))
  Box(modifier = modifier, contentAlignment = Alignment.Center) {
    WidgetIcon(scope, icon, if (compact) 11.dp else 13.dp, if (enabled) scope.colors.contentVariant else scope.colors.track)
  }
}

@Composable
private fun Grid(
  scope: WidgetScope,
  month: LocalDate,
  data: JSONObject?,
  section: JSONObject?,
  compact: Boolean,
) {
  val colors = scope.colors
  val firstWeekday = section?.optInt("firstWeekday", 1)?.coerceIn(1, 7) ?: 1
  val names = section?.optJSONArray("weekdays")
  val lead = (month.dayOfWeek.value - firstWeekday + 7) % 7
  val days = month.lengthOfMonth()
  val rows = (lead + days + 6) / 7
  val numberSize = if (compact) 9.5f else 12f
  Column(modifier = GlanceModifier.fillMaxSize()) {
    Row(modifier = GlanceModifier.fillMaxWidth()) {
      for (i in 0 until 7) {
        val weekday = (firstWeekday - 1 + i) % 7 // 0 = 周一
        val name =
          names?.optString(weekday)?.ifEmpty { null }
            ?: java.time.DayOfWeek.of(weekday + 1).getDisplayName(TextStyle.NARROW, Locale.forLanguageTag(scope.snapshot.locale))
        WidgetText(
          scope,
          name,
          if (compact) 8.5f else 10f,
          colors.contentVariant,
          align = TextAlign.Center,
          modifier = GlanceModifier.defaultWeight(),
        )
      }
    }
    Spacer(GlanceModifier.height(2.dp))
    for (row in 0 until rows) {
      Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
        for (column in 0 until 7) {
          val day = row * 7 + column - lead + 1
          Box(modifier = GlanceModifier.defaultWeight().fillMaxHeight().padding(1.dp)) {
            if (day in 1..days) Cell(scope, month.withDayOfMonth(day), data, numberSize)
          }
        }
      }
    }
  }
}

@Composable
private fun Cell(scope: WidgetScope, date: LocalDate, data: JSONObject?, numberSize: Float) {
  val colors = scope.colors
  val key = WidgetDates.key(date)
  val node = data?.optJSONObject("days")?.optJSONObject(date.dayOfMonth.toString())
  val showMoods = scope.content.optBoolean("moods", true)
  val showWritten = scope.content.optBoolean("written", true)
  val showHoliday = scope.content.optBoolean("holiday", false)
  val stored = node?.takeIf { it.has("b") }?.optInt("b")
  val band = WidgetOverlay.moodBand(scope.overlay, scope.snapshot, key, stored)
  val tile = if (showMoods && band != null && band in 0..4) colors.moodTiles[band] else null
  val written = showWritten && (node?.optInt("w", 0) ?: 0) > 0
  val isToday = date == scope.today
  val foreground: ColorProvider = tile?.second ?: if (isToday) colors.accent else colors.content
  var modifier =
    GlanceModifier.fillMaxSize()
      .clickable(WidgetLaunch.action(scope.context, "calendar", mapOf("day" to key)))
  if (tile != null) modifier = modifier.roundedBackground(tile.first, 6.dp)
  Box(modifier = modifier, contentAlignment = Alignment.Center) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
      WidgetText(
        scope,
        date.dayOfMonth.toString(),
        numberSize,
        foreground,
        if (isToday) FontWeight.Bold else FontWeight.Medium,
        align = TextAlign.Center,
      )
      // 今天：一道短线；写过：一个小点（在心情色上用心情色的前景色）。
      when {
        isToday ->
          Box(modifier = GlanceModifier.width(10.dp).height(2.dp).roundedBackground(tile?.second ?: colors.accent, 1.dp)) {}
        written ->
          Box(modifier = GlanceModifier.size(3.dp).roundedBackground(tile?.second ?: colors.accent, 1.5.dp)) {}
        else -> Spacer(GlanceModifier.height(2.dp))
      }
    }
    if (showHoliday) {
      node?.optString("h")?.ifEmpty { null }?.let { mark ->
        Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopEnd) {
          WidgetText(
            scope,
            mark,
            7f,
            if (node.optBoolean("hw")) colors.contentVariant else colors.accent,
            FontWeight.Bold,
          )
        }
      }
    }
  }
}

/** 快照里没有这个月时的标题（中文、日文为“2026年11月”，其余为“November 2026”）。 */
private fun monthTitle(scope: WidgetScope, month: LocalDate): String {
  val language = scope.snapshot.locale
  return if (language.startsWith("zh") || language.startsWith("ja")) {
    "${month.year}年${month.monthValue}月"
  } else {
    "${month.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.forLanguageTag(language))} ${month.year}"
  }
}
