import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(WidgetTester tester, {int diaryCount = 0}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
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
}

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
}
