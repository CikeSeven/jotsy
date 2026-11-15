package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
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
import androidx.glance.unit.ColorProvider
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * 快速记录：一到四个自选动作（写日记、新待办、今天的日历、搜索），第一个是主动作
 * （强调色实心），其余为色块。动作已按功能开关过滤（home_widget_native_config.dart）。
 *
 * 版式：
 * - 1×1：只有主动作，一个大圆钮；
 * - 一行（2×1 / 4×1）：动作横排成胶囊，宽度够时带文字；
 * - 方块（2×2）：上面日期与问候，下面动作（三个以上时改为 2×2 宫格、不放问候）；
 * - 横幅（4×2）：左边日期、问候与提示语，右边动作宫格。
 *
 * 问候按此刻的时段（早上 / 下午 / 晚上 / 深夜）；Dart 排好了每天各时段起点的重画。
 */
class QuickCaptureWidget : JotsyGlanceWidget(KIND, setOf(TINY, ROW, ROW_WIDE, SQUARE, WIDE)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val actions = QuickAction.listOf(scope)
    // 按阈值分档（理由见 TodayWidget.Content）。
    when {
      scope.size.width < SQUARE.width -> TinyLayout(scope, actions.first())
      scope.size.height < SQUARE.height ->
        WidgetFrame(scope, null) { RowLayout(scope, actions) }
      scope.size.width >= WIDE.width -> WidgetFrame(scope, null) { WideLayout(scope, actions) }
      else -> WidgetFrame(scope, null) { SquareLayout(scope, actions) }
    }
  }

  companion object {
    const val KIND = "quick_capture"
    val TINY = DpSize(40.dp, 40.dp)
    val ROW = DpSize(110.dp, 40.dp)
    val ROW_WIDE = DpSize(250.dp, 40.dp)
    val SQUARE = DpSize(110.dp, 110.dp)
    val WIDE = DpSize(250.dp, 110.dp)
  }
}

class QuickCaptureWidgetReceiver : HomeWidgetGlanceWidgetReceiver<QuickCaptureWidget>() {
  override val glanceAppWidget = QuickCaptureWidget()
}

@Composable
private fun TinyLayout(scope: WidgetScope, action: QuickAction) {
  WidgetFrame(scope, action.action) {
    Column(
      modifier = GlanceModifier.fillMaxSize(),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Box(
        modifier = GlanceModifier.size(44.dp).roundedBackground(scope.colors.accent, 22.dp),
        contentAlignment = Alignment.Center,
      ) {
        WidgetIcon(scope, action.icon, 20.dp, scope.colors.onAccent)
      }
    }
  }
}

@Composable
private fun RowLayout(scope: WidgetScope, actions: List<QuickAction>) {
  // 每个胶囊至少这么宽才放得下文字（图标 16 + 间距 + 两个字）。
  val labelled =
    scope.showLabels() &&
      scope.size.width.value / actions.size >=
        if (scope.size.width >= QuickCaptureWidget.ROW_WIDE.width) 70f else 96f
  Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
    actions.forEachIndexed { index, action ->
      if (index > 0) Spacer(GlanceModifier.width(scope.metrics.gap))
      ActionPill(
        scope,
        action,
        primary = index == 0,
        showLabel = labelled,
        modifier = GlanceModifier.defaultWeight().fillMaxHeight(),
      )
    }
  }
}

@Composable
private fun SquareLayout(scope: WidgetScope, actions: List<QuickAction>) {
  val colors = scope.colors
  if (actions.size >= 3) {
    ActionGrid(scope, actions, GlanceModifier.fillMaxSize())
    return
  }
  Column(modifier = GlanceModifier.fillMaxSize()) {
    if (scope.showGreeting()) {
      WidgetText(scope, scope.eyebrow(), 12f, colors.accent, FontWeight.Medium)
      Spacer(GlanceModifier.height(2.dp))
      WidgetText(scope, scope.greeting(), 18f, colors.content, FontWeight.Bold, maxLines = 2)
    }
    Spacer(GlanceModifier.defaultWeight())
    Row(modifier = GlanceModifier.fillMaxWidth()) {
      actions.forEachIndexed { index, action ->
        if (index > 0) Spacer(GlanceModifier.width(scope.metrics.gap))
        ActionPill(
          scope,
          action,
          primary = index == 0,
          showLabel = scope.showLabels() && actions.size == 1,
          modifier = GlanceModifier.defaultWeight().height(46.dp),
        )
      }
    }
  }
}

