import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_cover_alignment.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_tiles_view.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> _settleImage(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    final images = find.byType(RawImage).evaluate();
    if (images.isNotEmpty &&
        images.every(
          (element) => (element.renderObject! as RenderImage).image != null,
        )) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  group('LongImageTilesView', () {
    final tiles = LongImageTiles(
      width: 1000,
      height: 10000,
      tiles: <LongImageTile>[
        for (var i = 0; i < 5; i++)
          LongImageTile(
            path: '/missing/tile_$i.png',
            top: i * 2048,
            height: 2050,
          ),
      ],
    );

    testWidgets('builds only the tiles inside the visible range', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 50,
              height: 500,
              child: LongImageTilesView(
                tiles: tiles,
                decodeWidth: 200,
                visibleEnd: 0.3,
              ),
            ),
          ),
        ),
      );

      final images = find.byType(Image);
      // 第一段 0～0.205、第二段 0.2048～0.4098 与 0～0.3 相交，其余不构建。
      expect(images, findsNWidgets(2));
      final second = find.byKey(const ValueKey<String>('/missing/tile_1.png'));
      expect(tester.getTopLeft(second).dy, closeTo(102.4, 1e-6));
      // 每段含 2 像素重叠，盒子高度按原图比例换算。
      expect(tester.getSize(second).height, closeTo(102.5, 1e-6));
    });
  });

  group('CoverCroppedImage', () {
    Future<Alignment> alignmentFor(
      WidgetTester tester,
      int width,
      int height,
    ) async {
      final bytes = (await tester.runAsync(() => _png(width, height)))!;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CoverCroppedImage(image: MemoryImage(bytes)),
            ),
          ),
        ),
      );
      await _settleImage(tester);
      return tester.widget<Image>(find.byType(Image)).alignment as Alignment;
    }

    testWidgets('a long image is cropped from its top', (tester) async {
      expect(await alignmentFor(tester, 40, 200), Alignment.topCenter);
    });

    testWidgets('an ordinary portrait photo stays centered', (tester) async {
      expect(await alignmentFor(tester, 120, 200), Alignment.center);
    });
  });

  group('DoubleTapZoomViewer.tall', () {
    const viewport = Size(400, 400);

    Future<void> doubleTapAt(WidgetTester tester, Offset position) async {
      await tester.tapAt(position);
      await tester.pump(kDoubleTapMinTime + const Duration(milliseconds: 10));
      await tester.tapAt(position);
      await tester.pumpAndSettle();
    }

    TransformationController transformation(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    testWidgets('scrolls a tall image from the top and zooms around the tap', (
      tester,
    ) async {
      final visibleRects = <Rect>[];
      final scrolledEvents = <bool>[];
      final zoomEvents = <bool>[];
      Size? contentSize;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: viewport,
              child: DoubleTapZoomViewer.tall(
                contentHeightFactor: 5,
                onScrolledChanged: scrolledEvents.add,
                onZoomChanged: zoomEvents.add,
                builder: (context, size, visible) {
                  contentSize = size;
                  visibleRects.add(visible);
                  return const ColoredBox(color: Color(0xFF3366CC));
                },
              ),
            ),
          ),
        ),
      );

      // 宽度铺满视口、高度 = 宽 × 5，从顶部开始。
      expect(contentSize, const Size(400, 2000));
      expect(visibleRects.last, const Rect.fromLTWH(0, 0, 400, 400));

      // 原始大小下竖向拖动即滚动，不需要先放大。
      await tester.dragFrom(const Offset(200, 300), const Offset(0, -250));
      await tester.pumpAndSettle();
      final scrolledY = transformation(tester).value.getTranslation().y;
      expect(scrolledY, lessThan(-200));
      expect(scrolledEvents, <bool>[true]);
      expect(visibleRects.last.top, closeTo(-scrolledY, 1e-6));
      expect(zoomEvents, isEmpty);

      // 双击放大：点按处的内容点留在手指下。
      const focal = Offset(100, 200);
      final before = transformation(tester).toScene(focal);
      await doubleTapAt(tester, focal);
      expect(
        transformation(tester).value.getMaxScaleOnAxis(),
        closeTo(2.5, 1e-6),
      );
      final zoomed = transformation(tester).toScene(focal);
      expect(zoomed.dx, closeTo(before.dx, 1e-6));
      expect(zoomed.dy, closeTo(before.dy, 1e-6));
      expect(zoomEvents, <bool>[true]);

      // 再双击复原到原始大小，但不跳回顶部。
      await doubleTapAt(tester, focal);
      expect(
        transformation(tester).value.getMaxScaleOnAxis(),
        closeTo(1, 1e-6),
      );
      final restored = transformation(tester).toScene(focal);
      expect(restored.dy, closeTo(before.dy, 1e-6));
      expect(zoomEvents, <bool>[true, false]);
      expect(tester.takeException(), isNull);
    });
  });
}
