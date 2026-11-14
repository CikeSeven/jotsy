import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/widgets/app_background_layers_view.dart';
import 'package:node_diary/ui/app_surface/widgets/app_paged_background.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/widgets/diaries_header_sliver.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_rail.dart';
import 'package:node_diary/ui/home/widgets/home_tab_entrance.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _width = 400;
const double _height = 860;
const Color _diariesColor = Color(0xFF2E7D6B);

/// 日记区域单独设纯色背景，其余区域跟随全局（无背景）。
String _diariesColorOnly() => AppSurfaceSettings.defaults
    .withArea(
      AppBackgroundArea.diaries,
      AppAreaBackground(
        mode: AppAreaBackgroundMode.custom,
        custom: AppBackground(
          kind: AppBackgroundKind.color,
          colorLight: _diariesColor.toARGB32(),
        ),
      ),
    )
    .encode()!;

Future<void> _pumpHome(
  WidgetTester tester, {
  String? appSurfaceRaw,
  double width = _width,
}) async {
  tester.view.physicalSize = Size(width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.app_surface': ?appSurfaceRaw,
  });
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
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

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(HomePage))).colorScheme;

Color _scaffoldColorIn(WidgetTester tester, Finder page) => tester
    .widget<Scaffold>(
      find
          .descendant(
            of: page,
            matching: find.byType(Scaffold, skipOffstage: false),
          )
          .first,
    )
    .backgroundColor!;

Color _homeScaffoldColor(WidgetTester tester) =>
    _scaffoldColorIn(tester, find.byType(HomePage));

/// 首页背景层里铺满的纯色（自下而上）。只看背景层本身，不含景深卡片
/// 自带的那份区域背景（[AppPagedAreaBackground]，在各页的 HomeTabDepth 里）。
List<Color> _backgroundColors(WidgetTester tester) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppBackgroundLayersView &&
              widget.key is ValueKey<AppBackgroundArea>,
        ),
        matching: find.byType(ColoredBox),
      ),
    )
    .map((box) => box.color)
    .toList();

/// 景深卡片自带的 [area] 区域背景铺的纯色。
List<Color> _cardBackgroundColors(
  WidgetTester tester,
  AppBackgroundArea area,
) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppPagedAreaBackground && widget.area == area,
          skipOffstage: false,
        ),
        matching: find.byType(ColoredBox, skipOffstage: false),
      ),
    )
    .map((box) => box.color)
    .toList();

/// 背景层里插值上面那一层的透明度层（没有时为空）。
Iterable<Opacity> _blendLayers(WidgetTester tester) =>
    tester.widgetList<Opacity>(
      find.ancestor(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppBackgroundLayersView &&
              widget.key is ValueKey<AppBackgroundArea>,
        ),
        matching: find.byType(Opacity),
      ),
    );

