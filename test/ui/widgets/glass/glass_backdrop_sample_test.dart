import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/glass/glass_backdrop_sample.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

void main() {
  late ui.Image image;
  late GlassBackdropLink link;

  setUp(() {
    GlassBackdropBlurCache.debugClear();
    link = GlassBackdropLink();
  });
  tearDown(GlassBackdropBlurCache.debugClear);
  tearDown(() => link.dispose());

  Future<void> loadImage(WidgetTester tester) async {
    image = (await tester.runAsync(
      () => createTestImage(width: 40, height: 80),
    ))!;
    addTearDown(image.dispose);
  }

  GlassBackdropSample sampleOf({Color? scrim}) => GlassBackdropSample(
    link: link,
    image: image,
    alignment: Alignment.center,
    underColor: const Color(0xFFFFFFFF),
    scrim: scrim,
  );

  Widget host({required Widget glass}) => MaterialApp(
    home: Stack(
      children: <Widget>[
        Positioned.fill(
          child: CompositedTransformTarget(
            link: link,
            child: const ColoredBox(color: Colors.white),
          ),
        ),
        Center(child: SizedBox(width: 200, height: 120, child: glass)),
      ],
    ),
  );

  BackdropFilter backdropFilter(WidgetTester tester) =>
      tester.widget<BackdropFilter>(find.byType(BackdropFilter));

  testWidgets(
    'content glass with a sample paints the pre-blurred background instead '
    'of a live blur',
    (tester) async {
      await loadImage(tester);
      await tester.pumpWidget(
        host(
          glass: GlassSurface(
            fill: const Color(0x66FFFFFF),
            backdropKey: BackdropKey(),
            backdropSample: sampleOf(),
            child: const SizedBox.expand(),
          ),
        ),
      );

      expect(backdropFilter(tester).enabled, isFalse);
      expect(find.byType(GlassBackdropSampleView), findsOneWidget);
      final follower = tester.widget<CompositedTransformFollower>(
        find.byType(CompositedTransformFollower),
      );
      expect(follower.link, same(link));
      expect(follower.showWhenUnlinked, isFalse);
      expect(GlassBackdropBlurCache.debugGenerations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('without a sample the content glass keeps its live blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        glass: GlassSurface(
          fill: const Color(0x66FFFFFF),
          backdropKey: BackdropKey(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(backdropFilter(tester).enabled, isTrue);
    expect(find.byType(GlassBackdropSampleView), findsNothing);
  });

  testWidgets('the sample slot stays in place so content is not remounted', (
    tester,
  ) async {
    await loadImage(tester);
    final key = BackdropKey();
    Widget glass({GlassBackdropSample? sample}) => GlassSurface(
      fill: const Color(0x66FFFFFF),
      backdropKey: key,
      backdropSample: sample,
      child: const _Counter(),
    );

    await tester.pumpWidget(host(glass: glass()));
    tester.state<_CounterState>(find.byType(_Counter)).bump();
    await tester.pumpWidget(host(glass: glass(sample: sampleOf())));
    await tester.pumpWidget(host(glass: glass()));

    // 取样出现又消失（背景图解码完成、换成纯色），内容的状态还在。
    expect(tester.state<_CounterState>(find.byType(_Counter)).count, 1);
  });

  testWidgets('fading top bars never sample: they blur scrolling content', (
    tester,
  ) async {
    await loadImage(tester);
    await tester.pumpWidget(
      host(
        glass: GlassSurface(
          fill: const Color(0x66FFFFFF),
          fadeToBottom: true,
          backdropSample: sampleOf(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(GlassBackdropSampleView), findsNothing);
    expect(backdropFilter(tester).enabled, isTrue);
  });

  testWidgets('glass that is not content glass ignores a sample', (
    tester,
  ) async {
    await loadImage(tester);
    await tester.pumpWidget(
      host(
        glass: GlassSurface(
          fill: const Color(0x66FFFFFF),
          backdropSample: sampleOf(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(GlassBackdropSampleView), findsNothing);
    expect(backdropFilter(tester).enabled, isTrue);
  });

  testWidgets('the same background is blurred once and reused', (tester) async {
    await loadImage(tester);
    final sample = sampleOf();
    const size = Size(400, 800);
    late ui.Image? first;
    late ui.Image? again;
    late ui.Image? fromClone;
    late ui.Image? otherSigma;
    final clone = image.clone();
    addTearDown(clone.dispose);
    await tester.runAsync(() async {
      first = GlassBackdropBlurCache.resolve(
        sample: sample,
        size: size,
        sigma: 20,
        saturation: 1,
      );
      again = GlassBackdropBlurCache.resolve(
        sample: sample,
        size: size,
        sigma: 20,
        saturation: 1,
      );
      // 页面重建后拿到的是同一张图的另一个句柄，仍算同一份背景。
      fromClone = GlassBackdropBlurCache.resolve(
        sample: GlassBackdropSample(
          link: link,
          image: clone,
          alignment: Alignment.center,
          underColor: const Color(0xFFFFFFFF),
        ),
        size: size,
        sigma: 20,
        saturation: 1,
      );
      otherSigma = GlassBackdropBlurCache.resolve(
        sample: sample,
        size: size,
        sigma: 30,
        saturation: 1,
      );
    });

    expect(first, isNotNull);
    expect(again, same(first));
    expect(fromClone, same(first));
    expect(otherSigma, isNot(same(first)));
    expect(GlassBackdropBlurCache.debugGenerations, 2);
    // 模糊图按半径缩小分辨率，远小于逻辑尺寸。
    expect(first!.width, lessThan(size.width));
  });

  testWidgets('a disposed source image is skipped instead of crashing', (
    tester,
  ) async {
    final disposed = (await tester.runAsync(
      () => createTestImage(width: 4, height: 4),
    ))!;
    disposed.dispose();
    final blurred = GlassBackdropBlurCache.resolve(
      sample: GlassBackdropSample(
        link: link,
        image: disposed,
        alignment: Alignment.center,
        underColor: const Color(0xFFFFFFFF),
      ),
      size: const Size(100, 100),
      sigma: 20,
      saturation: 1,
    );
    expect(blurred, isNull);
  });

  testWidgets('moving a card keeps its sample aligned with the background', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 20, 40),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      const Rect.fromLTWH(20, 0, 20, 40),
      Paint()..color = Colors.green,
    );
    final picture = recorder.endRecording();
    image = (await tester.runAsync(() => picture.toImage(40, 40)))!;
    picture.dispose();
    addTearDown(image.dispose);
    final capture = GlobalKey();

    Widget scene(double left, {double height = 400}) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: capture,
          child: SizedBox(
            width: 400,
            height: height,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CompositedTransformTarget(
                    link: link,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
                Positioned(
                  left: left,
                  top: 150,
                  width: 60,
                  height: 60,
                  child: GlassSurface(
                    fill: Colors.transparent,
                    blurSigma: 0.1,
                    backdropKey: BackdropKey(),
                    backdropSample: sampleOf(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Future<Color> pixel(int x, int y) async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shot = (await tester.runAsync(() => boundary.toImage()))!;
      final data = (await tester.runAsync(() => shot.toByteData()))!;
      final i = (y * shot.width + x) * 4;
      final color = Color.fromARGB(
        data.getUint8(i + 3),
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      );
      shot.dispose();
      return color;
    }

    await tester.pumpWidget(scene(250));
    expect((await pixel(280, 180)).toARGB32(), Colors.green.toARGB32());
    await tester.pumpWidget(scene(100));
    expect((await pixel(130, 180)).toARGB32(), Colors.red.toARGB32());
    expect(GlassBackdropBlurCache.debugGenerations, 1);
    await tester.pumpWidget(scene(100, height: 500));
    expect(GlassBackdropBlurCache.debugGenerations, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'eviction leaves source handles valid and huge samples stay bounded',
    (tester) async {
      await loadImage(tester);
      await tester.runAsync(() async {
        for (var sigma = 1; sigma <= 5; sigma++) {
          final result = GlassBackdropBlurCache.resolve(
            sample: sampleOf(),
            size: const Size(8000, 4000),
            sigma: sigma.toDouble(),
            saturation: 1,
          )!;
          expect(result.width * result.height, lessThanOrEqualTo(1051000));
          expect(result.width / result.height, closeTo(2, 0.01));
        }
        // 五种参数超过四项缓存上限；淘汰只释放缓存自己的源句柄。
        final clone = image.clone();
        clone.dispose();
        GlassBackdropBlurCache.resolve(
          sample: sampleOf(),
          size: const Size(8000, 4000),
          sigma: 1,
          saturation: 1,
        );
      });
      expect(GlassBackdropBlurCache.debugGenerations, 6);
    },
  );

  test('saturating a scrim keeps grays and full saturation unchanged', () {
    const gray = Color(0x80808080);
    final kept = GlassBackdropBlurCache.saturate(gray, 1.4);
    expect(kept.r, closeTo(gray.r, 1e-6));
    expect(kept.g, closeTo(gray.g, 1e-6));
    expect(kept.b, closeTo(gray.b, 1e-6));
    expect(kept.a, gray.a);
    const red = Color(0xFFCC3333);
    expect(GlassBackdropBlurCache.saturate(red, 1), red);
    expect(
      GlassBackdropBlurCache.saturate(red, 0).r,
      closeTo(GlassBackdropBlurCache.saturate(red, 0).g, 1e-6),
    );
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  void bump() => setState(() => count++);

  @override
  Widget build(BuildContext context) => Text('$count');
}
