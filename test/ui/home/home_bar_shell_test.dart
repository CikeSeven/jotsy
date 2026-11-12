import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diaries_header_sliver.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/explore/widgets/explore_module_menu.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_indicator.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _screenWidth = 400;
const double _screenHeight = 860;

/// 模拟的系统手势条高度。
const double _gestureInset = 24;

/// 默认三个 Tab（日记 / 日历 / 探索；待办默认关闭，设置不在底栏）的胶囊
/// 宽度：3 × 72 + 两侧各 6 的缝。
const double _pillWidth = 3 * 72 + 12;

/// 默认样式只关掉文字时的胶囊：项宽不变（72），格高 42，栏高 54。
const Size _compactPill = Size(3 * 72 + 12, 54);

/// 默认样式：悬浮玻璃栏 + 玻璃顶栏。
const HomeBarStyle _glass = HomeBarStyle.defaults;

String? _raw(HomeBarStyle style, [HomeBarBehavior? behavior]) =>
    HomeBarSettings(
      current: style,
      behavior: behavior ?? HomeBarBehavior.defaults,
    ).encode();

/// 挂载完整应用（只调度，不推进时间）；返回真实的 [SettingsService]。
Future<SettingsService> _mountApp(
  WidgetTester tester, {
  String? homeBarRaw,
  String? appFeaturesRaw,
  int diaryCount = 0,
  double statusBar = 0,
  double width = _screenWidth,
}) async {
  tester.view.physicalSize = Size(width, _screenHeight);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(
    top: statusBar,
    bottom: _gestureInset,
  );
  tester.view.padding = FakeViewPadding(top: statusBar, bottom: _gestureInset);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.home_bar_style': ?homeBarRaw,
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
  return settings;
}

