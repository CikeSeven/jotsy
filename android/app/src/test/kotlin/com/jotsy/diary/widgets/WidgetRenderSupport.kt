package com.jotsy.diary.widgets

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.view.View
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.glance.ExperimentalGlanceApi
import androidx.glance.appwidget.compose
import java.io.File
import kotlin.math.roundToInt
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

/** 渲染测试共用：读 Dart 生成的快照样例，按给定外观组合并展开一个小组件。 */
object WidgetRenderSupport {
  /**
   * test/ui/home_widgets/home_widget_snapshot_builder_test.dart 生成的快照。照片路径
   * （`/fixture/<名字>.png`）换成这里现画的图片；[redacted] 为 true 时按开了应用锁处理
   * （Dart 那时不写日记内容，这里把三节一并去掉）。
   */
  fun fixture(context: Context, redacted: Boolean = false): WidgetSnapshot {
    val photos = fixturePhotos(context)
    val raw =
      javaClass.classLoader!!.getResource("widget_snapshot_fixture.json")!!.readText()
        .replace("\"/fixture/", "\"${photos.path}/")
    val json = JSONObject(raw)
    if (redacted) {
      json.put("redacted", true)
      json.remove("diaries")
      json.remove("onThisDay")
      json.remove("recent")
      json.remove("photos")
    }
    val preferences = context.getSharedPreferences("widget-render-test", Context.MODE_PRIVATE)
    preferences.edit().putString(WidgetSnapshot.KEY, json.toString()).commit()
    return WidgetSnapshot.read(preferences)
  }

  /** 某种界面语言的示例快照（`widget_sample_<语言>.json`，预览用，见 `WidgetPreviewImageTest`）。 */
  fun sample(context: Context, language: String): WidgetSnapshot {
    val raw =
      javaClass.classLoader!!.getResource("widget_sample_$language.json")!!.readText()
    val preferences = context.getSharedPreferences("widget-preview-test", Context.MODE_PRIVATE)
    preferences.edit().putString(WidgetSnapshot.KEY, raw).commit()
    return WidgetSnapshot.read(preferences)
  }

  /** 夹具里引用的几张照片：色块拼成的风景，横竖各有，验证裁切与缩放。 */
  private fun fixturePhotos(context: Context): File {
    val dir = File(context.cacheDir, "fixture").apply { mkdirs() }
    val photos =
      mapOf(
        "sea.png" to Triple(1200, 800, intArrayOf(0xFF8EC5E8.toInt(), 0xFF2F6E9E.toInt(), 0xFFE9D8B4.toInt())),
        "run.png" to Triple(800, 1200, intArrayOf(0xFFF4C27A.toInt(), 0xFF7BA66B.toInt(), 0xFF4E5D3F.toInt())),
        "market.png" to Triple(1000, 1000, intArrayOf(0xFFF7E3D0.toInt(), 0xFFD9774B.toInt(), 0xFF8C3B2E.toInt())),
      )
    for ((name, spec) in photos) {
      val file = File(dir, name)
      if (file.exists()) continue
      val (width, height, bands) = spec
      val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bitmap)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG)
      bands.forEachIndexed { index, color ->
        paint.color = color
        val top = height * index / bands.size.toFloat()
        canvas.drawRect(0f, top, width.toFloat(), height.toFloat(), paint)
      }
      paint.color = 0xFFFFF6D8.toInt()
      canvas.drawCircle(width * 0.72f, height * 0.22f, minOf(width, height) * 0.09f, paint)
      file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    return dir
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
