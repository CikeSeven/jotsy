import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_fab.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_rail.dart';
import 'package:node_diary/ui/widgets/glass/glass_reveal.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _height = 860;

/// “控件”为玻璃（整体材质为玻璃）的设置原文。
String _glassControls() => AppSurfaceSettings.defaults
    .withGlass(const AppGlassStyle(mode: AppGlassMode.glass))
    .encode()!;

/// 挂载完整应用（只调度，不推进时间）。
Future<void> _mount(
  WidgetTester tester, {
  String? appSurfaceRaw,
  int diaryCount = 0,
  double width = 400,
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
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

Finder get _glassFab => find.byType(AppGlassFab);

Finder _fabSurface() =>
    find.descendant(of: _glassFab, matching: find.byType(GlassSurface));

/// 玻璃 FAB 到首页之间有没有透明度层（Opacity / FadeTransition /
/// AnimatedOpacity）。GlassSurface 自己放在玻璃里面的内容 Opacity 在它之下，
/// 不算。
bool _fabUnderOpacity(WidgetTester tester) {
  var under = false;
  tester.element(_fabSurface()).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is HomePage) return false;
    if (widget is Opacity ||
        widget is FadeTransition ||
        widget is AnimatedOpacity) {
      under = true;
      return false;
    }
    return true;
  });
  return under;
}

Finder _diariesList() => find
    .descendant(
      of: find.byType(DiariesPage, skipOffstage: false),
      matching: find.byType(Scrollable, skipOffstage: false),
    )
    .first;

void main() {
  testWidgets('classic controls keep the plain FAB without glass', (
    tester,
  ) async {
    await _mount(tester);
    await _settle(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(_glassFab, findsNothing);
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    // 经典时按钮不覆盖主题底色。
    expect(fab.backgroundColor, isNull);
    await _unmount(tester);
  });

  testWidgets('glass controls float a blurred primary glass FAB', (
    tester,
  ) async {
    await _mount(tester, appSurfaceRaw: _glassControls());
    await _settle(tester);
    expect(_glassFab, findsOneWidget);
    final surface = tester.widget<GlassSurface>(_fabSurface());
    final scheme = Theme.of(tester.element(find.byType(HomePage))).colorScheme;
    expect(surface.fill.a, lessThan(1));
    expect(
      surface.fill.withValues(alpha: 1),
      scheme.primaryContainer.withValues(alpha: 1),
    );
    expect(surface.shadowColor, isNotNull);
    final blur = tester.widget<BackdropFilter>(
      find.descendant(of: _fabSurface(), matching: find.byType(BackdropFilter)),
    );
    expect(blur.enabled, isTrue);
    // 外形与经典 FAB 一致：主题圆角 20、高 56。
    expect(surface.borderRadius, BorderRadius.circular(20));
    expect(tester.getSize(_fabSurface()).height, 56);
    expect(_fabUnderOpacity(tester), isFalse);
    await _unmount(tester);
  });

  testWidgets('the glass FAB launches through GlassReveal, not opacity', (
    tester,
  ) async {
    await _mount(tester, appSurfaceRaw: _glassControls());
    final reveals = <double>[];
    for (var frame = 0; frame < 120; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (_fabSurface().evaluate().isEmpty) continue;
      expect(_fabUnderOpacity(tester), isFalse, reason: 'frame $frame');
      reveals.add(GlassReveal.of(tester.element(_fabSurface())));
      if (reveals.last == 1 && reveals.length > 1) break;
    }
    expect(reveals.any((value) => value > 0 && value < 1), isTrue);
    expect(reveals.last, 1);
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('hiding on scroll fades the glass FAB without opacity', (
    tester,
  ) async {
    await _mount(tester, appSurfaceRaw: _glassControls(), diaryCount: 18);
    await _settle(tester);
    await tester.drag(_diariesList(), const Offset(0, -300));
    final reveals = <double>[];
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_fabUnderOpacity(tester), isFalse, reason: 'frame $frame');
      reveals.add(GlassReveal.of(tester.element(_fabSurface())));
    }
    expect(reveals.any((value) => value > 0 && value < 1), isTrue);
    expect(reveals.last, 0);
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('tapping the glass FAB still opens a new diary', (tester) async {
    await _mount(tester, appSurfaceRaw: _glassControls());
    await _settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(EditDiaryPage).evaluate().isNotEmpty) break;
    }
    expect(find.byType(EditDiaryPage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('the wide rail button is unblurred glass', (tester) async {
    await _mount(tester, appSurfaceRaw: _glassControls(), width: 1100);
    await _settle(tester);
    final rail = find.byType(HomeNavRailCreateButton);
    final surface = find.descendant(
      of: rail,
      matching: find.byType(GlassSurface),
    );
    expect(surface, findsOneWidget);
    expect(tester.widget<GlassSurface>(surface).blur, isFalse);
    expect(tester.getSize(surface), const Size(56, 56));
    await _unmount(tester);
  });
}
