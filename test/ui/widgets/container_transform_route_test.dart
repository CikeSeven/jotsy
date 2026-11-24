import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/display_corners.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_below_snapshot.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_route.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_source.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_transition.dart';

import '../app_surface/app_surface_test_images.dart';

/// 容器展开路由：从卡片展开、首帧画完才起步、停稳后与普通页面无异、返回时
/// 缩回卡片（找不到卡片或页面说不回时原地淡出）、转场期间关闭 Hero、下层
/// 页面途中画成快照（玻璃取样照常在里面）。
void main() {
  const cardRect = Rect.fromLTWH(16, 200, 368, 120);

  /// 一页列表：两张卡片（标签 a、b），点按 a 从它展开 [page]。
  Future<List<Object?>> pumpList(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool Function(Object? result)? returnsToOrigin,
    List<ContainerTransformOrigin?>? captured,
    GlobalKey? sceneKey,
    LayerLink? backdropLink,
    double cardATop = 200,
    double cardBTop = 340,
    Color cardAColor = Colors.teal,
    Color cardBColor = Colors.teal,
    Color? listBackgroundColor,
    bool glassCardA = false,
  }) async {
    final results = <Object?>[];
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget card(String tag, double top, Color color, {bool glass = false}) =>
        Positioned.fromRect(
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
                child: glass && backdropLink != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          CompositedTransformFollower(
                            link: backdropLink,
                            showWhenUnlinked: false,
                            offset: Offset(cardRect.left, top),
                            child: ColoredBox(color: color),
                          ),
                          Column(
                            children: <Widget>[
                              Text('card $tag'),
                              Hero(
                                tag: 'cover $tag',
                                child: Text('cover $tag'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : ColoredBox(
                        color: color,
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
          backgroundColor: listBackgroundColor,
          body: _wrapBackdropLink(
            backdropLink,
            Stack(
              children: <Widget>[
                card('a', cardATop, cardAColor, glass: glassCardA),
                card('b', cardBTop, cardBColor),
                if (backdropLink != null) _followerBand(backdropLink),
              ],
            ),
          ),
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

  Rect containerRectOf(WidgetTester tester) => tester
      .renderObject<RenderContainerTransform>(
        find.byType(ContainerTransformTransition),
      )
      .debugContainerRect;

  /// 推入后起步前的固定等待：首帧（offstage）构建排版并实时画原卡片、首帧末
  /// 截卡并隐藏原卡片、第二帧页面首次绘制并拍下层快照、第三帧空等光栅追上。
  /// 再下一帧才开始计时（仍从 0 出发）。
  Future<void> pumpOpeningHold(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  /// 停稳后返回、起步前的固定等待：首帧下层实时排版绘制、帧末量并截卡后隐藏、
  /// 第二帧拍下层快照、第三帧空等光栅追上。再下一帧才开始计时（仍从 1 出发）。
  Future<void> pumpClosingHold(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  void expectColorNear(Color actual, Color expected, {required String reason}) {
    final a = actual.toARGB32();
    final e = expected.toARGB32();
    for (final shift in <int>[0, 8, 16, 24]) {
      expect(
        (a >> shift) & 0xff,
        closeTo((e >> shift) & 0xff, 2),
        reason: reason,
      );
    }
  }

  /// 起步帧（仍在起点）加一个正常间隔的帧：此后时钟按真实时间走。起步
  /// 后第一步隔得太久会从那一帧重新起算（真机上是拍完快照、GPU 还没追上），
  /// 测试里直接跳一大步就要先走这一小步。
  Future<void> pumpStart(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// 下层页面的快照渲染对象（停稳后下层 offstage，查找时要带上它）。
  RenderContainerTransformBelowSnapshot belowOf(WidgetTester tester) =>
      tester.renderObject<RenderContainerTransformBelowSnapshot>(
        find.byType(ContainerTransformBelowSnapshot, skipOffstage: false),
      );

  Future<Color> scenePixel(
    WidgetTester tester,
    GlobalKey scene,
    Offset at,
  ) async => (await tester.runAsync(() async {
    final boundary =
        scene.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      return (await pixelReader(image))(at.dx.round(), at.dy.round());
    } finally {
      image.dispose();
    }
  }))!;

  testWidgets('the container starts and lands as the card itself', (
    tester,
  ) async {
    final scene = GlobalKey();
    await pumpList(tester, sceneKey: scene);
    const teal = Color(0xFF009688);
    const inCard = Offset(200, 280);
    expect(await scenePixel(tester, scene, inCard), teal);
    await tester.tap(find.text('card a'));
    // Hero 首帧把目的路由放到 offstage：这帧仍是原卡片；之后容器停在卡片
    // 上，画的是截下的同一张卡片（采集真正上屏的合成结果，不能只检查帧末的
    // widget 状态）。
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
      expect(
        await scenePixel(tester, scene, inCard),
        teal,
        reason: 'opening frame $frame',
      );
    }
    // 渐变结束后容器里是页面。
    final route = routeOf(tester);
    final pageColor = Theme.of(
      tester.element(find.byType(_DetailPage)),
    ).scaffoldBackgroundColor;
    while (route.animation!.value < 0.7) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(await scenePixel(tester, scene, inCard), pageColor);
    await tester.pumpAndSettle();

    // 返回：落位前容器里已经完全是卡片，路由卸载后露出原卡片，不跳。
    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    await pumpClosingHold(tester);
    await pumpStart(tester);
    while (route.animation!.value > 0.2) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(await scenePixel(tester, scene, inCard), teal);
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
    expect(await scenePixel(tester, scene, inCard), teal);
  });

  testWidgets(
    'the card slot below stays empty while expanding and collapsing',
    (tester) async {
      final scene = GlobalKey();
      const listBg = Color(0xFFECEFF1);
      const cardAColor = Color(0xFF009688);
      const cardBColor = Color(0xFFFFB300);
      // 把 a 放在列表下半部（460..580）：展开与收回中段容器上移并保持卡片比例，
      // 会完整露出 a 原来的位置（550..580）；列表里此处不应再画出一张卡片。
      await pumpList(
        tester,
        sceneKey: scene,
        cardATop: 460,
        cardBTop: 180,
        cardAColor: cardAColor,
        cardBColor: cardBColor,
        listBackgroundColor: listBg,
      );
      const exposedSlot = Offset(200, 565);
      const neighborCard = Offset(200, 220);
      expect(await scenePixel(tester, scene, exposedSlot), cardAColor);
      expect(await scenePixel(tester, scene, neighborCard), cardBColor);

      await tester.tap(find.text('card a'));
      // 起步前几帧容器停在原位，不闪空位。
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump();
        expect(
          await scenePixel(tester, scene, exposedSlot),
          cardAColor,
          reason: 'opening hold frame $frame',
        );
      }
      await pumpStart(tester);
      final route = routeOf(tester);
      while (route.animation!.value < 0.25) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final openProgress = route.animation!.value;
      final openContainer = containerRectOf(tester);
      expect(
        openContainer.bottom,
        lessThan(exposedSlot.dy - 10),
        reason: '展开中段应露出原卡片位置',
      );
      expectColorNear(
        await scenePixel(tester, scene, exposedSlot),
        Color.alphaBlend(
          Colors.black.withValues(alpha: 0.28 * openProgress),
          listBg,
        ),
        reason: '展开途中原位置应只剩列表背景，不再有一张日记卡片',
      );
      await tester.pumpAndSettle();

      // 返回：缩回途中同样露出原卡片位置，原位置不能提前出现第二张卡片。
      Navigator.of(tester.element(find.byType(_DetailPage))).pop();
      await pumpClosingHold(tester);
      await pumpStart(tester);
      while (route.animation!.value > 0.35) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final closeProgress = route.animation!.value;
      final closeContainer = containerRectOf(tester);
      expect(
        closeContainer.bottom,
        lessThan(exposedSlot.dy - 10),
        reason: '收回中段应露出原卡片位置',
      );
      expectColorNear(
        await scenePixel(tester, scene, exposedSlot),
        Color.alphaBlend(
          Colors.black.withValues(alpha: 0.28 * closeProgress),
          listBg,
        ),
        reason: '收回途中原位置应只剩列表背景，不再有一张日记卡片',
      );
      await tester.pumpAndSettle();
      // 落定当帧恢复原卡片绘制。
      expect(await scenePixel(tester, scene, exposedSlot), cardAColor);
      expect(await scenePixel(tester, scene, neighborCard), cardBColor);
    },
  );

  testWidgets(
    'switching return target hides only that card and keeps origin visible',
    (tester) async {
      final scene = GlobalKey();
      const listBg = Color(0xFFECEFF1);
      const cardAColor = Color(0xFF009688);
      const cardBColor = Color(0xFFFFB300);
      await pumpList(
        tester,
        sceneKey: scene,
        cardATop: 140,
        cardBTop: 460,
        cardAColor: cardAColor,
        cardBColor: cardBColor,
        listBackgroundColor: listBg,
      );
      await tester.tap(find.text('card a'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_DetailPage));
      final route = routeOf(tester);
      ContainerTransformPageRoute.setReturnTag(context, 'b');
      Navigator.of(context).pop();
      await pumpClosingHold(tester);
      await pumpStart(tester);
      while (route.animation!.value > 0.35) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final p = route.animation!.value;
      final container = containerRectOf(tester);
      const bSlot = Offset(200, 565);
      const aCard = Offset(200, 160);
      expect(container.bottom, lessThan(bSlot.dy - 10));
      expect(container.top, greaterThan(aCard.dy + 10));
      // 归位目标 b 的原位置留空，原本点开的 a 照常显示。
      expectColorNear(
        await scenePixel(tester, scene, bSlot),
        Color.alphaBlend(Colors.black.withValues(alpha: 0.28 * p), listBg),
        reason: '归位目标 b 原位置在收回途中应留空',
      );
      expectColorNear(
        await scenePixel(tester, scene, aCard),
        Color.alphaBlend(Colors.black.withValues(alpha: 0.28 * p), cardAColor),
        reason: '非归位目标 a 应照常显示',
      );
      await tester.pumpAndSettle();
      expect(await scenePixel(tester, scene, bSlot), cardBColor);
      expect(await scenePixel(tester, scene, aCard), cardAColor);
    },
  );

  testWidgets('removing a route during expansion goes back to live painting', (
    tester,
  ) async {
    final scene = GlobalKey();
    const teal = Color(0xFF009688);
    await pumpList(tester, sceneKey: scene);
    await tester.tap(find.text('card a'));
    await tester.pump();
    await tester.pump();
    expect(belowOf(tester).debugImage, isNotNull);

    final context = tester.element(find.byType(_DetailPage));
    Navigator.of(context).removeRoute(routeOf(tester));
    await tester.pumpAndSettle();
    expect(find.byType(ContainerTransformBelowSnapshot), findsNothing);
    expect(find.text('card a'), findsOneWidget);
    // 提前移除路由后原卡片必须立即恢复绘制，不能留在隐藏态。
    expect(await scenePixel(tester, scene, const Offset(200, 280)), teal);
    expect(tester.takeException(), isNull);
  });

  testWidgets('losing the return target during expansion fades out in place', (
    tester,
  ) async {
    final scene = GlobalKey();
    const teal = Color(0xFF009688);
    await pumpList(tester, sceneKey: scene, cardATop: 460, cardBTop: 180);
    await tester.tap(find.text('card a'));
    await pumpOpeningHold(tester);
    await pumpStart(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final context = tester.element(find.byType(_DetailPage));
    ContainerTransformPageRoute.setReturnTag(context, 'missing');
    Navigator.of(context).pop();
    await tester.pump();
    expect(geometryOf(tester).fallback, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
    expect(await scenePixel(tester, scene, const Offset(200, 560)), teal);
  });

  testWidgets(
    'disposing the navigator during return setup releases the source safely',
    (tester) async {
      await pumpList(tester);
      await tester.tap(find.text('card a'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(_DetailPage))).pop();
      // 量卡片、起步安排在帧末；在回调执行前移除整个导航器，不能再访问
      // 已销毁的来源或路由控制器。
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('glass samples below stay in the snapshot both ways', (
    tester,
  ) async {
    // 内容玻璃的预模糊取样是跟随页面背景 Leader 的 Follower（Leader 不在
    // 时不画）。卡片本身截下后与下层改画快照后，玻璃卡片与其余取样必须都与
    // 实时绘制时一样，不能只剩半透明底色、透出更清楚的背景。
    final scene = GlobalKey();
    final link = LayerLink();
    const glassCardColor = Color(0xFF009688);
    await pumpList(
      tester,
      sceneKey: scene,
      backdropLink: link,
      cardAColor: glassCardColor,
      glassCardA: true,
    );
    Future<Color> bandPixel() =>
        scenePixel(tester, scene, const Offset(200, _bandTop + 50));
    const inGlassCard = Offset(200, 280);
    expect(await bandPixel(), _bandColor);
    expect(await scenePixel(tester, scene, inGlassCard), glassCardColor);

    await tester.tap(find.text('card a'));
    // 起步前的几帧进度停在 0（遮罩为 0）：卡片图与下层取样带都原样可见。
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
      expect(await bandPixel(), _bandColor, reason: 'opening band $frame');
      expect(
        await scenePixel(tester, scene, inGlassCard),
        glassCardColor,
        reason: 'opening glass card $frame',
      );
    }
    expect(belowOf(tester).debugImage, isNotNull);
    await tester.pumpAndSettle();

    // 停稳后返回：首帧实时绘制并截卡，第二帧拍下层快照（其余玻璃照常保留）。
    final route = routeOf(tester);
    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    await tester.pump();
    await tester.pump();
    expect(belowOf(tester).debugImage, isNotNull);
    while (route.animation!.value > 0.5) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final p = route.animation!.value;
    final container = Rect.lerp(
      cardRect,
      const Rect.fromLTWH(0, 0, 400, 800),
      p,
    )!;
    expect(container.bottom, lessThan(_bandTop));
    expectColorNear(
      await bandPixel(),
      Color.alphaBlend(Colors.black.withValues(alpha: 0.28 * p), _bandColor),
      reason: 'returning at progress $p',
    );
    while (route.animation!.value > 0.2) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 落位前容器里的玻璃卡片画面也保持原色。
    expect(await scenePixel(tester, scene, inGlassCard), glassCardColor);
    await tester.pumpAndSettle();
  });

  testWidgets('a tap captures where the card sits', (tester) async {
    final captured = <ContainerTransformOrigin?>[];
    await pumpList(tester, captured: captured);

    await tester.tap(find.text('card a'));
    // 第一帧路由 offstage（只构建、排版），帧末截卡，第二帧才上屏。
    await tester.pump();
    await tester.pump();

    final origin = captured.single!;
    expect(origin.tag, 'a');
    expect(
      origin.bounds,
      const ContainerTransformBounds(rect: cardRect, radius: 16),
    );
    final geometry = geometryOf(tester);
    expect(geometry.fallback, isFalse);
    expect(geometry.closed?.bounds, origin.bounds);
    expect(geometry.closed?.image, isNotNull);
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
    // 第二帧：页面第一次绘制且下层拍快照；第三帧：空等光栅追上。哪怕这几帧
    // 很慢，进度也停在卡片上。
    await tester.pump(const Duration(milliseconds: 200));
    expect(route.animation!.value, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(route.animation!.value, 0);
    // 三帧画完后的这一帧才开始计时，仍从 0 出发——不会因前几帧耗时跳一截。
    await tester.pump(const Duration(milliseconds: 200));
    expect(route.animation!.value, 0);

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final midway = route.animation!.value;
    expect(midway, greaterThan(0.2));
    expect(midway, lessThan(1));

    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
    expect(route.animation!.status, AnimationStatus.completed);
    // 停稳后不再留着下层的整屏快照。
    expect(belowOf(tester).debugImage, isNull);
  });

  testWidgets('a stalled first step starts late instead of jumping', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('card a'));
    await pumpOpeningHold(tester);
    // 起步帧，进度仍在 0。
    await tester.pump();
    final route = routeOf(tester);
    expect(route.animation!.value, 0);
    // 下一帧被积压的光栅工作拖了 40ms：从这一帧重新起算，不跳一截。
    await tester.pump(const Duration(milliseconds: 40));
    expect(route.animation!.value, 0);
    // 之后照常按真实时间走：一帧只走一帧的量。
    await tester.pump(const Duration(milliseconds: 8));
    final oneFrame = route.animation!.value;
    expect(oneFrame, inExclusiveRange(0, 0.05));
    // 只纠正一次：中途再卡也按真实时间追上，不会一直拖长。
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, greaterThan(0.3));
    await tester.pumpAndSettle();
  });

  testWidgets('the page grows into the screen corners', (tester) async {
    DisplayCorners.debugRadii = BorderRadius.circular(40);
    addTearDown(DisplayCorners.debugReset);
    await pumpList(tester);

    await tester.tap(find.text('card a'));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<ContainerTransformTransition>(
            find.byType(ContainerTransformTransition),
          )
          .pageRadius,
      BorderRadius.circular(40),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('expanding and returning each take their container duration', (
    tester,
  ) async {
    const frame = Duration(milliseconds: 16);
    await pumpList(tester);

    await tester.tap(find.text('card a'));
    // 固定等待之后的这一帧闸门打开、从 0 开始计时。
    await pumpOpeningHold(tester);
    await tester.pump();
    final route = routeOf(tester);
    expect(route.animation!.value, 0);
    await tester.pump(frame);
    await tester.pump(ExpressiveMotion.containerOpen - frame * 2);
    // 弹簧在最后一帧仍差一点点才落稳，时长走完的那一帧才停。
    expect(route.animation!.value, lessThan(1));
    expect(route.animation!.status, AnimationStatus.forward);
    await tester.pump(frame);
    expect(route.animation!.value, 1);
    expect(route.animation!.status, AnimationStatus.completed);

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    // 固定等待期间停在整页上，之后的这一帧闸门打开、从 1 开始计时。
    await pumpClosingHold(tester);
    expect(route.animation!.value, 1);
    await tester.pump();
    expect(route.animation!.value, 1);
    await tester.pump(frame);
    await tester.pump(ExpressiveMotion.containerClose - frame * 2);
    expect(route.animation!.value, greaterThan(0));
    expect(route.animation!.status, AnimationStatus.reverse);
    await tester.pump(frame);
    expect(route.animation!.status, AnimationStatus.dismissed);
    await tester.pumpAndSettle();
  });

  testWidgets('the page below is a snapshot only while the container moves', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.byType(ContainerTransformBelowSnapshot), findsNothing);

    await tester.tap(find.text('card a'));
    // 第一帧（新路由 offstage）下层仍实时绘制（截卡后再藏起原卡片），第二帧
    // 才拍成不含原卡片的快照。
    await tester.pump();
    expect(belowOf(tester).debugImage, isNull);
    await tester.pump();
    final first = belowOf(tester).debugImage;
    expect(first, isNotNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect(belowOf(tester).debugImage, same(first));
    // 停稳当帧恢复实时绘制、释放快照。
    await tester.pumpAndSettle();
    expect(belowOf(tester).debugImage, isNull);

    // 返回：首帧下层实时绘制以截归位卡片，第二帧拍不含该卡片的快照。
    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    await tester.pump();
    expect(belowOf(tester).debugImage, isNull);
    await tester.pump();
    expect(belowOf(tester).debugImage, isNotNull);
    await tester.pumpAndSettle();
    // 归位后下层不再包快照。
    expect(find.byType(ContainerTransformBelowSnapshot), findsNothing);
  });

  testWidgets(
    'returning to another card mid-way restores the old card and hides the new one',
    (tester) async {
      final scene = GlobalKey();
      const listBg = Color(0xFFECEFF1);
      const cardAColor = Color(0xFF009688);
      const cardBColor = Color(0xFFFFB300);
      await pumpList(
        tester,
        sceneKey: scene,
        cardATop: 140,
        cardBTop: 460,
        cardAColor: cardAColor,
        cardBColor: cardBColor,
        listBackgroundColor: listBg,
      );
      await tester.tap(find.text('card a'));
      // 固定等待、起步，再走 100ms：进度已离开 0。
      await pumpOpeningHold(tester);
      await pumpStart(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final snapshot = belowOf(tester).debugImage;
      expect(snapshot, isNotNull);

      // 展开途中翻到 b 再返回：旧快照里藏着 a、留着 b，必须恢复 a 并改藏 b
      // 后重拍快照。
      final route = routeOf(tester);
      final before = route.animation!.value;
      final context = tester.element(find.byType(_DetailPage));
      ContainerTransformPageRoute.setReturnTag(context, 'b');
      Navigator.of(context).pop();
      await pumpClosingHold(tester);
      expect(geometryOf(tester).closed!.rect, cardRect.translate(0, 260));
      expect(belowOf(tester).debugImage, isNotNull);
      expect(belowOf(tester).debugImage, isNot(same(snapshot)));
      await pumpStart(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect(route.animation!.value, lessThan(before));
      await tester.pumpAndSettle();
      expect(find.byType(_DetailPage), findsNothing);
      expect(
        await scenePixel(tester, scene, const Offset(200, 160)),
        cardAColor,
      );
      expect(
        await scenePixel(tester, scene, const Offset(200, 560)),
        cardBColor,
      );
    },
  );

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
    // 首帧实时重排绘制并截卡、第二帧拍下层快照、第三帧空等光栅追上，三帧
    // 都停在整页上。
    await tester.pump();
    expect(route.animation!.value, 1);
    await tester.pump();
    expect(route.animation!.value, 1);
    await tester.pump();
    expect(route.animation!.value, 1);
    final geometry = geometryOf(tester);
    expect(geometry.fallback, isFalse);
    expect(geometry.closed!.rect, cardRect);
    await pumpStart(tester);
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
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
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
    await pumpOpeningHold(tester);
    await pumpStart(tester);
    await tester.pump(const Duration(milliseconds: 120));
    final route = routeOf(tester);
    final before = route.animation!.value;
    final opening = geometryOf(tester).closed;
    final snapshot = belowOf(tester).debugImage;
    expect(before, inExclusiveRange(0, 1));
    expect(snapshot, isNotNull);

    Navigator.of(tester.element(find.byType(_DetailPage))).pop();
    // 返回后的第一帧从当前进度出发，不跳变；复用同一张卡片截图与下层快照。
    await tester.pump(const Duration(milliseconds: 16));
    expect(route.animation!.value, closeTo(before, 0.001));
    expect(geometryOf(tester).closed, same(opening));
    expect(belowOf(tester).debugImage, same(snapshot));
    await tester.pumpAndSettle();
    expect(find.byType(_DetailPage), findsNothing);
  });

  testWidgets('glass samples stay intact when fading out in place', (
    tester,
  ) async {
    final scene = GlobalKey();
    final link = LayerLink();
    await pumpList(
      tester,
      sceneKey: scene,
      backdropLink: link,
      returnsToOrigin: (Object? result) => result != 'deleted',
    );
    Future<Color> bandPixel() =>
        scenePixel(tester, scene, const Offset(200, _bandTop + 50));

    await tester.tap(find.text('card a'));
    await tester.pumpAndSettle();

    // 不回卡片的原地退场：返回首帧下层刚从 offstage 回来就拍快照（挂根图层
    // 路径），玻璃取样仍须留在快照里。
    Navigator.of(tester.element(find.byType(_DetailPage))).pop('deleted');
    await tester.pump();
    final snapshot = belowOf(tester).debugImage;
    expect(snapshot, isNotNull);
    final sampled = await tester.runAsync(
      () async => (await pixelReader(snapshot!))(200, (_bandTop + 50).round()),
    );
    expect(sampled, _bandColor);
    await tester.pumpAndSettle();
    expect(await bandPixel(), _bandColor);
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

const double _bandTop = 600;
const Color _bandColor = Color(0xFF7B1FA2);

/// 列表页的“页面背景”：一个 Leader 铺满整页（对应页面背景层上的取样锚点）。
Widget _wrapBackdropLink(LayerLink? link, Widget child) =>
    link == null ? child : CompositedTransformTarget(link: link, child: child);

/// 一条“内容玻璃的预模糊取样”：跟随 [link] 的 Follower，Leader 不在时不画
/// （与 `GlassBackdropSampleView` 相同）。
Widget _followerBand(LayerLink link) => Positioned(
  left: 0,
  top: _bandTop,
  width: 400,
  height: 100,
  child: CompositedTransformFollower(
    link: link,
    showWhenUnlinked: false,
    offset: const Offset(0, _bandTop),
    child: const ColoredBox(color: _bandColor),
  ),
);

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
