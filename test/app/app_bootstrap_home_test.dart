import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/app_bootstrap_home.dart';
import 'package:node_diary/app/launch_brand_mark.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/launch_reveal.dart';

const _homeMarker = ValueKey<String>('home_marker');
const _brand = ValueKey<String>('bootstrap_brand');
const _loader = ValueKey<String>('bootstrap_loader');

Widget _app({
  required AppBootstrapPhase phase,
  bool showBrandMark = true,
  bool holdReveal = false,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AppBootstrapHome(
      phase: phase,
      showBrandMark: showBrandMark,
      holdReveal: holdReveal,
      homeBuilder: (BuildContext context) => const Scaffold(
        body: LaunchReveal(
          slot: LaunchRevealSlot.masthead,
          child: SizedBox.expand(key: _homeMarker),
        ),
      ),
    ),
  );
}

/// 首页编排中顶栏槽位的不透明度。
double _homeOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.byKey(_homeMarker), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

/// 品牌层整体的不透明度（退场时与缩放一起变化）；最外层的 Opacity 属于品牌层
/// 本身，其内还有加载指示的入场淡入。
double _brandOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .descendant(of: find.byKey(_brand), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

Offset _screenCentre(WidgetTester tester) =>
    (tester.view.physicalSize / tester.view.devicePixelRatio).center(
      Offset.zero,
    );

void main() {
  testWidgets('the brand mark sits where the native splash draws it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.blank));

    final mark = find.byType(LaunchBrandMark);
    expect(tester.getCenter(mark), _screenCentre(tester));
    expect(tester.getSize(mark), LaunchBrandMark.size);
    expect(find.byKey(_loader), findsNothing);
  });

  testWidgets('without a native mark the wait paints only the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(phase: AppBootstrapPhase.blank, showBrandMark: false),
    );
    expect(find.byType(LaunchBrandMark), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('bootstrap_blank'))),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
  });

  testWidgets('a slow start shows the loader below the unmoved mark', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.blank));
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.loading));
    await tester.pump(const Duration(milliseconds: 300));

    final centre = _screenCentre(tester);
    expect(tester.getCenter(find.byType(LaunchBrandMark)), centre);
    final loader = tester.getRect(find.byKey(_loader));
    expect(loader.center.dx, centre.dx);
    expect(
      loader.top,
      greaterThan(centre.dy + LaunchBrandMark.size.height / 2),
    );
  });

  testWidgets('home rises in while the brand recedes, then the brand leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.loading));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.home));

    // 挂载首页的这一帧还在起点：首页尚不可见，品牌层与加载指示完整显示。
    expect(_homeOpacity(tester), 0);
    expect(_brandOpacity(tester), 1);
    expect(find.byKey(_loader), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 90));
    expect(_brandOpacity(tester), inExclusiveRange(0, 1));
    expect(_homeOpacity(tester), inExclusiveRange(0, 1));

    // 品牌层在 fast 内退场完毕即移出树（加载指示一起停止）。
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_brand), findsNothing);
    expect(find.byKey(_loader), findsNothing);

    await tester.pumpAndSettle();
    expect(_homeOpacity(tester), 1);
    // 首页挂载后不再在其下方铺底色。
    expect(find.byKey(const ValueKey<String>('bootstrap_blank')), findsNothing);
  });

  testWidgets('a slow home-mount frame does not eat into the reveal', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.blank));
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.home));
    // 挂载首页的这一帧很重，下一帧 80ms 后才到：揭幕应从这一帧才开始计时，
    // 而不是一上来就跳过 80ms（品牌图形一帧内淡掉八成）。
    await tester.pump(const Duration(milliseconds: 80));
    expect(_brandOpacity(tester), 1);
    expect(_homeOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 16));
    expect(_brandOpacity(tester), lessThan(1));
    await tester.pumpAndSettle();
  });

  testWidgets('an app lock holds the reveal until it is released', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.loading));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      _app(phase: AppBootstrapPhase.home, holdReveal: true),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(_homeOpacity(tester), 0);
    expect(_brandOpacity(tester), 1);
    // 数据已就绪：加载指示不再在锁屏遮罩下循环。
    expect(find.byKey(_loader), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_app(phase: AppBootstrapPhase.home));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 90));
    expect(_homeOpacity(tester), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_homeOpacity(tester), 1);
    expect(find.byKey(_brand), findsNothing);
  });

  testWidgets('a lock that lands after the reveal began rewinds it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.home));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_homeOpacity(tester), greaterThan(0));

    await tester.pumpWidget(
      _app(phase: AppBootstrapPhase.home, holdReveal: true),
    );
    expect(_homeOpacity(tester), 0);
    expect(_brandOpacity(tester), 1);

    await tester.pumpWidget(_app(phase: AppBootstrapPhase.home));
    await tester.pumpAndSettle();
    expect(_homeOpacity(tester), 1);
    expect(find.byKey(_brand), findsNothing);
  });

  testWidgets('reduce motion shows the home at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_app(phase: AppBootstrapPhase.blank));
    await tester.pumpWidget(_app(phase: AppBootstrapPhase.home));

    expect(_homeOpacity(tester), 1);
    expect(find.byKey(_brand), findsNothing);
  });
}
