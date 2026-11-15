package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetActions
import com.jotsy.diary.widgets.WidgetDates
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetLocked
import com.jotsy.diary.widgets.WidgetMessage
import com.jotsy.diary.widgets.WidgetPhoto
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetState
import com.jotsy.diary.widgets.WidgetText
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlin.math.floor

/**
 * 那年今日：往年这一天（或前后几天、同月，内容选项 `match`）写下的日记，一次一篇。
 *
 * 表头是这一篇的说法（“3 年前的今天”或日期），多篇时右侧翻页（[WidgetActions.shiftEntry]，
 * 只在原生记住翻到第几篇，换一天回到最近的那一年）。有照片且开着“照片优先”时以照片为主：
 * 2×2 照片在上、标题在下；4×2 照片在左、文字在右；4×4 照片在上、标题与摘要在下。没有照片
 * 时是大号标题、摘要与日期。整块点按打开这篇日记；没有往年的日记时提示并给“写一篇”。
 *
 * 开了应用锁：锁定占位（快照里本来就没有日记内容）。
 */
class OnThisDayWidget :
  JotsyGlanceWidget(KIND, setOf(SQUARE, SQUARE_ROOMY, WIDE, WIDE_TALL, LARGE, LARGE_TALL)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    if (scope.snapshot.redacted) {
      WidgetLocked(scope)
      return
    }
    // 今天超出快照预算（应用很久没打开）：不显示可能过期的内容。
    val entries = DiaryEntry.onThisDay(scope)
    if (entries == null) {
      WidgetMessage(scope, scope.snapshot.string("openToUpdate"))
      return
    }
    if (entries.isEmpty()) {
      MemoryEmpty(scope)
      return
    }
    val index =
      scope.appWidgetId?.let {
        Math.floorMod(WidgetState.entryIndex(scope.context, it, WidgetDates.key(scope.today)), entries.size)
      } ?: 0
    val entry = entries[index]
    val layout =
      when {
        scope.size.width < WIDE_MIN -> MemoryLayout.SQUARE
        scope.size.height < LARGE_MIN -> MemoryLayout.WIDE
        else -> MemoryLayout.LARGE
      }
    val page = MemoryPage(index, entries.size)
    WidgetFrame(scope, WidgetLaunch.action(scope.context, "diary", mapOf("id" to entry.id))) {
      val photo = photoFor(scope, entry, layout)
      if (photo != null) {
        PhotoLayout(scope, entry, layout, page, photo)
      } else {
        TextLayout(scope, entry, layout, page)
      }
    }
  }

  companion object {
    const val KIND = "on_this_day"
    val SQUARE = DpSize(110.dp, 110.dp)
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)

    // 照片随格子放大：最小档之外各加一档常见手机上的实际格子大小，照片不至于按最小档
    // 画得很小、四周留白。
    val SQUARE_ROOMY = DpSize(140.dp, 140.dp)
    val WIDE_TALL = DpSize(250.dp, 150.dp)
    val LARGE_TALL = DpSize(250.dp, 320.dp)

    /** 分档界线（比档位略小：桌面上的格子总比声明的档位大一点）。 */
    private val WIDE_MIN = 230.dp
    private val LARGE_MIN = 230.dp
  }
}

class OnThisDayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<OnThisDayWidget>() {
  override val glanceAppWidget = OnThisDayWidget()
}


