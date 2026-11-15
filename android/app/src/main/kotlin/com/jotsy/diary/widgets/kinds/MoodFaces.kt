package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.size
import com.jotsy.diary.widgets.WidgetActions
import com.jotsy.diary.widgets.WidgetMoodFace
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.roundedBackground

/**
 * 一排五张心情脸（由低到高），均匀铺满一行。选中的那张铺这种心情的颜色（与应用日历的
 * `DayMoodColors` 同一套），其余是淡淡的轨道色；点一张记下 [day] 的心情，再点一下取消
 * （[WidgetActions.setMood]：先乐观重画，再交给 Dart 写库）。
 */
@Composable
fun MoodFaces(scope: WidgetScope, day: String, current: String?, size: Dp) {
  val colors = scope.colors
  Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
    WidgetMoodFace.MOODS.forEachIndexed { index, mood ->
      if (index > 0) Spacer(GlanceModifier.defaultWeight())
      val selected = mood == current
      val (tile, onTile) = colors.moodTiles[index]
      Box(
        modifier =
          GlanceModifier.size(size)
            .roundedBackground(if (selected) tile else colors.track, size / 2)
            .clickable(WidgetActions.setMood(day, mood)),
        contentAlignment = Alignment.Center,
      ) {
        val faceSize = size * 0.6f
        Image(
          provider = ImageProvider(WidgetMoodFace.bitmap(scope.context, mood, faceSize.value)),
          contentDescription = scope.snapshot.string("mood_$mood"),
          modifier = GlanceModifier.size(faceSize),
          colorFilter = ColorFilter.tint(if (selected) onTile else colors.contentVariant),
        )
      }
    }
  }
}
