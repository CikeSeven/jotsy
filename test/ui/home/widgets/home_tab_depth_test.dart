import 'dart:ui' as ui;

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

/// 按快照绘制的一页：页面是 [page]，卡片自带的底是 [background]。
Future<RenderHomeTabDepth> _pumpSnapshotDepth(
  WidgetTester tester, {
  required ValueNotifier<double> position,
  int index = 0,
  bool hold = false,
  Widget? background,
  Widget page = const ColoredBox(color: Color(0xFFFAFAFA)),
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: HomeTabDepth(
        index: index,
        position: position,
        enabled: true,
        snapshot: true,
        holdSnapshot: hold,
        stageColor: const Color(0xFF101010),
        scrimColor: const Color(0xFF000000),
        background: background,
        child: page,
      ),
    ),
  );
  return tester.renderObject<RenderHomeTabDepth>(find.byType(HomeTabDepth));
}

/// 读出 [image] 在物理像素 ([x], [y]) 处的颜色。
Future<Color> _pixel(WidgetTester tester, ui.Image image, int x, int y) async {
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  ))!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
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

    testWidgets('moving from a snapshot builds no layers at all', (
      tester,
    ) async {
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      final render = await _pumpSnapshotDepth(tester, position: position);
      expect(render.debugHasSnapshot, isFalse);

      position.value = 0.5;
      await tester.pump();
      // 一张位图一笔画完：没有变换、裁切图层，页面自己的图层也不在树上。
      expect(render.debugHasSnapshot, isTrue);
      expect(render.debugSpec.scale, closeTo(0.96, 1e-9));
      expect(_hasClip(tester), isFalse);
      expect(_transformLayers(tester), 1);
      expect(tester.layers.whereType<OffsetLayer>().length, 1);

      // 继续移动只重画同一张快照。
      position.value = 0.3;
      await tester.pump();
      expect(render.debugHasSnapshot, isTrue);

      // 回到正中、没有保持：释放快照，直接画页面。
      position.value = 0;
      await tester.pump();
      expect(render.debugHasSnapshot, isFalse);
      expect(_hasClip(tester), isFalse);
      expect(_transformLayers(tester), 1);
    });

    testWidgets('holds the snapshot at rest until released', (tester) async {
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      final render = await _pumpSnapshotDepth(
        tester,
        position: position,
        hold: true,
      );
      // 从没移动过：保持也没有快照可画，照常实时绘制。
      expect(render.debugHasSnapshot, isFalse);

      position.value = 0.5;
      await tester.pump();
      position.value = 0;
      await tester.pump();
      // 落位后仍画快照（与实时绘制逐像素一致），不建任何图层。
      expect(render.debugHasSnapshot, isTrue);
      expect(render.debugSpec, same(HomeTabDepthSpec.identity));
      expect(_transformLayers(tester), 1);

      await _pumpSnapshotDepth(tester, position: position);
      expect(render.debugHasSnapshot, isFalse);
    });

    testWidgets('releases the snapshot once the page is a full page away', (
      tester,
    ) async {
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      final render = await _pumpSnapshotDepth(
        tester,
        position: position,
        hold: true,
      );
      position.value = 0.5;
      await tester.pump();
      expect(render.debugHasSnapshot, isTrue);
      // 整页移出视口：快照不会再用到，即使在保持期间也立即释放；也不会
      // 在视口之外重新拍一张。
      position.value = 1;
      expect(render.debugHasSnapshot, isFalse);
      await tester.pump();
      expect(render.debugHasSnapshot, isFalse);
      expect(_transformLayers(tester), 1);
    });

    testWidgets('the snapshot carries the card background under the page', (
      tester,
    ) async {
      final position = ValueNotifier<double>(0);
      addTearDown(position.dispose);
      const background = Color(0xFFE53935);
      const content = Color(0xFF1E88E5);
      final render = await _pumpSnapshotDepth(
        tester,
        position: position,
        background: const ColoredBox(color: background),
        // 页面本身透明，只在右下角画一块内容。
        page: const Align(
          alignment: Alignment.bottomRight,
          child: SizedBox.square(
            dimension: 40,
            child: ColoredBox(color: content),
          ),
        ),
      );
      position.value = 0.5;
      await tester.pump();
      final image = render.debugSnapshot!;
      // 快照按物理像素：左上角是卡片自带的底，右下角是页面的内容。
      expect(await _pixel(tester, image, 1, 1), background);
      expect(
        await _pixel(tester, image, image.width - 2, image.height - 2),
        content,
      );
    });

    testWidgets(
      'content glass in the snapshot lines up with the rest position',
      (tester) async {
        final position = ValueNotifier<double>(0.5);
        addTearDown(position.dispose);
        final link = LayerLink();
        const marker = Color(0xFF43A047);
        const width = 400.0;
        tester.view.physicalSize = const Size(width, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // 第 1 页、页码 0.5：PageView 会把它摆在右移半页处。页面里有一块跟随
        // 背景层 Leader 的取样（与内容玻璃同一机制），静止时它在页面左上角。
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CompositedTransformTarget(
                    link: link,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: width / 2,
                  top: 0,
                  width: width,
                  height: 300,
                  child: HomeTabDepth(
                    index: 1,
                    position: position,
                    enabled: true,
                    snapshot: true,
                    stageColor: null,
                    scrimColor: const Color(0x00000000),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: CompositedTransformFollower(
                        link: link,
                        showWhenUnlinked: false,
                        child: const SizedBox.square(
                          dimension: 20,
                          child: ColoredBox(color: marker),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final render = tester.renderObject<RenderHomeTabDepth>(
          find.byType(HomeTabDepth),
        );
        final image = render.debugSnapshot!;
        // 按落在正中的位置拍：取样在快照的左上角；若按此刻右移半页的位置
        // 拍，它会落在快照左边之外。
        expect(await _pixel(tester, image, 5, 5), marker);
        expect(await _pixel(tester, image, 205, 5), const Color(0x00000000));
      },
    );

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

    testWidgets('hit tests through a card painted from a snapshot', (
      tester,
    ) async {
      final position = ValueNotifier<double>(0.5);
      addTearDown(position.dispose);
      var taps = 0;
      await _pumpSnapshotDepth(
        tester,
        position: position,
        page: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const ColoredBox(color: Color(0xFFFAFAFA)),
        ),
      );
      final size = tester.getSize(find.byType(HomeTabDepth));
      await tester.tapAt(const Offset(1, 1));
      expect(taps, 0);
      await tester.tapAt(size.center(Offset.zero));
      expect(taps, 1);
    });
  });
}
