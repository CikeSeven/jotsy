import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_snack_bar_theme.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/snack_bar_clearance.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  Finder snackBarCard() => find
      .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
      .first;

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 50);
    for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
      await tester.pump(step);
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness floating SnackBar clears in-body bottom bar and passes taps through',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        var barTapped = 0;
        late BuildContext pageContext;
        await tester.pumpWidget(
          MaterialApp(
            theme: expressiveTestTheme(brightness),
            home: SnackBarClearanceHost(
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    pageContext = context;
                    return Stack(
                      children: <Widget>[
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 8,
                          child: SnackBarClearanceArea(
                            child: SizedBox(
                              key: const ValueKey<String>('floating-bar'),
                              height: 52,
                              child: FilledButton(
                                onPressed: () => barTapped++,
                                child: const Text('Bar Action'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        unawaited(
          HomeHintVisibilityScope.showTrackedSnackBar(
            context: pageContext,
            snackBar: const SnackBar(
              content: Text('Copied'),
              duration: Duration(seconds: 3),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final barRect = tester.getRect(
          find.byKey(const ValueKey<String>('floating-bar')),
        );
        final snackRect = tester.getRect(snackBarCard());
        expect(
          snackRect.bottom,
          closeTo(barRect.top - SnackBarClearanceHost.defaultGap, 1.0),
        );

        await tester.tap(find.text('Bar Action'));
        await tester.pump();
        expect(barTapped, 1);

        await pumpFor(tester, const Duration(seconds: 4));
      },
    );
  }

  testWidgets(
    'gesture bar viewPadding is not double-counted and keyboard stays aligned',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);

      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          home: SnackBarClearanceHost(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  pageContext = context;
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          minimum: const EdgeInsets.only(bottom: 8),
                          child: SnackBarClearanceArea(
                            child: Container(
                              key: const ValueKey<String>('toolbar'),
                              height: 44,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: pageContext,
          snackBar: const SnackBar(
            content: Text('Saved'),
            duration: Duration(seconds: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barClosed = tester.getRect(
        find.byKey(const ValueKey<String>('toolbar')),
      );
      final snackClosed = tester.getRect(snackBarCard());
      expect(
        snackClosed.bottom,
        closeTo(barClosed.top - SnackBarClearanceHost.defaultGap, 1.0),
      );

      // 键盘弹起时 SafeArea 落回 minimum 8dp，提示条依然贴在工具栏上方 16dp。
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final barKeyboard = tester.getRect(
        find.byKey(const ValueKey<String>('toolbar')),
      );
      final snackKeyboard = tester.getRect(snackBarCard());
      expect(
        snackKeyboard.bottom,
        closeTo(barKeyboard.top - SnackBarClearanceHost.defaultGap, 1.0),
      );

      await pumpFor(tester, const Duration(seconds: 6));
    },
  );

  testWidgets('preserves glass SnackBar styling and wide horizontal margins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        builder: (context, child) => AppGlassScope(
          style: const AppGlassStyle(mode: AppGlassMode.glass),
          child: AppGlassSnackBarTheme(child: child!),
        ),
        home: Builder(
          builder: (context) {
            final base = Theme.of(context);
            return Theme(
              data: base.copyWith(
                snackBarTheme: base.snackBarTheme.copyWith(
                  insetPadding: const EdgeInsets.fromLTRB(320, 0, 320, 24),
                ),
              ),
              child: SnackBarClearanceHost(
                child: Scaffold(
                  body: Builder(
                    builder: (inner) {
                      pageContext = inner;
                      return Stack(
                        children: <Widget>[
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 16,
                            child: SnackBarClearanceArea(
                              child: Container(
                                key: const ValueKey<String>('wide-bar'),
                                height: 60,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: pageContext,
        snackBar: const SnackBar(
          content: Text('Glass hint'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(snackBarCard());
    final barRect = tester.getRect(
      find.byKey(const ValueKey<String>('wide-bar')),
    );
    expect(rect.width, closeTo(560, 0.5));
    expect(
      rect.bottom,
      closeTo(barRect.top - SnackBarClearanceHost.defaultGap, 1.0),
    );
    final material = tester.widget<Material>(snackBarCard());
    expect(
      material.color!.a,
      greaterThanOrEqualTo(AppGlassSnackBarTheme.minOpacity - 0.01),
    );

    await pumpFor(tester, const Duration(seconds: 3));
  });

  testWidgets('clamps bottom inset on a very short viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: SnackBarClearanceHost(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SnackBarClearanceArea(
                        child: Container(height: 260),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: pageContext,
        snackBar: const SnackBar(
          content: Text('Clamped hint'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(snackBarCard());
    expect(rect.top, greaterThanOrEqualTo(0));

    await pumpFor(tester, const Duration(seconds: 3));
  });

  testWidgets('nested host delegates to root and off-screen page is ignored', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final pages = PageController();
    addTearDown(pages.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: SnackBarClearanceHost(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return PageView(
                  controller: pages,
                  children: <Widget>[
                    const SizedBox.expand(),
                    _KeepAliveTestPage(
                      child: SnackBarClearanceHost(
                        child: Scaffold(
                          body: Stack(
                            children: <Widget>[
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 16,
                                child: SnackBarClearanceArea(
                                  child: Container(
                                    key: const ValueKey<String>('nested-bar'),
                                    height: 64,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 滑到第 1 页：嵌套宿主透传给根宿主，提示条避开 nested-bar。
    pages.jumpToPage(1);
    await tester.pumpAndSettle();
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: pageContext,
        snackBar: const SnackBar(
          content: Text('Page 1'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nestedRect = tester.getRect(
      find.byKey(const ValueKey<String>('nested-bar')),
    );
    expect(
      tester.getRect(snackBarCard()).bottom,
      closeTo(nestedRect.top - SnackBarClearanceHost.defaultGap, 1.0),
    );
    await pumpFor(tester, const Duration(seconds: 3));

    // 滑回第 0 页：第 1 页保活但已滚出屏幕，其底栏不应继续抬高提示条。
    pages.jumpToPage(0);
    await tester.pumpAndSettle();
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: pageContext,
        snackBar: const SnackBar(
          content: Text('Page 0'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(snackBarCard()).bottom, closeTo(800 - 16, 1.0));
    await pumpFor(tester, const Duration(seconds: 3));
  });

  testWidgets(
    'holds clearance steady while visible when bar leaves and lifts when bar appears',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final hintController = HomeHintVisibilityController();
      addTearDown(hintController.dispose);
      final showBar = ValueNotifier<bool>(true);
      addTearDown(showBar.dispose);
      late BuildContext pageContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          builder: (context, child) => HomeHintVisibilityScope(
            controller: hintController,
            child: child!,
          ),
          home: SnackBarClearanceHost(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  pageContext = context;
                  return ValueListenableBuilder<bool>(
                    valueListenable: showBar,
                    builder: (context, visible, _) => Stack(
                      children: <Widget>[
                        if (visible)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 16,
                            child: SnackBarClearanceArea(
                              child: Container(
                                key: const ValueKey<String>('temp-bar'),
                                height: 60,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 弹提示后底栏立刻消失：提示条停留在原高度，不中途下跳。
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: pageContext,
          snackBar: const SnackBar(
            content: Text('Deleted'),
            duration: Duration(seconds: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final elevatedBottom = tester.getRect(snackBarCard()).bottom;
      expect(elevatedBottom, closeTo(800 - 16 - 60 - 16, 1.0));

      showBar.value = false;
      await tester.pumpAndSettle();
      expect(tester.getRect(snackBarCard()).bottom, closeTo(elevatedBottom, 1));

      // 等本条提示彻底关闭（含防抖）后，下一条提示回落到底部默认位置。
      await pumpFor(tester, const Duration(seconds: 3));
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: pageContext,
          snackBar: const SnackBar(
            content: Text('Normal'),
            duration: Duration(seconds: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(snackBarCard()).bottom, closeTo(800 - 16, 1.0));

      // 提示停留期间新出现底栏：立刻上抬到新底栏上方。
      showBar.value = true;
      await tester.pumpAndSettle();
      expect(tester.getRect(snackBarCard()).bottom, closeTo(elevatedBottom, 1));
      await pumpFor(tester, const Duration(seconds: 3));
    },
  );

  testWidgets(
    'tracks bottom bar revealed via SizeTransition without resizing',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final visible = ValueNotifier<bool>(false);
      addTearDown(visible.dispose);
      late BuildContext pageContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          home: SnackBarClearanceHost(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  pageContext = context;
                  return Column(
                    children: <Widget>[
                      const Expanded(child: SizedBox.shrink()),
                      ValueListenableBuilder<bool>(
                        valueListenable: visible,
                        builder: (context, show, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              SizeTransition(
                                sizeFactor: animation,
                                alignment: Alignment.topCenter,
                                child: child,
                              ),
                          child: show
                              ? SnackBarClearanceArea(
                                  key: const ValueKey<String>('size-bar-area'),
                                  child: Container(
                                    key: const ValueKey<String>('size-bar'),
                                    height: 68,
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey<String>('size-bar-empty'),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 展开只移动位置不改子尺寸的 SizeTransition：提示条仍应落在其上方。
      visible.value = true;
      await tester.pumpAndSettle();
      final barRect = tester.getRect(
        find.byKey(const ValueKey<String>('size-bar')),
      );

      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: pageContext,
          snackBar: const SnackBar(
            content: Text('Size transitioned'),
            duration: Duration(seconds: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(snackBarCard()).bottom,
        closeTo(barRect.top - SnackBarClearanceHost.defaultGap, 1.0),
      );
      await pumpFor(tester, const Duration(seconds: 3));
    },
  );
}

class _KeepAliveTestPage extends StatefulWidget {
  const _KeepAliveTestPage({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTestPage> createState() => _KeepAliveTestPageState();
}

class _KeepAliveTestPageState extends State<_KeepAliveTestPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
