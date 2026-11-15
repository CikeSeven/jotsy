package com.jotsy.diary.widgets.kinds

import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetActions
import com.jotsy.diary.widgets.WidgetPhotos
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetLocked
import com.jotsy.diary.widgets.WidgetPhoto
import com.jotsy.diary.widgets.WidgetPillButton
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetState
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * 照片回忆：日记里的一张照片铺满整个小组件（圆角与外框相同），左下角日期（那年今日为
 * “N 年前的今天”），右上角“换一张”。
 *
 * 照片来自快照「照片」一节按来源存的候选（全部 / 某个日记本），或“那年今日”这一天前后
 * 3 天里带照片的日记（没有时退回全部）。每天按日期轮到下一张；“换一张”只记在原生
 * （[WidgetActions.shufflePhoto]），不经过 Dart。照片读不出来（文件已删）时顺延下一张。
 * 点按打开这张照片所在的日记。1×1 只有照片。开了应用锁：锁定占位。
 */
class PhotoMemoriesWidget :
  JotsyGlanceWidget(KIND, setOf(TINY, SQUARE, SQUARE_ROOMY, WIDE, WIDE_TALL, LARGE, LARGE_TALL)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val tiny = scope.size.width < SQUARE.width || scope.size.height < SQUARE.height
    if (scope.snapshot.redacted) {
      if (tiny) TinyIcon(scope, "lock") else WidgetLocked(scope)
      return
    }
    val pool = pool(scope)
    val radius = scope.metrics.radius
    val offset =
      scope.appWidgetId?.let { WidgetState.photoOffset(scope.context, it) } ?: 0
    // 从今天轮到的那张起，跳过读不出来的照片。
    val picked =
      pool.indices.asSequence()
        .map { pool[Math.floorMod(scope.today.toEpochDay() + offset + it, pool.size.toLong()).toInt()] }
        .firstNotNullOfOrNull { entry ->
          WidgetPhotos.load(
            scope.context,
            entry.photo ?: return@firstNotNullOfOrNull null,
            scope.size.width.value,
            scope.size.height.value,
            radius.value,
          )?.let { entry to it }
        }
    if (picked == null) {
      if (tiny) TinyIcon(scope, "photo") else Empty(scope)
      return
    }
    val (entry, bitmap) = picked
    var frame =
      GlanceModifier.fillMaxSize()
        .appWidgetBackground()
        .clickable(WidgetLaunch.action(scope.context, "diary", mapOf("id" to entry.id)))
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) frame = frame.cornerRadius(radius)
    Box(modifier = frame) {
      WidgetPhoto(bitmap, radius, GlanceModifier.fillMaxSize())
      if (!tiny) {
        if (scope.content.optBoolean("date", true)) DateChip(scope, entry)
        if (pool.size > 1) ShuffleButton(scope)
      }
    }
  }

  companion object {
    const val KIND = "photo_memories"
    val TINY = DpSize(40.dp, 40.dp)
    val SQUARE = DpSize(110.dp, 110.dp)
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)

    // 照片按实际格子的比例裁：除了最小档，再加常见手机上的格子档。
    val SQUARE_ROOMY = DpSize(140.dp, 140.dp)
    val WIDE_TALL = DpSize(250.dp, 150.dp)
    val LARGE_TALL = DpSize(250.dp, 320.dp)
  }
}

class PhotoMemoriesWidgetReceiver : HomeWidgetGlanceWidgetReceiver<PhotoMemoriesWidget>() {
  override val glanceAppWidget = PhotoMemoriesWidget()
}

/** 这个实例的候选照片（都带本机照片）。 */
private fun pool(scope: WidgetScope): List<DiaryEntry> {
  val source = scope.content.optString("source", "all")
  if (source == "onThisDay") {
    val memories =
      DiaryEntry.onThisDay(scope, match = "nearby")?.filter { it.photo != null }.orEmpty()
    if (memories.isNotEmpty()) return memories
  }
  val photos = scope.snapshot.section("photos") ?: return emptyList()
  val list = photos.optJSONArray(source) ?: photos.optJSONArray("all") ?: return emptyList()
  return (0 until list.length())
    .mapNotNull { DiaryEntry.byId(scope.snapshot, list.optString(it)) }
    .filter { it.photo != null }
}

/** 左下角的日期签：小组件底色的小圆角块（透明底时用色块色），那年今日写“N 年前的今天”。 */
@Composable
private fun DateChip(scope: WidgetScope, entry: DiaryEntry) {
  val colors = scope.colors
  Box(modifier = GlanceModifier.fillMaxSize().padding(10.dp), contentAlignment = Alignment.BottomStart) {
    Box(
      modifier =
        GlanceModifier.roundedBackground(colors.background ?: colors.tile, 10.dp)
          .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
      WidgetText(
        scope,
        entry.label ?: entry.date,
        11f,
        if (colors.background != null) colors.content else colors.onTile,
        FontWeight.Medium,
      )
    }
  }
}

/** 右上角“换一张”：28dp 圆钮。 */
@Composable
private fun ShuffleButton(scope: WidgetScope) {
  val colors = scope.colors
  Box(modifier = GlanceModifier.fillMaxSize().padding(8.dp), contentAlignment = Alignment.TopEnd) {
    Box(
      modifier =
        GlanceModifier.size(28.dp)
          .roundedBackground(colors.background ?: colors.tile, 14.dp)
          .clickable(WidgetActions.shufflePhoto())
          .semantics { contentDescription = scope.snapshot.string("photoShuffle") },
      contentAlignment = Alignment.Center,
    ) {
      WidgetIcon(scope, "shuffle", 12.dp, if (colors.background != null) colors.content else colors.onTile)
    }
  }
}

/** 1×1 放不下文字：居中一个图标（锁定、还没有照片），点按打开应用。 */
@Composable
private fun TinyIcon(scope: WidgetScope, icon: String) {
  WidgetFrame(scope, WidgetLaunch.action(scope.context, "home")) {
    Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      WidgetIcon(scope, icon, 18.dp, scope.colors.accent)
    }
  }
}

/** 还没有带照片的日记：图标、说明与“写一篇”。 */
@Composable
private fun Empty(scope: WidgetScope) {
  val write = WidgetLaunch.action(scope.context, "write")
  WidgetFrame(scope, write) {
    Column(
      modifier = GlanceModifier.fillMaxSize(),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      WidgetIcon(scope, "photo", 20.dp, scope.colors.accent)
      Spacer(GlanceModifier.height(6.dp))
      WidgetText(
        scope,
        scope.snapshot.string("photoEmpty"),
        12f,
        scope.colors.contentVariant,
        maxLines = 2,
        align = TextAlign.Center,
      )
      Spacer(GlanceModifier.height(8.dp))
      WidgetPillButton(scope, scope.snapshot.string("writeOne"), write)
    }
  }
}
