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
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
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
    .widget<BottomNav>(find.byType(BottomNav))
    .items
    .map((item) => item.label)
    .toList();

/// 底栏高亮项的文案。
String _selectedNavLabel(WidgetTester tester) {
  final nav = tester.widget<BottomNav>(find.byType(BottomNav));
  return nav.items[nav.selectedIndex].label;
}

Finder _navItem(String label) =>
    find.descendant(of: find.byType(BottomNav), matching: find.text(label));

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
    await tester.tap(find.text(l10n.navCalendar));
    await tester.pumpAndSettle();
    expect(_homePage(tester), 1);
    expect(_createFabShown(tester), isFalse);

    await tester.tap(find.text(l10n.navDiaries));
    await tester.pumpAndSettle();
    expect(_createFabShown(tester), isTrue);
    await _unmount(tester);
  });

  testWidgets('jumping across tabs only animates the final page', (
    tester,
  ) async {
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;

    await tester.tap(find.text(l10n.navSettings));
    await tester.pump();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      // 日记(0) -> 设置(3)：不应再滑过日历(1)与探索(2)。
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

    await tester.tap(find.text(l10n.navSettings));
    await tester.pump();
    expect(_homePage(tester), 3);
    await tester.pumpAndSettle();
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
    await _pumpHome(tester, diaryCount: 18);
    final l10n = tester.element(find.byType(HomePage)).l10n;
    await tester.drag(_diariesList(), const Offset(0, -600));
    await tester.pumpAndSettle();
    final diariesOffset = _diariesListPosition(tester).pixels;

    // 切到设置页再点一次设置：只有设置页回到顶部，日记列表位置保持不变。
    final settingsNav = find.descendant(
      of: find.byType(BottomNav),
      matching: find.text(l10n.navSettings),
    );
    await tester.tap(settingsNav);
    await tester.pumpAndSettle();
    await tester.tap(settingsNav);
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

    // PageView 只构建可见页：此时设置页尚未构建。
    expect(tickersEnabled(DiariesPage), isTrue);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNav),
        matching: find.text(l10n.navSettings),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 切换途中目标页与相邻页都在动，不会冻结半露出的内容。
    expect(tickersEnabled(SettingsPage), isTrue);
    await tester.pumpAndSettle();

    expect(tickersEnabled(SettingsPage), isTrue);
    expect(tickersEnabled(DiariesPage), isFalse);
    await _unmount(tester);
  });

  group('feature toggles hide home tabs', () {
    testWidgets('calendar and explore off leaves only diaries and settings', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        appFeaturesRaw: '{"calendar":false,"explore":false}',
      );
      final l10n = tester.element(find.byType(HomePage)).l10n;

      expect(_navLabels(tester), <String>[l10n.navDiaries, l10n.navSettings]);
      expect(_navItem(l10n.navCalendar), findsNothing);
      expect(_navItem(l10n.navExplore), findsNothing);

      await tester.tap(_navItem(l10n.navSettings));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 1);
      expect(_selectedNavLabel(tester), l10n.navSettings);
      expect(find.byType(SettingsPage), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('only explore off keeps the other three in order', (
      tester,
    ) async {
      await _pumpHome(tester, appFeaturesRaw: '{"explore":false}');
      final l10n = tester.element(find.byType(HomePage)).l10n;

      expect(_navLabels(tester), <String>[
        l10n.navDiaries,
        l10n.navCalendar,
        l10n.navSettings,
      ]);
      await _unmount(tester);
    });

    testWidgets('hiding a tab at runtime keeps the settings tab selected', (
      tester,
    ) async {
      final settings = await _pumpHome(tester);
      final l10n = tester.element(find.byType(HomePage)).l10n;

      await tester.tap(_navItem(l10n.navSettings));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 3);
      final settingsElement = tester.element(find.byType(SettingsPage));

      unawaited(settings.setAppFeaturesRaw('{"calendar":false}'));
      await tester.pump();
      // 本帧就落在新下标上：设置页仍在屏幕上，没有闪到别的页。
      expect(_homePage(tester), 2);
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.pumpAndSettle();

      expect(_navLabels(tester), <String>[
        l10n.navDiaries,
        l10n.navExplore,
        l10n.navSettings,
      ]);
      expect(_selectedNavLabel(tester), l10n.navSettings);
      expect(_homePage(tester), 2);
      expect(find.byType(SettingsPage), findsOneWidget);
      // 下标前移不重建设置页。
      expect(tester.element(find.byType(SettingsPage)), same(settingsElement));
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
        appFeaturesRaw: '{"calendar":false,"explore":false}',
      );
      final l10n = tester.element(find.byType(HomePage)).l10n;
      await tester.tap(_navItem(l10n.navSettings));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 1);
      final settingsElement = tester.element(find.byType(SettingsPage));

      unawaited(settings.setAppFeaturesRaw(null));
      await tester.pump();
      expect(_homePage(tester), 3);
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.pumpAndSettle();

      expect(_navLabels(tester), <String>[
        l10n.navDiaries,
        l10n.navCalendar,
        l10n.navExplore,
        l10n.navSettings,
      ]);
      expect(_selectedNavLabel(tester), l10n.navSettings);
      expect(tester.element(find.byType(SettingsPage)), same(settingsElement));
      // 重新开启的日历页还没访问过，不提前构建。
      expect(find.byType(CalendarPage, skipOffstage: false), findsNothing);

      await tester.tap(_navItem(l10n.navCalendar));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 1);
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('diaries tab keeps its state when other tabs are hidden', (
      tester,
    ) async {
      final settings = await _pumpHome(tester, diaryCount: 18);
      final l10n = tester.element(find.byType(HomePage)).l10n;
      await tester.drag(_diariesList(), const Offset(0, -600));
      await tester.pumpAndSettle();
      final diariesOffset = _diariesListPosition(tester).pixels;
      expect(diariesOffset, greaterThan(0));
      final diariesState = tester.state(
        find.byType(DiariesPage, skipOffstage: false),
      );

      await tester.tap(_navItem(l10n.navSettings));
      await tester.pumpAndSettle();
      unawaited(
        settings.setAppFeaturesRaw('{"calendar":false,"explore":false}'),
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
      await tester.tap(_navItem(l10n.navSettings));
      await tester.pumpAndSettle();
      expect(_homePage(tester), 2);
      expect(_selectedNavLabel(tester), l10n.navSettings);
      await _unmount(tester);
    });
  });
}
