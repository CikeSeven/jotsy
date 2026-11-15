package com.jotsy.diary.widgets

import com.jotsy.diary.widgets.kinds.AnniversaryWidget
import com.jotsy.diary.widgets.kinds.AnniversaryWidgetReceiver
import com.jotsy.diary.widgets.kinds.MoodCalendarWidget
import com.jotsy.diary.widgets.kinds.MoodCalendarWidgetReceiver
import com.jotsy.diary.widgets.kinds.OnThisDayWidget
import com.jotsy.diary.widgets.kinds.OnThisDayWidgetReceiver
import com.jotsy.diary.widgets.kinds.QuickCaptureWidget
import com.jotsy.diary.widgets.kinds.QuickCaptureWidgetReceiver
import com.jotsy.diary.widgets.kinds.RecentDiariesWidget
import com.jotsy.diary.widgets.kinds.RecentDiariesWidgetReceiver
import com.jotsy.diary.widgets.kinds.TodayWidget
import com.jotsy.diary.widgets.kinds.TodayWidgetReceiver
import com.jotsy.diary.widgets.kinds.TodosWidget
import com.jotsy.diary.widgets.kinds.TodosWidgetReceiver

/**
 * 小组件种类的登记表：种类 id（Dart `HomeWidgetKind.id`）↔ Glance 小组件 ↔ 接收器。
 * 新增种类时在这里、`AndroidManifest.xml` 与 Dart 的 `HomeWidgetKind` 三处一起登记。
 */
object WidgetKinds {
  private val receivers: Map<String, String> =
    mapOf(
      QuickCaptureWidget.KIND to QuickCaptureWidgetReceiver::class.java.name,
      TodayWidget.KIND to TodayWidgetReceiver::class.java.name,
      AnniversaryWidget.KIND to AnniversaryWidgetReceiver::class.java.name,
      MoodCalendarWidget.KIND to MoodCalendarWidgetReceiver::class.java.name,
      TodosWidget.KIND to TodosWidgetReceiver::class.java.name,
      OnThisDayWidget.KIND to OnThisDayWidgetReceiver::class.java.name,
      RecentDiariesWidget.KIND to RecentDiariesWidgetReceiver::class.java.name,
    )

  /** 预览用：按种类 id 新建一个 Glance 小组件；认不出时为 null。 */
  fun create(kind: String): JotsyGlanceWidget? =
    when (kind) {
      QuickCaptureWidget.KIND -> QuickCaptureWidget()
      TodayWidget.KIND -> TodayWidget()
      AnniversaryWidget.KIND -> AnniversaryWidget()
      MoodCalendarWidget.KIND -> MoodCalendarWidget()
      TodosWidget.KIND -> TodosWidget()
      OnThisDayWidget.KIND -> OnThisDayWidget()
      RecentDiariesWidget.KIND -> RecentDiariesWidget()
      else -> null
    }

  /** 接收器类名对应的种类 id；认不出时为 null。 */
  fun kindOfReceiver(className: String?): String? =
    receivers.entries.firstOrNull { it.value == className }?.key
}
