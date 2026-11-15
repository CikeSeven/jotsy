package com.jotsy.diary.widgets

import android.view.View
import android.view.ViewGroup
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.jotsy.diary.widgets.kinds.QuickCaptureWidget
import com.jotsy.diary.widgets.kinds.TodayWidget
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** 种类 → 小组件与要测的尺寸（各档的代表尺寸，比分档界线略大，像真实的格子）。 */
private val cases: Map<String, Pair<() -> JotsyGlanceWidget, List<DpSize>>> =
  linkedMapOf(
    TodayWidget.KIND to
      Pair(
        { TodayWidget() },
        listOf(
          DpSize(152.dp, 76.dp),
          DpSize(312.dp, 76.dp),
          DpSize(152.dp, 160.dp),
          DpSize(152.dp, 244.dp),
          DpSize(312.dp, 160.dp),
        ),
      ),
    QuickCaptureWidget.KIND to
      Pair(
        { QuickCaptureWidget() },
        listOf(
          DpSize(72.dp, 76.dp),
          DpSize(152.dp, 76.dp),
          DpSize(312.dp, 76.dp),
          DpSize(152.dp, 160.dp),
          DpSize(312.dp, 160.dp),
        ),
      ),
  )

/**
 * 每种小组件在每档尺寸、每种外观与明暗下都能组合、展开并排出内容（不抛异常、不是空的）。
 * Android 11（圆角用 drawable 兜底、没有动态色）与 Android 14 两条路径都走一遍。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30, 34])
class WidgetRenderTest {
  @Test
  fun everyKindRendersAtEverySizeAndStyle() {
    val context = RuntimeEnvironment.getApplication()
    val snapshot = WidgetRenderSupport.fixture(context)
    for ((kind, case) in cases) {
      for (size in case.second) {
        for ((name, style) in WidgetRenderSupport.styles) {
          for (dark in listOf(false, true)) {
            val themed = WidgetRenderSupport.themed(context, dark)
            val state = WidgetPreviewState(snapshot, WidgetRenderSupport.instance(snapshot, kind, style))
            val root = WidgetRenderSupport.render(themed, case.first(), size, state)
            assertTrue("$kind $size $name dark=$dark is empty", countViews(root) > 2)
          }
        }
      }
    }
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
    val context = RuntimeEnvironment.getApplication()
    val snapshot = WidgetRenderSupport.fixture(context)
    for ((kind, case) in cases) {
      for (size in case.second) {
        for ((name, style) in WidgetRenderSupport.styles) {
          for (dark in listOf(false, true)) {
            val themed = WidgetRenderSupport.themed(context, dark)
            val state = WidgetPreviewState(snapshot, WidgetRenderSupport.instance(snapshot, kind, style))
            val root = WidgetRenderSupport.render(themed, case.first(), size, state)
            val bitmap = WidgetRenderSupport.draw(root)
            val file =
              File(
                out,
                "${kind}_${size.width.value.toInt()}x${size.height.value.toInt()}_${name}_${if (dark) "dark" else "light"}.png",
              )
            file.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
          }
        }
      }
    }
  }
}
