package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.background
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
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import com.jotsy.diary.widgets.DisplayText
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetDates
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * 今日：大号日期、星期、农历与节气 / 节日、法定节假日的“休 / 班”，今天写了多少字、到期
 * 待办与今年进度（各项由内容选项开关，见 home_widget_native_config.dart 的 `_today`）。
 *
 * 四档版式：
 * - 一行（2×1 / 4×1）：数字 + 星期日期与农历，右侧节假日标签；4×1 再加写作状态；
 * - 方块（2×2）：眉标、大数字、农历，底部一行状态；更高的方块（[TALL]）放下两行状态、
 *   进度条与一排心情脸；
 * - 横幅（4×2）：左边日期块，细分隔，右边农历、节假日、状态与一排心情脸。
 *
 * 心情脸点一下就记下今天的心情（[MoodFaces]，不打开应用）。
 *
 * 跨零点：原生按本机日期取快照里这一天的预算内容（[TodayDay]），Dart 排好了之后几天
 * 零点的重画；超出预算的日子只显示公历日期与星期。
 */
class TodayWidget : JotsyGlanceWidget(KIND, setOf(ROW, ROW_WIDE, SQUARE, TALL, WIDE)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val day = TodayDay.of(scope)
    val tap =
      when (scope.content.optString("tap")) {
        "write" -> WidgetLaunch.action(scope.context, "write")
        "app" -> WidgetLaunch.action(scope.context, "home")
        else -> WidgetLaunch.action(scope.context, "calendar", mapOf("day" to WidgetDates.key(scope.today)))
      }
    // 按阈值分档而不是比较相等：桌面上 LocalSize 是挑中的那一档，应用内预览按精确
    // 尺寸组合时则是实际尺寸，两种情况要落到同一个版式。
    WidgetFrame(scope, tap) {
      when {
        scope.size.height < SQUARE.height -> RowLayout(scope, day)
        scope.size.width >= WIDE.width -> WideLayout(scope, day)
        else -> SquareLayout(scope, day)
      }
    }
  }

  companion object {
    const val KIND = "today"
    val ROW = DpSize(110.dp, 40.dp)
    val ROW_WIDE = DpSize(250.dp, 40.dp)
    val SQUARE = DpSize(110.dp, 110.dp)
    val TALL = DpSize(110.dp, 170.dp)
    val WIDE = DpSize(250.dp, 110.dp)
  }
}

class TodayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayWidget>() {
  override val glanceAppWidget = TodayWidget()
}

@Composable
private fun RowLayout(scope: WidgetScope, day: TodayDay) {
  val colors = scope.colors
  Row(
    modifier = GlanceModifier.fillMaxSize(),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    DisplayText(scope, day.dayOfMonth, 34f, colors.accent, maxWidth = 64.dp)
    Spacer(GlanceModifier.width(10.dp))
    Column(modifier = GlanceModifier.defaultWeight()) {
      // 2×1 只放得下“11月 · 周日”；4×1 右侧还有写作状态，用“周日 · 11月15日”。
      val title =
        if (scope.size.width >= TodayWidget.ROW_WIDE.width) "${day.weekdayShort} · ${day.monthDay}"
        else "${day.month} · ${day.weekdayShort}"
      WidgetText(scope, title, 13.5f, colors.content, FontWeight.Bold)
      day.almanacLine?.let { WidgetText(scope, it, 11.5f, colors.contentVariant) }
    }
    day.holiday?.let { HolidayTag(scope, it) }
    if (scope.size.width >= TodayWidget.ROW_WIDE.width && day.showWriting) {
      Spacer(GlanceModifier.width(scope.metrics.gap))
      Box(
        modifier =
          GlanceModifier.roundedBackground(colors.tile, scope.metrics.innerRadius)
            .padding(horizontal = 10.dp, vertical = 6.dp),
      ) {
        StatusLine(scope, "words", day.writingLabel, colors.onTile)
      }
    }
  }
}

