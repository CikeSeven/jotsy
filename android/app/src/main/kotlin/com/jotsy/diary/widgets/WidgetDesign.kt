package com.jotsy.diary.widgets

import android.content.Context
import android.os.Build
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.ContentScale
import androidx.glance.unit.ColorProvider
import com.jotsy.diary.R
import androidx.glance.ColorFilter

/**
 * 桌面小组件的版式度量（DESIGN.md「桌面小组件」）：外圆角、内边距、间距与文字缩放，
 * 都由外观（[WidgetStyle]）算出，所有种类共用。
 *
 * 同心圆角：内层块的圆角 = 外圆角 - 内边距，块与外框的弧线平行，不会出现大圆角里套
 * 小直角的“错位”。
 */
class WidgetMetrics(context: Context, style: WidgetStyle) {
  /** 外圆角（dp）：跟随系统时取 Android 12+ 的系统小组件圆角，更早的系统 16。 */
  val radius: Dp =
    if (style.radius >= 0f) {
      style.radius.dp
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val px = context.resources.getDimension(android.R.dimen.system_app_widget_background_radius)
      (px / context.resources.displayMetrics.density).dp
    } else {
      16.dp
    }

  /** 内边距：紧凑 / 标准 / 宽松。 */
  val padding: Dp =
    when (style.density) {
      "compact" -> 10.dp
      "roomy" -> 18.dp
      else -> 14.dp
    }

  /** 块与块之间的间距。 */
  val gap: Dp =
    when (style.density) {
      "compact" -> 6.dp
      "roomy" -> 10.dp
      else -> 8.dp
    }

  /** 内层块（按钮、色块）的同心圆角，至少 8。 */
  val innerRadius: Dp = maxOf(radius - padding, 8.dp)

  private val textScale = style.textScale

  /** 按外观的文字缩放换算字号（sp 值，系统字体缩放另由 TextView 自己叠加）。 */
  fun sp(base: Float): Float = base * textScale
}

/**
 * 圆角底色。Android 12+ 用 Glance 的 [cornerRadius]（真正的裁切）；更早的系统没有这个
 * 能力，改用白色圆角矩形 drawable 按颜色着色当底（就近取 0–32 中 4 的倍数一档）。
 */
fun GlanceModifier.roundedBackground(color: ColorProvider, radius: Dp): GlanceModifier =
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    this.background(color).cornerRadius(radius)
  } else {
    this.background(
      ImageProvider(roundedDrawable(radius)),
      ContentScale.FillBounds,
      ColorFilter.tint(color),
    )
  }

private fun roundedDrawable(radius: Dp): Int =
  when ((radius.value / 4f).let { Math.round(it) }.coerceIn(0, 8)) {
    0 -> R.drawable.widget_round_0
    1 -> R.drawable.widget_round_4
    2 -> R.drawable.widget_round_8
    3 -> R.drawable.widget_round_12
    4 -> R.drawable.widget_round_16
    5 -> R.drawable.widget_round_20
    6 -> R.drawable.widget_round_24
    7 -> R.drawable.widget_round_28
    else -> R.drawable.widget_round_32
  }
