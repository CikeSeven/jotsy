package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import com.jotsy.diary.widgets.WidgetActions
import com.jotsy.diary.widgets.WidgetPhotos
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetPillButton
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import kotlin.math.min

// 那年今日（OnThisDayWidget.kt）的零件：版式分档、照片区域的大小与位图、表头与翻页、
// 末行日期、空状态。

internal enum class MemoryLayout { SQUARE, WIDE, LARGE }

/** 翻到第几篇、一共几篇。 */
internal class MemoryPage(val index: Int, val count: Int)

/** 表头约 22dp 高。 */
internal const val HEADER = 22f

/** 照片区域的大小（dp）与位图；没有照片、关了照片优先或读不出来时为 null。 */
internal class MemoryPhoto(val width: Float, val height: Float, val bitmap: android.graphics.Bitmap)

internal fun photoFor(scope: WidgetScope, entry: DiaryEntry, layout: MemoryLayout): MemoryPhoto? {
  val path = entry.photo ?: return null
  if (!scope.content.optBoolean("photo", true)) return null
  val metrics = scope.metrics
  val innerW = scope.size.width.value - metrics.padding.value * 2
  val innerH = scope.size.height.value - metrics.padding.value * 2
  val (width, height) =
    when (layout) {
      MemoryLayout.SQUARE -> innerW to innerH - HEADER - metrics.gap.value - 6f - 18f
      MemoryLayout.WIDE -> min(innerH, innerW * 0.42f).let { it to innerH }
      MemoryLayout.LARGE -> innerW to innerH * 0.56f
    }
  if (width < 24f || height < 24f) return null
  val bitmap =
    WidgetPhotos.load(scope.context, path, width, height, metrics.innerRadius.value) ?: return null
  return MemoryPhoto(width, height, bitmap)
}

/**
 * 表头：这一篇的说法（强调色），多篇时右侧翻页。2×2 多篇时只留说法与“›”：图标与
 * “1/3”都放下的话，“3 年前的今天”会被截断。
 */
@Composable
internal fun MemoryHeader(scope: WidgetScope, entry: DiaryEntry, page: MemoryPage, compact: Boolean) {
  val colors = scope.colors
  val paged = page.count > 1
  Row(modifier = GlanceModifier.fillMaxWidth().height(HEADER.dp), verticalAlignment = Alignment.CenterVertically) {
    if (!(compact && paged)) {
      WidgetIcon(scope, "memory", 12.dp, colors.accent)
      Spacer(GlanceModifier.width(6.dp))
    }
    WidgetText(
      scope,
      entry.label ?: scope.snapshot.string("onThisDayTitle"),
      12.5f,
      colors.accent,
      FontWeight.Medium,
      modifier = GlanceModifier.defaultWeight(),
    )
    if (paged) {
      if (!compact) {
        MemoryPagerButton(scope, "previous", WidgetActions.shiftEntry(-1), "entryPrevious")
        WidgetText(scope, "${page.index + 1}/${page.count}", 11f, colors.contentVariant)
      }
      MemoryPagerButton(scope, "next", WidgetActions.shiftEntry(1), "entryNext")
    }
  }
}

@Composable
internal fun MemoryPagerButton(scope: WidgetScope, icon: String, action: Action, label: String) {
  Box(
    modifier =
      GlanceModifier.size(HEADER.dp)
        .clickable(action)
        .semantics { contentDescription = scope.snapshot.string(label) },
    contentAlignment = Alignment.Center,
  ) {
    WidgetIcon(scope, icon, 12.dp, scope.colors.contentVariant)
  }
}

/** 末行：完整日期（表头已经是日期时不重复）与心情。 */
@Composable
internal fun MemoryDateLine(scope: WidgetScope, entry: DiaryEntry) {
  val date = entry.date.takeIf { it != entry.label && it.isNotEmpty() }
  val text = listOfNotNull(date, entry.mood).joinToString(" · ")
  if (text.isNotEmpty()) WidgetText(scope, text, 11f, scope.colors.contentVariant)
}

/** 往年的今天还没有日记：提示与“写一篇”。 */
@Composable
internal fun MemoryEmpty(scope: WidgetScope) {
  val colors = scope.colors
  val write = WidgetLaunch.action(scope.context, "write")
  WidgetFrame(scope, write) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
      Row(modifier = GlanceModifier.fillMaxWidth().height(HEADER.dp), verticalAlignment = Alignment.CenterVertically) {
        WidgetIcon(scope, "memory", 12.dp, colors.accent)
        Spacer(GlanceModifier.width(6.dp))
        WidgetText(scope, scope.snapshot.string("onThisDayTitle"), 12.5f, colors.accent, FontWeight.Medium)
      }
      Column(
        modifier = GlanceModifier.fillMaxWidth().defaultWeight(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        WidgetText(
          scope,
          scope.snapshot.string("onThisDayEmpty"),
          12.5f,
          colors.contentVariant,
          maxLines = 3,
          align = TextAlign.Center,
        )
        Spacer(GlanceModifier.height(8.dp))
        WidgetPillButton(scope, scope.snapshot.string("writeOne"), write)
      }
    }
  }
}