@Composable
private fun WideLayout(scope: WidgetScope, actions: List<QuickAction>) {
  val colors = scope.colors
  Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
    if (scope.showGreeting()) {
      Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
        WidgetText(scope, scope.eyebrow(), 12.5f, colors.accent, FontWeight.Medium)
        Spacer(GlanceModifier.height(4.dp))
        WidgetText(scope, scope.greeting(), 20f, colors.content, FontWeight.Bold, maxLines = 2)
        Spacer(GlanceModifier.defaultWeight())
        WidgetText(scope, scope.snapshot.string("quickPrompt"), 12.5f, colors.contentVariant, maxLines = 2)
      }
      Spacer(GlanceModifier.width(scope.metrics.gap * 1.5f))
    }
    ActionGrid(
      scope,
      actions,
      if (scope.showGreeting()) GlanceModifier.width(156.dp).fillMaxHeight()
      else GlanceModifier.fillMaxSize(),
    )
  }
}

/** 动作宫格：两列，一到四个；只有一两个时各占一整行。 */
@Composable
private fun ActionGrid(scope: WidgetScope, actions: List<QuickAction>, modifier: GlanceModifier) {
  val rows = if (actions.size <= 2) actions.map { listOf(it) } else actions.chunked(2)
  Column(modifier = modifier) {
    rows.forEachIndexed { rowIndex, row ->
      if (rowIndex > 0) Spacer(GlanceModifier.height(scope.metrics.gap))
      Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
        row.forEachIndexed { columnIndex, action ->
          if (columnIndex > 0) Spacer(GlanceModifier.width(scope.metrics.gap))
          ActionTile(
            scope,
            action,
            primary = rowIndex == 0 && columnIndex == 0,
            modifier = GlanceModifier.defaultWeight().fillMaxHeight(),
          )
        }
      }
    }
  }
}

/** 胶囊按钮：图标（可带文字）横排居中。 */
@Composable
private fun ActionPill(
  scope: WidgetScope,
  action: QuickAction,
  primary: Boolean,
  showLabel: Boolean,
  modifier: GlanceModifier,
) {
  val (background, foreground) = actionColors(scope, primary)
  Box(
    modifier =
      modifier.roundedBackground(background, pillRadius(scope)).clickable(action.action),
    contentAlignment = Alignment.Center,
  ) {
    Row(verticalAlignment = Alignment.CenterVertically) {
      WidgetIcon(scope, action.icon, 16.dp, foreground)
      if (showLabel && action.label.isNotEmpty()) {
        Spacer(GlanceModifier.width(6.dp))
        WidgetText(scope, action.label, 13f, foreground, FontWeight.Medium)
      }
    }
  }
}

/** 宫格色块：图标在上、文字在下。 */
@Composable
private fun ActionTile(
  scope: WidgetScope,
  action: QuickAction,
  primary: Boolean,
  modifier: GlanceModifier,
) {
  val (background, foreground) = actionColors(scope, primary)
  Box(
    modifier =
      modifier.roundedBackground(background, scope.metrics.innerRadius).clickable(action.action),
    contentAlignment = Alignment.Center,
  ) {
    Column(
      horizontalAlignment = Alignment.CenterHorizontally,
      modifier = GlanceModifier.padding(horizontal = 4.dp),
    ) {
      WidgetIcon(scope, action.icon, 18.dp, foreground)
      if (scope.showLabels() && action.label.isNotEmpty()) {
        Spacer(GlanceModifier.height(4.dp))
        WidgetText(scope, action.label, 12f, foreground, FontWeight.Medium)
      }
    }
  }
}

private fun actionColors(scope: WidgetScope, primary: Boolean): Pair<ColorProvider, ColorProvider> =
  if (primary) scope.colors.accent to scope.colors.onAccent
  else scope.colors.tile to scope.colors.onTile

/** 胶囊的圆角：一行版式里取内圆角与高度一半中较小的，按钮是胶囊或同心圆角块。 */
private fun pillRadius(scope: WidgetScope): Dp = minOf(scope.metrics.innerRadius * 1.5f, 24.dp)
