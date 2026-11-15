// 小组件种类、分组与快速记录动作在应用内的名字与图标（小组件页、工作室共用）。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../l10n/app_localizations.dart';

String homeWidgetKindName(AppLocalizations l10n, HomeWidgetKind kind) =>
    switch (kind) {
      HomeWidgetKind.quickCapture => l10n.homeWidgetKindQuickCapture,
      HomeWidgetKind.today => l10n.homeWidgetKindToday,
      HomeWidgetKind.anniversary => l10n.homeWidgetKindAnniversary,
      HomeWidgetKind.moodCalendar => l10n.homeWidgetKindMoodCalendar,
      HomeWidgetKind.todos => l10n.homeWidgetKindTodos,
      HomeWidgetKind.onThisDay => l10n.homeWidgetKindOnThisDay,
      HomeWidgetKind.recentDiaries => l10n.homeWidgetKindRecentDiaries,
      HomeWidgetKind.writingStats => l10n.homeWidgetKindWritingStats,
      HomeWidgetKind.photoMemories => l10n.homeWidgetKindPhotoMemories,
    };

String homeWidgetKindDescription(
  AppLocalizations l10n,
  HomeWidgetKind kind,
) => switch (kind) {
  HomeWidgetKind.quickCapture => l10n.homeWidgetKindQuickCaptureDescription,
  HomeWidgetKind.today => l10n.homeWidgetKindTodayDescription,
  HomeWidgetKind.anniversary => l10n.homeWidgetKindAnniversaryDescription,
  HomeWidgetKind.moodCalendar => l10n.homeWidgetKindMoodCalendarDescription,
  HomeWidgetKind.todos => l10n.homeWidgetKindTodosDescription,
  HomeWidgetKind.onThisDay => l10n.homeWidgetKindOnThisDayDescription,
  HomeWidgetKind.recentDiaries => l10n.homeWidgetKindRecentDiariesDescription,
  HomeWidgetKind.writingStats => l10n.homeWidgetKindWritingStatsDescription,
  HomeWidgetKind.photoMemories => l10n.homeWidgetKindPhotoMemoriesDescription,
};

FaIconData homeWidgetKindIcon(HomeWidgetKind kind) => switch (kind) {
  HomeWidgetKind.quickCapture => FontAwesomeIcons.penNib,
  HomeWidgetKind.today => FontAwesomeIcons.solidCalendar,
  HomeWidgetKind.anniversary => FontAwesomeIcons.heart,
  HomeWidgetKind.moodCalendar => FontAwesomeIcons.faceSmile,
  HomeWidgetKind.todos => FontAwesomeIcons.solidSquareCheck,
  HomeWidgetKind.onThisDay => FontAwesomeIcons.clockRotateLeft,
  HomeWidgetKind.recentDiaries => FontAwesomeIcons.bookOpen,
  HomeWidgetKind.writingStats => FontAwesomeIcons.chartSimple,
  HomeWidgetKind.photoMemories => FontAwesomeIcons.solidImages,
};

String homeWidgetGroupName(AppLocalizations l10n, HomeWidgetGroup group) =>
    switch (group) {
      HomeWidgetGroup.capture => l10n.homeWidgetGroupCapture,
      HomeWidgetGroup.time => l10n.homeWidgetGroupTime,
      HomeWidgetGroup.todos => l10n.homeWidgetGroupTodos,
      HomeWidgetGroup.stats => l10n.homeWidgetGroupStats,
    };

String quickCaptureActionName(
  AppLocalizations l10n,
  QuickCaptureAction action,
) => switch (action) {
  QuickCaptureAction.write => l10n.homeWidgetQuickActionWrite,
  QuickCaptureAction.camera => l10n.homeWidgetQuickActionCamera,
  QuickCaptureAction.voice => l10n.homeWidgetQuickActionVoice,
  QuickCaptureAction.todo => l10n.homeWidgetQuickActionTodo,
  QuickCaptureAction.calendar => l10n.homeWidgetQuickActionCalendar,
  QuickCaptureAction.search => l10n.homeWidgetQuickActionSearch,
};

FaIconData quickCaptureActionIcon(QuickCaptureAction action) =>
    switch (action) {
      QuickCaptureAction.write => FontAwesomeIcons.penNib,
      QuickCaptureAction.camera => FontAwesomeIcons.camera,
      QuickCaptureAction.voice => FontAwesomeIcons.microphone,
      QuickCaptureAction.todo => FontAwesomeIcons.solidSquareCheck,
      QuickCaptureAction.calendar => FontAwesomeIcons.solidCalendar,
      QuickCaptureAction.search => FontAwesomeIcons.magnifyingGlass,
    };