@Composable
private fun PhotoLayout(scope: WidgetScope, entry: DiaryEntry, layout: MemoryLayout, page: MemoryPage, photo: MemoryPhoto) {
  val colors = scope.colors
  val radius = scope.metrics.innerRadius
  when (layout) {
    MemoryLayout.SQUARE ->
      Column(modifier = GlanceModifier.fillMaxSize()) {
        MemoryHeader(scope, entry, page, compact = true)
        Spacer(GlanceModifier.height(scope.metrics.gap))
        WidgetPhoto(photo.bitmap, radius, GlanceModifier.fillMaxWidth().defaultWeight())
        Spacer(GlanceModifier.height(6.dp))
        WidgetText(scope, entry.headline(scope.snapshot), 13f, colors.content, FontWeight.Bold)
      }
    MemoryLayout.WIDE ->
      Row(modifier = GlanceModifier.fillMaxSize()) {
        WidgetPhoto(photo.bitmap, radius, GlanceModifier.fillMaxHeight().width(photo.width.dp))
        Spacer(GlanceModifier.width(12.dp))
        Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
          MemoryHeader(scope, entry, page, compact = false)
          Spacer(GlanceModifier.height(6.dp))
          WidgetText(scope, entry.headline(scope.snapshot), 15f, colors.content, FontWeight.Bold, maxLines = 2)
          entry.body?.takeIf { scope.content.optBoolean("excerpt", true) }?.let {
            Spacer(GlanceModifier.height(2.dp))
            WidgetText(scope, it, 12f, colors.contentVariant, maxLines = 2)
          }
          Spacer(GlanceModifier.defaultWeight())
          MemoryDateLine(scope, entry)
        }
      }
    MemoryLayout.LARGE ->
      Column(modifier = GlanceModifier.fillMaxSize()) {
        MemoryHeader(scope, entry, page, compact = false)
        Spacer(GlanceModifier.height(scope.metrics.gap))
        WidgetPhoto(photo.bitmap, radius, GlanceModifier.fillMaxWidth().height(photo.height.dp))
        Spacer(GlanceModifier.height(10.dp))
        val body = entry.body?.takeIf { scope.content.optBoolean("excerpt", true) }
        WidgetText(
          scope,
          entry.headline(scope.snapshot),
          16f,
          colors.content,
          FontWeight.Bold,
          maxLines = if (body == null) 2 else 1,
        )
        body?.let {
          Spacer(GlanceModifier.height(2.dp))
          WidgetText(scope, it, 12.5f, colors.contentVariant, maxLines = 2)
        }
        Spacer(GlanceModifier.defaultWeight())
        MemoryDateLine(scope, entry)
      }
  }
}

/**
 * 没有照片：大号标题、摘要、日期。行数按高度现算，放不下的摘要少几行，大号文字缩放下
 * 也不会把日期挤出去。
 */
@Composable
private fun TextLayout(scope: WidgetScope, entry: DiaryEntry, layout: MemoryLayout, page: MemoryPage) {
  val colors = scope.colors
  val metrics = scope.metrics
  val headlineSize =
    when (layout) {
      MemoryLayout.SQUARE -> 15f
      MemoryLayout.WIDE -> 16f
      MemoryLayout.LARGE -> 18f
    }
  val scale = metrics.sp(1f)
  val headlineLine = headlineSize * 1.35f * scale
  val bodyLine = 12.5f * 1.4f * scale
  val innerH = scope.size.height.value - metrics.padding.value * 2
  val room = innerH - HEADER - metrics.gap.value - 16f * scale - 8f
  val headline = entry.headline(scope.snapshot)
  // 标题实际占几行（粗估：中日文一字一个字号宽，其余半个多），短标题把省下的行让给摘要。
  val innerW = scope.size.width.value - metrics.padding.value * 2
  val headlineWidth = headline.sumOf { if (it.code >= 0x2E80) 1.0 else 0.58 } * headlineSize * scale
  val headlineNeeds = if (headlineWidth > innerW) 2 else 1
  val headlineLines = if (headlineNeeds == 2 && room >= headlineLine * 2 + bodyLine) 2 else 1
  val body = entry.body?.takeIf { scope.content.optBoolean("excerpt", true) }
  val bodyLines = floor((room - headlineLine * headlineLines - 4f) / bodyLine).toInt().coerceIn(0, 8)
  Column(modifier = GlanceModifier.fillMaxSize()) {
    MemoryHeader(scope, entry, page, compact = layout == MemoryLayout.SQUARE)
    Spacer(GlanceModifier.height(metrics.gap))
    WidgetText(
      scope,
      headline,
      headlineSize,
      colors.content,
      FontWeight.Bold,
      maxLines = if (body == null || bodyLines == 0) headlineLines + 1 else headlineLines,
    )
    if (body != null && bodyLines > 0) {
      Spacer(GlanceModifier.height(4.dp))
      WidgetText(scope, body, 12.5f, colors.contentVariant, maxLines = bodyLines)
    }
    Spacer(GlanceModifier.defaultWeight())
    MemoryDateLine(scope, entry)
  }
}
