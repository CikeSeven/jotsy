package com.jotsy.diary.widgets

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.glance.ExperimentalGlanceApi
import androidx.glance.appwidget.compose
import kotlin.math.roundToInt
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

/** 渲染测试共用：读 Dart 生成的快照样例，按给定外观组合并展开一个小组件。 */
object WidgetRenderSupport {
  /** test/ui/home_widgets/home_widget_snapshot_builder_test.dart 生成的快照。 */
  fun fixture(context: Context): WidgetSnapshot {
    val raw =
      javaClass.classLoader!!.getResource("widget_snapshot_fixture.json")!!.readText()
    val preferences = context.getSharedPreferences("widget-render-test", Context.MODE_PRIVATE)
    preferences.edit().putString(WidgetSnapshot.KEY, raw).commit()
    return WidgetSnapshot.read(preferences)
  }

  /** 外观的几种组合（配色 × 底色 × 强调色 × 圆角），覆盖各个分支。 */
  val styles: Map<String, JSONObject> =
    linkedMapOf(
      "surface" to style(),
      "tonal-tertiary" to style(background = "tonal", accent = "tertiary"),
      "vivid-seed" to style(background = "vivid", palette = "seed:FFD98BA0"),
      "clear-dark" to style(background = "clear", brightness = "dark"),
      "translucent-roomy" to style(opacity = 0.6, density = "roomy", radius = 28.0),
      "wallpaper-compact" to style(palette = "wallpaper", density = "compact", textScale = 1.2),
    )

  private fun style(
    palette: String = "app",
    brightness: String = "system",
    background: String = "surface",
    opacity: Double = 1.0,
    radius: Double = -1.0,
    textScale: Double = 1.0,
    density: String = "standard",
    accent: String = "primary",
  ) =
    JSONObject()
      .put("palette", palette)
      .put("brightness", brightness)
      .put("background", background)
      .put("opacity", opacity)
      .put("radius", radius)
      .put("textScale", textScale)
      .put("density", density)
      .put("accent", accent)

  /** 快照里某种类的默认配置换上 [style]（[content] 给出时换掉其中这几项）。 */
  fun instance(
    snapshot: WidgetSnapshot,
    kind: String,
    style: JSONObject,
    content: JSONObject? = null,
  ): WidgetInstance {
    val base = snapshot.instanceFor(null, kind)
    val merged = JSONObject(base.content.toString())
    content?.keys()?.forEach { merged.put(it, content.get(it)) }
    return WidgetInstance(base.kind, base.disabled, WidgetStyle.parse(style), merged)
  }

  fun themed(context: Context, dark: Boolean): Context {
    val config = Configuration(context.resources.configuration)
    config.uiMode =
      (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
        if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
    return context.createConfigurationContext(config)
  }

  /** 组合、展开并按 [size] 排版，返回展开后的根视图。 */
  @OptIn(ExperimentalGlanceApi::class)
  fun render(
    context: Context,
    widget: JotsyGlanceWidget,
    size: DpSize,
    state: WidgetPreviewState,
  ): View {
    val views = runBlocking { widget.compose(context, size = size, state = state) }
    val host = FrameLayout(context)
    val root = views.apply(context, host)
    val density = context.resources.displayMetrics.density
    val width = (size.width.value * density).roundToInt()
    val height = (size.height.value * density).roundToInt()
    root.measure(
      View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
    )
    root.layout(0, 0, width, height)
    return root
  }

  fun draw(root: View): Bitmap {
    val bitmap = Bitmap.createBitmap(root.width, root.height, Bitmap.Config.ARGB_8888)
    root.draw(Canvas(bitmap))
    return bitmap
  }
}
