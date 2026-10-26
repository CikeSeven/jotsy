import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_breakpoints.dart';
import 'package:node_diary/ui/diaries/viewmodels/diaries_page_layout.dart';

DiariesPageLayout _layout(
  AppWindowClass windowClass,
  double width, {
  bool waterfall = false,
}) => DiariesPageLayout.resolve(
  windowClass: windowClass,
  width: width,
  waterfall: waterfall,
);

void main() {
  test('a phone-width page is a single full-width column', () {
    for (final waterfall in <bool>[false, true]) {
      final layout = _layout(AppWindowClass.compact, 400, waterfall: waterfall);
      expect(layout.twoPane, isFalse);
      expect(layout.listPaneWidth, 400);
      expect(layout.contentInset, 0);
      expect(layout.listWidth, 400);
      expect(layout.minWaterfallColumns, 0);
    }
  });

  test('a medium window centres the list column at 720', () {
    final layout = _layout(AppWindowClass.medium, 900);
    expect(layout.twoPane, isFalse);
    expect(layout.listPaneWidth, 900);
    expect(layout.contentInset, 90);
    expect(layout.listWidth, 720);
    expect(layout.minWaterfallColumns, 0);

    // 比 720 窄时铺满，不补留白。
    final narrow = _layout(AppWindowClass.medium, 600);
    expect(narrow.contentInset, 0);
    expect(narrow.listWidth, 600);
  });

  test('a medium waterfall centres at 1200 and adds a column per 320', () {
    final layout = _layout(AppWindowClass.medium, 927, waterfall: true);
    expect(layout.contentInset, 0);
    expect(layout.listWidth, 927);
    expect(layout.minWaterfallColumns, 2);

    final wide = _layout(AppWindowClass.medium, 1300, waterfall: true);
    expect(wide.contentInset, 50);
    expect(wide.listWidth, 1200);
    expect(wide.minWaterfallColumns, 3);
  });

  test(
    'an expanded window splits into a clamped list pane and a detail pane',
    () {
      // 1280 窗口扣掉 96 的导航栏：38% 为 449.9，夹到 440。
      final wide = _layout(AppWindowClass.expanded, 1184, waterfall: true);
      expect(wide.twoPane, isTrue);
      expect(wide.listPaneWidth, 440);
      expect(wide.contentInset, 0);
      expect(wide.listWidth, 440);
      // 左栏里瀑布流用用户设的列数。
      expect(wide.minWaterfallColumns, 0);

      // 1024 窗口：38% 为 352.6，夹到 360。
      expect(_layout(AppWindowClass.expanded, 928).listPaneWidth, 360);
      expect(_layout(AppWindowClass.expanded, 1100).listPaneWidth, 418);
    },
  );
}
