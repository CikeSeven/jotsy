package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
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
import com.jotsy.diary.widgets.WidgetBitmaps
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetMessage
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlin.math.floor

/**
 * 写作统计：连续记录天数（大号数字）、今天写了没有、本月篇数与字数、今年篇数，以及最近
 * 几周的热力图（内容选项 `heatmap`、着色依据 `basis`）。
 *
 * 2×2 为数字、单位与本月两项；4×2 左为数字，右为热力图（关了热力图时为三项数字）；4×4
 * 上为数字，中间三块数字，下面一整排热力图。热力图放得下几周就画几周（最多 53 周），格子
 * 不小于看得清的大小。整块点按打开探索页。统计不是日记内容，应用锁开着也照常显示。
 */
class WritingStatsWidget :
  JotsyGlanceWidget(KIND, setOf(SQUARE, SQUARE_ROOMY, WIDE, WIDE_TALL, LARGE, LARGE_TALL)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val stats = WritingStats.read(scope)
    if (stats == null) {
      WidgetMessage(scope, scope.snapshot.string("openToUpdate"))
      return
    }
    val innerW = scope.size.width.value - scope.metrics.padding.value * 2
    val innerH = scope.size.height.value - scope.metrics.padding.value * 2
    WidgetFrame(scope, WidgetLaunch.action(scope.context, "explore")) {
      when {
        scope.size.width < WIDE_MIN -> SquareLayout(scope, stats, innerH)
        scope.size.height < LARGE_MIN -> WideLayout(scope, stats, innerW, innerH)
        else -> LargeLayout(scope, stats, innerW, innerH)
      }
    }
  }

  companion object {
    const val KIND = "writing_stats"
    val SQUARE = DpSize(110.dp, 110.dp)
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)

    // 常见手机上的实际格子档，数字与热力图随之放大（理由同那年今日）。
    val SQUARE_ROOMY = DpSize(140.dp, 140.dp)
    val WIDE_TALL = DpSize(250.dp, 150.dp)
    val LARGE_TALL = DpSize(250.dp, 320.dp)

    private val WIDE_MIN = 230.dp
    private val LARGE_MIN = 230.dp
  }
}

class WritingStatsWidgetReceiver : HomeWidgetGlanceWidgetReceiver<WritingStatsWidget>() {
  override val glanceAppWidget = WritingStatsWidget()
}

/** 热力图格子的最大边长与间距（dp）。 */
private const val HEAT_CELL = 9f
private const val HEAT_GAP = 2f

@Composable
private fun SquareLayout(scope: WidgetScope, stats: WritingStats, innerH: Float) {
  // 放得下表头、大数字、单位与本月两项才放本月两项（约 117dp，随文字大小放大），否则
  // 只放一行“今天已写”。
  val roomy = innerH >= 117f * scope.metrics.sp(1f) + 6f
  Column(modifier = GlanceModifier.fillMaxSize()) {
    Title(scope)
    Spacer(GlanceModifier.height(6.dp))
    Streak(scope, stats, if (roomy) 44f else 34f)
    Spacer(GlanceModifier.defaultWeight())
    if (roomy) {
      Row(modifier = GlanceModifier.fillMaxWidth()) {
        StatCell(scope, stats.monthEntries, "statsMonthEntries", GlanceModifier.defaultWeight())
        StatCell(scope, stats.monthWords, "statsMonthWords", GlanceModifier.defaultWeight())
      }
    } else {
      TodayStatus(scope, stats)
    }
  }
}

@Composable
private fun WideLayout(scope: WidgetScope, stats: WritingStats, innerW: Float, innerH: Float) {
  val heatmap = scope.content.optBoolean("heatmap", true)
  Row(modifier = GlanceModifier.fillMaxSize()) {
    Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
      Title(scope)
      Spacer(GlanceModifier.height(4.dp))
      Streak(scope, stats, if (innerH >= 100f) 42f else 32f)
      Spacer(GlanceModifier.defaultWeight())
      if (innerH >= 100f) TodayStatus(scope, stats)
    }
    Spacer(GlanceModifier.width(12.dp))
    val rightW = innerW * 0.55f
    if (heatmap) {
      Column(modifier = GlanceModifier.width(rightW.dp).fillMaxHeight()) {
        Spacer(GlanceModifier.defaultWeight())
        Heatmap(scope, stats, rightW, innerH - 18f)
      }
    } else {
      Column(modifier = GlanceModifier.width(rightW.dp).fillMaxHeight()) {
        StatCell(scope, stats.monthEntries, "statsMonthEntries", GlanceModifier.defaultWeight())
        StatCell(scope, stats.monthWords, "statsMonthWords", GlanceModifier.defaultWeight())
        StatCell(scope, stats.yearEntries, "statsYearEntries", GlanceModifier.defaultWeight())
      }
    }
  }
}

