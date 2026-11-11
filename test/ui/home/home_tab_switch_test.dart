import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 挂载完整应用并停在首页；[appFeaturesRaw] 为功能管理开关的设置原文
/// （null 即全部开启）。返回真实的 [SettingsService]，测试可在运行中改开关。
Future<SettingsService> _pumpHome(
  WidgetTester tester, {
  int diaryCount = 0,
  String? appFeaturesRaw,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.app_features': ?appFeaturesRaw,
  });
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.runAsync(() async {
    for (var i = 0; i < diaryCount; i++) {
      await database.createDiary(
        title: 'Diary $i',
        contentDocJson: '[{"insert":"content $i\\n"}]',
        contentText: 'content $i',
        metadataJson: '{}',
      );
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: const NodeDiaryApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
  return settings;
}

/// 底栏当前的各项文案（按顺序）。
List<String> _navLabels(WidgetTester tester) => tester
    .widget<HomeFloatingBar>(find.byType(HomeFloatingBar))
    .items
    .map((item) => item.label)
    .toList();

/// 底栏高亮项的文案。
String _selectedNavLabel(WidgetTester tester) {
  final nav = tester.widget<HomeFloatingBar>(find.byType(HomeFloatingBar));
  return nav.items[nav.selectedIndex].label;
}

Finder _navItem(String label) => find.descendant(
  of: find.byType(HomeFloatingBar),
  matching: find.text(label),
);

double _homePage(WidgetTester tester) => tester
    .widget<PageView>(
      find
          .descendant(
            of: find.byType(HomePage),
            matching: find.byType(PageView),
          )
          .first,
    )
    .controller!
    .page!;

/// 日记页主列表。切到其他 Tab 后日记页仍被保活，只是不在可见视口里。
Finder _diariesList() => find
    .descendant(
      of: find.byType(DiariesPage, skipOffstage: false),
      matching: find.byType(Scrollable, skipOffstage: false),
    )
    .first;

ScrollPosition _diariesListPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_diariesList()).position;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// 全局“新建”FAB 是否可见且可点（显隐由外层 AnimatedOpacity 与
/// IgnorePointer 决定，FAB 本身一直挂在树上）。
bool _createFabShown(WidgetTester tester) {
  final fab = find.byType(FloatingActionButton);
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: fab, matching: find.byType(AnimatedOpacity)).first,
  );
  final pointer = tester.widget<IgnorePointer>(
    find.ancestor(of: fab, matching: find.byType(IgnorePointer)).first,
  );
  return opacity.opacity == 1 && !pointer.ignoring;
}

