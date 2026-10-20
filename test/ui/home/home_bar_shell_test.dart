import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_indicator.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _screenWidth = 400;
const double _screenHeight = 860;

/// 模拟的系统手势条高度。
const double _gestureInset = 24;

const HomeBarStyle _glass = HomeBarStyle(material: HomeBarMaterial.glass);

String? _raw(HomeBarStyle style, [HomeBarBehavior? behavior]) =>
    HomeBarSettings(
      current: style,
      behavior: behavior ?? HomeBarBehavior.defaults,
    ).encode();

/// 挂载完整应用（只调度，不推进时间）；返回真实的 [SettingsService]。
Future<SettingsService> _mountApp(
  WidgetTester tester, {
  String? homeBarRaw,
  int diaryCount = 0,
}) async {
  tester.view.physicalSize = const Size(_screenWidth, _screenHeight);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(bottom: _gestureInset);
  tester.view.padding = const FakeViewPadding(bottom: _gestureInset);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.home_bar_style': ?homeBarRaw,
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
  return settings;
}

/// 挂载并停在启动编排结束后的首页。
Future<SettingsService> _pumpHome(
  WidgetTester tester, {
  String? homeBarRaw,
  int diaryCount = 0,
}) async {
  final settings = await _mountApp(
    tester,
    homeBarRaw: homeBarRaw,
    diaryCount: diaryCount,
  );
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(HomePage)).l10n;

Scaffold _homeScaffold(WidgetTester tester) => tester.widget<Scaffold>(
  find
      .descendant(of: find.byType(HomePage), matching: find.byType(Scaffold))
      .first,
);

Finder get _pill => find.descendant(
  of: find.byType(HomeFloatingBar),
  matching: find.byType(GlassSurface),
);

Finder get _pillBackdrop =>
    find.descendant(of: _pill, matching: find.byType(BackdropFilter));

Finder get _inlineButton => find.byType(HomeInlineCreateButton);

/// 胶囊的 BackdropFilter 与 HomeBottomBar 之间是否夹着 Opacity。
bool _glassUnderOpacity(WidgetTester tester) {
  var underOpacity = false;
  tester.element(_pillBackdrop).visitAncestorElements((element) {
    if (element.widget is HomeBottomBar) {
      return false;
    }
    if (element.widget is Opacity) {
      underOpacity = true;
      return false;
    }
    return true;
  });
  return underOpacity;
}

Finder _diariesList() => find
    .descendant(
      of: find.byType(DiariesPage, skipOffstage: false),
      matching: find.byType(Scrollable, skipOffstage: false),
    )
    .first;