@Composable
private fun LargeLayout(scope: WidgetScope, stats: WritingStats, innerW: Float, innerH: Float) {
  val colors = scope.colors
  Column(modifier = GlanceModifier.fillMaxSize()) {
    Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
      Box(modifier = GlanceModifier.defaultWeight()) { Title(scope) }
      TodayStatus(scope, stats)
    }
    Spacer(GlanceModifier.height(8.dp))
    Streak(scope, stats, 54f)
    Spacer(GlanceModifier.height(scope.metrics.gap + 4.dp))
    Row(modifier = GlanceModifier.fillMaxWidth()) {
      StatTile(scope, stats.monthEntries, "statsMonthEntries", GlanceModifier.defaultWeight())
      Spacer(GlanceModifier.width(8.dp))
      StatTile(scope, stats.monthWords, "statsMonthWords", GlanceModifier.defaultWeight())
      Spacer(GlanceModifier.width(8.dp))
      StatTile(scope, stats.yearEntries, "statsYearEntries", GlanceModifier.defaultWeight())
    }
    Spacer(GlanceModifier.defaultWeight())
    if (scope.content.optBoolean("heatmap", true)) {
      // 表头约 20、数字约 80、三块约 56，剩下的给热力图。
      Heatmap(scope, stats, innerW, innerH - 20f - 80f - 56f - 24f)
    } else {
      WidgetText(scope, scope.snapshot.string("statsTitle"), 11f, colors.contentVariant)
    }
  }
}

@Composable
private fun Title(scope: WidgetScope) {
  Row(verticalAlignment = Alignment.CenterVertically) {
    WidgetIcon(scope, "streak", 12.dp, scope.colors.accent)
    Spacer(GlanceModifier.width(6.dp))
    WidgetText(scope, scope.snapshot.string("statsTitle"), 12.5f, scope.colors.accent, FontWeight.Medium)
  }
}

/** 连续天数的大号数字（强调色）与下方单位（“天连续记录”，按数量取复数写法）。 */
@Composable
private fun Streak(scope: WidgetScope, stats: WritingStats, size: Float) {
  val colors = scope.colors
  DisplayText(scope, stats.streak.toString(), size, colors.accent, scope.size.width - scope.metrics.padding * 2)
  WidgetText(
    scope,
    scope.snapshot.plural("streakUnit", stats.streak.toLong()),
    12f,
    colors.content,
    FontWeight.Medium,
  )
}

/** 今天写了没有：强调色实心勾或次要文字色空心圆，加一句话。 */
@Composable
private fun TodayStatus(scope: WidgetScope, stats: WritingStats) {
  val colors = scope.colors
  Row(verticalAlignment = Alignment.CenterVertically) {
    WidgetIcon(
      scope,
      if (stats.wroteToday) "checked" else "unchecked",
      11.dp,
      if (stats.wroteToday) colors.accent else colors.contentVariant,
    )
    Spacer(GlanceModifier.width(5.dp))
    WidgetText(
      scope,
      scope.snapshot.string(if (stats.wroteToday) "statsWroteToday" else "statsNotYetToday"),
      11f,
      colors.contentVariant,
    )
  }
}

/** 一项数字：数字 15 / Bold，下面一行说明。 */
@Composable
private fun StatCell(scope: WidgetScope, value: String, caption: String, modifier: GlanceModifier) {
  Column(modifier = modifier) {
    WidgetText(scope, value, 15f, scope.colors.content, FontWeight.Bold)
    WidgetText(scope, scope.snapshot.string(caption), 10.5f, scope.colors.contentVariant)
  }
}

/** 4×4 的数字块：色块底、同心内圆角。 */
@Composable
private fun StatTile(scope: WidgetScope, value: String, caption: String, modifier: GlanceModifier) {
  val colors = scope.colors
  Column(
    modifier =
      modifier.roundedBackground(colors.tile, scope.metrics.innerRadius).padding(horizontal = 10.dp, vertical = 8.dp),
  ) {
    WidgetText(scope, value, 17f, colors.onTile, FontWeight.Bold)
    WidgetText(scope, scope.snapshot.string(caption), 10.5f, colors.onTile)
  }
}

/**
 * 热力图：轨道层（每个已过去的日子一格，轨道色）上叠档位层（强调色，四档不透明度），
 * 下方“最近 N 周”。格子边长取 [HEAT_CELL] 与高度能容下的较小值，宽度放得下几周就画几周。
 */
@Composable
private fun Heatmap(scope: WidgetScope, stats: WritingStats, width: Float, maxHeight: Float) {
  val colors = scope.colors
  val cell = minOf(HEAT_CELL, (maxHeight - 6 * HEAT_GAP) / 7f)
  if (cell < 4f) return
  val weeks = floor((width + HEAT_GAP) / (cell + HEAT_GAP)).toInt().coerceIn(4, 53)
  val levels = stats.heatLevels(scope.today, weeks)
  val track = WidgetBitmaps.heatmap(scope.context, levels, weeks, cell, HEAT_GAP, track = true)
  val heat = WidgetBitmaps.heatmap(scope.context, levels, weeks, cell, HEAT_GAP, track = false)
  Box {
    Image(provider = ImageProvider(track), contentDescription = null, colorFilter = ColorFilter.tint(colors.track))
    Image(provider = ImageProvider(heat), contentDescription = null, colorFilter = ColorFilter.tint(colors.accent))
  }
  Spacer(GlanceModifier.height(4.dp))
  WidgetText(scope, scope.snapshot.plural("recentWeeks", weeks.toLong()), 10.5f, colors.contentVariant)
}
