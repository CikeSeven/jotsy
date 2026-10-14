import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../support/expressive_test_theme.dart';

const _tag = ImageViewerHeroTag('test', 'thumb');

/// 2:1 的真实可解码图片；解码走真实异步，需在 runAsync 中调用。
Future<MemoryImage> _wideImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 80, 40),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(80, 40);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}

/// 来源页：一个 100×100、圆角 12、cover 裁切的缩略图，点按后以共享元素打开。
Future<BuildContext> _pumpSource(
  WidgetTester tester,
  ImageProvider thumb,
) async {
  late BuildContext cellContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 100,
            child: Builder(
              builder: (context) {
                cellContext = context;
                return ImageViewerHeroSource(
                  tag: _tag,
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(image: thumb, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() => precacheImage(thumb, cellContext));
  await tester.pump();
  return cellContext;
}

/// 飞行中的画面：圆角严格介于来源（12）与看图页（0）之间的裁切层。
Iterable<ClipRRect> _flyingShuttles(WidgetTester tester) =>
    tester.widgetList<ClipRRect>(find.byType(ClipRRect)).where((clip) {
      final radius = (clip.borderRadius as BorderRadius).topLeft.x;
      return radius > 0.01 && radius < 11.99;
    });

void main() {
  testWidgets('thumbnail expands into the viewer and flies back on close', (
    tester,
  ) async {
    final thumb = (await tester.runAsync(_wideImage))!;
    final cellContext = await _pumpSource(tester, thumb);

    final hero = ImageViewerHero.capture(cellContext, tag: _tag);
    expect(hero, isNotNull);
    expect(hero!.aspectRatio, 2);

    unawaited(
      openImageViewer(
        cellContext,
        items: const <ImageViewerItem>[
          ImageViewerItem(source: '/missing/original.jpg'),
        ],
        initialIndex: 0,
        hero: hero,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_flyingShuttles(tester), isNotEmpty);

    await tester.pumpAndSettle();
    expect(_flyingShuttles(tester), isEmpty);
    // 落地后的盒子就是原图比例的画面本身（来源画面垫底，原图加载失败也不留白）。
    final target = find.byType(ImageViewerHeroTarget);
    final box = tester.getSize(
      find.descendant(of: target, matching: find.byType(AspectRatio)),
    );
    expect(box.width / box.height, closeTo(2, 0.01));
    expect(
      find.descendant(of: target, matching: find.byType(RawImage)),
      findsWidgets,
    );

    await tester.tap(find.byTooltip(cellContext.l10n.commonBack));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_flyingShuttles(tester), isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion opens without a shared element flight', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final thumb = (await tester.runAsync(_wideImage))!;
    final cellContext = await _pumpSource(tester, thumb);

    expect(ImageViewerHero.capture(cellContext, tag: _tag), isNull);
    expect(find.byType(Hero), findsNothing);

    unawaited(
      openImageViewer(
        cellContext,
        items: const <ImageViewerItem>[
          ImageViewerItem(source: '/missing/original.jpg'),
        ],
        initialIndex: 0,
      ),
    );
    await tester.pump();
    await tester.pump();
    // 无动画路由：一帧之内就位。
    expect(find.byType(ImageViewerPage), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('capture returns null before the source image is decoded', (
    tester,
  ) async {
    late BuildContext cellContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            cellContext = context;
            // 文件读取在测试的假时钟里不会完成：始终处于“尚未解码”。
            return Image.file(File('/missing/never-decoded.jpg'));
          },
        ),
      ),
    );
    expect(ImageViewerHero.capture(cellContext, tag: _tag), isNull);
  });
}
