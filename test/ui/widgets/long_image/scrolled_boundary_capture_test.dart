import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/long_image/scrolled_boundary_capture.dart';

/// 截图要等真实的引擎回调（toImage / 编码），帧又只能由测试推进：交替让出
/// 真实时间与推进一帧，直到截取完成。
Future<Uint8List> _drive(WidgetTester tester, Future<Uint8List> capture) async {
  var done = false;
  capture.whenComplete(() => done = true).ignore();
  for (var i = 0; i < 400 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done, isTrue, reason: 'capture did not finish');
  return capture;
}

Future<ui.Image> _decode(WidgetTester tester, Uint8List bytes) async =>
    (await tester.runAsync(() => decodeImageFromList(bytes)))!;

Future<(GlobalKey, ScrollController)> _pumpList(
  WidgetTester tester, {
  required int items,
}) async {
  final key = GlobalKey();
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 300,
          child: RepaintBoundary(
            key: key,
            child: ListView.builder(
              controller: controller,
              itemCount: items,
              itemExtent: 100,
              itemBuilder: (context, index) => ColoredBox(
                color: index.isEven
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF1565C0),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return (key, controller);
}

void main() {
  testWidgets('stitches every screen of the scrolled content', (tester) async {
    final (key, controller) = await _pumpList(tester, items: 10);
    controller.jumpTo(120);
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    final bytes = await _drive(
      tester,
      captureScrolledBoundary(
        boundary,
        scrollController: controller,
        pixelRatio: 2,
        background: const Color(0xFFFFFFFF),
      ),
    );
    final image = await _decode(tester, bytes);
    // 1000 逻辑像素的内容 × 2 倍。
    expect(image.width, 400);
    expect(image.height, 2000);
    // 每 100 逻辑像素一条，绿蓝交替：逐条核对，任何一屏错位都会对不上。
    final pixels = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    for (var item = 0; item < 10; item++) {
      final y = item * 200 + 100;
      final offset = (y * image.width + 200) * 4;
      final green = pixels.getUint8(offset + 1);
      final blue = pixels.getUint8(offset + 2);
      expect(
        item.isEven ? green > blue : blue > green,
        isTrue,
        reason: '$item',
      );
    }
    image.dispose();
    // 截完滚回开始时的位置。
    expect(controller.offset, 120);
  });

  testWidgets('lowers the pixel ratio to stay under the texture limit', (
    tester,
  ) async {
    final (key, controller) = await _pumpList(tester, items: 10);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    final bytes = await _drive(
      tester,
      captureScrolledBoundary(
        boundary,
        scrollController: controller,
        pixelRatio: 3,
        background: const Color(0xFFFFFFFF),
        maxPixelHeight: 1500,
      ),
    );
    final image = await _decode(tester, bytes);
    expect(image.height, 1500);
    expect(image.width, 300);
    image.dispose();
  });

  testWidgets('content that does not scroll is captured once', (tester) async {
    final (key, controller) = await _pumpList(tester, items: 2);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    final bytes = await _drive(
      tester,
      captureScrolledBoundary(
        boundary,
        scrollController: controller,
        pixelRatio: 1,
        background: const Color(0xFFFFFFFF),
      ),
    );
    final image = await _decode(tester, bytes);
    expect((image.width, image.height), (200, 300));
    image.dispose();
  });
}
