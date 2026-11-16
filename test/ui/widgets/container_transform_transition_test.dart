import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_below_snapshot.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_source.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_transition.dart';

import '../app_surface/app_surface_test_images.dart';

/// 截取真实合成结果：容器在任何进度下都不透明，后面的列表从不透出；里面
/// 起点 / 终点是从下层快照裁出的卡片（这里是整屏 teal 快照），中段与页面
/// （带它所在区域的背景）互相渐变；容器之外只有下层列表与遮罩。
const _size = Size(400, 800);
const _card = Rect.fromLTWH(16, 200, 368, 120);
const _backdropKey = ValueKey<String>('backdrop');
const _teal = Color(0xFF009688);

void _expectColorNear(Color actual, Color expected, {required String reason}) {
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

class _Harness {
  _Harness(this.progress, this.boundary, this.scheme);

  final AnimationController progress;
  final GlobalKey boundary;
  final ColorScheme scheme;

  Rect container(WidgetTester tester) => tester
      .renderObject<RenderContainerTransform>(
        find.byType(ContainerTransformTransition),
      )
      .debugContainerRect;

  /// 容器底边内侧一点：页面文字在顶部，这里只有页面背景（或卡片）。
  Future<Color> insideColor(WidgetTester tester) {
    final rect = container(tester);
    return colorAt(
      tester,
      Offset(rect.center.dx, (rect.bottom - 3).floorToDouble()),
    );
  }

  /// 容器顶边内侧一点：卡片画在容器顶部。
  Future<Color> topInsideColor(WidgetTester tester) {
    final rect = container(tester);
    return colorAt(tester, Offset(rect.right - 20, rect.top + 10));
  }

  /// 容器底边外侧一点：只剩下层列表。
  Future<void> expectListBelowContainer(WidgetTester tester) {
    final rect = container(tester);
    return expectListAt(
      tester,
      Offset(rect.center.dx, (rect.bottom + 6).ceilToDouble()),
      reason: '容器之外只有列表',
    );
  }

  /// [point] 处没有容器，只有下层列表（errorContainer）与随进度加深的遮罩。
  Future<void> expectListAt(
    WidgetTester tester,
    Offset point, {
    required String reason,
  }) async {
    final actual = (await colorAt(tester, point)).toARGB32();
    // 列表只剩随进度消退的 28% 遮罩；给合成取整留 1 个色阶的余量。
    final expected = Color.alphaBlend(
      scheme.scrim.withValues(alpha: 0.28 * progress.value),
      scheme.errorContainer,
    ).toARGB32();
    for (final shift in <int>[0, 8, 16, 24]) {
      expect(
        (actual >> shift) & 0xff,
        closeTo((expected >> shift) & 0xff, 1),
        reason: '$reason：progress ${progress.value}',
      );
    }
  }

  Future<Color> colorAt(WidgetTester tester, Offset point) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await render.toImage();
      try {
        return (await pixelReader(image))(point.dx.round(), point.dy.round());
      } finally {
        image.dispose();
      }
    }))!;
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required AppBackground background,
  Brightness brightness = Brightness.light,
  FakeBackgroundLoader? loader,
  Widget? backdrop,
  Widget? page,
  BorderRadius pageRadius = BorderRadius.zero,
  bool fallback = false,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: brightness,
  );
  final geometry = ContainerTransformGeometry(
    fallback ? null : const ContainerTransformBounds(rect: _card, radius: 16),
  );
  addTearDown(geometry.dispose);
  // 下层快照：整屏 teal，裁出来的卡片也是 teal。
  final snapshot = (await tester.runAsync(
    () => paintedImage(_size.width.round(), _size.height.round(), _teal),
  ))!;
  addTearDown(snapshot.dispose);
  final below = ContainerTransformBelowSnapshotController()
    ..debugSetSnapshot(snapshot, Offset.zero & _size);
  addTearDown(below.dispose);
  final progress = AnimationController(vsync: tester, value: 0.15);
  addTearDown(progress.dispose);
  final cache = AppBackgroundImageCache(loader: loader?.call);
  addTearDown(cache.dispose);
  if (background.kind == AppBackgroundKind.image) {
    await tester.runAsync(() async {
      (await cache.load(
        AppBackgroundImageKey.forDisplay(
          fileName: background.image!,
          blur: background.blur,
          logicalSize: _size,
          devicePixelRatio: 1,
        ),
      ))?.dispose();
    });
  }
  final boundary = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAreaBackgroundProvider(
          AppBackgroundArea.preview,
        ).overrideWithValue(background),
        appBackgroundImageCacheProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: scheme.errorContainer,
            child: ContainerTransformTransition(
              animation: progress,
              geometry: geometry,
              scrimColor: scheme.scrim,
              pageRadius: pageRadius,
              belowSnapshot: below,
              backdrop:
                  backdrop ??
                  const AppPageBackgroundFill(
                    key: _backdropKey,
                    area: AppBackgroundArea.preview,
                  ),
              child: RepaintBoundary(
                // 与正式页面一样带背景和 Scaffold，不能拿空页面代替，否则
                // 会漏掉页面本身留下的白色底。
                child:
                    page ??
                    AppPageBackground(
                      area: AppBackgroundArea.preview,
                      child: Builder(
                        builder: (context) => Scaffold(
                          backgroundColor: AppPageBackdrop.pageColorOf(context),
                          body: const Text('Diary content'),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return _Harness(progress, boundary, scheme);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final kind in AppBackgroundKind.values) {
      testWidgets('$brightness $kind keeps the container opaque all the way', (
        tester,
      ) async {
        const light = Color(0xFF7B5F92);
        const dark = Color(0xFF382742);
        const imageColor = Color(0xFF3060C0);
        final h = await _pump(
          tester,
          brightness: brightness,
          background: AppBackground(
            kind: kind,
            colorLight: light.toARGB32(),
            colorDark: dark.toARGB32(),
            image: 'bg.png',
            scrimLight: 0,
            scrimDark: 0,
          ),
          loader: FakeBackgroundLoader(color: imageColor),
        );
        final expected = switch (kind) {
          AppBackgroundKind.none => h.scheme.surface,
          AppBackgroundKind.color =>
            brightness == Brightness.light ? light : dark,
          AppBackgroundKind.image => imageColor,
        };
        expect(tester.getSize(find.byKey(_backdropKey)), _size);
        // 页面段：容器里是页面与它的背景，不透出列表。
        for (final p in <double>[0.95, 0.75, 0.6]) {
          h.progress.value = p;
          await tester.pump();
          expect(await h.insideColor(tester), expected, reason: 'progress $p');
          await h.expectListBelowContainer(tester);
        }
        // 渐变段：卡片半透明地叠在不透明的页面上，列表仍不透出。
        h.progress.value = 0.425;
        await tester.pump();
        _expectColorNear(
          await h.topInsideColor(tester),
          Color.alphaBlend(_teal.withValues(alpha: 0.5), expected),
          reason: 'progress 0.425',
        );
        await h.expectListBelowContainer(tester);
        // 卡片段（含落位）：容器正好是缩放后的卡片，从上到下都是卡片，
        // 卡片下方不拖出一截页面。
        for (final p in <double>[0.25, 0.1, 0.005, 0]) {
          h.progress.value = p;
          await tester.pump();
          expect(await h.topInsideColor(tester), _teal, reason: 'top $p');
          expect(await h.insideColor(tester), _teal, reason: 'bottom $p');
          await h.expectListBelowContainer(tester);
        }
        expect(h.container(tester), _card);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('$brightness a missing image keeps the gap opaque', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        brightness: brightness,
        background: const AppBackground(
          kind: AppBackgroundKind.image,
          image: 'missing.png',
        ),
        loader: FakeBackgroundLoader()..missing.add('missing.png'),
      );
      h.progress.value = 0.75;
      await tester.pumpAndSettle();
      expect(await h.insideColor(tester), h.scheme.surface);
      h.progress.value = 0.02;
      await tester.pump();
      expect(await h.insideColor(tester), _teal);
      await h.expectListBelowContainer(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('without a card to land on the page fades out in place', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      background: const AppBackground(),
      fallback: true,
    );
    // 无处可回：唯一保留的淡出。容器缩向屏幕中央，页面半透明地叠在列表上。
    h.progress.value = 0.5;
    await tester.pump();
    final mixed = (await h.colorAt(tester, const Offset(200, 600))).toARGB32();
    expect(mixed, isNot(h.scheme.surface.toARGB32()));
    expect(mixed, isNot(h.scheme.errorContainer.toARGB32()));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the expanding page grows into the screen corners', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      background: const AppBackground(),
      pageRadius: BorderRadius.circular(40),
    );
    // 将近落位：容器几乎铺满，四角已是屏幕的圆角。
    h.progress.value = 0.999;
    await tester.pump();
    await h.expectListAt(tester, const Offset(3, 796), reason: '屏幕圆角之外不画页面');
    expect(await h.colorAt(tester, const Offset(3, 400)), h.scheme.surface);

    // 刚起步：圆角仍接近卡片的 16，不会先变成直角。
    h.progress.value = 0.02;
    await tester.pump();
    final rect = Rect.lerp(_card, Offset.zero & _size, 0.02)!;
    await h.expectListAt(
      tester,
      rect.topLeft + const Offset(1, 1),
      reason: '起步时仍是卡片的圆角',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without screen corners the page lands square', (tester) async {
    final h = await _pump(tester, background: const AppBackground());
    h.progress.value = 0.999;
    await tester.pump();
    expect(await h.colorAt(tester, const Offset(3, 796)), h.scheme.surface);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a settled page paints, receives taps and exposes only its semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        const backdropColor = Color(0xFF7B1FA2);
        const pageColor = Color(0xFF3060C0);
        var backdropTaps = 0;
        var pageTaps = 0;
        final h = await _pump(
          tester,
          background: const AppBackground(),
          backdrop: Semantics(
            label: 'transition backdrop',
            child: GestureDetector(
              onTap: () => backdropTaps++,
              child: const ColoredBox(color: backdropColor),
            ),
          ),
          page: Semantics(
            label: 'diary page',
            child: GestureDetector(
              onTap: () => pageTaps++,
              child: const ColoredBox(color: pageColor),
            ),
          ),
        );
        h.progress.value = 1;
        await tester.pump();

        expect(await h.colorAt(tester, const Offset(200, 600)), pageColor);
        expect(
          tester.renderObject(find.byType(ContainerTransformTransition)),
          isNot(paints..rect(color: backdropColor)),
        );
        expect(find.bySemanticsLabel('transition backdrop'), findsNothing);
        expect(find.bySemanticsLabel('diary page'), findsOneWidget);
        await tester.tapAt(const Offset(200, 600));
        expect(pageTaps, 1);
        expect(backdropTaps, 0);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
