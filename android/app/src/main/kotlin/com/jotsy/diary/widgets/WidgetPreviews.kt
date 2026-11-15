package com.jotsy.diary.widgets

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidgetManager

/**
 * 启动器小组件列表里的预览（Android 15+ 的生成预览）。
 *
 * 预览一律画示例数据（Dart `buildHomeWidgetSampleSnapshot`，按界面语言写好的几篇日记、
 * 几项待办），不画用户自己的内容：小组件列表谁都能翻，开着应用锁也一样。示例快照存在
 * `HomeWidgetPreferences` 的 [SAMPLE_KEY]，各小组件的 `providePreview` 从这里读。
 *
 * 系统对 `setWidgetPreviews` 限流（每个应用每小时只能调几次）：逐个种类发布，记下每个
 * 种类发布时的口径（[publish] 的 `key`：日期、语言与主题色），口径没变的不再发；被限流时
 * 停下，返回 [PENDING]，由 Dart 过一阵再来。Android 15 以下没有生成预览，用 `res/xml`
 * 里的静态预览图（`previewImage`）。
 */
object WidgetPreviews {
  const val SAMPLE_KEY = "jotsy.widgets.sample"

  const val DONE = "done"
  const val PENDING = "pending"
  const val UNSUPPORTED = "unsupported"

  private const val TAG = "JotsyWidgets"
  private const val PUBLISHED = "JotsyWidgetPreviews"

  suspend fun publish(context: Context, sample: String, key: String): String {
    WidgetState.homeWidgetPreferences(context).edit().putString(SAMPLE_KEY, sample).apply()
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return UNSUPPORTED
    val published = context.getSharedPreferences(PUBLISHED, Context.MODE_PRIVATE)
    val manager = GlanceAppWidgetManager(context)
    for ((kind, receiver) in WidgetKinds.receiverClasses) {
      if (published.getString(kind, null) == key) continue
      val result =
        try {
          manager.setWidgetPreviews(receiver)
        } catch (error: Exception) {
          Log.w(TAG, "publishing the $kind preview failed", error)
          continue
        }
      if (result == GlanceAppWidgetManager.SET_WIDGET_PREVIEWS_RESULT_RATE_LIMITED) return PENDING
      published.edit().putString(kind, key).apply()
    }
    return DONE
  }
}
