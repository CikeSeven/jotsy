import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_anchor.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_landing.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_live_target.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_page_route.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_transition.dart';

/// 整页收放路由：从小控件展开，返回时按结果落进不同的落点。
void main() {
  const fabRect = Rect.fromLTWH(300, 760, 80, 56);
  const badgeRect = Rect.fromLTWH(360, 40, 16, 16);
  const cardRect = Rect.fromLTWH(16, 200, 368, 120);

  late MorphLandingResolver<Object?> resolver;
  late ModalRoute<Object?> homeRoute;

  setUp(() => resolver = (_) => const <MorphLanding>[]);

  Widget positioned(Rect rect, Widget child) =>
      Positioned.fromRect(rect: rect, child: child);

  Future<void> pumpHome(WidgetTester tester, {bool withCard = true}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            homeRoute = ModalRoute.of(context)!;
            return Scaffold(
              body: Stack(
                children: <Widget>[
                  positioned(
                    badgeRect,
                    const MorphAnchor(
                      tag: 'badge',
                      borderRadius: 8,
                      color: Colors.indigo,
                      appearance: Center(child: Text('1')),
                      child: ColoredBox(
                        key: ValueKey<String>('badge'),
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  if (withCard)
                    positioned(
                      cardRect,
                      const MorphLiveTarget(
                        tag: 'card',
                        borderRadius: 20,
                        child: ColoredBox(color: Colors.amber),
                      ),
                    ),
                  positioned(
                    fabRect,
                    MorphAnchor(
                      tag: 'fab',
                      borderRadius: 20,
                      color: Colors.teal,
                      appearance: const Icon(Icons.add),
                      child: Builder(
                        builder: (context) => GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MorphPageRoute<Object?>(
                              origin: MorphAnchor.capture(context, 'fab'),
                              originRoute: ModalRoute.of(context)!,
                              landing: (result) => resolver(result),
                              builder: (_) => const Scaffold(
                                body: Center(child: Text('editor')),
                              ),
                            ),
                          ),
                          child: const ColoredBox(
                            key: ValueKey<String>('fab'),
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  RenderMorphTransition morph(WidgetTester tester) =>
      tester.renderObject<RenderMorphTransition>(
        find.byType(MorphTransition, skipOffstage: false),
      );

  void expectRect(Rect actual, Rect expected) {
    expect(actual.left, moreOrLessEquals(expected.left, epsilon: 0.5));
    expect(actual.top, moreOrLessEquals(expected.top, epsilon: 0.5));
    expect(actual.width, moreOrLessEquals(expected.width, epsilon: 0.5));
    expect(actual.height, moreOrLessEquals(expected.height, epsilon: 0.5));
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('fab')));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
  }

  /// 返回，并停在第一次量出落点之后（停稳后返回要等两帧）。
  Future<MorphLandingSession> popUntilLanding(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    final session = MorphLandingSession.current.value!;
    expect(session.phase.value, MorphLandingPhase.holding);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(session.phase.value, MorphLandingPhase.landing);
    return session;
  }

  testWidgets('the page grows out of the tapped button', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey<String>('fab')));
    await tester.pump();
    await tester.pump();
    // 起步前停在按钮上：容器就是按钮的位置与底色。
    expectRect(morph(tester).debugFrame.rect, fabRect);
    expect(morph(tester).debugFrame.appearanceAlpha, 1);
    expect(morph(tester).debugFrame.groupAlpha, 0);

    // 起步后按 60Hz 推进（一次跳太久，闸门模拟会把那一帧当作起步帧重新起算）。
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final mid = morph(tester).debugFrame.rect;
    expect(mid.width, greaterThan(fabRect.width));
    expect(mid.width, lessThan(400));

    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
    expectRect(
      morph(tester).debugFrame.rect,
      const Rect.fromLTWH(0, 0, 400, 900),
    );
  });

  testWidgets('with nothing to keep the page shrinks back into the button', (
    tester,
  ) async {
    await pumpHome(tester);
    await open(tester);

    final session = await popUntilLanding(tester);
    expect(session.targets('fab'), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    final mid = morph(tester).debugFrame.rect;
    expect(mid.width, lessThan(400));
    expect(mid.width, greaterThan(fabRect.width));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(session.phase.value, MorphLandingPhase.landed);
    expect(find.text('editor'), findsNothing);
    expect(MorphLandingSession.current.value, isNull);
    // 落定后按钮接住余速，先被压小一点再弹回。
    await tester.pump(const Duration(milliseconds: 30));
    final scale = tester.widget<ScaleTransition>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('fab')),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scale.scale.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(scale.scale.value, 1);
  });

  testWidgets('the first visible candidate wins', (tester) async {
    resolver = (_) => const <MorphLanding>[
      MorphAnchorLanding('missing'),
      MorphAnchorLanding('badge'),
      MorphAnchorLanding('fab'),
    ];
    await pumpHome(tester);
    await open(tester);

    final session = await popUntilLanding(tester);
    expect(session.involves('missing'), isTrue);
    expect(session.targets('badge'), isTrue);
    // 收到末段：容器收成角标，外观淡入、页面淡出。
    await tester.pump(const Duration(milliseconds: 370));
    final frame = morph(tester).debugFrame;
    expect(frame.rect.width, lessThan(40));
    expect(frame.appearanceAlpha, greaterThan(0));
    expect(frame.groupAlpha, lessThan(1));
    await tester.pumpAndSettle();
    expect(session.phase.value, MorphLandingPhase.landed);
  });

  testWidgets('landing on a live card shapes the container like the card', (
    tester,
  ) async {
    resolver = (_) => const <MorphLanding>[MorphLiveLanding('card')];
    await pumpHome(tester);
    await open(tester);

    final session = await popUntilLanding(tester);
    expect(session.targets('card'), isTrue);
    // 卡片拍成了图交给容器：落下途中卡片自己不画。
    expect(session.takesOverTarget, isTrue);
    await tester.pump(const Duration(milliseconds: 360));
    final frame = morph(tester).debugFrame;
    // 末段：容器按宽度缩放、形状就是卡片；页面始终不透明，卡片图盖在上面。
    expect(frame.rect.width, closeTo(cardRect.width, 24));
    expect(
      frame.rect.height / frame.rect.width,
      closeTo(cardRect.height / cardRect.width, 0.02),
    );
    expect(frame.groupAlpha, 1);
    expect(frame.imageAlpha, greaterThan(0.7));
    expect(frame.appearanceAlpha, 0);
    await tester.pumpAndSettle();
    expect(session.phase.value, MorphLandingPhase.landed);
  });

  testWidgets('a live card that never shows up falls back to a fade', (
    tester,
  ) async {
    resolver = (_) => const <MorphLanding>[MorphLiveLanding('card')];
    await pumpHome(tester, withCard: false);
    await open(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    final session = MorphLandingSession.current.value!;
    // 整页先停着等卡片排进列表（最多十几帧），等不到才原地退场。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(session.phase.value, MorphLandingPhase.landing);
    expect(session.target, isNull);
    await tester.pumpAndSettle();
    expect(session.phase.value, MorphLandingPhase.cancelled);
    expect(find.text('editor'), findsNothing);
  });

  testWidgets('a page pushed by the theme pops by the theme without targets', (
    tester,
  ) async {
    await pumpHome(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MorphPageRoute<Object?>(
        originRoute: homeRoute,
        landing: (result) => result is String
            ? <MorphLanding>[MorphLiveLanding(result)]
            : const <MorphLanding>[],
        builder: (_) => const Scaffold(body: Center(child: Text('publish'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('publish'), findsOneWidget);

    navigator.pop();
    await tester.pump();
    expect(MorphLandingSession.current.value, isNull);
    await tester.pump(const Duration(milliseconds: 50));
    // 按主题转场退场：容器不接手（原样绘制）。
    final transition = tester.widget<MorphTransition>(
      find.byType(MorphTransition),
    );
    expect(transition.active, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('publish'), findsNothing);
  });

  testWidgets('a page pushed by the theme lands on the card it returns', (
    tester,
  ) async {
    await pumpHome(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MorphPageRoute<Object?>(
        originRoute: homeRoute,
        landing: (result) => result is String
            ? <MorphLanding>[MorphLiveLanding(result)]
            : const <MorphLanding>[],
        builder: (_) => const Scaffold(body: Center(child: Text('publish'))),
      ),
    );
    await tester.pumpAndSettle();

    navigator.pop('card');
    await tester.pump();
    final session = MorphLandingSession.current.value!;
    expect(
      tester.widget<MorphTransition>(find.byType(MorphTransition)).active,
      isTrue,
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(session.targets('card'), isTrue);
    await tester.pumpAndSettle();
    expect(session.phase.value, MorphLandingPhase.landed);
    expect(find.text('publish'), findsNothing);
  });

  testWidgets('reduced motion opens without a morph', (tester) async {
    await pumpHome(tester);
    late MorphTarget? captured;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              captured = MorphAnchor.capture(context, 'fab');
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(captured, isNull);
  });
}