/// 挂载并停在启动编排结束后的首页。
Future<SettingsService> _pumpHome(
  WidgetTester tester, {
  String? homeBarRaw,
  String? appFeaturesRaw,
  int diaryCount = 0,
  double statusBar = 0,
  double width = _screenWidth,
}) async {
  final settings = await _mountApp(
    tester,
    homeBarRaw: homeBarRaw,
    appFeaturesRaw: appFeaturesRaw,
    diaryCount: diaryCount,
    statusBar: statusBar,
    width: width,
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

/// 模拟的状态栏高度（玻璃顶栏测试用）。
const double _statusBar = 24;

/// 日记页刊头可收起部分的高度（与 `_headerCollapsibleHeight` 一致）。
const double _mastheadHeight = 56;

/// 日记页刊头这一片：只画内容，玻璃由下面的标签栏垫着；它的范围就是刊头
/// 当时露出的范围。
Finder get _masthead => find
    .descendant(
      of: find.byType(DiariesHeaderSliver),
      matching: find.byType(HomeTopBarSurface),
    )
    .first;

Finder get _tagBarGlass => find
    .ancestor(
      of: find.byType(DiaryTagFilterBar),
      matching: find.byType(GlassSurface),
    )
    .first;

/// 切到底栏上 [label] 对应的 Tab。
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(HomeBottomBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// [page] 里的主纵向滚动视图。
Finder _mainScrollable(Finder page) => find
    .descendant(
      of: page,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .first;

/// 把 [page] 的主滚动视图滚到底（分页加载会续上内容，所以滚两轮）。
Future<void> _scrollToEnd(WidgetTester tester, Finder page) async {
  for (var round = 0; round < 2; round++) {
    final position = tester
        .state<ScrollableState>(_mainScrollable(page))
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

/// [page] 主滚动视图末尾的留白：最后一个 sliver 是占位盒子（日记 / 日历 /
/// 探索）或列表的 SliverPadding（设置）。
double _trailingSpace(WidgetTester tester, Finder page) {
  final viewport = tester.renderObject<RenderViewport>(
    find
        .descendant(of: _mainScrollable(page), matching: find.byType(Viewport))
        .first,
  );
  final last = viewport.lastChild;
  if (last is RenderSliverPadding) {
    return last.resolvedPadding!.bottom;
  }
  return (last! as RenderSliverToBoxAdapter).child!.size.height;
}

/// 底栏槽位高度：玻璃时首页 body 读到的底部 padding。
double _slotHeight(WidgetTester tester, Finder page) =>
    MediaQuery.paddingOf(tester.element(page)).bottom;

/// 日记页标签栏（顶栏最下面一片）的底缘。
double _tagBarBottom(WidgetTester tester) => tester
    .getRect(
      find
          .ancestor(
            of: find.byType(DiaryTagFilterBar),
            matching: find.byType(HomeTopBarSurface),
          )
          .first,
    )
    .bottom;

void main() {
  testWidgets('the default style floats a blurred pill above the gesture '
      'inset', (tester) async {
    // 没有存过任何样式：默认就是悬浮玻璃栏，不再有贴底的实色栏。
    await _pumpHome(tester);
    expect(_homeScaffold(tester).extendBody, isTrue);
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // 胶囊按内容定宽（四项 × 72 + 两侧的缝）、水平居中，不再左右撑满。
    final rect = tester.getRect(_pill);
    expect(rect.width, _pillWidth);
    expect(rect.center.dx, _screenWidth / 2);
    expect(
      rect.bottom,
      _screenHeight - _gestureInset - HomeBarMetrics.bottomGap,
    );
    // 默认样式：格高 48 + 上下两道 6 的缝。
    expect(rect.height, 60);
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
    expect(tester.getSize(_inlineButton), const Size.square(60));
    // 胶囊与按钮作为一组居中。
    expect(
      (tester.getRect(_pill).left + tester.getRect(_inlineButton).right) / 2,
      closeTo(_screenWidth / 2, 0.01),
    );
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
        matching: find.text(l10n.navExplore),
      ),
    );
    await tester.pumpAndSettle();
    // 探索页没有新建按钮：槽位收起，胶囊回到正中。
    expect(tester.getSize(_pill).width, _pillWidth);
    expect(tester.getRect(_pill).center.dx, closeTo(_screenWidth / 2, 0.01));
    await _unmount(tester);
  });

  testWidgets('with only diaries left the glass bar and inline button give '
      'way to the global FAB', (tester) async {
    await _pumpHome(
      tester,
      homeBarRaw: _raw(
        _glass.copyWith(fabPlacement: HomeBarFabPlacement.inline),
      ),
      appFeaturesRaw: '{"calendar":false,"explore":false}',
    );
    // 只有一个 Tab：不画底栏，内容也不再延伸到胶囊下方。
    expect(find.byType(HomeBottomBar), findsNothing);
    expect(find.byType(HomeFloatingBar), findsNothing);
    expect(_inlineButton, findsNothing);
    expect(_homeScaffold(tester).extendBody, isFalse);
    // 新建入口回到全局 FAB，落在手势条上方 10dp。
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(fab.bottom, closeTo(_screenHeight - _gestureInset - 10, 0.01));
    expect(tester.takeException(), isNull);
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
    // 指示器是栏里铺满导航行的一层画布（不属于某个导航项），量它此刻画出
    // 的圆角矩形，再换算到屏幕坐标。
    final indicatorLayer = find.descendant(
      of: find.descendant(
        of: find.byType(HomeFloatingBar),
        matching: find.byType(HomeNavIndicator),
      ),
      matching: find.byType(CustomPaint),
    );
    double indicatorX() {
      RRect? painted;
      expect(
        tester.renderObject(indicatorLayer),
        paints..something((Symbol method, List<dynamic> arguments) {
          if (method != #drawRRect) {
            return false;
          }
          painted = arguments.first as RRect;
          return true;
        }),
      );
      return tester.getTopLeft(indicatorLayer).dx + painted!.center.dx;
    }

    final gesture = await tester.startGesture(
      const Offset(_screenWidth / 2, _screenHeight / 2),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    // 从居中的日记(1)左滑向探索(2)：指示器停在两项之间。
    final x = indicatorX();
    expect(x, greaterThan(iconX(1) + 1));
    expect(x, lessThan(iconX(2) - 1));
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
    expect(tester.getRect(_pill).width, _pillWidth);
    await _unmount(tester);
  });

  testWidgets('changing the style reshapes the pill live', (tester) async {
    final settings = await _pumpHome(tester, diaryCount: 3);
    expect(tester.getSize(_pill), const Size(_pillWidth, 60));

    const compact = HomeBarStyle(labelMode: HomeBarLabelMode.never);
    unawaited(settings.setHomeBarStyleRaw(_raw(compact)));
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill), _compactPill);
    expect(tester.getRect(_pill).center.dx, _screenWidth / 2);
    expect(find.byType(DiariesPage), findsOneWidget);

    unawaited(settings.setHomeBarStyleRaw(null));
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill), const Size(_pillWidth, 60));
    expect(_homeScaffold(tester).extendBody, isTrue);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('settings saved by older versions still open', (tester) async {
    // 旧版本的样式：已移除的字段（材质、栏高）忽略，留下的照常生效。
    await _pumpHome(
      tester,
      homeBarRaw:
          '{"v":1,"current":{"material":"solid","barHeight":72,'
          '"labelMode":"never"}}',
    );
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(tester.getSize(_pill), _compactPill);
    await _unmount(tester);
  });

  group('glass top bars on the diaries tab', () {
    testWidgets('the masthead glass covers the status bar at rest', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        diaryCount: 18,
        statusBar: _statusBar,
        homeBarRaw: _raw(_glass),
      );
      final masthead = tester.getRect(_masthead);
      expect(masthead.top, 0);
      expect(masthead.height, _statusBar + _mastheadHeight);
      expect(tester.getTopLeft(find.byType(DiaryHeadSection)).dy, _statusBar);
      expect(tester.getRect(_tagBarGlass).top, masthead.bottom);
      await _unmount(tester);
    });

    testWidgets('scrolling collapses the masthead to the status strip', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        diaryCount: 18,
        statusBar: _statusBar,
        homeBarRaw: _raw(_glass),
      );
      await tester.drag(_diariesList(), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(_masthead).top, 0);
      expect(tester.getRect(_masthead).height, _statusBar);
      expect(tester.getRect(_tagBarGlass).top, _statusBar);

      // 浮动刊头：上滑要逐帧推进才会露出（见 diaries_sort_test）。
      final gesture = await tester.startGesture(
        tester.getCenter(_diariesList()),
      );
      for (var step = 0; step < 4; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(_masthead).height, _statusBar + _mastheadHeight);
      expect(tester.getRect(_tagBarGlass).top, _statusBar + _mastheadHeight);
      await _unmount(tester);
    });

    testWidgets('selection mode keeps the whole masthead visible', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        diaryCount: 18,
        statusBar: _statusBar,
        homeBarRaw: _raw(_glass),
      );
      await tester.longPress(find.byType(DiaryCard).first);
      await tester.pumpAndSettle();
      await tester.drag(_diariesList(), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(_masthead).top, 0);
      expect(tester.getRect(_masthead).height, _statusBar + _mastheadHeight);
      expect(tester.getRect(_tagBarGlass).top, _statusBar + _mastheadHeight);
      await _unmount(tester);
    });

    testWidgets('the whole top bar is one sheet of glass with no line', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        diaryCount: 3,
        statusBar: _statusBar,
        homeBarRaw: _raw(_glass),
      );
      // 刊头不画玻璃，整条顶栏只读一次背景：两片各读一次时，后画的刊头会把
      // 标签糊进自己的下缘，接缝处看得出一道线。
      expect(
        find.descendant(
          of: find.byType(DiariesHeaderSliver),
          matching: find.byType(GlassSurface),
        ),
        findsNothing,
      );
      final backdrops = find.descendant(
        of: find.byType(DiariesPage),
        matching: find.byType(BackdropFilter),
      );
      final filters = tester
          .renderObjectList<RenderBackdropFilter>(backdrops)
          .toList();
      expect(filters, hasLength(1));
      expect(filters.single.enabled, isTrue);
      // 渐变靠在自己的图层里擦除：不共用背景读取，否则 Impeller 会把页面
      // 擦成黑色。
      expect(filters.single.backdropKey, isNull);
      // 玻璃从屏幕顶端一直铺到标签栏下缘。
      final glass = tester.getRect(backdrops);
      expect(glass.top, lessThanOrEqualTo(0));
      expect(glass.bottom, _tagBarBottom(tester));
      expect(tester.widget<GlassSurface>(_tagBarGlass).bottomHairline, isNull);
      await _unmount(tester);
    });

    testWidgets('the top bar hairline lands on the tag bar only', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        diaryCount: 3,
        statusBar: _statusBar,
        homeBarRaw: _raw(_glass.copyWith(topBarHairline: true)),
      );
      expect(
        find.descendant(
          of: find.byType(DiariesHeaderSliver),
          matching: find.byType(GlassSurface),
        ),
        findsNothing,
      );
      expect(
        tester.widget<GlassSurface>(_tagBarGlass).bottomHairline,
        isNotNull,
      );
      await _unmount(tester);
    });

    testWidgets('the first card keeps the shared top gap below the hairline', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        diaryCount: 3,
        statusBar: _statusBar,
        homeBarRaw: _raw(_glass),
      );
      // 四个 Tab 统一的顶部间距，与卡片间距无关。
      const gap = kHomeTopContentGap;
      final tagBarBottom = _tagBarBottom(tester);
      expect(tester.getRect(_tagBarGlass).bottom, tagBarBottom);
      final firstCardTop = tester.getRect(find.byType(DiaryCard).first).top;
      expect(firstCardTop, greaterThanOrEqualTo(tagBarBottom + gap - 0.01));
      expect(firstCardTop, closeTo(tagBarBottom + gap, 0.01));

      // 空白随内容滚走：上滑一点后，固定的标签栏不变高。
      final tagBarHeight = tester.getRect(_tagBarGlass).height;
      await tester.drag(_diariesList(), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getRect(_tagBarGlass).height, tagBarHeight);
      await _unmount(tester);
    });

    testWidgets('settings that turned glass top bars off still get glass', (
      tester,
    ) async {
      // 旧版本可以关掉顶栏玻璃；这个开关已移除，存过的值一律忽略。
      await _pumpHome(
        tester,
        diaryCount: 3,
        statusBar: _statusBar,
        homeBarRaw: '{"v":1,"current":{"glassTopBars":false}}',
      );
      expect(
        find.descendant(
          of: find.byType(DiariesPage),
          matching: find.byType(GlassSurface),
        ),
        findsWidgets,
      );
      // 玻璃刊头铺到状态栏，第一张卡片与标签栏之间留出统一的间距。
      expect(tester.getRect(_masthead).top, 0);
      expect(tester.getTopLeft(find.byType(DiaryHeadSection)).dy, _statusBar);
      expect(
        tester.getRect(find.byType(DiaryCard).first).top -
            _tagBarBottom(tester),
        closeTo(kHomeTopContentGap, 0.01),
      );
      await _unmount(tester);
    });
  });

  group('content scrolls fully above the floating pill', () {
    // 日历页在 400dp 宽的测试字体下本就有一处横向溢出（与底栏无关），
    // 这组只关心纵向留白，用宽一点的屏幕避开它。
    const wide = 480.0;

    testWidgets('every tab pads its end by the bar slot', (tester) async {
      await _pumpHome(
        tester,
        diaryCount: 18,
        homeBarRaw: _raw(_glass),
        width: wide,
      );
      final l10n = _l10n(tester);
      final pillTop = tester.getRect(_pill).top;

      final diaries = find.byType(DiariesPage);
      final slot = _slotHeight(tester, diaries);
      expect(slot, greaterThan(0));
      expect(_trailingSpace(tester, diaries), 12 + slot);
      // 列表一直延伸到屏幕底部（从胶囊下方透出）。
      expect(tester.getRect(_diariesList()).bottom, _screenHeight);
      await _scrollToEnd(tester, diaries);
      final lastCard = find.byType(DiaryCard).last;
      expect(tester.getRect(lastCard).bottom, lessThanOrEqualTo(pillTop));

      await _openTab(tester, l10n.navCalendar);
      final calendar = find.byType(CalendarPage);
      expect(_slotHeight(tester, calendar), slot);
      expect(_trailingSpace(tester, calendar), 12 + slot);

      await _openTab(tester, l10n.navExplore);
      final explore = find.byType(ExplorePage);
      expect(_trailingSpace(tester, explore), 12 + slot);
      await _scrollToEnd(tester, explore);
      expect(
        // 正式内容是 sliver，检查实际最后一张卡片的可见底缘。
        tester.getRect(find.byType(ExploreModuleMenu).last).bottom,
        lessThanOrEqualTo(pillTop),
      );
      await _unmount(tester);
    });
  });
}
