package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
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
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import com.jotsy.diary.widgets.DisplayText
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetPhotos
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetLocked
import com.jotsy.diary.widgets.WidgetPhoto
import com.jotsy.diary.widgets.WidgetPillButton
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlin.math.max

/**
 * 最近日记：全部、某个日记本、某个标签或置顶的最近几篇（内容选项 `source`，Dart 已把失效的
 * 来源落回全部日记）。
 *
 * 表头是来源的名字与“写一篇”（来源是能写的日记本时写进这本）。每行行首是照片缩略图，没有
 * 照片（或关了缩略图）时是日期块；右边标题，下面一行是今天 / 昨天 / 日期、心情与摘要。
 * 放得下几行就放几行（不滚动：LazyColumn 在应用内预览里画不出来）。每行点按打开那篇日记。
 *
 * 开了应用锁：锁定占位（快照里本来就没有日记内容）。
 */
class RecentDiariesWidget : JotsyGlanceWidget(KIND, setOf(WIDE, WIDE_TALL, LARGE, LARGE_TALL)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    if (scope.snapshot.redacted) {
      WidgetLocked(scope)
      return
    }
    val entries = DiaryEntry.recent(scope)
    val write =
      WidgetLaunch.action(scope.context, "write", mapOf("notebook" to scope.content.optString("notebook").ifEmpty { null }))
    WidgetFrame(scope, null) {
      Column(modifier = GlanceModifier.fillMaxSize()) {
        Header(scope, write)
        Spacer(GlanceModifier.height(scope.metrics.gap))
        if (entries.isEmpty()) {
          Empty(scope, write)
        } else {
          val rowHeight = rowHeight(scope)
          val room = scope.size.height.value - scope.metrics.padding.value * 2 - HEADER_HEIGHT - scope.metrics.gap.value
          val rows = max(1, ((room + ROW_GAP) / (rowHeight + ROW_GAP)).toInt())
          // 行另放进一个 Column：Glance 的一个 Column 最多 10 个子项，多出来的会被丢掉。
          Column(modifier = GlanceModifier.fillMaxWidth()) {
            entries.take(rows).forEachIndexed { index, entry ->
              EntryRow(scope, entry, rowHeight, top = if (index > 0) ROW_GAP else 0f)
            }
          }
        }
      }
    }
  }

  companion object {
    const val KIND = "recent_diaries"
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)

    // 行数随高度：除了 4×2 / 4×4 的最小档，再各加一档更高的，常见手机上 4×2 的实际格子
    // （约 150dp 高）能放两行，而不是按最小档只放一行。
    val WIDE_TALL = DpSize(250.dp, 150.dp)
    val LARGE_TALL = DpSize(250.dp, 320.dp)
  }
}

class RecentDiariesWidgetReceiver : HomeWidgetGlanceWidgetReceiver<RecentDiariesWidget>() {
  override val glanceAppWidget = RecentDiariesWidget()
}

/** 表头高（dp），与“+”圆钮一样高。 */
private const val HEADER_HEIGHT = 30f

/** 行首块的边长（dp）。 */
private const val THUMB = 38f

/** 行间距（dp）。 */
private const val ROW_GAP = 6f

/**
 * 一行的高度（dp）：至少放得下行首块；文字放大时（外观的文字大小）跟着两行字变高，
 * 免得第二行被裁掉。
 */
private fun rowHeight(scope: WidgetScope): Float = max(THUMB, (13.5f + 11.5f) * 1.32f * scope.metrics.sp(1f) + 2f)

@Composable
private fun Header(scope: WidgetScope, write: Action) {
  val colors = scope.colors
  val source = scope.content.optString("source", "all")
  val title =
    scope.content.optString("title").ifEmpty {
      scope.snapshot.string(if (source == "pinned") "recentPinned" else "recentTitle")
    }
  val icon =
    when {
      source == "pinned" -> "pin"
      source.startsWith("tag:") -> "tag"
      else -> "diary"
    }
  Row(
    modifier = GlanceModifier.fillMaxWidth().height(HEADER_HEIGHT.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    WidgetIcon(scope, icon, 13.dp, colors.accent)
    Spacer(GlanceModifier.width(8.dp))
    WidgetText(
      scope,
      title,
      14f,
      colors.content,
      FontWeight.Bold,
      modifier = GlanceModifier.defaultWeight(),
    )
    Box(
      modifier =
        GlanceModifier.size(HEADER_HEIGHT.dp)
          .roundedBackground(colors.accent, (HEADER_HEIGHT / 2).dp)
          .clickable(write)
          .semantics { contentDescription = scope.snapshot.string("writeOne") },
      contentAlignment = Alignment.Center,
    ) {
      WidgetIcon(scope, "plus", 14.dp, colors.onAccent)
    }
  }
}

@Composable
private fun EntryRow(scope: WidgetScope, entry: DiaryEntry, height: Float, top: Float) {
  val colors = scope.colors
  val radius = minOf(scope.metrics.innerRadius, 12.dp)
  Row(
    modifier =
      GlanceModifier.fillMaxWidth()
        .padding(top = top.dp)
        .height((height + top).dp)
        .clickable(WidgetLaunch.action(scope.context, "diary", mapOf("id" to entry.id))),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    val photo =
      entry.photo
        ?.takeIf { scope.content.optBoolean("photos", true) }
        ?.let { WidgetPhotos.load(scope.context, it, THUMB, THUMB, radius.value) }
    if (photo != null) {
      WidgetPhoto(photo, radius, GlanceModifier.size(THUMB.dp))
    } else {
      DateTile(scope, entry, radius)
    }
    Spacer(GlanceModifier.width(10.dp))
    Column(modifier = GlanceModifier.defaultWeight()) {
      WidgetText(scope, entry.headline(scope.snapshot), 13.5f, colors.content, FontWeight.Medium)
      val excerpt = entry.body?.takeIf { scope.content.optBoolean("excerpt", true) }
      val detail = listOfNotNull(entry.relativeDate(scope), entry.mood, excerpt).joinToString(" · ")
      WidgetText(scope, detail, 11.5f, colors.contentVariant)
    }
  }
}

/** 没有照片的行首：色调底上的日与月。 */
@Composable
private fun DateTile(scope: WidgetScope, entry: DiaryEntry, radius: androidx.compose.ui.unit.Dp) {
  val colors = scope.colors
  Column(
    modifier = GlanceModifier.size(THUMB.dp).roundedBackground(colors.tile, radius),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalAlignment = Alignment.CenterVertically,
  ) {
    DisplayText(scope, entry.day.toString(), 15f, colors.onTile, (THUMB - 4).dp)
    WidgetText(scope, entry.month, 9f, colors.onTile)
  }
}

@Composable
private fun Empty(scope: WidgetScope, write: Action) {
  Column(
    modifier = GlanceModifier.fillMaxSize().padding(bottom = 4.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalAlignment = Alignment.CenterVertically,
  ) {
    WidgetText(
      scope,
      scope.snapshot.string("recentEmpty"),
      12.5f,
      scope.colors.contentVariant,
      maxLines = 2,
      align = TextAlign.Center,
    )
    Spacer(GlanceModifier.height(8.dp))
    WidgetPillButton(scope, scope.snapshot.string("writeOne"), write)
  }
}
