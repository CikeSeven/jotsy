package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import com.jotsy.diary.widgets.DisplayText
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlin.math.max

/**
 * 纪念日：一个纪念日的大号倒数，或接下来几个的列表（内容选项 `display`）。
 *
 * 单个：1×1 只有数字与单位；一行（2×1 / 4×1）为数字 + 名称与日期；方块为名称、大数字、
 * 单位（“天后 / 天前”）与日期；横幅为左边大数字、右边名称、日期与第几周年。当天显示
 * “就是今天 / 今天是第 N 周年”。
 * 列表：眉标“纪念日”，下面按今天重新排序的若干行（行数随高度），每行名称、日期与
 * 行尾的天数。
 *
 * 点按：单个打开它的详情，列表的每一行打开各自的详情、眉标打开纪念日列表；还没有
 * 纪念日时打开纪念日列表。
 */
class AnniversaryWidget : JotsyGlanceWidget(KIND, setOf(TINY, ROW, ROW_WIDE, SQUARE, WIDE, LARGE)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val items =
      AnniversaryItem.sorted(AnniversaryItem.listOf(scope.snapshot.array("anniversaries")), scope.today)
    if (items.isEmpty()) {
      WidgetFrame(scope, WidgetLaunch.action(scope.context, "anniversary")) {
        EmptyState(scope)
      }
      return
    }
    val size = scope.size
    val list = scope.content.optString("display") == "list"
    when {
      size.width < SQUARE.width -> Single(scope, pick(scope, items), Variant.TINY)
      size.height < SQUARE.height -> Single(scope, pick(scope, items), Variant.ROW)
      list -> ListLayout(scope, items)
      size.width >= WIDE.width -> Single(scope, pick(scope, items), Variant.WIDE)
      else -> Single(scope, pick(scope, items), Variant.SQUARE)
    }
  }

  companion object {
    const val KIND = "anniversary"
    val TINY = DpSize(40.dp, 40.dp)
    val ROW = DpSize(110.dp, 40.dp)
    val ROW_WIDE = DpSize(250.dp, 40.dp)
    val SQUARE = DpSize(110.dp, 110.dp)
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)
  }
}

class AnniversaryWidgetReceiver : HomeWidgetGlanceWidgetReceiver<AnniversaryWidget>() {
  override val glanceAppWidget = AnniversaryWidget()
}

private enum class Variant {
  TINY,
  ROW,
  SQUARE,
  WIDE,
}

/** 单个模式显示哪一个：指定的那个（还在的话），否则排在最前的。 */
private fun pick(
  scope: WidgetScope,
  items: List<Pair<AnniversaryItem, AnniversaryItem.State>>,
): Pair<AnniversaryItem, AnniversaryItem.State> {
  val id = scope.content.optString("id")
  return items.firstOrNull { it.first.id == id } ?: items.first()
}

/** 大数字下方的单位，当天为“就是今天 / 今天是第 N 周年”。 */
private fun unitOf(scope: WidgetScope, state: AnniversaryItem.State): String =
  when (state.phase) {
    AnniversaryItem.Phase.UPCOMING -> scope.snapshot.plural("daysToGo", state.days)
    AnniversaryItem.Phase.PAST -> scope.snapshot.plural("daysAgo", state.days)
    AnniversaryItem.Phase.TODAY -> state.next?.todayLabel ?: scope.snapshot.string("isToday")
  }

/** 日期一行：“12月3日 · 周四 · 第 5 周年”；已过去的不重复纪念日没有下一次，不显示。 */
private fun dateLineOf(scope: WidgetScope, state: AnniversaryItem.State): String? {
  if (!scope.content.optBoolean("date", true)) return null
  val next = state.next ?: return null
  // 当天上方已经写着“今天是第 N 周年”，日期行不再重复周年。
  if (state.phase == AnniversaryItem.Phase.TODAY) return next.dateLabel
  return listOfNotNull(next.dateLabel, next.ordinalLabel).joinToString(" · ")
}

