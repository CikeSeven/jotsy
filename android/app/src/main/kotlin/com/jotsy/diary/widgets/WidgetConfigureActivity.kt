package com.jotsy.diary.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.jotsy.diary.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * 小组件的“配置”入口，只做中转、没有界面。
 *
 * 小组件信息里声明了 `reconfigurable|configuration_optional`：Android 12+ 放置时不经过
 * 这里（直接按默认配置显示），长按选“重新配置”时才来——这时带着这个实例的 id 与种类
 * 打开应用里的小组件工作室（`jotsy://widget/configure`，Dart `HomeWidgetConfigureLaunch`）。
 *
 * Android 12 以下放置时启动器一定会先打开这里：直接确认放置、不打开应用，小组件按默认
 * 配置显示，用户想调整再从设置里的“桌面小组件”进去，不打断放置。
 *
 * 必须先 setResult(RESULT_OK) 再结束，否则启动器认为配置被取消、把刚放下的小组件移除。
 */
class WidgetConfigureActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val widgetId =
      intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        ?: AppWidgetManager.INVALID_APPWIDGET_ID
    setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
      widgetId != AppWidgetManager.INVALID_APPWIDGET_ID
    ) {
      openStudio(widgetId)
    }
    finish()
  }

  private fun openStudio(widgetId: Int) {
    val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider
    val kind = WidgetKinds.kindOfReceiver(provider?.className)
    val launch =
      Intent(this, MainActivity::class.java).apply {
        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        data =
          WidgetLaunch.uri("configure", mapOf("id" to widgetId.toString(), "kind" to kind))
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
    try {
      startActivity(launch)
    } catch (_: Exception) {
      // 打不开应用也不影响小组件本身：配置结果已经确认。
    }
  }
}