@Composable
private fun SquareLayout(scope: WidgetScope, day: TodayDay) {
  val colors = scope.colors
  val tall = scope.size.height >= TodayWidget.TALL.height
  Column(modifier = GlanceModifier.fillMaxSize()) {
    Row(
      modifier = GlanceModifier.fillMaxWidth(),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      WidgetText(
        scope,
        "${day.month} · ${day.weekdayShort}",
        12.5f,
        colors.accent,
        FontWeight.Medium,
        modifier = GlanceModifier.defaultWeight(),
      )
      day.holiday?.let { HolidayTag(scope, it) }
    }
    DisplayText(scope, day.dayOfMonth, if (tall) 56f else 46f, colors.content, maxWidth = scope.size.width)
    day.almanacLine?.let { WidgetText(scope, it, 12f, colors.contentVariant) }
    Spacer(GlanceModifier.defaultWeight())
    // 普通方块只放一行状态（写作优先）；更高的方块两行都放，再放心情脸。
    val lines = day.statusLines()
    for (line in if (tall) lines else lines.take(1)) {
      StatusLine(scope, line.first, line.second, colors.content)
      Spacer(GlanceModifier.height(2.dp))
    }
    if (day.showYearProgress) {
      Spacer(GlanceModifier.height(4.dp))
      YearProgress(scope, day, showLabel = tall)
    }
    if (tall && day.showMood) {
      Spacer(GlanceModifier.height(8.dp))
      MoodFaces(scope, day.key, day.mood, 24.dp)
    }
  }
}

@Composable
private fun WideLayout(scope: WidgetScope, day: TodayDay) {
  val colors = scope.colors
  Row(
    modifier = GlanceModifier.fillMaxSize(),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Column(modifier = GlanceModifier.width(104.dp)) {
      WidgetText(scope, day.month, 12.5f, colors.accent, FontWeight.Medium)
      DisplayText(scope, day.dayOfMonth, 54f, colors.content, maxWidth = 104.dp)
      WidgetText(scope, day.weekday, 14f, colors.content, FontWeight.Bold)
    }
    Spacer(GlanceModifier.width(scope.metrics.gap * 1.5f))
    Box(modifier = GlanceModifier.width(1.dp).fillMaxHeight().background(colors.track)) {}
    Spacer(GlanceModifier.width(scope.metrics.gap * 1.5f))
    Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
      Row(verticalAlignment = Alignment.CenterVertically) {
        day.lunarTitle?.let {
          WidgetText(scope, it, 15f, colors.content, FontWeight.Bold)
          Spacer(GlanceModifier.width(6.dp))
        }
        day.holiday?.let { HolidayTag(scope, it) }
      }
      day.almanacDetail?.let { WidgetText(scope, it, 12f, colors.contentVariant) }
      Spacer(GlanceModifier.defaultWeight())
      // 放心情脸时状态只留一行（写作优先），横幅的高度放不下更多。
      val lines = day.statusLines()
      for (line in if (day.showMood) lines.take(1) else lines) {
        StatusLine(scope, line.first, line.second, colors.content)
        Spacer(GlanceModifier.height(3.dp))
      }
      if (day.showYearProgress) {
        Spacer(GlanceModifier.height(3.dp))
        YearProgress(scope, day, showLabel = true)
      }
      if (day.showMood) {
        Spacer(GlanceModifier.height(6.dp))
        MoodFaces(scope, day.key, day.mood, 26.dp)
      }
    }
  }
}

/** 一行状态：图标（强调色）+ 文字。 */
@Composable
private fun StatusLine(
  scope: WidgetScope,
  icon: String,
  text: String,
  color: androidx.glance.unit.ColorProvider,
) {
  Row(verticalAlignment = Alignment.CenterVertically) {
    WidgetIcon(scope, icon, 12.dp, scope.colors.accent)
    Spacer(GlanceModifier.width(6.dp))
    WidgetText(scope, text, 12f, color, FontWeight.Medium)
  }
}

/** 法定节假日的“休 / 班”小标签。 */
@Composable
private fun HolidayTag(scope: WidgetScope, holiday: TodayDay.Holiday) {
  val colors = scope.colors
  Box(
    modifier =
      GlanceModifier.roundedBackground(
          if (holiday.work) colors.workTag else colors.restTag,
          8.dp,
        )
        .padding(horizontal = 6.dp, vertical = 2.dp),
  ) {
    WidgetText(
      scope,
      holiday.mark,
      11f,
      if (holiday.work) colors.onWorkTag else colors.onRestTag,
      FontWeight.Bold,
    )
  }
}

/** 今年进度：细进度条，可带百分比文字。 */
@Composable
private fun YearProgress(scope: WidgetScope, day: TodayDay, showLabel: Boolean) {
  Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
    LinearProgressIndicator(
      progress = day.yearProgress,
      modifier = GlanceModifier.defaultWeight().height(4.dp),
      color = scope.colors.accent,
      backgroundColor = scope.colors.track,
    )
    if (showLabel) {
      Spacer(GlanceModifier.width(8.dp))
      WidgetText(scope, day.yearProgressLabel, 10.5f, scope.colors.contentVariant)
    }
  }
}