/// 在屏幕中央按下、左滑到 0.3 页处停住（不松手），返回手势。
Future<TestGesture> _dragToThreeTenths(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    const Offset(_width / 2, _height / 2),
  );
  await gesture.moveBy(const Offset(-20, 0));
  await tester.pump();
  // 再左滑 100：共 120 / 400 = 0.3 页（触发拖动的那 20 也算在页位置里）。
  await gesture.moveBy(const Offset(-100, 0));
  await tester.pump();
  return gesture;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(HomeBottomBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('page blend', () {
    test('interpolates between the two neighbouring pages', () {
      final blend = AppPagedBlend.at(0.3, 4);
      expect(blend.lower, 0);
      expect(blend.upper, 1);
      expect(blend.upperOpacity, closeTo(0.3, 1e-9));
      expect(AppPagedBlend.at(2.75, 4).lower, 2);
      expect(AppPagedBlend.at(2.75, 4).upperOpacity, closeTo(0.75, 1e-9));
    });

    test('rests on whole pages and clamps overscroll', () {
      expect(AppPagedBlend.at(1, 4), const AppPagedBlend(1, 1, 0));
      expect(AppPagedBlend.at(-0.2, 4), const AppPagedBlend(0, 0, 0));
      expect(AppPagedBlend.at(3.4, 4), const AppPagedBlend(3, 3, 0));
      expect(AppPagedBlend.at(0.5, 1), const AppPagedBlend(0, 0, 0));
      expect(AppPagedBlend.at(double.nan, 4), const AppPagedBlend(0, 0, 0));
    });
  });

  testWidgets('without backgrounds home paints exactly as before', (
    tester,
  ) async {
    await _pumpHome(tester);
    final surface = _scheme(tester).surface;
    expect(find.byType(AppBackgroundLayersView), findsNothing);
    expect(_homeScaffoldColor(tester), surface);
    expect(_scaffoldColorIn(tester, find.byType(DiariesPage)), surface);
    expect(
      tester
          .widget<DiariesHeaderSliver>(find.byType(DiariesHeaderSliver))
          .backgroundColor,
      surface,
    );
    await _unmount(tester);
  });

  testWidgets('each tab reads its own area: diaries colored, calendar plain', (
    tester,
  ) async {
    await _pumpHome(tester, appSurfaceRaw: _diariesColorOnly());
    final surface = _scheme(tester).surface;

    // 日记 Tab：页面与首页外壳都透明，露出首页画的背景；实色顶栏与背景同色。
    expect(_homeScaffoldColor(tester), Colors.transparent);
    expect(
      _scaffoldColorIn(tester, find.byType(DiariesPage)),
      Colors.transparent,
    );
    expect(
      tester
          .widget<DiariesHeaderSliver>(find.byType(DiariesHeaderSliver))
          .backgroundColor,
      _diariesColor,
    );
    expect(_backgroundColors(tester), <Color>[_diariesColor]);

    // 日历 Tab 没有背景：页面仍是原来的 surface，背景层落到 surface。
    final l10n = tester.element(find.byType(HomePage)).l10n;
    await _openTab(tester, l10n.navCalendar);
    expect(_scaffoldColorIn(tester, find.byType(CalendarPage)), surface);
    expect(_homeScaffoldColor(tester), Colors.transparent);
    expect(_backgroundColors(tester), <Color>[surface]);
    await _unmount(tester);
  });

  testWidgets('swiping with depth carries each area background on its card', (
    tester,
  ) async {
    await _pumpHome(tester, appSurfaceRaw: _diariesColorOnly());
    final surface = _scheme(tester).surface;

    final gesture = await _dragToThreeTenths(tester);
    // 日记居中，左滑去探索：两页各自连同自己区域的背景缩成卡片——日记卡片
    // 垫着日记的颜色，探索卡片垫着探索的页面底色。
    expect(_cardBackgroundColors(tester, AppBackgroundArea.diaries), <Color>[
      _diariesColor,
    ]);
    expect(_cardBackgroundColors(tester, AppBackgroundArea.explore), <Color>[
      surface,
    ]);
    // 背景层被卡片与舞台色整个盖住：只垫下面那一层，不再做透明度插值。
    expect(_blendLayers(tester), isEmpty);
    expect(_backgroundColors(tester), <Color>[_diariesColor]);

    // 只拖了 0.3 页、没有甩动：松手吸附回日记，背景层仍是日记的颜色。
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_backgroundColors(tester), <Color>[_diariesColor]);
    await _unmount(tester);
  });

  testWidgets('with reduced motion swiping blends the two area backgrounds', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpHome(tester, appSurfaceRaw: _diariesColorOnly());
    final surface = _scheme(tester).surface;

    final gesture = await _dragToThreeTenths(tester);
    // 减少动画没有景深：页面透明地平移，背景固定在下面按页位置插值。
    final blend = _blendLayers(tester).single;
    expect(blend.opacity, inExclusiveRange(0.05, 0.6));
    // 下层是日记的颜色（不透明），上层是探索的页面底色。
    expect(_backgroundColors(tester), <Color>[_diariesColor, surface]);
    expect(find.byType(AppPagedAreaBackground), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('identical area backgrounds skip the blend layer', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    // 全局纯色背景，各区域都跟随它：相邻两区画面完全相同。
    await _pumpHome(
      tester,
      appSurfaceRaw: AppSurfaceSettings.defaults
          .withGlobal(
            AppBackground(
              kind: AppBackgroundKind.color,
              colorLight: _diariesColor.toARGB32(),
            ),
          )
          .encode(),
    );

    final gesture = await _dragToThreeTenths(tester);
    expect(_blendLayers(tester), isEmpty);
    expect(_backgroundColors(tester), <Color>[_diariesColor]);

    await gesture.up();
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('the wide rail takes the solid bar color of a colored area', (
    tester,
  ) async {
    await _pumpHome(tester, appSurfaceRaw: _diariesColorOnly(), width: 1100);
    final rail = find.descendant(
      of: find.byType(HomeNavRail),
      matching: find.byType(Material),
    );
    expect(tester.widget<Material>(rail.first).color, _diariesColor);
    await _unmount(tester);
  });

  testWidgets('wide tab switches cross-fade instead of jumping', (
    tester,
  ) async {
    await _pumpHome(tester, appSurfaceRaw: _diariesColorOnly(), width: 1100);
    final surface = _scheme(tester).surface;
    final l10n = tester.element(find.byType(HomePage)).l10n;
    await tester.tap(
      find.descendant(
        of: find.byType(HomeNavRail),
        matching: find.text(l10n.navCalendar),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 宽窗口直接跳页，背景从日记的颜色交叉淡入到日历的页面底色。
    expect(_backgroundColors(tester), <Color>[_diariesColor, surface]);
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            // 最近的祖先在前：淡入的是日历区域那一层。
            of: find.byKey(
              const ValueKey<AppBackgroundArea>(AppBackgroundArea.calendar),
            ),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    // 目标 Tab 没有背景：切页入场的盖层仍是原来的页面底色。
    expect(
      tester.widget<HomeTabEntrance>(find.byType(HomeTabEntrance)).color,
      surface,
    );

    await tester.pumpAndSettle();
    expect(_backgroundColors(tester), <Color>[surface]);
    await _unmount(tester);
  });
}