@Composable
private fun Single(
  scope: WidgetScope,
  entry: Pair<AnniversaryItem, AnniversaryItem.State>,
  variant: Variant,
) {
  val (item, state) = entry
  val colors = scope.colors
  val tap = WidgetLaunch.action(scope.context, "anniversary", mapOf("id" to item.id))
  val today = state.phase == AnniversaryItem.Phase.TODAY
  // 当天不显示“0”：大字换成“今天”。
  val number = if (today) scope.snapshot.string("isToday") else state.days.toString()
  val unit = unitOf(scope, state)
  val icon = if (item.repeats) "anniversary" else "countdown"
  WidgetFrame(scope, tap) {
    when (variant) {
      // 窄的版式里当天不写“就是今天”四个大字（会挤掉名称）：换成强调色的大号图标，
      // 文字放到副标题（“今天是第 N 周年”）。
      Variant.TINY ->
        Column(
          modifier = GlanceModifier.fillMaxSize(),
          horizontalAlignment = Alignment.CenterHorizontally,
          verticalAlignment = Alignment.CenterVertically,
        ) {
          if (today) {
            WidgetIcon(scope, icon, 24.dp, colors.accent)
            Spacer(GlanceModifier.height(4.dp))
            WidgetText(scope, scope.snapshot.string("isToday"), 10f, colors.contentVariant, align = TextAlign.Center)
          } else {
            DisplayText(scope, number, 28f, colors.accent, scope.size.width)
            WidgetText(scope, unit, 10f, colors.contentVariant, align = TextAlign.Center)
          }
        }
      Variant.ROW ->
        Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
          if (today) {
            WidgetIcon(scope, icon, 28.dp, colors.accent)
          } else {
            DisplayText(scope, number, 34f, colors.accent, 120.dp)
          }
          Spacer(GlanceModifier.width(10.dp))
          Column(modifier = GlanceModifier.defaultWeight()) {
            WidgetText(scope, item.title, 13.5f, colors.content, FontWeight.Bold)
            WidgetText(
              scope,
              if (today) unit else listOfNotNull(unit, dateLineOf(scope, state)).joinToString(" · "),
              11.5f,
              colors.contentVariant,
            )
          }
        }
      Variant.SQUARE ->
        Column(modifier = GlanceModifier.fillMaxSize()) {
          Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            WidgetIcon(scope, icon, 12.dp, colors.accent)
            Spacer(GlanceModifier.width(6.dp))
            WidgetText(
              scope,
              item.title,
              13f,
              colors.content,
              FontWeight.Bold,
              modifier = GlanceModifier.defaultWeight(),
            )
          }
          Spacer(GlanceModifier.defaultWeight())
          DisplayText(scope, number, if (today) 26f else 48f, colors.accent, scope.size.width)
          WidgetText(scope, unit, 12.5f, colors.contentVariant, FontWeight.Medium)
          Spacer(GlanceModifier.defaultWeight())
          dateLineOf(scope, state)?.let { WidgetText(scope, it, 11f, colors.contentVariant) }
        }
      Variant.WIDE ->
        Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
          Column(modifier = GlanceModifier.width(132.dp)) {
            DisplayText(scope, number, if (today) 24f else 54f, colors.accent, 132.dp)
            WidgetText(scope, unit, 13f, colors.contentVariant, FontWeight.Medium)
          }
          Spacer(GlanceModifier.width(scope.metrics.gap * 1.5f))
          Box(modifier = GlanceModifier.width(1.dp).height(72.dp).background(colors.track)) {}
          Spacer(GlanceModifier.width(scope.metrics.gap * 1.5f))
          Column(modifier = GlanceModifier.defaultWeight()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
              WidgetIcon(scope, icon, 13.dp, colors.accent)
              Spacer(GlanceModifier.width(6.dp))
              WidgetText(scope, item.title, 16f, colors.content, FontWeight.Bold)
            }
            Spacer(GlanceModifier.height(6.dp))
            if (scope.content.optBoolean("date", true)) {
              state.next?.let {
                WidgetText(scope, it.dateLabel, 12f, colors.contentVariant)
                it.ordinalLabel?.let { ordinal -> WidgetText(scope, ordinal, 12f, colors.contentVariant) }
              }
              item.lunar?.let { WidgetText(scope, it, 12f, colors.contentVariant) }
            }
          }
        }
    }
  }
}

