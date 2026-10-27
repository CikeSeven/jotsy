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

/// 首页背景层里铺满的纯色（自下而上）。
List<Color> _backgroundColors(WidgetTester tester) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(AppBackgroundLayersView),
        matching: find.byType(ColoredBox),
      ),
    )
    .map((box) => box.color)
    .toList();

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

  testWidgets('swiping between tabs blends the two area backgrounds', (
    tester,
  ) async {
    await _pumpHome(tester, appSurfaceRaw: _diariesColorOnly());
    final surface = _scheme(tester).surface;

    final gesture = await tester.startGesture(
      const Offset(_width / 2, _height / 2),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    // 再左滑 100：共 120 / 400 = 0.3 页（触发拖动的那 20 也算在页位置里）。
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();

    final blend = tester.widget<Opacity>(
      find.ancestor(
        of: find.byType(AppBackgroundLayersView),
        matching: find.byType(Opacity),
      ),
    );
    expect(blend.opacity, inExclusiveRange(0.05, 0.6));
    // 下层是日记的颜色（不透明），上层是日历的页面底色。
    expect(_backgroundColors(tester), <Color>[_diariesColor, surface]);

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
