package com.jotsy.diary.widgets.kinds

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
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
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextDecoration
import androidx.glance.text.TextStyle
import com.jotsy.diary.widgets.JotsyGlanceWidget
import com.jotsy.diary.widgets.WidgetActions
import com.jotsy.diary.widgets.WidgetBitmaps
import com.jotsy.diary.widgets.WidgetFrame
import com.jotsy.diary.widgets.WidgetIcon
import com.jotsy.diary.widgets.WidgetLaunch
import com.jotsy.diary.widgets.WidgetScope
import com.jotsy.diary.widgets.WidgetText
import com.jotsy.diary.widgets.roundedBackground
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlin.math.max

/**
 * 待办清单：今天（含逾期）/ 计划 / 全部 / 某个清单的待办，在桌面上直接勾选完成。
 *
 * 表头：“今天”视图带完成进度环与“已完成 / 总数”，其余视图为名称与条数；右侧“+”新建
 * （某个清单时预先选好这个清单）。下面是待办行：圆圈点一下即完成（先乐观划掉，再交给
 * Dart 写库，[WidgetActions.completeTodo]），标题点一下打开详情；今天完成的划掉排在最后，
 * 点圆圈恢复。截止日按本机日期说成昨天 / 今天 / 明天或日期，逾期为警示色。
 *
 * 尺寸：2×2 / 4×2 / 4×4 都是放得下几行就放几行（不滚动，理由见 Content 里的注释）。
 */
class TodosWidget : JotsyGlanceWidget(KIND, setOf(SQUARE, WIDE, LARGE)) {
  @Composable
  override fun Content(scope: WidgetScope) {
    val section = scope.snapshot.section("todos")
    val lists = section?.optJSONObject("lists")
    val listId = scope.content.optString("list")
    val requested = scope.content.optString("view", "today")
    // 清单被删除时按“全部”显示。
    val view = if (requested == "list" && (listId.isEmpty() || lists?.has(listId) != true)) "all" else requested
    val (open, done) = TodoEntry.read(scope)
    val today = scope.today
    fun matches(entry: TodoEntry) =
      when (view) {
        "today" -> entry.due != null && !entry.due.isAfter(today)
        "planned" -> entry.due != null
        "list" -> entry.list == listId
        else -> true
      }
    val shownOpen = open.filter(::matches)
    // 今天完成的：“今天”视图里不论原来的截止日都算（今天做完的事），清单视图只算这个清单的。
    val doneToday = done.filter { view != "list" || it.list == listId }
    val shownDone = if (scope.content.optBoolean("completed", true)) doneToday else emptyList()
    val title =
      when (view) {
        "today" -> scope.snapshot.string("todoViewToday")
        "planned" -> scope.snapshot.string("todoViewPlanned")
        "list" -> lists?.optString(listId).orEmpty()
        else -> scope.snapshot.string("todoViewAll")
      }
    val add =
      WidgetLaunch.action(scope.context, "todo-new", mapOf("list" to listId.takeIf { view == "list" }))
    WidgetFrame(scope, null) {
      Column(modifier = GlanceModifier.fillMaxSize()) {
        Header(scope, title, view == "today", shownOpen.size, doneToday.size, add)
        Spacer(GlanceModifier.height(scope.metrics.gap))
        val rows = shownOpen + shownDone
        if (rows.isEmpty()) {
          Empty(scope, if (view == "today") "todoEmptyToday" else "todoEmpty")
        } else {
          if (shownOpen.isEmpty()) AllDone(scope)
          // 不用可滚动的 LazyColumn：它在应用内预览（RemoteViews 直接展开）里画不出来，
          // 预览与桌面会不一致。放得下几行就放几行：表头约 44dp，每行约 34dp，按格子的
          // 实际高度算（桌面上是挑中的那一档）。
          val room = scope.size.height.value - scope.metrics.padding.value * 2 - 44f - scope.metrics.gap.value
          rows.take(max(1, (room / 34f).toInt())).forEach { TodoRow(scope, it, view == "today") }
        }
      }
    }
  }

  companion object {
    const val KIND = "todos"
    val SQUARE = DpSize(110.dp, 110.dp)
    val WIDE = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)
  }
}

class TodosWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodosWidget>() {
  override val glanceAppWidget = TodosWidget()
}

