package com.jotsy.diary.widgets

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.jotsy.diary.MainActivity
import es.antonborri.home_widget.actionStartActivity
import java.time.LocalDate
import java.util.Locale

/**
 * 小组件的外框：整块底色（透明底时没有）、外圆角、内边距，点按打开 [onClick]。
 * 标了 [appWidgetBackground]，Android 12+ 的启动器据此做展开动画与圆角裁切。
 */
@Composable
fun WidgetFrame(
  scope: WidgetScope,
  onClick: Action?,
  content: @Composable () -> Unit,
) {
  var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
  scope.colors.background?.let { modifier = modifier.roundedBackground(it, scope.metrics.radius) }
  if (onClick != null) modifier = modifier.clickable(onClick)
  Box(modifier = modifier.padding(scope.metrics.padding)) { content() }
}

/** 一个 FontAwesome 图标（按 [tint] 着色）；字形读不到时留出同样大小的空位。 */
@Composable
fun WidgetIcon(scope: WidgetScope, key: String, size: Dp, tint: ColorProvider) {
  val bitmap = WidgetGlyphs.icon(scope.context, scope.snapshot.icon(key), size.value)
  if (bitmap == null) {
    Spacer(GlanceModifier.size(size))
    return
  }
  Image(
    provider = ImageProvider(bitmap),
    contentDescription = null,
    modifier = GlanceModifier.size(size),
    colorFilter = ColorFilter.tint(tint),
  )
}

/**
 * 展示文字（大号日期数字等）：应用的展示字体（HarmonyOS Sans 粗体），画成位图后着色。
 * [maxWidth] 为这行最多能占的宽度，放不下时省略号截断。
 */
@Composable
fun DisplayText(
  scope: WidgetScope,
  text: String,
  sizeSp: Float,
  color: ColorProvider,
  maxWidth: Dp,
  weight: Int = 700,
) {
  val bitmap =
    WidgetGlyphs.text(
      scope.context,
      scope.snapshot.displayFont,
      text,
      scope.metrics.sp(sizeSp),
      weight,
      maxWidth.value,
    )
  Image(
    provider = ImageProvider(bitmap),
    contentDescription = text,
    colorFilter = ColorFilter.tint(color),
  )
}

/** 系统字体的一行文字，字号按外观的文字缩放换算。 */
@Composable
fun WidgetText(
  scope: WidgetScope,
  text: String,
  sizeSp: Float,
  color: ColorProvider,
  weight: FontWeight = FontWeight.Normal,
  maxLines: Int = 1,
  modifier: GlanceModifier = GlanceModifier,
  align: TextAlign? = null,
) {
  Text(
    text = text,
    modifier = modifier,
    maxLines = maxLines,
    style =
      TextStyle(
        color = color,
        fontSize = scope.metrics.sp(sizeSp).sp,
        fontWeight = weight,
        textAlign = align,
      ),
  )
}

/** 占位：居中的图标与一句话（打开应用、功能已关闭），点按打开应用。 */
@Composable
fun WidgetMessage(scope: WidgetScope, message: String) {
  WidgetFrame(scope, WidgetLaunch.action(scope.context, "home")) {
    Column(
      modifier = GlanceModifier.fillMaxSize(),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      WidgetIcon(scope, "write", 20.dp, scope.colors.accent)
      Spacer(GlanceModifier.height(8.dp))
      WidgetText(
        scope,
        message,
        12.5f,
        scope.colors.contentVariant,
        maxLines = 3,
        align = TextAlign.Center,
      )
    }
  }
}

/** 点小组件打开应用的链接（`jotsy://widget/<目标>`，Dart `HomeWidgetLaunch.parse`）。 */
object WidgetLaunch {
  fun uri(target: String, params: Map<String, String?> = emptyMap()): Uri {
    val builder = Uri.Builder().scheme("jotsy").authority("widget").appendPath(target)
    params.forEach { (key, value) -> if (value != null) builder.appendQueryParameter(key, value) }
    return builder.build()
  }

  fun action(context: Context, target: String, params: Map<String, String?> = emptyMap()): Action =
    actionStartActivity<MainActivity>(context, uri(target, params))
}

/** 日期键（`YYYY-MM-DD`，与 Dart `homeWidgetDayKey` 同口径）。 */
object WidgetDates {
  // Locale.ROOT：有的系统语言（阿拉伯语等）的默认数字不是 0-9。
  fun key(day: LocalDate): String =
    String.format(Locale.ROOT, "%04d-%02d-%02d", day.year, day.monthValue, day.dayOfMonth)
}