void main() {
  testWidgets('the create FAB belongs to the diaries tab only', (tester) async {
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;
    expect(_createFabShown(tester), isTrue);

    // 日历页在长按日期的菜单里新建，不再显示全局 FAB。
    // 默认三个 Tab 为 日历(0) · 日记(1) · 探索(2)，启动落在日记。
    expect(_homePage(tester), 1);
    await tester.tap(find.text(l10n.navCalendar));
    await tester.pumpAndSettle();
    expect(_homePage(tester), 0);
    expect(_createFabShown(tester), isFalse);

    await tester.tap(find.text(l10n.navDiaries));
    await tester.pumpAndSettle();
    expect(_createFabShown(tester), isTrue);
    await _unmount(tester);
  });

  testWidgets('jumping across tabs only animates the final page', (
    tester,
  ) async {
    await _pumpHome(tester, appFeaturesRaw: '{"todos":true}');
    final l10n = tester.element(find.byType(HomePage)).l10n;
    await tester.tap(_navItem(l10n.navTodos));
    await tester.pumpAndSettle();
    expect(_homePage(tester), 0);

    await tester.tap(_navItem(l10n.navExplore));
    await tester.pump();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      // 待办(0) -> 探索(3)：不应再滑过日记(1)与日历(2)。
      expect(_homePage(tester), greaterThanOrEqualTo(2), reason: '$frame');
    }
    await tester.pumpAndSettle();
    expect(_homePage(tester), 3);
    await _unmount(tester);
  });

  testWidgets('reduce motion switches tabs without animating', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;

    await tester.tap(_navItem(l10n.navExplore));
    await tester.pump();
    expect(_homePage(tester), 2);
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('settings is not a tab but opens from the diaries more menu', (
    tester,
  ) async {
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;

    expect(_navLabels(tester), <String>[
      l10n.navCalendar,
      l10n.navDiaries,
      l10n.navExplore,
    ]);
    expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.navSettings));
    // 菜单项的 onPressed 在点按后的下一帧才执行，推入页面再晚一帧。
    await tester.pump();
    await tester.pumpAndSettle();

    // 设置是推入的二级页：标准顶栏带返回按钮，盖住首页与底栏。
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byTooltip(l10n.commonBack),
      ),
      findsOneWidget,
    );
    expect(_navItem(l10n.navDiaries), findsNothing);

    // 返回键回到首页的日记页，而不是退出应用。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(_homePage(tester), 1);
    expect(_selectedNavLabel(tester), l10n.navDiaries);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('tapping the current tab scrolls its list back to the top', (
    tester,
  ) async {
    await _pumpHome(tester, diaryCount: 18);
    final l10n = tester.element(find.byType(HomePage)).l10n;

    await tester.drag(_diariesList(), const Offset(0, -1200));
    await tester.pumpAndSettle();
    final scrolled = _diariesListPosition(tester).pixels;
    expect(scrolled, greaterThan(0));

    await tester.tap(find.text(l10n.navDiaries));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 平滑滚动而不是一帧跳到顶。
    expect(_diariesListPosition(tester).pixels, inExclusiveRange(0, scrolled));
    await tester.pumpAndSettle();
    expect(_diariesListPosition(tester).pixels, 0);
    await _unmount(tester);
  });

  testWidgets('each tab keeps its own primary scroll controller', (
    tester,
  ) async {
    await _pumpHome(tester, diaryCount: 18, appFeaturesRaw: '{"todos":true}');
    final l10n = tester.element(find.byType(HomePage)).l10n;
    await tester.drag(_diariesList(), const Offset(0, -600));
    await tester.pumpAndSettle();
    final diariesOffset = _diariesListPosition(tester).pixels;

    // 切到待办页再点一次待办：只有待办页回到顶部，日记列表位置保持不变。
    // （探索、日历页在 400dp 宽的测试字体与 18 篇日记下本身就会横向溢出，
    // 与这里要验证的滚动控制器无关，不用它们。）
    final todosNav = _navItem(l10n.navTodos);
    await tester.tap(todosNav);
    await tester.pumpAndSettle();
    await tester.tap(todosNav);
    await tester.pumpAndSettle();

    expect(_diariesListPosition(tester).pixels, diariesOffset);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('only the visible tab keeps its tickers running', (tester) async {
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;
    bool tickersEnabled(Type page) => TickerMode.valuesOf(
      tester.element(find.byType(page, skipOffstage: false)),
    ).enabled;

    // PageView 只构建可见页：此时探索页尚未构建。
    expect(tickersEnabled(DiariesPage), isTrue);

    await tester.tap(_navItem(l10n.navExplore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 切换途中目标页与相邻页都在动，不会冻结半露出的内容。
    expect(tickersEnabled(ExplorePage), isTrue);
    await tester.pumpAndSettle();

    expect(tickersEnabled(ExplorePage), isTrue);
    expect(tickersEnabled(DiariesPage), isFalse);
    await _unmount(tester);
  });

  group('feature toggles hide home tabs', () {
    testWidgets('only diaries left hides the bottom bar but keeps the FAB', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        appFeaturesRaw: '{"calendar":false,"explore":false}',
      );
      final l10n = tester.element(find.byType(HomePage)).l10n;

      // 一项的导航行没有意义：底栏整个不显示，新建入口仍是全局 FAB。
      expect(find.byType(HomeFloatingBar), findsNothing);
      expect(find.text(l10n.navDiaries), findsNothing);
      expect(_createFabShown(tester), isTrue);
      final fabBottom = tester
          .getRect(find.byType(FloatingActionButton))
          .bottom;
      // 内容止于屏幕底部，FAB 离底 10dp（测试视图没有手势条）。
      expect(fabBottom, closeTo(860 - 10, 0.01));

      // 设置照样从日记页顶栏“更多”进入。
      await tester.tap(find.byTooltip(l10n.autoT0125));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.navSettings));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('to-dos are off by default and sit first when on', (
      tester,
    ) async {
      await _pumpHome(tester, appFeaturesRaw: '{"todos":true}');
      final l10n = tester.element(find.byType(HomePage)).l10n;

      // 四个 Tab 时日记居中偏左（第二格），启动仍落在日记。
      expect(_navLabels(tester), <String>[
        l10n.navTodos,
        l10n.navDiaries,
        l10n.navCalendar,
        l10n.navExplore,
      ]);
      expect(_selectedNavLabel(tester), l10n.navDiaries);
      expect(_homePage(tester), 1);
      await tester.tap(_navItem(l10n.navTodos));
      await tester.pumpAndSettle();
      expect(find.byType(TodosPage), findsOneWidget);
      // 待办页上 FAB 新建待办。
      expect(find.text(l10n.todoNew), findsOneWidget);
      await _unmount(tester);

      await _pumpHome(tester);
      expect(_navItem(l10n.navTodos), findsNothing);
      await _unmount(tester);
    });

    testWidgets('only explore off keeps the other two in order', (
      tester,
    ) async {
      await _pumpHome(tester, appFeaturesRaw: '{"explore":false}');
      final l10n = tester.element(find.byType(HomePage)).l10n;

      expect(_navLabels(tester), <String>[l10n.navDiaries, l10n.navCalendar]);
      await _unmount(tester);
    });

    testWidgets('hiding a tab at runtime keeps the explore tab selected', (
      tester,
    ) async {
      final settings = await _pumpHome(tester);
      final l10n = tester.element(find.byType(HomePage)).l10n;

      await tester.tap(_navItem(l10n.navExplore));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 2);
      final exploreElement = tester.element(find.byType(ExplorePage));

      unawaited(settings.setAppFeaturesRaw('{"calendar":false}'));
      await tester.pump();
      // 本帧就落在新下标上：探索页仍在屏幕上，没有闪到别的页。
      expect(_homePage(tester), 1);
      expect(find.byType(ExplorePage), findsOneWidget);
      await tester.pumpAndSettle();

      expect(_navLabels(tester), <String>[l10n.navDiaries, l10n.navExplore]);
      expect(_selectedNavLabel(tester), l10n.navExplore);
      expect(_homePage(tester), 1);
      expect(find.byType(ExplorePage), findsOneWidget);
      // 下标前移不重建探索页。
      expect(tester.element(find.byType(ExplorePage)), same(exploreElement));
      expect(tester.takeException(), isNull);

      // 返回键仍先回到日记页。
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_homePage(tester), 0);
      expect(_selectedNavLabel(tester), l10n.navDiaries);
      expect(_createFabShown(tester), isTrue);
      await _unmount(tester);
    });

    testWidgets('re-enabling a tab brings it back in its original slot', (
      tester,
    ) async {
      final settings = await _pumpHome(
        tester,
        appFeaturesRaw: '{"calendar":false}',
      );
      final l10n = tester.element(find.byType(HomePage)).l10n;
      await tester.tap(_navItem(l10n.navExplore));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 1);
      final exploreElement = tester.element(find.byType(ExplorePage));

      unawaited(settings.setAppFeaturesRaw(null));
      await tester.pump();
      expect(_homePage(tester), 2);
      expect(find.byType(ExplorePage), findsOneWidget);
      await tester.pumpAndSettle();

      // 日历回到最左，日记随之居中。
      expect(_navLabels(tester), <String>[
        l10n.navCalendar,
        l10n.navDiaries,
        l10n.navExplore,
      ]);
      expect(_selectedNavLabel(tester), l10n.navExplore);
      expect(tester.element(find.byType(ExplorePage)), same(exploreElement));
      // 重新开启的日历页还没访问过，不提前构建。
      expect(find.byType(CalendarPage, skipOffstage: false), findsNothing);

      await tester.tap(_navItem(l10n.navCalendar));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 0);
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('diaries tab keeps its state when other tabs are hidden', (
      tester,
    ) async {
      final settings = await _pumpHome(
        tester,
        diaryCount: 18,
        appFeaturesRaw: '{"todos":true}',
      );
      final l10n = tester.element(find.byType(HomePage)).l10n;
      await tester.drag(_diariesList(), const Offset(0, -600));
      await tester.pumpAndSettle();
      final diariesOffset = _diariesListPosition(tester).pixels;
      expect(diariesOffset, greaterThan(0));
      final diariesState = tester.state(
        find.byType(DiariesPage, skipOffstage: false),
      );

      // 停在待办页时关掉日历与探索（两页在测试字体与 18 篇日记下本身会
      // 横向溢出，不切过去）。
      await tester.tap(_navItem(l10n.navTodos));
      await tester.pumpAndSettle();
      unawaited(
        settings.setAppFeaturesRaw(
          '{"todos":true,"calendar":false,"explore":false}',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_navItem(l10n.navDiaries));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 0);
      expect(
        tester.state(find.byType(DiariesPage, skipOffstage: false)),
        same(diariesState),
      );
      expect(_diariesListPosition(tester).pixels, diariesOffset);
      await _unmount(tester);
    });

    testWidgets('hiding the current tab falls back to diaries', (tester) async {
      final settings = await _pumpHome(tester);
      final l10n = tester.element(find.byType(HomePage)).l10n;
      await tester.tap(_navItem(l10n.navCalendar));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(_createFabShown(tester), isFalse);

      unawaited(settings.setAppFeaturesRaw('{"calendar":false}'));
      await tester.pump();
      expect(_homePage(tester), 0);
      await tester.pumpAndSettle();

      expect(_selectedNavLabel(tester), l10n.navDiaries);
      expect(_homePage(tester), 0);
      // 被关闭的日历页随之销毁，不再在后台保活。
      expect(find.byType(CalendarPage, skipOffstage: false), findsNothing);
      expect(find.byType(DiariesPage), findsOneWidget);
      expect(_createFabShown(tester), isTrue);
      expect(tester.takeException(), isNull);

      // 底栏点击与左右滑动仍按新的下标工作。
      await tester.tap(_navItem(l10n.navExplore));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 1);
      expect(_selectedNavLabel(tester), l10n.navExplore);
      await _unmount(tester);
    });
  });
}
