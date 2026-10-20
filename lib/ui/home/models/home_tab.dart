// 首页底栏的 Tab 身份。
//
// 职责：给每个 Tab 一个与位置无关的身份（文案、图标），并按功能管理开关
// 推出当前可见的 Tab 列表。日历、探索可在设置 → 功能管理中关闭，关闭后
// 后面的 Tab 下标会前移，所以首页一律按身份而不是下标判断“当前是哪一页”。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/app_features.dart';
import '../../../l10n/app_localizations.dart';

/// 首页 Tab。声明顺序就是底栏中的顺序。
enum HomeTab {
  diaries,
  calendar,
  explore,
  settings;

  /// 底栏文案。
  String label(AppLocalizations l10n) => switch (this) {
    HomeTab.diaries => l10n.navDiaries,
    HomeTab.calendar => l10n.navCalendar,
    HomeTab.explore => l10n.navExplore,
    HomeTab.settings => l10n.navSettings,
  };

  /// 底栏图标。
  FaIconData get icon => switch (this) {
    HomeTab.diaries => FontAwesomeIcons.solidRectangleList,
    HomeTab.calendar => FontAwesomeIcons.solidCalendar,
    HomeTab.explore => FontAwesomeIcons.solidCompass,
    HomeTab.settings => FontAwesomeIcons.gear,
  };
}

/// 按功能开关推出可见的 Tab（保持 [HomeTab] 的声明顺序）。
///
/// 日记与设置始终可见：日记是应用的主体，设置是重新打开功能的唯一入口；
/// 因此结果至少有两项，底栏始终是正常的导航行（不会落到单项兜底）。
List<HomeTab> visibleHomeTabs(AppFeatures features) => <HomeTab>[
  HomeTab.diaries,
  if (features.calendar) HomeTab.calendar,
  if (features.explore) HomeTab.explore,
  HomeTab.settings,
];