@Composable
private fun Header(
  scope: WidgetScope,
  title: String,
  todayView: Boolean,
  open: Int,
  done: Int,
  add: androidx.glance.action.Action,
) {
  val colors = scope.colors
  Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
    if (todayView) {
      val total = open + done
      val ringSize = 26.dp
      Box(modifier = GlanceModifier.size(ringSize), contentAlignment = Alignment.Center) {
        Image(
          provider = ImageProvider(WidgetBitmaps.ring(scope.context, ringSize.value, 3f, 1f)),
          contentDescription = null,
          modifier = GlanceModifier.size(ringSize),
          colorFilter = ColorFilter.tint(colors.track),
        )
        if (total > 0 && done > 0) {
          Image(
            provider = ImageProvider(WidgetBitmaps.ring(scope.context, ringSize.value, 3f, done.toFloat() / total)),
            contentDescription = null,
            modifier = GlanceModifier.size(ringSize),
            colorFilter = ColorFilter.tint(colors.accent),
          )
        }
      }
      Spacer(GlanceModifier.width(8.dp))
    }
    Column(modifier = GlanceModifier.defaultWeight()) {
      WidgetText(scope, title, 14f, colors.content, FontWeight.Bold)
      WidgetText(
        scope,
        if (todayView) "$done / ${open + done}" else open.toString(),
        11f,
        colors.contentVariant,
      )
    }
    Box(
      modifier =
        GlanceModifier.size(30.dp)
          .roundedBackground(colors.accent, 15.dp)
          .clickable(add)
          .semantics { contentDescription = scope.snapshot.string("todoAdd") },
      contentAlignment = Alignment.Center,
    ) {
      WidgetIcon(scope, "plus", 14.dp, colors.onAccent)
    }
  }
}

@Composable
private fun TodoRow(scope: WidgetScope, entry: TodoEntry, todayView: Boolean) {
  val colors = scope.colors
  val showDue = scope.content.optBoolean("due", true)
  Row(
    modifier = GlanceModifier.fillMaxWidth().padding(vertical = 4.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    val check =
      if (entry.done) WidgetActions.reopenTodo(entry.id)
      else WidgetActions.completeTodo(entry.id, entry.due?.toString())
    Box(
      modifier =
        GlanceModifier.size(26.dp)
          .clickable(check)
          .semantics {
            contentDescription =
              scope.snapshot.string(if (entry.done) "todoUncheck" else "todoCheck")
          },
      contentAlignment = Alignment.Center,
    ) {
      WidgetIcon(
        scope,
        if (entry.done) "checked" else "unchecked",
        18.dp,
        if (entry.done) colors.accent else colors.contentVariant,
      )
    }
    Spacer(GlanceModifier.width(6.dp))
    Text(
      text = entry.title,
      maxLines = 1,
      modifier =
        GlanceModifier.defaultWeight()
          .clickable(WidgetLaunch.action(scope.context, "todo", mapOf("id" to entry.id))),
      style =
        TextStyle(
          color = if (entry.done) colors.contentVariant else colors.content,
          fontSize = scope.metrics.sp(13.5f).sp,
          textDecoration = if (entry.done) TextDecoration.LineThrough else TextDecoration.None,
        ),
    )
    if (entry.repeat && !entry.done) {
      Spacer(GlanceModifier.width(4.dp))
      WidgetIcon(scope, "repeat", 10.dp, colors.contentVariant)
    }
    if (showDue) {
      entry.dueText(scope, todayView)?.let { (text, overdue) ->
        Spacer(GlanceModifier.width(6.dp))
        WidgetText(
          scope,
          text,
          11.5f,
          if (overdue) colors.danger else colors.contentVariant,
          if (overdue) FontWeight.Medium else FontWeight.Normal,
        )
      }
    }
  }
}

/** 还有完成的、但没有待做的了：“今天的事都做完了”。 */
@Composable
private fun AllDone(scope: WidgetScope) {
  WidgetText(scope, scope.snapshot.string("todoAllDone"), 12f, scope.colors.accent, FontWeight.Medium)
  Spacer(GlanceModifier.height(2.dp))
}

@Composable
private fun Empty(scope: WidgetScope, key: String) {
  Column(
    modifier = GlanceModifier.fillMaxSize(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalAlignment = Alignment.CenterVertically,
  ) {
    WidgetIcon(scope, "checked", 22.dp, scope.colors.accent)
    Spacer(GlanceModifier.height(6.dp))
    WidgetText(
      scope,
      scope.snapshot.string(key),
      12.5f,
      scope.colors.contentVariant,
      maxLines = 2,
      align = TextAlign.Center,
    )
  }
}
