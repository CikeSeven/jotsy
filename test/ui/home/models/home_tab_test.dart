import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';

void main() {
  group('visibleHomeTabs puts diaries in the middle', () {
    test('default three tabs centre diaries between calendar and explore', () {
      expect(visibleHomeTabs(const AppFeatures()), <HomeTab>[
        HomeTab.calendar,
        HomeTab.diaries,
        HomeTab.explore,
      ]);
    });

    test('four tabs put calendar first, diaries second, to-dos third', () {
      expect(visibleHomeTabs(const AppFeatures(todos: true)), <HomeTab>[
        HomeTab.calendar,
        HomeTab.diaries,
        HomeTab.todos,
        HomeTab.explore,
      ]);
    });

    test('any three tabs keep the others in their relative order', () {
      expect(
        visibleHomeTabs(const AppFeatures(todos: true, explore: false)),
        <HomeTab>[HomeTab.calendar, HomeTab.diaries, HomeTab.todos],
      );
      expect(
        visibleHomeTabs(const AppFeatures(todos: true, calendar: false)),
        <HomeTab>[HomeTab.todos, HomeTab.diaries, HomeTab.explore],
      );
    });

    test('two tabs keep diaries on the left', () {
      expect(visibleHomeTabs(const AppFeatures(explore: false)), <HomeTab>[
        HomeTab.diaries,
        HomeTab.calendar,
      ]);
      expect(visibleHomeTabs(const AppFeatures(calendar: false)), <HomeTab>[
        HomeTab.diaries,
        HomeTab.explore,
      ]);
    });

    test('with every other tab off only diaries is left', () {
      expect(
        visibleHomeTabs(const AppFeatures(calendar: false, explore: false)),
        <HomeTab>[HomeTab.diaries],
      );
    });

    test('the settings preview uses the four-tab order', () {
      expect(
        allHomeTabsInBarOrder,
        visibleHomeTabs(const AppFeatures(todos: true)),
      );
    });
  });
}
