package com.jotsy.diary.widgets

import android.view.View
import android.view.ViewGroup
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.jotsy.diary.widgets.kinds.AnniversaryWidget
import com.jotsy.diary.widgets.kinds.MoodCalendarWidget
import com.jotsy.diary.widgets.kinds.QuickCaptureWidget
import com.jotsy.diary.widgets.kinds.TodayWidget
import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 一组渲染用例：名字（出图文件名的前缀）、种类、小组件、尺寸与内容覆盖。 */
private class RenderCase(
  val name: String,
  val kind: String,
  val widget: () -> JotsyGlanceWidget,
  val sizes: List<DpSize>,
  val content: JSONObject? = null,
)

/** 各档的代表尺寸（比分档界线略大，像真实的格子）。 */
private val S1 = DpSize(72.dp, 76.dp)
private val ROW2 = DpSize(152.dp, 76.dp)
private val ROW4 = DpSize(312.dp, 76.dp)
private val SQ2 = DpSize(152.dp, 160.dp)
private val TALL2 = DpSize(152.dp, 244.dp)
private val SQ3 = DpSize(232.dp, 244.dp)
private val WIDE4 = DpSize(312.dp, 160.dp)
private val LARGE4 = DpSize(312.dp, 328.dp)

private val cases: List<RenderCase> =
  listOf(
    RenderCase(TodayWidget.KIND, TodayWidget.KIND, { TodayWidget() }, listOf(ROW2, ROW4, SQ2, TALL2, WIDE4)),
    RenderCase(
      QuickCaptureWidget.KIND,
      QuickCaptureWidget.KIND,
      { QuickCaptureWidget() },
      listOf(S1, ROW2, ROW4, SQ2, WIDE4),
    ),
    RenderCase(
      AnniversaryWidget.KIND,
      AnniversaryWidget.KIND,
      { AnniversaryWidget() },
      listOf(S1, ROW2, ROW4, SQ2, WIDE4),
    ),
    RenderCase(
      "anniversary_list",
      AnniversaryWidget.KIND,
      { AnniversaryWidget() },
      listOf(SQ2, WIDE4, LARGE4),
      JSONObject().put("display", "list"),
    ),
    RenderCase(
      MoodCalendarWidget.KIND,
      MoodCalendarWidget.KIND,
      { MoodCalendarWidget() },
      listOf(SQ2, SQ3, WIDE4, LARGE4),
      JSONObject().put("holiday", true),
    ),
  )

/** 按用例逐个组合：每种小组件 × 每档尺寸 × 每种外观 × 明暗。 */
private fun forEachRender(dark: List<Boolean> = listOf(false, true), block: (String, View) -> Unit) {
  val context = RuntimeEnvironment.getApplication()
  val snapshot = WidgetRenderSupport.fixture(context)
  for (case in cases) {
    for (size in case.sizes) {
      for ((name, style) in WidgetRenderSupport.styles) {
        for (isDark in dark) {
          val themed = WidgetRenderSupport.themed(context, isDark)
          val instance = WidgetRenderSupport.instance(snapshot, case.kind, style, case.content)
          val root = WidgetRenderSupport.render(themed, case.widget(), size, WidgetPreviewState(snapshot, instance))
          val label =
            "${case.name}_${size.width.value.toInt()}x${size.height.value.toInt()}_${name}_${if (isDark) "dark" else "light"}"
          block(label, root)
        }
      }
    }
  }
}

/**
 * 每种小组件在每档尺寸、每种外观与明暗下都能组合、展开并排出内容（不抛异常、不是空的）。
 * Android 11（圆角用 drawable 兜底、没有动态色）与 Android 14 两条路径都走一遍。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30, 34])
class WidgetRenderTest {
  @Test
  fun everyKindRendersAtEverySizeAndStyle() {
    forEachRender { label, root -> assertTrue("$label is empty", countViews(root) > 2) }
  }

  @Test
  fun aWidgetWithoutSnapshotAsksToOpenTheApp() {
    val context = RuntimeEnvironment.getApplication()
    val state = WidgetPreviewState(WidgetSnapshot.EMPTY, WidgetInstance.fallback(TodayWidget.KIND))
    val root = WidgetRenderSupport.render(context, TodayWidget(), DpSize(152.dp, 160.dp), state)
    assertTrue(countViews(root) > 1)
  }

  private fun countViews(view: View): Int =
    1 + if (view is ViewGroup) (0 until view.childCount).sumOf { countViews(view.getChildAt(it)) } else 0
}

/**
 * 把上面的组合画成 PNG 供人看（设计核对，不在 CI 跑）：设了环境变量
 * `JOTSY_WIDGET_RENDER_DIR` 才执行，图片写到那个目录。
 *
 * ```
 * JOTSY_WIDGET_RENDER_DIR=/tmp/widgets ./gradlew :app:testDebugUnitTest --tests '*WidgetRenderPreview*'
 * ```
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WidgetRenderPreviewTest {
  @Test
  fun writePngs() {
    val dir = System.getenv("JOTSY_WIDGET_RENDER_DIR")
    assumeTrue(dir != null)
    val out = File(dir!!).apply { mkdirs() }
    forEachRender { label, root ->
      val bitmap = WidgetRenderSupport.draw(root)
      File(out, "$label.png").outputStream().use {
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)
      }
    }
  }
}
