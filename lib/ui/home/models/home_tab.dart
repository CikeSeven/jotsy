// 首页底栏的 Tab 身份。
//
// 职责：给每个 Tab 一个与位置无关的身份（文案、图标），并按功能管理开关
// 推出当前可见的 Tab 列表。底栏顺序固定为日记、待办、日历、探索、设置；
// 待办、日历、探索可在设置 → 功能管理中关闭，关闭后其后各 Tab 的下标都会
// 变，所以首页一律按身份而不是下标判断“当前是哪一页”，启动时也按身份落在
// 日记页。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/app_features.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';

/// 首页 Tab。底栏中的顺序只由 [allHomeTabsInBarOrder] 决定，不依赖声明顺序。
enum HomeTab {
  diaries,
  todos,
  calendar,
  explore,
  settings;

  /// 底栏文案。
  String label(AppLocalizations l10n) => switch (this) {
    HomeTab.diaries => l10n.navDiaries,
    HomeTab.todos => l10n.navTodos,
    HomeTab.calendar => l10n.navCalendar,
    HomeTab.explore => l10n.navExplore,
    HomeTab.settings => l10n.navSettings,
  };

  /// 底栏图标。
  FaIconData get icon => switch (this) {
    HomeTab.diaries => FontAwesomeIcons.solidRectangleList,
    HomeTab.todos => FontAwesomeIcons.solidSquareCheck,
    HomeTab.calendar => FontAwesomeIcons.solidCalendar,
    HomeTab.explore => FontAwesomeIcons.solidCompass,
    HomeTab.settings => FontAwesomeIcons.gear,
  };

  /// 是否有首页的“新建”FAB（玻璃底栏时为并排按钮）：日记页新建日记，
  /// 待办页新建待办；其余 Tab 没有。
  bool get hasCreateFab => this == HomeTab.diaries || this == HomeTab.todos;

  /// 这个 Tab 的背景区域（“背景与材质”里可以单独设置）。
  AppBackgroundArea get backgroundArea => switch (this) {
    HomeTab.diaries => AppBackgroundArea.diaries,
    HomeTab.todos => AppBackgroundArea.todos,
    HomeTab.calendar => AppBackgroundArea.calendar,
    HomeTab.explore => AppBackgroundArea.explore,
    HomeTab.settings => AppBackgroundArea.settings,
  };
}

/// 全部 Tab 都开启时的底栏（宽窗口为侧边栏）从左到右的固定顺序：日记、
/// 待办、日历、探索、设置。设置里导航栏样式的预览直接用它。
const List<HomeTab> allHomeTabsInBarOrder = <HomeTab>[
  HomeTab.diaries,
  HomeTab.todos,
  HomeTab.calendar,
  HomeTab.explore,
  HomeTab.settings,
];

/// 按功能开关推出可见的 Tab，即底栏（宽窗口为侧边栏）从左到右的顺序。
///
/// 顺序固定取 [allHomeTabsInBarOrder]，关闭的 Tab 直接去掉、其余不挪位置。
/// 日记与设置始终可见：日记是应用的主体，设置是重新打开功能的入口；因此
/// 结果至少有两项，底栏始终是正常的导航行。
List<HomeTab> visibleHomeTabs(AppFeatures features) => <HomeTab>[
  for (final tab in allHomeTabsInBarOrder)
    if (_isVisible(tab, features)) tab,
];

bool _isVisible(HomeTab tab, AppFeatures features) => switch (tab) {
  HomeTab.diaries || HomeTab.settings => true,
  HomeTab.todos => features.todos,
  HomeTab.calendar => features.calendar,
  HomeTab.explore => features.explore,
};
