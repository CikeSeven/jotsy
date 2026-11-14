import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_route.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_source.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_transition.dart';

import '../app_surface/app_surface_test_images.dart';

/// 容器展开路由：从卡片展开、首帧画完才起步、停稳后与普通页面无异、返回时
/// 缩回卡片（找不到卡片或页面说不回时原地淡出）、转场期间关闭 Hero。
void main() {
  const cardRect = Rect.fromLTWH(16, 200, 368, 120);

  /// 一页列表：两张卡片（标签 a、b），点按 a 从它展开 [page]。
  Future<List<Object?>> pumpList(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool Function(Object? result)? returnsToOrigin,
    List<ContainerTransformOrigin?>? captured,
    GlobalKey? sceneKey,
  }) async {
    final results = <Object?>[];
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget card(String tag, double top) => Positioned.fromRect(
      rect: cardRect.translate(0, top - cardRect.top),
      child: ContainerTransformSource(
        tag: tag,
        borderRadius: 16,
        child: Builder(
          builder: (BuildContext tapContext) => GestureDetector(
            onTap: () async {
              final origin = ContainerTransformSource.capture(tapContext);
              captured?.add(origin);
              if (origin == null) {
                return;
              }
              results.add(
                await Navigator.of(tapContext).push<Object?>(
                  ContainerTransformPageRoute<Object?>(
                    origin: origin,
                    returnsToOrigin: returnsToOrigin,
                    builder: (BuildContext context) => const _DetailPage(),
                  ),
                ),
              );
            },
            child: ColoredBox(
              color: Colors.teal,
              child: Column(
                children: <Widget>[
                  Text('card $tag'),
                  // 与详情页同一标签的共享元素（列表封面 ↔ 预览页头图）。
                  Hero(tag: 'cover $tag', child: Text('cover $tag')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (disableAnimations) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        builder: sceneKey == null
            ? null
            : (context, child) => RepaintBoundary(key: sceneKey, child: child),
        home: Scaffold(
          body: Stack(children: <Widget>[card('a', 200), card('b', 340)]),
        ),
      ),
    );
    return results;
  }

  ContainerTransformPageRoute<Object?> routeOf(WidgetTester tester) =>
      ModalRoute.of(tester.element(find.byType(_DetailPage)))!
          as ContainerTransformPageRoute<Object?>;

  ContainerTransformGeometry geometryOf(WidgetTester tester) => tester
      .widget<ContainerTransformTransition>(
        find.byType(ContainerTransformTransition),
      )
      .geometry;

  void expectSourceVisible(WidgetTester tester, String tag, bool visible) {
    final source = tester.renderObject(
      find.ancestor(
        of: find.text('card $tag', skipOffstage: false),
        matching: find.byType(ContainerTransformSource, skipOffstage: false),
      ),
    );
    final cardPaint = paints..rect(color: const Color(0xFF009688));
    expect(source, visible ? cardPaint : isNot(cardPaint));
  }

  testWidgets('the first offstage frame keeps the original card on screen', (
    tester,
  ) async {
    final scene = GlobalKey();
    await pumpList(tester, sceneKey: scene);
    Future<int> cardPixel() async => (await tester.runAsync(() async {
      final boundary =
          scene.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        return (await pixelReader(image))(200, 280).toARGB32();
      } finally {
        image.dispose();
      }
    }))!;
    final before = await cardPixel();
    await tester.tap(find.text('card a'));
    // Hero 首帧把目的路由放到 offstage：这帧还没有飞行画面接替来源。
    // 连续三帧采集真正上屏的合成结果，不能只检查帧末的 widget 状态。
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
      expect(await cardPixel(), before, reason: 'opening frame $frame');
    }
    await tester.pumpAndSettle();
  });

  testWidgets('only the flying card paints until it reaches its source', (
    tester,
  ) async {
    await pumpList(tester);
    expectSourceVisible(tester, 'a', true);
    await tester.tap(find.text('card a'));
    await tester.pump();
    await tester.pump();
    expectSourceVisible(tester, 'a', false);
    expectSourceVisible(tester, 'b', true);

    await tester.pumpAndSettle();
    expectSourceVisible(tester, 'a', true);

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(routeOf(tester).animation!.value, inExclusiveRange(0, 1));
    expectSourceVisible(tester, 'a', false);
    expectSourceVisible(tester, 'b', true);

    await tester.pumpAndSettle();
    expectSourceVisible(tester, 'a', true);
  });

  testWidgets('removing a route during expansion restores the source card', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('card a'));
    await tester.pump();
    await tester.pump();
    expectSourceVisible(tester, 'a', false);

    final context = tester.element(find.byType(_DetailPage));
    Navigator.of(context).removeRoute(routeOf(tester));
    await tester.pumpAndSettle();
    expectSourceVisible(tester, 'a', true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'losing the return target during expansion releases the old source',
    (tester) async {
      await pumpList(tester);
      await tester.tap(find.text('card a'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expectSourceVisible(tester, 'a', false);

      final context = tester.element(find.byType(_DetailPage));
      ContainerTransformPageRoute.setReturnTag(context, 'missing');
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump();
      expectSourceVisible(tester, 'a', true);
      expect(geometryOf(tester).fallback, isTrue);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'disposing the navigator during return setup releases the source safely',
    (tester) async {
      await pumpList(tester);
      await tester.tap(find.text('card a'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(_DetailPage))).pop();
      // 截图与隐藏来源安排在帧末；在回调执行前移除整个导航器，不能再访问
      // 已销毁的来源、路由控制器或截图。
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a tap captures the card rect and a snapshot of it', (
    tester,
  ) async {
    final captured = <ContainerTransformOrigin?>[];
    await pumpList(tester, captured: captured);

    await tester.tap(find.text('card a'));
    // 第一帧路由 offstage（只构建、排版），第二帧才上屏。
    await tester.pump();
    await tester.pump();

    final origin = captured.single!;
    expect(origin.tag, 'a');
    final geometry = geometryOf(tester);
    expect(geometry.fallback, isFalse);
    expect(geometry.closed!.rect, cardRect);
    expect(geometry.closed!.imageRect, cardRect);
    expect(geometry.closed!.radius, 16);
    expect(geometry.closed!.image.width, cardRect.width.round());
    await tester.pumpAndSettle();
  });

  testWidgets('the expansion holds still until the first frame is painted', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.text('card a'));
    // 首帧：路由 offstage，页面在这一帧构建、排版。
    await tester.pump();
    final route = ModalRoute.of(
      tester.element(find.byType(_DetailPage, skipOffstage: false)),
    )!;
    expect(route.animation!.value, 0);
    // 第二帧：页面第一次绘制，哪怕这两帧很慢，进度也停在卡片上。
    await tester.pump(const Duration(milliseconds: 200));
    expect(route.animation!.value, 0);
    // 两帧画完后的这一帧才开始计时，仍从 0 出发——不会因前两帧耗时跳一截。
    await tester.pump(const Duration(milliseconds: 200));
    expect(route.animation!.value, 0);

    await tester.pump(const Duration(milliseconds: 100));
    final midway = route.animation!.value;
    expect(midway, greaterThan(0.2));
    expect(midway, lessThan(1));

    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
    expect(route.animation!.status, AnimationStatus.completed);
    // 停稳后不再留着起飞的卡片画面。
    expect(geometryOf(tester).closed, isNull);
  });

  testWidgets('expanding and returning each take their container duration', (
    tester,
  ) async {
    const frame = Duration(milliseconds: 16);
    await pumpList(tester);

    await tester.tap(find.text('card a'));
    // 两帧等页面排版、绘制，第三帧闸门打开、从 0 开始计时。
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final route = routeOf(tester);
    expect(route.animation!.value, 0);
    await tester.pump(ExpressiveMotion.containerOpen - frame);
    // 弹簧在最后一帧仍差一点点才落稳，时长走完的那一帧才停。
    expect(route.animation!.value, lessThan(1));
    expect(route.animation!.status, AnimationStatus.forward);
    await tester.pump(frame);
    expect(route.animation!.value, 1);
    expect(route.animation!.status, AnimationStatus.completed);

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    // 第一帧重新排版、绘制下层并量出卡片，第二帧闸门打开、从 1 开始计时。
    await tester.pump();
    await tester.pump();
    expect(route.animation!.value, 1);
    await tester.pump(ExpressiveMotion.containerClose - frame);
    expect(route.animation!.value, greaterThan(0));
    expect(route.animation!.status, AnimationStatus.reverse);
    await tester.pump(frame);
    expect(route.animation!.status, AnimationStatus.dismissed);
    await tester.pumpAndSettle();
    expectSourceVisible(tester, 'a', true);
  });

  testWidgets('heroes in the page are off until the route settles', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.text('card a'));
    HeroMode heroMode() => tester.widget<HeroMode>(
      find
          .ancestor(
            of: find.byType(_DetailPage, skipOffstage: false),
            matching: find.byType(HeroMode, skipOffstage: false),
          )
          .first,
    );
    // 第一帧（offstage，路由动画被代理成“已完成”）就已经关着：Hero 控制器
    // 正是在这一帧之后收集两端的 Hero。
    await tester.pump();
    expect(heroMode().enabled, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(heroMode().enabled, isFalse);

    await tester.pumpAndSettle();
    expect(heroMode().enabled, isTrue);

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    await tester.pump();
    expect(heroMode().enabled, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('the card cover does not fly on its own during the expansion', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.text('card a'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // 没有飞行：两端的 Hero 都还在原处显示，没有第三份飞行画面。
    expect(find.text('cover a'), findsNWidgets(2));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('cover a'), findsNWidgets(2));
    await tester.pumpAndSettle();
  });

  testWidgets('a settled page hit-tests like a plain page', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('card a'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('detail action'));
    await tester.pump();
    expect(find.text('tapped'), findsOneWidget);
  });

  testWidgets('popping collapses back into the card it came from', (
    tester,
  ) async {
    final results = await pumpList(tester);
    await tester.tap(find.text('card a'));
    await tester.pumpAndSettle();

    final route = routeOf(tester);
    Navigator.of(tester.element(find.byType(_DetailPage))).pop('done');
    // 下层页面重新排版的这一帧停在整页上，画完后量出卡片。
    await tester.pump();
    expect(route.animation!.value, 1);
    await tester.pump();
    final geometry = geometryOf(tester);
    expect(geometry.fallback, isFalse);
    expect(geometry.closed!.rect, cardRect);

    await tester.pump(const Duration(milliseconds: 150));
    expect(route.animation!.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
    expect(results, <Object?>['done']);
  });

  testWidgets('after switching content the page returns to that card', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('card a'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(_DetailPage));
    ContainerTransformPageRoute.setReturnTag(context, 'b');
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump();
    expect(geometryOf(tester).closed!.rect, cardRect.translate(0, 140));
    expectSourceVisible(tester, 'a', true);
    expectSourceVisible(tester, 'b', false);
    await tester.pumpAndSettle();
    expectSourceVisible(tester, 'b', true);
  });

  testWidgets('without a card to return to the page fades out in place', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('card a'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(_DetailPage));
    ContainerTransformPageRoute.setReturnTag(context, 'missing');
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump();
    expect(geometryOf(tester).fallback, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
  });

  testWidgets('a result that says not to return fades out in place', (
    tester,
  ) async {
    await pumpList(
      tester,
      returnsToOrigin: (Object? result) => result != 'deleted',
    );
    await tester.tap(find.text('card a'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(_DetailPage))).pop('deleted');
    await tester.pump();
    await tester.pump();
    expect(geometryOf(tester).fallback, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
  });

  testWidgets('a pop during the expansion reverses from where it is', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('card a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 120));
    final route = routeOf(tester);
    final before = route.animation!.value;
    final openingShot = geometryOf(tester).closed;
    expect(before, inExclusiveRange(0, 1));

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    await tester.pump(const Duration(milliseconds: 16));
    // 等待下层重新排版的那一帧不动：进度停在返回时的位置，不跳变。
    expect(route.animation!.value, closeTo(before, 0.001));
    expect(geometryOf(tester).closed, same(openingShot));
    expectSourceVisible(tester, 'a', false);
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
    expectSourceVisible(tester, 'a', true);
  });

  testWidgets('with reduced motion no origin is captured', (tester) async {
    final captured = <ContainerTransformOrigin?>[];
    await pumpList(tester, disableAnimations: true, captured: captured);

    await tester.tap(find.text('card a'));
    await tester.pump();
    expect(captured, <ContainerTransformOrigin?>[null]);
    expect(find.byType(_DetailPage), findsNothing);
  });

  testWidgets('Apple platforms keep the Cupertino swipe-back and opt out', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final captured = <ContainerTransformOrigin?>[];
    await pumpList(tester, captured: captured);

    await tester.tap(find.text('card a'));
    await tester.pump();
    expect(captured, <ContainerTransformOrigin?>[null]);
    debugDefaultTargetPlatformOverride = null;
  });
}

class _DetailPage extends StatefulWidget {
  const _DetailPage();

  @override
  State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Hero(tag: 'cover a', child: Text('cover a')),
            TextButton(
              onPressed: () => setState(() => _tapped = true),
              child: Text(_tapped ? 'tapped' : 'detail action'),
            ),
          ],
        ),
      ),
    );
  }
}
