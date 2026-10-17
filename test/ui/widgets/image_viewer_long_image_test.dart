import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';
import 'package:node_diary/ui/widgets/swipe_dismiss_viewer.dart';
import 'package:path/path.dart' as p;

import '../../support/expressive_test_theme.dart';

Future<String> _writePng(
  Directory dir,
  String name,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}

DoubleTapZoomViewer _viewer(WidgetTester tester) =>
    tester.widget<DoubleTapZoomViewer>(find.byType(DoubleTapZoomViewer));

bool _dismissEnabled(WidgetTester tester) =>
    tester.widget<SwipeDismissViewer>(find.byType(SwipeDismissViewer)).enabled;

void main() {
  late Directory root;
  final originalTiles = LongImageTileService.instance;

  setUp(() {
    ImageDimensions.debugReset();
    // 不走原生切片：整张按比例缩小解码。
    LongImageTileService.instance = LongImageTileService(supported: false);
  });

  tearDown(() async {
    LongImageTileService.instance = originalTiles;
    ImageDimensions.debugReset();
  });

  testWidgets(
    'a long image scrolls at screen width instead of shrinking to a strip',
    (tester) async {
      root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('jotsy_viewer_long_'),
      ))!;
      addTearDown(() => root.delete(recursive: true));
      final long = (await tester.runAsync(
        () => _writePng(root, 'long.png', 100, 600),
      ))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageViewerPage(
            items: <ImageViewerItem>[
              ImageViewerItem(source: long),
              const ImageViewerItem(source: '/missing/second.jpg'),
            ],
            initialIndex: 0,
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        if (_viewer(tester).contentHeightFactor != null) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump();

      // 高是宽的 6 倍：宽度铺满、从顶部开始，而不是 contain 成一条细线。
      expect(_viewer(tester).contentHeightFactor, closeTo(6, 1e-9));
      final page = tester.getRect(find.byType(PageView));
      final image = find.byType(Image);
      expect(tester.getTopLeft(image), page.topLeft);
      expect(tester.getSize(image).width, page.width);
      // 竖向拖动留给滚动：这一页不响应下拉关闭。
      expect(_dismissEnabled(tester), isFalse);

      // 逐步拖动（真机拖动是一串移动事件；缩放识别器接管后才开始平移）。
      final gesture = await tester.startGesture(page.center);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsOneWidget);
      expect(tester.getTopLeft(image).dy, lessThan(page.top - 200));

      // 翻到普通图片后恢复下拉关闭。
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(_viewer(tester).contentHeightFactor, isNull);
      expect(_dismissEnabled(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
