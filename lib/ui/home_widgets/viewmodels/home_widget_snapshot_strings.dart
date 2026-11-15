// 快照里给原生用的文案与图标。
//
// 文案一律来自 ARB（随应用的界面语言，而不是系统语言）：原生不另存一份
// 翻译，只有启动器列表里的名称与描述是 Android 资源（docs/rules/home_widgets.md
// 「文案」）。带变量、要由原生在绘制时代入的文案导出为模板，变量位置写成
// `%s`（原生 `WidgetStrings.format`）；按日期变化的文案（几项待办）在今日
// 一节里逐日算好，原生不做复数。
//
// 图标导出字体族与码位，原生从应用自带的字体（flutter_assets）里画出同一个
// 字形，与应用内的 FontAwesome 图标完全一致。图标在这里以 const 引用，
// 发布构建的图标字体裁剪会保留这些字形。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart' show DayMood;
import '../../../l10n/app_localizations.dart';
import '../../calendar/widgets/day_mood_face.dart' show dayMoodLabel;

/// 原生取用的文案（键名与 `WidgetStrings.kt` 一致）。
Map<String, String> homeWidgetStringsOf(AppLocalizations l10n) =>
    <String, String>{
      'greetingMorning': l10n.homeWidgetGreetingMorning,
      'greetingAfternoon': l10n.homeWidgetGreetingAfternoon,
      'greetingEvening': l10n.homeWidgetGreetingEvening,
      'greetingNight': l10n.homeWidgetGreetingNight,
      'quickPrompt': l10n.homeWidgetQuickPrompt,
      'actionWrite': l10n.homeWidgetQuickActionWrite,
      'actionTodo': l10n.homeWidgetQuickActionTodo,
      'actionCalendar': l10n.homeWidgetQuickActionCalendar,
      'actionSearch': l10n.homeWidgetQuickActionSearch,
      'todayNotWritten': l10n.homeWidgetTodayNotWritten,
      'yearProgress': l10n.homeWidgetYearProgress('%s'),
      'featureOff': l10n.homeWidgetFeatureOff,
      'openToUpdate': l10n.homeWidgetOpenToUpdate,
      'isToday': l10n.anniversaryIsToday,
      'anniversaryTitle': l10n.anniversaryListTitle,
      'anniversaryEmpty': l10n.homeWidgetAnniversaryEmpty,
      'moodPrompt': l10n.homeWidgetTodayMoodPrompt,
      for (final mood in DayMood.values)
        'mood_${mood.name}': dayMoodLabel(l10n, mood),
      'monthPrevious': l10n.homeWidgetMonthPrevious,
      'monthNext': l10n.homeWidgetMonthNext,
      'todoViewToday': l10n.todoViewToday,
      'todoViewPlanned': l10n.todoViewPlanned,
      'todoViewAll': l10n.todoViewAll,
      'todoToday': l10n.todoDueToday,
      'todoTomorrow': l10n.todoDueTomorrow,
      'todoYesterday': l10n.todoDueYesterday,
      'todoOverdue': l10n.todoGroupOverdue,
      'todoEmptyToday': l10n.todoEmptyToday,
      'todoEmpty': l10n.todoEmptyList,
      'todoAllDone': l10n.todoHeroAllDone,
      'todoAdd': l10n.homeWidgetQuickActionTodo,
      'todoCheck': l10n.homeWidgetTodoCheck,
      'todoUncheck': l10n.homeWidgetTodoUncheck,
    };

/// 一个图标：字体族在 `FontManifest.json` 里的键与码位。
Map<String, Object?> _icon(FaIconData icon) => <String, Object?>{
  'f': icon.fontPackage == null
      ? icon.fontFamily
      : 'packages/${icon.fontPackage}/${icon.fontFamily}',
  'c': icon.codePoint,
};

/// 原生取用的图标（键名与 `WidgetIcons.kt` 一致）。
Map<String, Object?> homeWidgetIcons() => <String, Object?>{
  'write': _icon(FontAwesomeIcons.penNib),
  'todo': _icon(FontAwesomeIcons.solidSquareCheck),
  'calendar': _icon(FontAwesomeIcons.solidCalendar),
  'search': _icon(FontAwesomeIcons.magnifyingGlass),
  'words': _icon(FontAwesomeIcons.featherPointed),
  'list': _icon(FontAwesomeIcons.listCheck),
  'leaf': _icon(FontAwesomeIcons.leaf),
  'anniversary': _icon(FontAwesomeIcons.solidHeart),
  'countdown': _icon(FontAwesomeIcons.solidFlag),
  'pin': _icon(FontAwesomeIcons.thumbtack),
  'previous': _icon(FontAwesomeIcons.angleLeft),
  'next': _icon(FontAwesomeIcons.angleRight),
  'unchecked': _icon(FontAwesomeIcons.circle),
  'checked': _icon(FontAwesomeIcons.solidCircleCheck),
  'plus': _icon(FontAwesomeIcons.plus),
  'repeat': _icon(FontAwesomeIcons.arrowsRotate),
};
