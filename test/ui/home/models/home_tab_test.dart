import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';

void main() {
  group('visibleHomeTabs keeps a fixed order', () {
    test('all five tabs read diaries, to-dos, calendar, explore, settings', () {
      expect(visibleHomeTabs(const AppFeatures(todos: true)), <HomeTab>[
        HomeTab.diaries,
        HomeTab.todos,
        HomeTab.calendar,
        HomeTab.explore,
        HomeTab.settings,
      ]);
    });

    test('the default four tabs drop to-dos without moving the rest', () {
      expect(visibleHomeTabs(const AppFeatures()), <HomeTab>[
        HomeTab.diaries,
        HomeTab.calendar,
        HomeTab.explore,
        HomeTab.settings,
      ]);
    });

    test('turning a tab off removes it and keeps diaries first and settings '
        'last', () {
      expect(
        visibleHomeTabs(const AppFeatures(todos: true, explore: false)),
        <HomeTab>[
          HomeTab.diaries,
          HomeTab.todos,
          HomeTab.calendar,
          HomeTab.settings,
        ],
      );
      expect(
        visibleHomeTabs(const AppFeatures(todos: true, calendar: false)),
        <HomeTab>[
          HomeTab.diaries,
          HomeTab.todos,
          HomeTab.explore,
          HomeTab.settings,
        ],
      );
      expect(visibleHomeTabs(const AppFeatures(explore: false)), <HomeTab>[
        HomeTab.diaries,
        HomeTab.calendar,
        HomeTab.settings,
      ]);
      expect(visibleHomeTabs(const AppFeatures(calendar: false)), <HomeTab>[
        HomeTab.diaries,
        HomeTab.explore,
        HomeTab.settings,
      ]);
    });

    test('with every switchable tab off diaries and settings remain', () {
      expect(
        visibleHomeTabs(const AppFeatures(calendar: false, explore: false)),
        <HomeTab>[HomeTab.diaries, HomeTab.settings],
      );
    });

    test('the settings preview uses the five-tab order', () {
      expect(
        allHomeTabsInBarOrder,
        visibleHomeTabs(const AppFeatures(todos: true)),
      );
    });
  });
}
