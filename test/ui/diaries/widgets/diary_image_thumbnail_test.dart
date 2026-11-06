import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/widgets/diary_embedded_image.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_fallback.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_thumbnail.dart';
import 'package:node_diary/ui/diaries/widgets/diary_long_image_fold.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/expressive_test_theme.dart';

/// 4:3 的示例照片（宽图）。
final _photo = File('assets/img/diary_card_samples/cafe.webp').absolute.path;
const _style = 'width: 200.0; height: 600.0; ';

DiaryEditorController _controller({
  String? source,
  Object? thumbnail,
  bool readOnly = false,
}) => DiaryEditorController(
  document: diaryEditorDocument(
    jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'image',
            'data': {
              'url': source ?? _photo,
              'style': _style,
              kDiaryImageThumbnailKey: ?thumbnail,
            },
          },
        ],
      },
    }),
  ),
  selection: af.Selection.single(path: [0], startOffset: 0),
  readOnly: readOnly,
);

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

Finder get _image => find.descendant(
  of: find.byType(DiaryEmbeddedImage),
  matching: find.byType(Image),
);

af.Node _node(DiaryEditorController controller) =>
    controller.document.nodeAtPath([0])!;

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  Brightness brightness = Brightness.light,
  void Function(String source, ImageViewerHero? hero)? onImageOpen,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final editor = nativeTestEditor(
    controller: controller,
    shrinkWrap: controller.readOnly,
    onImageOpen: onImageOpen,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('zh'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        af.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: controller.readOnly
            ? SingleChildScrollView(child: editor)
            : editor,
      ),
    ),
  );
  await _settle(tester);
}

/// 读尺寸（文件头）与解码都是真实异步：离开 FakeAsync 等待，再推进帧，
/// 直到图片解码完成或出现失败占位。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final raw = find.descendant(
      of: find.byType(DiaryEmbeddedImage),
      matching: find.byType(RawImage),
    );
    final decoded =
        raw.evaluate().isNotEmpty &&
        tester.renderObject<RenderImage>(raw).image != null;
    if (decoded || find.byType(DiaryImageFallback).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

Future<void> _chooseFromMenu(WidgetTester tester, String label) async {
  await tester.tap(_image);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await _settle(tester);
}

void main() {
  setUp(ImageDimensions.debugReset);

  for (final brightness in Brightness.values) {
    testWidgets(
      'turning an image into a thumbnail draws a fixed square in one undoable step and turning it off restores its saved size (${brightness.name})',
      (tester) async {
        final controller = _controller();
        addTearDown(controller.dispose);
        final original = controller.contentJson;
        await _pump(tester, controller, brightness: brightness);
        expect(tester.getSize(_image), const Size(200, 150));

        await _chooseFromMenu(tester, '显示为小图');
        expect(find.byType(DiaryImageThumbnail), findsOneWidget);
        expect(
          tester.getSize(_image),
          const Size.square(kDiaryImageThumbnailExtent),
        );
        // 宽图按高铺满格子解码，cover 裁切后不发糊。
        final decode = tester.widget<Image>(_image).image as ResizeImage;
        expect(decode.height, kDiaryImageThumbnailExtent.toInt());
        expect(controller.revision, 1);
        expect(_node(controller).attributes[kDiaryImageThumbnailKey], isTrue);
        // 缩放写入的宽高原样保留，取消小图后才能回到原来的大小。
        expect(_node(controller).attributes['style'], _style);

        await tester.tap(_image);
        await tester.pumpAndSettle();
        // 小图尺寸固定，菜单里不再提供调整大小。
        expect(find.text('调整大小'), findsNothing);
        expect(find.text('显示为小图'), findsNothing);
        await tester.tap(find.text('恢复正常显示'));
        await tester.pumpAndSettle();
        await _settle(tester);
        expect(find.byType(DiaryImageThumbnail), findsNothing);
        expect(tester.getSize(_image), const Size(200, 150));
        // 稀疏写入：关闭时删键，而不是留一个 false。
        expect(
          _node(controller).attributes.containsKey(kDiaryImageThumbnailKey),
          isFalse,
        );
        expect(controller.contentJson, original);
        expect(controller.revision, 2);

        controller.undo();
        await tester.pumpAndSettle();
        expect(_node(controller).attributes[kDiaryImageThumbnailKey], isTrue);
        controller.undo();
        await tester.pumpAndSettle();
        expect(controller.contentJson, original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tapping a thumbnail in read-only text opens the full image', (
    tester,
  ) async {
    final controller = _controller(thumbnail: true, readOnly: true);
    addTearDown(controller.dispose);
    String? opened;
    ImageViewerHero? hero;
    await _pump(
      tester,
      controller,
      onImageOpen: (source, captured) {
        opened = source;
        hero = captured;
      },
    );
    expect(
      tester.getSize(_image),
      const Size.square(kDiaryImageThumbnailExtent),
    );
    // 靠行首，与普通的缩小图片一致。
    expect(tester.getTopLeft(_image).dx, lessThan(40));

    await tester.tap(_image);
    expect(opened, _photo);
    // 共享元素从小图飞入看图页。
    expect(hero, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the read-only image menu offers no thumbnail switch', (
    tester,
  ) async {
    final controller = _controller(readOnly: true);
    addTearDown(controller.dispose);
    await _pump(tester, controller);
    await tester.tap(_image);
    await tester.pumpAndSettle();
    expect(find.text('查看'), findsOneWidget);
    expect(find.text('显示为小图'), findsNothing);
    expect(find.text('恢复正常显示'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only a literal true marks an image as a thumbnail', (
    tester,
  ) async {
    final controller = _controller(thumbnail: 'true');
    addTearDown(controller.dispose);
    await _pump(tester, controller);
    expect(find.byType(DiaryImageThumbnail), findsNothing);
    expect(tester.getSize(_image), const Size(200, 150));
  });

  testWidgets(
    'a long image thumbnail is decoded by width and shown without the fold',
    (tester) async {
      final source = (await tester.runAsync(() => _pngDataUri(100, 1000)))!;
      final controller = _controller(source: source, thumbnail: true);
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      expect(find.byType(DiaryLongImageFold), findsNothing);
      expect(find.text('长图'), findsNothing);
      expect(
        tester.getSize(_image),
        const Size.square(kDiaryImageThumbnailExtent),
      );
      final decode = tester.widget<Image>(_image).image as ResizeImage;
      expect(decode.width, kDiaryImageThumbnailExtent.toInt());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a thumbnail whose file is missing shows the failure placeholder at full width',
    (tester) async {
      final controller = _controller(
        source: '${Directory.systemTemp.path}/node_diary_missing_thumb.png',
        thumbnail: true,
      );
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      final fallback = find.byType(DiaryImageFallback);
      expect(fallback, findsOneWidget);
      // 说明文字不被挤进 120 的小方格。
      expect(
        tester.getSize(fallback).width,
        greaterThan(kDiaryImageThumbnailExtent),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
