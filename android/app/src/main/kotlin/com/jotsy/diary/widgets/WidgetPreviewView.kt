package com.jotsy.diary.widgets

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.view.MotionEvent
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.ExperimentalGlanceApi
import androidx.glance.appwidget.compose
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * 应用内小组件预览（Dart `HomeWidgetPreview`，视图类型 `com.jotsy.diary/home_widget_preview`）。
 *
 * 用桌面上那份 Glance 代码按草稿配置画出 RemoteViews，再在应用里展开——预览就是真实的
 * 小组件，所见即所得。数据与文案取最新快照，草稿新选的配色随参数传进来。
 *
 * - 明暗：用带夜间模式的配置 Context 组合与展开，昼夜一对的颜色按它取；
 * - 快照变了（同步控制器刚写入）自动重画；
 * - 预览上的点按全部拦下：RemoteViews 里的点按会真的打开应用里的页面。
 *
 * 重画串行：新的参数到来时取消还没画完的那一次。
 */
class WidgetPreviewFactory(private val messenger: BinaryMessenger) :
  PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  private val views = HashMap<Int, WidgetPreviewView>()
  private val channel =
    MethodChannel(messenger, CHANNEL).apply {
      setMethodCallHandler { call, result ->
        when (call.method) {
          "update" -> {
            @Suppress("UNCHECKED_CAST") val args = call.arguments as? Map<String, Any?>
            val view = (args?.get("viewId") as? Number)?.toInt()?.let { views[it] }
            if (args != null) view?.update(args)
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
    }

  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = args as? Map<String, Any?> ?: emptyMap()
    val view = WidgetPreviewView(context, params) { views.remove(viewId) }
    views[viewId] = view
    return view
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    views.values.toList().forEach { it.dispose() }
    views.clear()
  }

  companion object {
    const val VIEW_TYPE = "com.jotsy.diary/home_widget_preview"
    const val CHANNEL = "com.jotsy.diary/home_widget_preview"
  }
}

class WidgetPreviewView(
  context: Context,
  initial: Map<String, Any?>,
  private val onDisposed: () -> Unit,
) : PlatformView {
  private val appContext = context.applicationContext
  private val host = TouchBlockingFrame(context)
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val preferences: SharedPreferences =
    appContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
  private var params: Map<String, Any?> = initial
  private var job: Job? = null

  // 强引用持有：SharedPreferences 只弱引用监听器。
  private val snapshotListener =
    SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
      if (key == WidgetSnapshot.KEY) render()
    }

  init {
    preferences.registerOnSharedPreferenceChangeListener(snapshotListener)
    render()
  }

  fun update(next: Map<String, Any?>) {
    params = next
    render()
  }

  @OptIn(ExperimentalGlanceApi::class)
  private fun render() {
    val kind = params["kind"] as? String ?: return
    val widget = WidgetKinds.create(kind) ?: return
    val width = (params["width"] as? Number)?.toFloat() ?: return
    val height = (params["height"] as? Number)?.toFloat() ?: return
    val dark = params["dark"] as? Boolean ?: false
    val config = parse(params["config"] as? String) ?: return
    val palettes = parse(params["palettes"] as? String)
    job?.cancel()
    job =
      scope.launch {
        val themed = themedContext(dark)
        val state =
          WidgetPreviewState(
            snapshot = WidgetSnapshot.read(preferences).withPalettes(palettes),
            instance = WidgetInstance.parse(config),
          )
        val views =
          try {
            withContext(Dispatchers.Default) {
              widget.compose(themed, size = DpSize(width.dp, height.dp), state = state)
            }
          } catch (e: Exception) {
            android.util.Log.w("WidgetPreview", "compose failed", e)
            return@launch
          }
        val content =
          try {
            views.apply(themed, host)
          } catch (e: Exception) {
            android.util.Log.w("WidgetPreview", "apply failed", e)
            return@launch
          }
        host.removeAllViews()
        host.addView(
          content,
          FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
      }
  }

  /** 按预览的明暗换一个配置 Context（不改应用本身的明暗）。 */
  private fun themedContext(dark: Boolean): Context {
    val config = Configuration(appContext.resources.configuration)
    config.uiMode =
      (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
        if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
    return appContext.createConfigurationContext(config)
  }

  private fun parse(raw: String?): JSONObject? =
    try {
      raw?.let { JSONObject(it) }
    } catch (_: Exception) {
      null
    }

  override fun getView(): android.view.View = host

  override fun dispose() {
    preferences.unregisterOnSharedPreferenceChangeListener(snapshotListener)
    scope.cancel()
    host.removeAllViews()
    onDisposed()
  }
}

/** 拦下所有触摸：预览只看不点（见 [WidgetPreviewView]）。 */
private class TouchBlockingFrame(context: Context) : FrameLayout(context) {
  override fun onInterceptTouchEvent(event: MotionEvent?) = true

  @SuppressLint("ClickableViewAccessibility")
  override fun onTouchEvent(event: MotionEvent?) = true
}
