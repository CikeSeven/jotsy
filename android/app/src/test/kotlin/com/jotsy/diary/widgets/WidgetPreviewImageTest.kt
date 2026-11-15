package com.jotsy.diary.widgets

import android.graphics.Bitmap
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.jotsy.diary.widgets.kinds.AnniversaryWidget
import com.jotsy.diary.widgets.kinds.MoodCalendarWidget
import com.jotsy.diary.widgets.kinds.OnThisDayWidget
import com.jotsy.diary.widgets.kinds.PhotoMemoriesWidget
import com.jotsy.diary.widgets.kinds.QuickCaptureWidget
import com.jotsy.diary.widgets.kinds.RecentDiariesWidget
import com.jotsy.diary.widgets.kinds.TodayWidget
import com.jotsy.diary.widgets.kinds.TodosWidget
import com.jotsy.diary.widgets.kinds.WritingStatsWidget
import java.io.File
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 生成启动器小组件列表里的静态预览图（`res/xml/widget_info_*.xml` 的 `previewImage`，
 * Android 15 以下用；15+ 用生成预览，见 `WidgetPreviews`）。不在 CI 跑：设了环境变量
 * `JOTSY_WIDGET_PREVIEW_RES`（指向 `android/app/src/main/res`）才执行，生成后提交。
 *
 * 画的是示例快照（`widget_sample_<语言>.json`，Dart `buildHomeWidgetSampleSnapshot` 生成），
 * 不含任何用户数据；英语放 `drawable-nodpi`（其他语言的兜底），中日俄各放
 * `drawable-<语言>-nodpi`。按 Android 11 画：圆角用 drawable 兜底，Robolectric 画得出来。
 * 示例快照或版式变了之后重新生成：
 *
 * ```
 * JOTSY_WIDGET_PREVIEW_RES=$PWD/app/src/main/res ./gradlew :app:testDebugUnitTest --tests '*WidgetPreviewImage*'
 * ```
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], qualifiers = "xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WidgetPreviewImageTest {
  /** 每种小组件在列表里的样子：放到桌面时的默认尺寸（与 Dart `HomeWidgetCellSize.sizesOf` 的第一个一致）。 */
  private val previews: List<Triple<String, () -> JotsyGlanceWidget, DpSize>> =
    listOf(
      Triple(QuickCaptureWidget.KIND, { QuickCaptureWidget() }, SQUARE),
      Triple(TodayWidget.KIND, { TodayWidget() }, SQUARE),
      Triple(AnniversaryWidget.KIND, { AnniversaryWidget() }, SQUARE),
      Triple(MoodCalendarWidget.KIND, { MoodCalendarWidget() }, DpSize(232.dp, 244.dp)),
      Triple(TodosWidget.KIND, { TodosWidget() }, WIDE),
      Triple(OnThisDayWidget.KIND, { OnThisDayWidget() }, SQUARE),
      Triple(RecentDiariesWidget.KIND, { RecentDiariesWidget() }, WIDE),
      Triple(WritingStatsWidget.KIND, { WritingStatsWidget() }, SQUARE),
      Triple(PhotoMemoriesWidget.KIND, { PhotoMemoriesWidget() }, SQUARE),
    )

  @Test
  fun writePreviewImages() {
    val res = System.getenv("JOTSY_WIDGET_PREVIEW_RES")
    assumeTrue(res != null)
    val context = WidgetRenderSupport.themed(RuntimeEnvironment.getApplication(), dark = false)
    for ((language, folder) in FOLDERS) {
      val snapshot = WidgetRenderSupport.sample(context, language)
      val out = File(res!!, folder).apply { mkdirs() }
      for ((kind, widget, size) in previews) {
        val state = WidgetPreviewState(snapshot, snapshot.instanceFor(null, kind))
        val root = WidgetRenderSupport.render(context, widget(), size, state)
        val bitmap = WidgetRenderSupport.draw(root)
        File(out, "widget_preview_$kind.webp").outputStream().use {
          check(bitmap.compress(Bitmap.CompressFormat.WEBP_LOSSY, 88, it)) { "WebP encoding failed" }
        }
      }
    }
  }

  private companion object {
    val SQUARE = DpSize(152.dp, 160.dp)
    val WIDE = DpSize(312.dp, 160.dp)

    /** 语言 → 资源目录；英语兼作没有翻译的语言的兜底。 */
    val FOLDERS =
      linkedMapOf(
        "en" to "drawable-nodpi",
        "zh" to "drawable-zh-nodpi",
        "ja" to "drawable-ja-nodpi",
        "ru" to "drawable-ru-nodpi",
      )
  }
}
