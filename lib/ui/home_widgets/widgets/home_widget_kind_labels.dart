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
    };

String homeWidgetKindDescription(AppLocalizations l10n, HomeWidgetKind kind) =>
    switch (kind) {
      HomeWidgetKind.quickCapture => l10n.homeWidgetKindQuickCaptureDescription,
      HomeWidgetKind.today => l10n.homeWidgetKindTodayDescription,
      HomeWidgetKind.anniversary => l10n.homeWidgetKindAnniversaryDescription,
      HomeWidgetKind.moodCalendar => l10n.homeWidgetKindMoodCalendarDescription,
    };

FaIconData homeWidgetKindIcon(HomeWidgetKind kind) => switch (kind) {
  HomeWidgetKind.quickCapture => FontAwesomeIcons.penNib,
  HomeWidgetKind.today => FontAwesomeIcons.solidCalendar,
  HomeWidgetKind.anniversary => FontAwesomeIcons.heart,
  HomeWidgetKind.moodCalendar => FontAwesomeIcons.faceSmile,
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
  QuickCaptureAction.todo => l10n.homeWidgetQuickActionTodo,
  QuickCaptureAction.calendar => l10n.homeWidgetQuickActionCalendar,
  QuickCaptureAction.search => l10n.homeWidgetQuickActionSearch,
};

FaIconData quickCaptureActionIcon(QuickCaptureAction action) =>
    switch (action) {
      QuickCaptureAction.write => FontAwesomeIcons.penNib,
      QuickCaptureAction.todo => FontAwesomeIcons.solidSquareCheck,
      QuickCaptureAction.calendar => FontAwesomeIcons.solidCalendar,
      QuickCaptureAction.search => FontAwesomeIcons.magnifyingGlass,
    };
