import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style_enums.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';

const _bar = HomeBarSettingsPlacement.bar;
const _menu = HomeBarSettingsPlacement.moreMenu;

void main() {
  group('visibleHomeTabs keeps a fixed order', () {
    test('all five tabs read diaries, to-dos, calendar, explore, settings', () {
      expect(
        visibleHomeTabs(const AppFeatures(todos: true), settings: _bar),
        <HomeTab>[
          HomeTab.diaries,
          HomeTab.todos,
          HomeTab.calendar,
          HomeTab.explore,
          HomeTab.settings,
        ],
      );
    });

    test('the default four tabs drop to-dos without moving the rest', () {
      expect(visibleHomeTabs(const AppFeatures(), settings: _bar), <HomeTab>[
        HomeTab.diaries,
        HomeTab.calendar,
        HomeTab.explore,
        HomeTab.settings,
      ]);
    });

    test('turning a tab off removes it and keeps diaries first and settings '
        'last', () {
      expect(
        visibleHomeTabs(
          const AppFeatures(todos: true, explore: false),
          settings: _bar,
        ),
        <HomeTab>[
          HomeTab.diaries,
          HomeTab.todos,
          HomeTab.calendar,
          HomeTab.settings,
        ],
      );
      expect(
        visibleHomeTabs(
          const AppFeatures(todos: true, calendar: false),
          settings: _bar,
        ),
        <HomeTab>[
          HomeTab.diaries,
          HomeTab.todos,
          HomeTab.explore,
          HomeTab.settings,
        ],
      );
      expect(
        visibleHomeTabs(const AppFeatures(explore: false), settings: _bar),
        <HomeTab>[HomeTab.diaries, HomeTab.calendar, HomeTab.settings],
      );
    });

    test('with every switchable tab off diaries and settings remain', () {
      expect(
        visibleHomeTabs(
          const AppFeatures(calendar: false, explore: false),
          settings: _bar,
        ),
        <HomeTab>[HomeTab.diaries, HomeTab.settings],
      );
    });

    test('settings in the more menu leaves the bar', () {
      expect(visibleHomeTabs(const AppFeatures(), settings: _menu), <HomeTab>[
        HomeTab.diaries,
        HomeTab.calendar,
        HomeTab.explore,
      ]);
      // 设置在菜单里、其余都关：只剩日记（首页不画底栏）。
      expect(
        visibleHomeTabs(
          const AppFeatures(calendar: false, explore: false),
          settings: _menu,
        ),
        <HomeTab>[HomeTab.diaries],
      );
    });

    test('the settings preview uses the five-tab order', () {
      expect(
        allHomeTabsInBarOrder,
        visibleHomeTabs(const AppFeatures(todos: true), settings: _bar),
      );
    });
  });
}
