import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/ui/diaries/widgets/diary_embedded_image.dart';
import 'package:node_diary/ui/diaries/widgets/diary_long_image_fold.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';
import 'package:path/path.dart' as p;

Future<String> _pngDataUri(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
}

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

/// 固定返回给定分片的切片服务（不走原生通道）。
class _FixedTiles extends LongImageTileService {
  _FixedTiles(this.tiles) : super(supported: true);

  final LongImageTiles tiles;

  @override
  bool isResolved(String path) => true;

  @override
  LongImageTiles? peek(String path) => tiles;

  @override
  Future<LongImageTiles?> tilesFor(String path) async => tiles;
}

Future<void> _pumpEditor(
  WidgetTester tester,
  DiaryEditorController controller, {
  void Function(String imageSource, ImageViewerHero? hero)? onImageOpen,
  bool foldLongImages = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        quill.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: nativeTestEditor(
          controller: controller,
          onImageOpen: onImageOpen,
          foldLongImages: foldLongImages,
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// 先读尺寸（文件头）再解码，两步都是真实异步：离开 FakeAsync 等待，再推进
/// 帧，直到正文里的图片都解码完成或出现失败占位。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final images = find.descendant(
      of: find.byType(DiaryEmbeddedImage),
      matching: find.byType(RawImage),
    );
    final decoded =
        images.evaluate().isNotEmpty &&
        images.evaluate().every(
          (element) => (element.renderObject! as RenderImage).image != null,
        );
    if (decoded || find.text('图片文件不存在或无法加载').evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'resized image keeps its aspect ratio inside a start-aligned rounded block',
    (tester) async {
      final source = (await tester.runAsync(() => _pngDataUri(400, 200)))!;
      final controller = DiaryEditorController(
        document: documentFromLegacyDelta([
          {
            'insert': {'image': source},
            'attributes': {'style': 'width: 100.0; height: 600.0; '},
          },
          {'insert': '\n'},
        ]),
        selection: quill.Selection.single(path: [0], startOffset: 0),
        readOnly: true,
      );
      addTearDown(controller.dispose);
      String? clicked;
      ImageViewerHero? hero;

      await _pumpEditor(
        tester,
        controller,
        onImageOpen: (imageSource, capturedHero) {
          clicked = imageSource;
          hero = capturedHero;
        },
      );

      final image = find.descendant(
        of: find.byType(DiaryEmbeddedImage),
        matching: find.byType(Image),
      );
      // 宽高只作上限：按 2:1 比例缩进 100 宽内，不会被撑成 100×600 的留白盒子。
      expect(tester.getSize(image), const Size(100, 50));
      // 缩小后贴着正文左缘（块级布局，不再居中悬在行中间）。
      expect(
        tester.getTopLeft(image).dx,
        closeTo(tester.getTopLeft(find.byType(DiaryEditor)).dx, 0.5),
      );
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(DiaryEmbeddedImage),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(16));

      await tester.tap(image);
      await tester.pump();
      expect(clicked, isNotNull);
      // 点按时抓取已绘制的画面作为看图页飞入画面，比例与原图一致。
      expect(hero, isNotNull);
      expect(hero!.aspectRatio, 2);
      // 圆角挂在来源 Hero 上：飞行中从 16 补间到看图页的 0。
      expect(
        tester.widget<ImageHero>(find.byType(ImageHero)).borderRadius,
        BorderRadius.circular(16),
      );
      hero!.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing image file shows a localized placeholder', (
    tester,
  ) async {
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': '/nonexistent/diary_images/missing.jpg'},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);

    await _pumpEditor(tester, controller);

    expect(find.text('图片文件不存在或无法加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a centered paragraph keeps its image centered', (tester) async {
    final source = (await tester.runAsync(() => _pngDataUri(400, 200)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
          'attributes': {'style': 'width: 100.0; height: 600.0; '},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);

    await _pumpEditor(tester, controller);

    final image = find.descendant(
      of: find.byType(DiaryEmbeddedImage),
      matching: find.byType(Image),
    );
    // 导入的居中段落仍按段落对齐，只有未设对齐时才靠行首。
    expect(
      tester.getCenter(image).dx,
      closeTo(tester.getCenter(find.byType(DiaryEditor)).dx, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long image folds to a 2:3 box showing its top, with a badge', (
    tester,
  ) async {
    ImageDimensions.debugReset();
    // 300×1500：高是宽的 5 倍，按原图宽 300 显示时折叠到 300×450。
    final source = (await tester.runAsync(() => _pngDataUri(300, 1500)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);
    ImageViewerHero? hero;

    await _pumpEditor(
      tester,
      controller,
      onImageOpen: (_, capturedHero) => hero = capturedHero,
    );

    final fold = find.byType(DiaryLongImageFold);
    expect(fold, findsOneWidget);
    expect(tester.getSize(fold), const Size(300, 450));
    expect(find.text('长图'), findsOneWidget);
    // 拼回原图比例后顶部对齐：图片高 1500，被折叠盒子裁掉下面的部分。
    final image = find.descendant(of: fold, matching: find.byType(Image));
    expect(tester.getTopLeft(image), tester.getTopLeft(fold));
    expect(tester.getSize(image), const Size(300, 1500));
    // 靠行首。
    expect(
      tester.getTopLeft(fold).dx,
      closeTo(tester.getTopLeft(find.byType(DiaryEditor)).dx, 0.5),
    );

    await tester.tap(fold);
    await tester.pump();
    // 看图页的飞入画面来自折叠盒子里已解码的图，仍是原图比例。
    expect(hero, isNotNull);
    expect(hero!.aspectRatio, closeTo(0.2, 1e-3));
    hero!.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide resize bound still folds a long image by its width', (
    tester,
  ) async {
    final source = (await tester.runAsync(() => _pngDataUri(300, 1500)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
          'attributes': {'style': 'width: 120.0; height: 900.0; '},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);

    await _pumpEditor(tester, controller);

    // 缩放菜单把宽度限到 120：折叠盒子跟着变成 120×180。
    expect(
      tester.getSize(find.byType(DiaryLongImageFold)),
      const Size(120, 180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sliced long image only builds the tiles inside the fold', (
    tester,
  ) async {
    ImageDimensions.debugReset();
    final original = LongImageTileService.instance;
    addTearDown(() => LongImageTileService.instance = original);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('jotsy_fold_tiles_'),
    ))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final source = (await tester.runAsync(
      () => _writePng(dir, 'long.png', 300, 1500),
    ))!;
    final tilePaths = <String>[];
    for (var i = 0; i < 3; i++) {
      tilePaths.add(
        (await tester.runAsync(() => _writePng(dir, 'tile_$i.png', 300, 502)))!,
      );
    }
    // 三段各 500 高（含 2 像素重叠）；折叠露出顶部 300 × 1.5 = 450 像素。
    LongImageTileService.instance = _FixedTiles(
      LongImageTiles(
        width: 300,
        height: 1500,
        tiles: <LongImageTile>[
          for (var i = 0; i < 3; i++)
            LongImageTile(path: tilePaths[i], top: i * 500, height: 502),
        ],
      ),
    );
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);

    await _pumpEditor(tester, controller);

    final fold = find.byType(DiaryLongImageFold);
    expect(tester.getSize(fold), const Size(300, 450));
    final images = find.descendant(of: fold, matching: find.byType(Image));
    expect(images, findsOneWidget);
    expect(
      (tester.widget<Image>(images).image as ResizeImage).imageProvider,
      FileImage(File(tilePaths.first)),
    );
    expect(tester.getTopLeft(images), tester.getTopLeft(fold));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the resize slider keeps the image on screen', (
    tester,
  ) async {
    final source = (await tester.runAsync(() => _pngDataUri(400, 200)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
          'attributes': {'style': 'width: 100.0; height: 600.0; '},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
    );
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);
    final image = find.descendant(
      of: find.byType(DiaryEmbeddedImage),
      matching: find.byType(Image),
    );
    final decodeKey = tester.widget<Image>(image).image;

    // 滑条每帧写一次宽度：解码尺寸不变，新宽度在同一帧里就画出来，
    // 不会因为重新解码而空白。
    for (final width in <double>[140, 180, 220]) {
      controller.formatText(
        0,
        1,
        MapEntry('style', 'width: $width; height: 600.0; '),
      );
      await tester.pump();
      expect(tester.widget<Image>(image).image, decodeKey);
      expect(
        (tester.renderObject(find.byType(RawImage)) as RenderImage).image,
        isNotNull,
      );
      expect(tester.getSize(image), Size(width, width / 2));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an image in the editor offers view, resize and more', (
    tester,
  ) async {
    final source = (await tester.runAsync(() => _pngDataUri(400, 200)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {'insert': '开头\n'},
        {
          'insert': {'image': source},
          'attributes': {'style': 'width: 100.0; height: 600.0; '},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
    );
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);
    final image = find.byType(DiaryEmbeddedImage);

    await tester.tap(image);
    await tester.pumpAndSettle();
    for (final label in <String>['查看', '调整大小', '复制', '保存到相册', '删除']) {
      expect(find.text(label), findsOneWidget);
    }
    // 上游菜单的“缩放”已由“查看”取代。
    expect(find.text('缩放'), findsNothing);

    // 查看：经看图页打开。
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(ImageViewerPage))).pop();
    await tester.pumpAndSettle();

    // 删除：只移出正文中的这张图，前面的文字不动。
    await tester.tap(image);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEmbeddedImage), findsNothing);
    expect(controller.document.toPlainText(), '开头\n');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read-only body without a viewer hook only views and copies', (
    tester,
  ) async {
    final source = (await tester.runAsync(() => _pngDataUri(400, 200)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);

    await tester.tap(find.byType(DiaryEmbeddedImage));
    await tester.pumpAndSettle();
    expect(find.text('查看'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('调整大小'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long images can show in full at column width', (tester) async {
    final source = (await tester.runAsync(() => _pngDataUri(300, 1500)))!;
    final controller = DiaryEditorController(
      document: documentFromLegacyDelta([
        {
          'insert': {'image': source},
          // 上游滑条总会顺带写入一个屏幕高的高度：完整显示时不按它限高。
          'attributes': {'style': 'width: 200.0; height: 600.0; '},
        },
        {'insert': '\n'},
      ]),
      selection: quill.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);
    ImageViewerHero? hero;
    var opened = false;

    await _pumpEditor(
      tester,
      controller,
      foldLongImages: false,
      onImageOpen: (_, capturedHero) {
        opened = true;
        hero = capturedHero;
      },
    );

    final full = find.byType(DiaryLongImageFull);
    expect(full, findsOneWidget);
    expect(find.byType(DiaryLongImageFold), findsNothing);
    expect(tester.getSize(full), const Size(200, 1000));
    expect(find.text('长图'), findsNothing);

    await tester.tap(full);
    await tester.pump();
    // 整张图比屏幕还高时不做共享元素飞入，看图页直接淡入。
    expect(opened, isTrue);
    expect(hero, isNull);
    expect(tester.takeException(), isNull);
  });
}
