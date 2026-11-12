import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_source.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_transition.dart';

import '../app_surface/app_surface_test_images.dart';

/// 截取真实合成结果：页面显出时使用正确的区域背景；收回末段页面已经
/// 淡去时，卡片下方必须露出列表，不能留下比卡片高一截的不透明页面底。
const _size = Size(400, 800);
const _card = Rect.fromLTWH(16, 200, 368, 120);
const _backdropKey = ValueKey<String>('backdrop');

class _Harness {
  _Harness(this.progress, this.boundary, this.scheme);

  final AnimationController progress;
  final GlobalKey boundary;
  final ColorScheme scheme;

  /// 取卡片截图底边与容器底边之间的像素：截图只按宽度缩放，这一段正是
  /// 旧版纯色底会露出来的位置，不能只检查某个背景 widget 是否已挂载。
  Future<Color> exposedColor(WidgetTester tester) async {
    final rect = Rect.lerp(_card, Offset.zero & _size, progress.value)!;
    final cardBottom = rect.top + _card.height * rect.width / _card.width;
    final y = ((cardBottom + rect.bottom) / 2).round();
    return colorAt(tester, Offset(rect.center.dx, y.toDouble()));
  }

  Future<void> expectListBelowCard(WidgetTester tester) async {
    final actual = (await exposedColor(tester)).toARGB32();
    // 列表只剩随进度消退的 28% 遮罩；给合成取整留 1 个色阶的余量。
    final expected = Color.alphaBlend(
      scheme.scrim.withValues(alpha: 0.28 * progress.value),
      scheme.errorContainer,
    ).toARGB32();
    for (final shift in <int>[0, 8, 16, 24]) {
      expect(
        (actual >> shift) & 0xff,
        closeTo((expected >> shift) & 0xff, 1),
        reason: '页面已淡去，卡片下方不应留底：progress ${progress.value}',
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
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: brightness,
  );
  final image = (await tester.runAsync(
    () => paintedImage(368, 120, Colors.teal),
  ))!;
  final geometry = ContainerTransformGeometry(
    ContainerTransformShot(
      rect: _card,
      radius: 16,
      image: image,
      imageRect: _card,
    ),
  );
  addTearDown(geometry.dispose);
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
      testWidgets(
        '$brightness $kind clears the page below the returning card',
        (tester) async {
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
          for (final p in <double>[0.75, 0.95, 0.75]) {
            h.progress.value = p;
            await tester.pump();
            expect(
              await h.exposedColor(tester),
              expected,
              reason: 'progress $p',
            );
          }
          for (final p in <double>[0.04, 0.02, 0.005]) {
            h.progress.value = p;
            await tester.pump();
            await h.expectListBelowCard(tester);
          }
          h.progress.value = 0;
          await tester.pump();
          expect(
            (await h.colorAt(tester, _card.center)).toARGB32(),
            Colors.teal.toARGB32(),
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
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
      expect(await h.exposedColor(tester), h.scheme.surface);
      h.progress.value = 0.02;
      await tester.pump();
      await h.expectListBelowCard(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