@Composable
private fun ListLayout(scope: WidgetScope, items: List<Pair<AnniversaryItem, AnniversaryItem.State>>) {
  val colors = scope.colors
  // 每行约 44dp（两行文字 + 间距），眉标约 24dp。
  val rows = max(1, ((scope.size.height.value - scope.metrics.padding.value * 2 - 24f) / 44f).toInt())
  WidgetFrame(scope, null) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
      Row(
        modifier = GlanceModifier.fillMaxWidth().clickable(WidgetLaunch.action(scope.context, "anniversary")),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        WidgetIcon(scope, "anniversary", 12.dp, colors.accent)
        Spacer(GlanceModifier.width(6.dp))
        WidgetText(scope, scope.snapshot.string("anniversaryTitle"), 12.5f, colors.accent, FontWeight.Medium)
      }
      Spacer(GlanceModifier.height(6.dp))
      items.take(rows).forEachIndexed { index, (item, state) ->
        if (index > 0) Box(modifier = GlanceModifier.fillMaxWidth().height(1.dp).background(colors.track)) {}
        ListRow(scope, item, state)
      }
    }
  }
}

@Composable
private fun ListRow(scope: WidgetScope, item: AnniversaryItem, state: AnniversaryItem.State) {
  val colors = scope.colors
  val today = state.phase == AnniversaryItem.Phase.TODAY
  Row(
    modifier =
      GlanceModifier.fillMaxWidth()
        .padding(vertical = 6.dp)
        .clickable(WidgetLaunch.action(scope.context, "anniversary", mapOf("id" to item.id))),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Column(modifier = GlanceModifier.defaultWeight()) {
      Row(verticalAlignment = Alignment.CenterVertically) {
        if (item.pinned) {
          WidgetIcon(scope, "pin", 10.dp, colors.accent)
          Spacer(GlanceModifier.width(4.dp))
        }
        WidgetText(scope, item.title, 13.5f, colors.content, FontWeight.Bold)
      }
      dateLineOf(scope, state)?.let { WidgetText(scope, it, 11f, colors.contentVariant) }
    }
    Spacer(GlanceModifier.width(8.dp))
    if (today) {
      // 窄的列表里只放心形，不放“就是今天”的文字标签（会挤掉名称）。
      val narrow = scope.size.width < AnniversaryWidget.WIDE.width
      Box(
        modifier =
          GlanceModifier.roundedBackground(colors.accent, 10.dp).padding(horizontal = 8.dp, vertical = 4.dp),
      ) {
        if (narrow) {
          WidgetIcon(scope, if (item.repeats) "anniversary" else "countdown", 11.dp, colors.onAccent)
        } else {
          WidgetText(scope, scope.snapshot.string("isToday"), 11.5f, colors.onAccent, FontWeight.Bold)
        }
      }
    } else {
      Row(verticalAlignment = Alignment.CenterVertically) {
        DisplayText(scope, state.days.toString(), 20f, colors.accent, 96.dp)
        Spacer(GlanceModifier.width(4.dp))
        WidgetText(scope, unitOf(scope, state), 11f, colors.contentVariant)
      }
    }
  }
}

/** 还没有纪念日：心形图标与一句话，点按打开纪念日列表（那里可以新建）。 */
@Composable
private fun EmptyState(scope: WidgetScope) {
  Column(
    modifier = GlanceModifier.fillMaxSize(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalAlignment = Alignment.CenterVertically,
  ) {
    WidgetIcon(scope, "anniversary", 20.dp, scope.colors.accent)
    Spacer(GlanceModifier.height(8.dp))
    WidgetText(
      scope,
      scope.snapshot.string("anniversaryEmpty"),
      12.5f,
      scope.colors.contentVariant,
      maxLines = 2,
      align = TextAlign.Center,
    )
  }
}
