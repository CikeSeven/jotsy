import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';

/// 生成一张真实可解码的小图；解码走真实异步，调用方需包在 `runAsync` 里。
Future<MemoryImage> _memoryImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(8, 8);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}

Widget _host(ImageProvider provider) => MaterialApp(
  home: Image(image: provider, frameBuilder: expressiveImageFrameBuilder),
);

/// 动画中的实际不透明度（AnimatedOpacity.opacity 只是目标值）。
double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(AnimatedOpacity),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

Future<void> _waitForDecode(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 100)),
);

void main() {
  testWidgets('image stays transparent until decoded, then fades in', (
    tester,
  ) async {
    final provider = (await tester.runAsync(_memoryImage))!;

    await tester.pumpWidget(_host(provider));
    // 解码未完成时不能露出任何半成品画面。
    expect(_opacity(tester), 0);

    await _waitForDecode(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_opacity(tester), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('cached image shows immediately without an animation layer', (
    tester,
  ) async {
    final provider = (await tester.runAsync(_memoryImage))!;
    await tester.pumpWidget(_host(provider));
    await tester.runAsync(
      () => precacheImage(provider, tester.element(find.byType(Image))),
    );

    // 卸载后重新挂载同一个 provider：模拟列表滚回已经显示过的卡片。
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(provider));

    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('image appears immediately under reduce motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final provider = (await tester.runAsync(_memoryImage))!;

    await tester.pumpWidget(_host(provider));
    await _waitForDecode(tester);
    await tester.pump();

    expect(_opacity(tester), 1);
  });
}
