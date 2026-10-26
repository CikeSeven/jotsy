import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_rail.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/home/widgets/home_tab_entrance.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _desktop = Size(1280, 800);
const Size _smallWindow = Size(800, 600);
const Size _phone = Size(400, 860);

/// 挂载完整应用并停在首页，窗口为 [size]（逻辑像素）。
Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = _desktop,
  int diaryCount = 0,
}) async {
  tester.view.physicalSize = size;
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

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(HomePage)).l10n;

double _homePage(WidgetTester tester) => tester
    .widget<PageView>(
      find
          .descendant(
            of: find.byType(HomePage, skipOffstage: false),
            matching: find.byType(PageView, skipOffstage: false),
          )
          .first,
    )
    .controller!
    .page!;

Finder _railItem(String label) =>
    find.descendant(of: find.byType(HomeNavRail), matching: find.text(label));

Finder _diariesList() => find
    .descendant(
      of: find.byType(DiariesPage, skipOffstage: false),
      matching: find.byType(Scrollable, skipOffstage: false),
    )
    .first;

/// 全局“新建”FAB（窄窗口浮在底栏上方的那个）。
Finder get _globalCreateFab => find.byWidgetPredicate(
  (widget) => widget is FloatingActionButton && widget.heroTag != null,
);

Future<void> _pressShortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  for (final size in <Size>[_desktop, _smallWindow]) {
    testWidgets('a ${size.width.toInt()}x${size.height.toInt()} window uses '
        'the side rail instead of the bottom bar', (tester) async {
      await _pumpHome(tester, size: size);
      final l10n = _l10n(tester);
      expect(find.byType(HomeNavRail), findsOneWidget);
      expect(find.byType(HomeBottomBar), findsNothing);
      expect(find.byType(BottomNav), findsNothing);
      expect(_globalCreateFab, findsNothing);
      expect(tester.getRect(find.byType(HomeNavRail)).left, 0);
      expect(tester.getSize(find.byType(HomeNavRail)).width, 96);
      // 页面区紧挨侧边栏，铺满其余宽度。
      expect(
        tester.getRect(find.byType(DiariesPage)),
        Rect.fromLTWH(96, 0, size.width - 96, size.height),
      );
      for (final label in <String>[
        l10n.navDiaries,
        l10n.navCalendar,
        l10n.navExplore,
        l10n.navSettings,
      ]) {
        expect(_railItem(label), findsOneWidget);
      }
      await _unmount(tester);
    });
  }

  testWidgets('a phone-sized window keeps the bottom bar and global FAB', (
    tester,
  ) async {
    await _pumpHome(tester, size: _phone);
    expect(find.byType(HomeNavRail), findsNothing);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(_globalCreateFab, findsOneWidget);
    expect(find.byType(HomeTabEntrance), findsNothing);
    await _unmount(tester);
  });

  testWidgets('tapping rail destinations jumps between tabs with a fade', (
    tester,
  ) async {
    await _pumpHome(tester);
    final l10n = _l10n(tester);

    await tester.tap(_railItem(l10n.navCalendar));
    await tester.pump();
    // 不滑动：第一帧就落在目标页。
    expect(_homePage(tester), 1);
    await tester.pump(const Duration(milliseconds: 60));
    final cover = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(HomeTabEntrance),
            matching: find.byType(FadeTransition),
          )
          .last,
    );
    expect(cover.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(cover.opacity.value, 0);
    expect(find.byType(CalendarPage), findsOneWidget);

    await tester.tap(_railItem(l10n.navSettings));
    await tester.pumpAndSettle();
    expect(_homePage(tester), 3);
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(_railItem(l10n.navDiaries));
    await tester.pumpAndSettle();
    expect(_homePage(tester), 0);
    await _unmount(tester);
  });

  testWidgets('reduce motion switches wide tabs without the fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpHome(tester);
    await tester.tap(_railItem(_l10n(tester).navExplore));
    await tester.pump();
    expect(_homePage(tester), 2);
    final cover = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(HomeTabEntrance),
            matching: find.byType(FadeTransition),
          )
          .last,
    );
    // 减少动画：切页同一帧盖层就已透明，不播放淡入。
    expect(cover.opacity.value, 0);
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('wide tabs cannot be switched by swiping', (tester) async {
    await _pumpHome(tester);
    await tester.drag(find.byType(DiariesPage), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(_homePage(tester), 0);
    await _unmount(tester);
  });

  testWidgets('the rail create button works from the calendar tab', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(_railItem(_l10n(tester).navCalendar));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(HomeNavRail),
        matching: find.byType(FloatingActionButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tab state survives resizing across 600 in both directions', (
    tester,
  ) async {
    await _pumpHome(tester, size: _phone, diaryCount: 18);
    final diariesState = tester.state(find.byType(DiariesPage));
    await tester.drag(_diariesList(), const Offset(0, -500));
    await tester.pumpAndSettle();
    final scrolled = tester.state<ScrollableState>(_diariesList()).position;
    final offset = scrolled.pixels;
    expect(offset, greaterThan(0));

    // 窄 → 宽：同一个 State、同一个滚动位置，换成侧边栏。
    await _resize(tester, _desktop);
    expect(find.byType(HomeNavRail), findsOneWidget);
    expect(tester.state(find.byType(DiariesPage)), same(diariesState));
    expect(
      tester.state<ScrollableState>(_diariesList()).position.pixels,
      offset,
    );

    // 宽窗口里切到设置再拖回窄窗口：当前 Tab 保持，日记页仍是同一个。
    // （日历页在测试字体与 18 篇日记下本身就会溢出，与外壳无关，这里不用它。）
    await tester.tap(_railItem(_l10n(tester).navSettings));
    await tester.pumpAndSettle();
    final settingsList = find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final settingsState = tester.state(settingsList);
    await _resize(tester, _phone);
    expect(find.byType(HomeNavRail), findsNothing);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(_homePage(tester), 3);
    expect(tester.state(settingsList), same(settingsState));
    expect(
      tester.state(find.byType(DiariesPage, skipOffstage: false)),
      same(diariesState),
    );
    await _unmount(tester);
  });

  testWidgets('Ctrl+1 to Ctrl+4 switch to the nth visible tab', (tester) async {
    await _pumpHome(tester);
    await _pressShortcut(tester, LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(_homePage(tester), 2);
    await _pressShortcut(tester, LogicalKeyboardKey.digit4);
    await tester.pumpAndSettle();
    expect(_homePage(tester), 3);
    await _pressShortcut(tester, LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(_homePage(tester), 0);
    await _unmount(tester);
  });

  testWidgets('tab shortcuts also work on a phone-sized window', (
    tester,
  ) async {
    await _pumpHome(tester, size: _phone);
    await _pressShortcut(tester, LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(_homePage(tester), 1);
    await _unmount(tester);
  });

  testWidgets('Ctrl+N opens the editor from any tab', (tester) async {
    await _pumpHome(tester);
    await tester.tap(_railItem(_l10n(tester).navSettings));
    await tester.pumpAndSettle();
    await _pressShortcut(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Ctrl+F opens diary search and shortcuts resume after it '
      'closes', (tester) async {
    await _pumpHome(tester);
    await _pressShortcut(tester, LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.byType(DiarySearchPage), findsOneWidget);

    // 搜索页在上面时首页快捷键不响应。
    await _pressShortcut(tester, LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(_homePage(tester), 0);

    Navigator.of(tester.element(find.byType(DiarySearchPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DiarySearchPage), findsNothing);
    await _pressShortcut(tester, LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(_homePage(tester), 1);
    await _unmount(tester);
  });

  testWidgets('wide snack bars float centred over the content area', (
    tester,
  ) async {
    await _pumpHome(tester);
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: tester.element(find.byType(DiariesPage)),
        snackBar: const SnackBar(
          content: Text('hint'),
          duration: Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // SnackBar 自身铺满 Scaffold 宽度，外边距内的 Material 才是提示条。
    final rect = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(rect.width, 560);
    // 内容区 [96, 1280] 的中线。
    expect(rect.center.dx, closeTo((96 + 1280) / 2, 0.01));
    expect(rect.bottom, closeTo(800 - 24, 0.01));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });
}