void main() {
  testWidgets('the default style keeps the solid bar under the body', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(_homeScaffold(tester).extendBody, isFalse);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.byType(HomeFloatingBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('glass floats a blurred pill above the gesture inset', (
    tester,
  ) async {
    await _pumpHome(tester, homeBarRaw: _raw(_glass));
    expect(_homeScaffold(tester).extendBody, isTrue);
    expect(find.byType(BottomNav), findsNothing);
    final rect = tester.getRect(_pill);
    expect(rect.left, _glass.sideMargin);
    expect(rect.right, _screenWidth - _glass.sideMargin);
    expect(rect.bottom, _screenHeight - _gestureInset - _glass.bottomGap);
    expect(rect.height, _glass.barHeight);
    expect(tester.widget<BackdropFilter>(_pillBackdrop).enabled, isTrue);
    expect(_glassUnderOpacity(tester), isFalse);
    await _unmount(tester);
  });

  testWidgets('the glass reveals through progress, never an opacity layer', (
    tester,
  ) async {
    await _mountApp(tester, homeBarRaw: _raw(_glass));
    final progresses = <double>[];
    for (var frame = 0; frame < 120; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (_pill.evaluate().isEmpty) {
        continue;
      }
      expect(_glassUnderOpacity(tester), isFalse, reason: 'frame $frame');
      progresses.add(tester.widget<GlassSurface>(_pill).progress);
      if (progresses.last == 1) {
        break;
      }
    }
    // 编排途中确实经过了 0 与 1 之间的显现进度。
    expect(progresses.any((value) => value > 0 && value < 1), isTrue);
    expect(progresses.last, 1);
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('the FAB sits 10dp above the floating pill', (tester) async {
    await _pumpHome(tester, homeBarRaw: _raw(_glass));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final pill = tester.getRect(_pill);
    expect(fab.bottom, lessThanOrEqualTo(pill.top - 10 + 0.01));
    expect(fab.bottom, closeTo(pill.top - 10, 0.01));
    await _unmount(tester);
  });

  testWidgets('inline placement docks the create button in the bar', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      homeBarRaw: _raw(
        _glass.copyWith(fabPlacement: HomeBarFabPlacement.inline),
      ),
    );
    final l10n = _l10n(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HomeFloatingBar),
        matching: _inlineButton,
      ),
      findsOneWidget,
    );
    expect(tester.getSize(_inlineButton), Size.square(_glass.barHeight));
    expect(
      tester.widget<HomeInlineCreateButton>(_inlineButton).label,
      l10n.commonNew,
    );
    expect(find.byTooltip(l10n.commonNew), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.semantics.byLabel(l10n.commonNew), findsOneWidget);
    semantics.dispose();

    await tester.tap(
      find.descendant(
        of: find.byType(HomeFloatingBar),
        matching: find.text(l10n.navSettings),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill).width, _screenWidth - _glass.sideMargin * 2);
    final slotWidth =
        tester.getRect(find.byType(HomeFloatingBar)).right -
        tester.getRect(_pill).right;
    expect(slotWidth, closeTo(0, 0.01));
    await _unmount(tester);
  });

  testWidgets('hide on scroll slides the glass bar away and back', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      diaryCount: 18,
      homeBarRaw: _raw(_glass, const HomeBarBehavior(hideOnScroll: true)),
    );
    final restingTop = tester.getRect(_pill).top;

    await tester.drag(_diariesList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill).top, greaterThanOrEqualTo(_screenHeight));
    // FAB 落到手势条上方（即使日记页同时把它滑出）。
    final fabPositioned = tester.widget<AnimatedPositioned>(
      find
          .ancestor(
            of: find.byType(FloatingActionButton),
            matching: find.byType(AnimatedPositioned),
          )
          .first,
    );
    expect(fabPositioned.bottom, _gestureInset + 10);

    await tester.drag(_diariesList(), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill).top, restingTop);
    await _unmount(tester);
  });

  testWidgets('a home hint brings the hidden bar back', (tester) async {
    await _pumpHome(
      tester,
      diaryCount: 18,
      homeBarRaw: _raw(_glass, const HomeBarBehavior(hideOnScroll: true)),
    );
    final restingTop = tester.getRect(_pill).top;
    await tester.drag(_diariesList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill).top, greaterThanOrEqualTo(_screenHeight));

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
    expect(tester.getRect(_pill).top, restingTop);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('without hide on scroll the bar never moves', (tester) async {
    await _pumpHome(tester, diaryCount: 18, homeBarRaw: _raw(_glass));
    final restingTop = tester.getRect(_pill).top;
    await tester.drag(_diariesList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill).top, restingTop);
    await tester.drag(_diariesList(), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill).top, restingTop);
    await _unmount(tester);
  });

  testWidgets('follow swipe moves the indicator with the page drag', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      homeBarRaw: _raw(
        _glass,
        const HomeBarBehavior(indicatorFollowsSwipe: true),
      ),
    );
    Finder destination(int index) => find.descendant(
      of: find.byType(HomeFloatingBar),
      matching: find.byType(HomeNavDestination).at(index),
    );
    double iconX(int index) => tester
        .getCenter(
          find.descendant(
            of: destination(index),
            matching: find.byType(FaIcon),
          ),
        )
        .dx;
    final indicator = find.descendant(
      of: destination(0),
      matching: find.byType(HomeNavIndicator),
    );

    final gesture = await tester.startGesture(
      const Offset(_screenWidth / 2, _screenHeight / 2),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    final x = tester.getRect(indicator).center.dx;
    expect(x, greaterThan(iconX(0) + 1));
    expect(x, lessThan(iconX(1) - 1));
    await gesture.up();
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('high contrast keeps the floating layout without blur', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpHome(tester, homeBarRaw: _raw(_glass));
    expect(_homeScaffold(tester).extendBody, isTrue);
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(tester.widget<BackdropFilter>(_pillBackdrop).enabled, isFalse);
    expect(tester.getRect(_pill).left, _glass.sideMargin);
    await _unmount(tester);
  });

  testWidgets('changing the setting swaps solid and glass live', (
    tester,
  ) async {
    final settings = await _pumpHome(tester, diaryCount: 3);
    expect(find.byType(BottomNav), findsOneWidget);

    unawaited(settings.setHomeBarStyleRaw(_raw(_glass)));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNav), findsNothing);
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(_homeScaffold(tester).extendBody, isTrue);
    expect(find.byType(DiariesPage), findsOneWidget);

    unawaited(settings.setHomeBarStyleRaw(null));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.byType(HomeFloatingBar), findsNothing);
    expect(_homeScaffold(tester).extendBody, isFalse);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
