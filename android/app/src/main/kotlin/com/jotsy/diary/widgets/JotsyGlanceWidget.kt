package com.jotsy.diary.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.glance.GlanceId
import androidx.glance.LocalSize
import androidx.glance.LocalState
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.PreviewSizeMode
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.time.LocalDate
import java.time.LocalDateTime
import org.json.JSONObject

/**
 * 所有 Jotsy 桌面小组件的基类。
 *
 * 数据：Glance 的状态是 home_widget 的 SharedPreferences（[HomeWidgetGlanceStateDefinition]），
 * Dart 写入快照后调用刷新，Glance 重新读状态、重新组合。应用内预览经 `compose(state =
 * WidgetPreviewState(...))` 传入草稿配置，同一份组合代码画出来，所见即所得。
 *
 * 尺寸：[SizeMode.Responsive]，每个种类声明自己的几档（[sizes]），启动器按实际格子挑最大的
 * 那一档，内容再按 [LocalSize] 细调。
 *
 * 兜底：还没有快照（应用装好后没打开过）时显示“打开 Jotsy”；所需功能关闭时显示“已在功能
 * 管理中关闭”。两者点按都只打开应用。
 */
abstract class JotsyGlanceWidget(
  private val kind: String,
  sizes: Set<DpSize>,
) : GlanceAppWidget() {
  override val sizeMode: SizeMode = SizeMode.Responsive(sizes)

  /** 生成预览（Android 15+）同样按这几档出图，启动器挑合适的那一张。 */
  override val previewSizeMode: PreviewSizeMode = SizeMode.Responsive(sizes)

  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    // 预览用的假 id 换不出真实的 appWidgetId，按“没有配置”处理即可（预览自带配置）。
    val appWidgetId =
      try {
        GlanceAppWidgetManager(context).getAppWidgetId(id)
      } catch (_: Exception) {
        null
      }
    provideContent {
      val state = LocalState.current
      val (snapshot, instance) =
        when (state) {
          is WidgetPreviewState -> state.snapshot to state.instance
          is HomeWidgetGlanceState -> {
            val read = WidgetSnapshot.read(state.preferences)
            read to read.instanceFor(appWidgetId, kind)
          }
          else -> WidgetSnapshot.EMPTY to WidgetInstance.fallback(kind)
        }
      // 乐观更新只在桌面上生效；预览只看快照与草稿。
      val overlay = (state as? HomeWidgetGlanceState)?.let { WidgetOverlay.read(it.preferences) }
      Render(WidgetScope(context, snapshot, instance, appWidgetId, LocalSize.current, overlay))
    }
  }

  /**
   * 启动器小组件列表里的生成预览（Android 15+，[WidgetPreviews] 发布）：示例快照与这个种类
   * 的默认配置，不读用户自己的数据。
   */
  override suspend fun providePreview(context: Context, widgetCategory: Int) {
    val sample = WidgetSnapshot.readSample(WidgetState.homeWidgetPreferences(context))
    provideContent {
      Render(WidgetScope(context, sample, sample.instanceFor(null, kind), null, LocalSize.current))
    }
  }

  @Composable
  private fun Render(scope: WidgetScope) {
    val context = scope.context
    when {
      scope.snapshot.isEmpty ->
        WidgetMessage(scope, context.getString(com.jotsy.diary.R.string.widget_open_app))
      scope.instance.disabled ->
        WidgetMessage(
          scope,
          scope.snapshot.string("featureOff", context.getString(com.jotsy.diary.R.string.widget_open_app)),
        )
      else -> Content(scope)
    }
  }

  @Composable abstract fun Content(scope: WidgetScope)
}

/** 应用内预览传进组合的状态：快照（含草稿新选的配色）与草稿配置。 */
class WidgetPreviewState(val snapshot: WidgetSnapshot, val instance: WidgetInstance)

/** 一次绘制所需的一切。 */
class WidgetScope(
  val context: Context,
  val snapshot: WidgetSnapshot,
  val instance: WidgetInstance,
  val appWidgetId: Int?,
  val size: DpSize,
  /** 桌面上操作的乐观更新（[WidgetOverlay]）；预览时为 null。 */
  val overlay: JSONObject? = null,
) {
  val style: WidgetStyle = instance.style
  val content: JSONObject = instance.content
  val colors: WidgetColors = WidgetColors.resolve(context, snapshot, style)
  val metrics: WidgetMetrics = WidgetMetrics(context, style)
  val now: LocalDateTime = LocalDateTime.now()
  val today: LocalDate = now.toLocalDate()
}
