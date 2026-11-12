import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/ui/home/widgets/home_tab_depth.dart';

/// 挂载一页带景深的内容：页序号 [index]，页码由 [position] 给出。
Future<RenderHomeTabDepth> _pumpDepth(
  WidgetTester tester, {
  required ValueNotifier<double> position,
  int index = 0,
  bool enabled = true,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: HomeTabDepth(
        index: index,
        position: position,
        enabled: enabled,
        stageColor: const Color(0xFF101010),
        scrimColor: const Color(0xFF000000),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const ColoredBox(color: Color(0xFFFAFAFA)),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderHomeTabDepth>(find.byType(HomeTabDepth));
}

/// 图层树里变换图层的个数（根视图自己有一个）。
int _transformLayers(WidgetTester tester) =>
    tester.layers.whereType<TransformLayer>().length;

bool _hasClip(WidgetTester tester) =>
    tester.layers.any((Layer layer) => layer is ClipRRectLayer);

void main() {
  group('HomeTabDepthSpec', () {
    test('is the identity at the centre', () {
      final spec = HomeTabDepthSpec.at(0);
      expect(spec.scale, 1);
      expect(spec.radius, 0);
      expect(spec.dim, 0);
    });

    test('recedes monotonically with distance', () {
      var previous = HomeTabDepthSpec.at(0);
      for (var step = 1; step <= 20; step++) {
        final spec = HomeTabDepthSpec.at(step / 20);
        expect(spec.scale, lessThan(previous.scale));
        expect(spec.dim, greaterThan(previous.dim));
        expect(spec.radius, greaterThanOrEqualTo(previous.radius));
        previous = spec;
      }
      expect(previous.scale, 1 - HomeTabDepthSpec.maxScaleDrop);
      expect(previous.dim, HomeTabDepthSpec.maxDim);
    });

    test('is a card with full corners half way through a switch', () {
      final spec = HomeTabDepthSpec.at(0.5);
      expect(spec.scale, closeTo(0.96, 1e-9));
      expect(spec.radius, AppRadii.nav);
      // 距离只看绝对值，越过一整页按一整页算。
      expect(HomeTabDepthSpec.at(-0.5).scale, spec.scale);
      expect(HomeTabDepthSpec.at(3).scale, HomeTabDepthSpec.at(1).scale);
    });

    test('starts gently under the finger', () {
      // smoothstep 起点斜率为 0：拖出 5% 时缩小不到千分之二。
      expect(HomeTabDepthSpec.at(0.05).scale, greaterThan(0.998));
    });
  });

  group('HomeTabDepth', () {
    testWidgets('paints the page as is when it is centred', (tester) async {
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      final render = await _pumpDepth(tester, position: position);
      expect(render.debugSpec, same(HomeTabDepthSpec.identity));
      expect(_hasClip(tester), isFalse);
      // 只有根视图的那一个变换图层。
      expect(_transformLayers(tester), 1);
    });

    testWidgets('shrinks into a rounded card while the page moves', (
      tester,
    ) async {
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      final render = await _pumpDepth(tester, position: position);

      position.value = 0.5;
      await tester.pump();
      expect(render.debugSpec.scale, closeTo(0.96, 1e-9));
      expect(_hasClip(tester), isTrue);
      expect(_transformLayers(tester), 2);

      // 回到正中：不再留下任何图层。
      position.value = 0;
      await tester.pump();
      expect(render.debugSpec, same(HomeTabDepthSpec.identity));
      expect(_hasClip(tester), isFalse);
      expect(_transformLayers(tester), 1);
    });

    testWidgets('measures the distance from its own index', (tester) async {
      final position = ValueNotifier<double>(0.25);
      addTearDown(position.dispose);
      final render = await _pumpDepth(tester, position: position, index: 1);
      expect(render.debugSpec.scale, HomeTabDepthSpec.at(0.75).scale);
    });

    testWidgets('stays flat when disabled', (tester) async {
      final position = ValueNotifier<double>(0.5);
      addTearDown(position.dispose);
      final render = await _pumpDepth(
        tester,
        position: position,
        enabled: false,
      );
      expect(render.debugSpec, same(HomeTabDepthSpec.identity));
      expect(_hasClip(tester), isFalse);
    });

    testWidgets('hit tests through the scaled card', (tester) async {
      final position = ValueNotifier<double>(0.5);
      addTearDown(position.dispose);
      var taps = 0;
      await _pumpDepth(tester, position: position, onTap: () => taps++);
      final size = tester.getSize(find.byType(HomeTabDepth));
      // 卡片缩到 0.96：左上角最边上的一点在卡片之外，正中仍在卡片里。
      await tester.tapAt(const Offset(1, 1));
      expect(taps, 0);
      await tester.tapAt(size.center(Offset.zero));
      expect(taps, 1);
    });
  });
}
