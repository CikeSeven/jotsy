import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_cover_alignment.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xff3366cc), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

class _Image extends ImageProvider<_Image> {
  _Image(this.bytes);
  final Uint8List bytes;
  int loads = 0;

  @override
  Future<_Image> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Image key, ImageDecoderCallback decode) {
    loads++;
    return MultiFrameImageStreamCompleter(
      codec: ui.ImmutableBuffer.fromUint8List(
        bytes,
      ).then((buffer) => decode(buffer)),
      scale: 1,
    );
  }
}

class _DeferredPhysics extends ScrollPhysics {
  const _DeferredPhysics(this.deferred, {super.parent});
  final ValueNotifier<bool> deferred;

  @override
  _DeferredPhysics applyTo(ScrollPhysics? ancestor) =>
      _DeferredPhysics(deferred, parent: buildParent(ancestor));

  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) => deferred.value;
}

Widget _cover(ImageProvider source, {int width = 100, int height = 100}) =>
    CoverCroppedImage(
      image: boundedImageProvider(
        source,
        width: width,
        height: height,
        cover: true,
      ),
      width: width.toDouble(),
      height: height.toDouble(),
    );

Future<ui.Image> _decoded(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump();
    final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    if (images.isNotEmpty && images.every((image) => image.image != null)) {
      return images.first.image!;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  throw StateError('Image did not decode');
}

void main() {
  for (final sample in <(int, int, int, int)>[
    (1000, 2000, 100, 200),
    (2000, 1000, 200, 100),
    (20, 40, 20, 40),
    (100, 10000, 82, 8192),
  ]) {
    testWidgets(
      'cover preserves aspect ratio and bounds for ${sample.$1} x ${sample.$2}',
      (tester) async {
        final bytes = (await tester.runAsync(
          () => _png(sample.$1, sample.$2),
        ))!;
        await tester.pumpWidget(
          MaterialApp(home: Center(child: _cover(MemoryImage(bytes)))),
        );
        final decoded = await _decoded(tester);
        expect(decoded.width, sample.$3);
        expect(decoded.height, sample.$4);
        expect(
          tester.widget<Image>(find.byType(Image)).alignment,
          sample.$2 >= sample.$1 * 3 ? Alignment.topCenter : Alignment.center,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a large cover respects the total pixel budget', (tester) async {
    final bytes = (await tester.runAsync(() => _png(2100, 2100)))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: _cover(MemoryImage(bytes), width: 2100, height: 2100),
        ),
      ),
    );
    final decoded = await _decoded(tester);
    expect(decoded.width, 2048);
    expect(decoded.height, 2048);
  });

  testWidgets(
    'alignment listeners and equal cover providers share one decode',
    (tester) async {
      final source = _Image((await tester.runAsync(() => _png(400, 200)))!);
      await tester.pumpWidget(
        MaterialApp(home: Row(children: [_cover(source), _cover(source)])),
      );
      await _decoded(tester);
      expect(source.loads, 1);
      expect(tester.widgetList<RawImage>(find.byType(RawImage)), hasLength(2));
    },
  );

  testWidgets(
    'a cover defers new decoding during fast scroll and loads when it settles',
    (tester) async {
      final deferred = ValueNotifier(true);
      addTearDown(deferred.dispose);
      final source = _Image((await tester.runAsync(() => _png(400, 200)))!);
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            physics: _DeferredPhysics(deferred),
            child: Column(
              children: [_cover(source), const SizedBox(height: 1000)],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(source.loads, 0, reason: 'The alignment listener must also defer');
      deferred.value = false;
      await _decoded(tester);
      expect(source.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an image removed while deferred never starts decoding', (
    tester,
  ) async {
    final deferred = ValueNotifier(true);
    addTearDown(deferred.dispose);
    final source = _Image((await tester.runAsync(() => _png(400, 200)))!);
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          physics: _DeferredPhysics(deferred),
          child: _cover(source),
        ),
      ),
    );
    expect(source.loads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    deferred.value = false;
    await tester.pump();
    expect(source.loads, 0);
    expect(tester.takeException(), isNull);
  });
}
