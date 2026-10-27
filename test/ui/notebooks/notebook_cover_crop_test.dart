import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/models/notebook_cover_crop.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_cover_crop_page.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover/notebook_cover_crop_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notebook_test_support.dart';

/// 封面取景：几何换算（cover + 放大 + 对齐点）与取景页（拖动、重置、完成 /
/// 返回的结果）。
void main() {
  group('NotebookCoverCrop', () {
    const frame = Size(150, 200);
    const landscape = Size(400, 200);

    test('matches a cover fit aligned by the focus point at zoom 1', () {
      // 横图按高度铺满：200 高 → 400 宽，水平方向溢出 250。
      expect(
        const NotebookCoverCrop().imageRect(frame, landscape),
        const Rect.fromLTWH(-125, 0, 400, 200),
      );
      expect(
        const NotebookCoverCrop(x: -1).imageRect(frame, landscape).left,
        0,
      );
      expect(
        const NotebookCoverCrop(x: 1).imageRect(frame, landscape).right,
        150,
      );
    });

    test('panning follows the finger and stops at the edges', () {
      const crop = NotebookCoverCrop();
      // 图片左移 50：露出更多右侧，对齐点向右。
      final moved = crop.panBy(const Offset(-50, 30), frame, landscape);
      expect(moved.x, closeTo(0.4, 1e-9));
      // 竖直方向没有溢出，对齐点保持不变。
      expect(moved.y, 0);
      final clamped = crop.panBy(const Offset(-1000, 0), frame, landscape);
      expect(clamped.x, 1);
      expect(crop.panBy(const Offset(1000, 0), frame, landscape).x, -1);
    });

    test('zooming keeps the point under the finger in place', () {
      const crop = NotebookCoverCrop(x: 0.2);
      const focal = Offset(40, 120);
      final before = crop.imageRect(frame, landscape);
      final zoomed = crop.zoomAround(2, focal, frame, landscape);
      final after = zoomed.imageRect(frame, landscape);
      expect(zoomed.zoom, 2);
      final u = (focal.dx - before.left) / before.width;
      final v = (focal.dy - before.top) / before.height;
      expect(after.left + u * after.width, closeTo(focal.dx, 1e-6));
      expect(after.top + v * after.height, closeTo(focal.dy, 1e-6));
      // 夹到 1..4 倍。
      expect(crop.zoomAround(9, focal, frame, landscape).zoom, 4);
      expect(crop.zoomAround(0.2, focal, frame, landscape).zoom, 1);
    });

    test('writes back to the style keeping layout and texture', () {
      final style = NotebookCoverStyle(
        layout: NotebookCoverLayout.label,
        texture: NotebookCoverTexture.grid,
      );
      final result = const NotebookCoverCrop(
        x: 0.12345,
        y: -0.5,
        zoom: 1.75,
      ).applyTo(style);
      expect(result.layout, NotebookCoverLayout.label);
      expect(result.texture, NotebookCoverTexture.grid);
      expect(result.focusX, 0.123);
      expect(result.focusY, -0.5);
      expect(result.zoom, 1.75);
    });
  });

  group('NotebookCoverCropPage', () {
    late Directory temp;
    late String imagePath;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('notebook_crop_test_');
      imagePath = '${temp.path}/landscape.png';
    });
    tearDown(() async => temp.delete(recursive: true));

    /// 写一张 400×200 的横图（真实 PNG，取景页按它的比例换算）。
    Future<void> writeImage(WidgetTester tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 400, 200),
          Paint()..color = const Color(0xFF3366AA),
        );
        final image = await recorder.endRecording().toImage(400, 200);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(imagePath).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    /// 首页一个按钮推入取景页，记下返回值；等图片解码出取景区。
    Future<List<NotebookCoverStyle?>> open(
      WidgetTester tester,
      NotebookCoverStyle style,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await writeImage(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final results = <NotebookCoverStyle?>[];
      // 页面背景读设置（ProviderScope 里的真实设置服务，空偏好即默认背景）。
      await tester.pumpWidget(
        ProviderScope(
          child: notebookTestApp(
            Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async => results.add(
                  await Navigator.of(context).push(
                    NotebookCoverCropPage.route(
                      coverPath: imagePath,
                      style: style,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      for (var i = 0; i < 50; i++) {
        if (find.byType(NotebookCoverCropViewport).evaluate().isNotEmpty) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.byType(NotebookCoverCropViewport), findsOneWidget);
      return results;
    }

    testWidgets('dragging moves the focus and done returns it', (tester) async {
      final style = NotebookCoverStyle(layout: NotebookCoverLayout.spine);
      final results = await open(tester, style);
      final resetButton = find.widgetWithText(TextButton, '重置');
      expect(tester.widget<TextButton>(resetButton).onPressed, isNull);

      await tester.drag(
        find.byType(NotebookCoverCropViewport),
        const Offset(-40, 25),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(resetButton).onPressed, isNotNull);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      final result = results.single!;
      expect(result.layout, NotebookCoverLayout.spine);
      // 图片左移：露出右侧，对齐点向右；竖直方向没有溢出，保持居中。
      expect(result.focusX, greaterThan(0));
      expect(result.focusY, 0);
      expect(result.zoom, 1);
    });

    testWidgets('reset goes back to the default framing', (tester) async {
      final style = NotebookCoverStyle(
        texture: NotebookCoverTexture.dots,
        focusX: 0.6,
        focusY: -0.4,
        zoom: 2.5,
      );
      final results = await open(tester, style);
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      final result = results.single!;
      expect(result.hasDefaultCrop, isTrue);
      expect(result.texture, NotebookCoverTexture.dots);
    });

    testWidgets('the zoom slider zooms and back discards the change', (
      tester,
    ) async {
      final results = await open(tester, NotebookCoverStyle.defaults);
      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, greaterThan(1));

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(results, <NotebookCoverStyle?>[null]);
    });
  });
}
