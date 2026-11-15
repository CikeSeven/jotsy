import 'package:flutter/material.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../controllers/home_widget_studio_controller.dart';
import 'home_widget_anniversary_options.dart';
import 'home_widget_mood_calendar_options.dart';
import 'home_widget_quick_capture_options.dart';
import 'home_widget_today_options.dart';

/// 工作室「内容」标签页：按小组件种类分派到各自的选项（各自是一个可滚动
/// 列表——快速记录的动作要能拖动排序）。
class HomeWidgetContentTab extends StatelessWidget {
  const HomeWidgetContentTab({super.key, required this.controller});

  final HomeWidgetStudioController controller;

  @override
  Widget build(BuildContext context) {
    return switch (controller.content) {
      final QuickCaptureContent content => HomeWidgetQuickCaptureOptions(
        content: content,
        onChanged: controller.updateContent,
      ),
      final TodayContent content => HomeWidgetTodayOptions(
        content: content,
        onChanged: controller.updateContent,
      ),
      final AnniversaryContent content => HomeWidgetAnniversaryOptions(
        content: content,
        onChanged: controller.updateContent,
      ),
      final MoodCalendarContent content => HomeWidgetMoodCalendarOptions(
        content: content,
        onChanged: controller.updateContent,
      ),
    };
  }
}
