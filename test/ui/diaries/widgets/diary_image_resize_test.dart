import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/widgets/diary_embedded_image.dart';

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/expressive_test_theme.dart';

final _source = File('assets/img/diary_card_samples/cafe.webp').absolute.path;
const _pageKey = ValueKey('image-resize-page');
const _initialStyle = 'opacity: 0.75; width: 200.0; height: 600.0; ';

DiaryEditorController _controller({
  bool readOnly = false,
  String style = _initialStyle,
}) => DiaryEditorController(
  document: diaryEditorDocument(
    jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'image',
            'data': {'url': _source, 'style': style},
          },
        ],
      },
    }),
  ),
  selection: af.Selection.single(path: [0], startOffset: 0),
  readOnly: readOnly,
);

Finder get _image => find.descendant(
  of: find.byType(DiaryEmbeddedImage),
  matching: find.byType(Image),
);

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller,
  Brightness brightness,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() => ImageDimensions.resolve(_source));
  final editor = nativeTestEditor(
    controller: controller,
    shrinkWrap: controller.readOnly,
    onImageOpen: controller.readOnly ? (_, _) {} : null,
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
      home: RepaintBoundary(
        key: _pageKey,
        child: Scaffold(
          body: controller.readOnly
              ? SingleChildScrollView(child: editor)
              : editor,
        ),
      ),
    ),
  );
  // 文件解码跨越真实异步与测试帧；不能在 runAsync 里等待 FakeAsync 中
  // 已开始的 ImageStream，否则其完成回调没有机会被 pump。
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final image = find.byType(RawImage);
    if (image.evaluate().isNotEmpty &&
        tester.renderObject<RenderImage>(image).image != null) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

Future<void> _openResizer(WidgetTester tester) async {
  await tester.tap(_image);
  await tester.pumpAndSettle();
  await tester.tap(find.text('调整大小'));
  await tester.pumpAndSettle();
  expect(find.byType(Slider), findsNWidgets(2));
}

void _expectPreviewSize(WidgetTester tester) {
  final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
  // 示例照片为 4:3；两个滑条均为显示上限，调整任一方向都不能拉伸照片。
  final expected = applyBoxFit(
    BoxFit.scaleDown,
    const Size(400, 300),
    Size(sliders[0].value, sliders[1].value),
  ).destination;
  final actual = tester.getSize(_image);
  expect(actual.width, closeTo(expected.width, 0.1));
  expect(actual.height, closeTo(expected.height, 0.1));
}

Future<Color> _pixelAt(WidgetTester tester, Offset position) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_pageKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset =
          (position.dy.floor() * image.width + position.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'resize sliders preview immediately and confirm saves one undoable change (${brightness.name})',
      (tester) async {
        final controller = _controller();
        addTearDown(controller.dispose);
        final original = controller.contentJson;
        await _pump(tester, controller, brightness);
        final decodeKey = tester.widget<Image>(_image).image;
        await _openResizer(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Slider).first),
        );
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump();
          _expectPreviewSize(tester);
          expect(tester.widget<Image>(_image).image, decodeKey);
          expect(
            tester.renderObject<RenderImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          expect(controller.contentJson, original);
          expect(controller.revision, 0);
        }
        await gesture.up();
        final height = find.byType(Slider).last;
        await tester.tapAt(
          tester.getTopLeft(height) +
              Offset(65, tester.getSize(height).height / 2),
        );
        await tester.pump();
        _expectPreviewSize(tester);
        final previewSize = tester.getSize(_image);
        final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
        final savedBounds = BoxConstraints(
          maxWidth: sliders[0].value,
          maxHeight: sliders[1].value,
        );

        await tester.tap(find.text('确认'));
        await tester.pumpAndSettle();
        expect(tester.getSize(_image), previewSize);
        expect(controller.revision, 1);
        expect(
          diaryImageEmbedBounds(controller.document.nodeAtPath([0])!),
          savedBounds,
        );
        expect(
          controller.document.nodeAtPath([0])!.attributes['style'],
          startsWith('opacity: 0.75; '),
        );
        controller.undo();
        await tester.pumpAndSettle();
        expect(controller.contentJson, original);
        expect(tester.getSize(_image), const Size(200, 150));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dismissing resize restores an image without saved size bounds (${brightness.name})',
      (tester) async {
        final controller = _controller(style: 'opacity: 0.75; ');
        addTearDown(controller.dispose);
        final original = controller.contentJson;
        await _pump(tester, controller, brightness);
        final originalSize = tester.getSize(_image);
        await _openResizer(tester);
        await tester.tapAt(tester.getCenter(find.byType(Slider).first));
        await tester.pump();
        _expectPreviewSize(tester);
        expect(tester.getSize(_image), isNot(originalSize));

        await tester.tapAt(const Offset(380, 20));
        await tester.pumpAndSettle();
        expect(find.byType(Slider), findsNothing);
        expect(tester.getSize(_image), originalSize);
        expect(controller.contentJson, original);
        expect(controller.revision, 0);
        expect(controller.hasUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a leading resized image in readonly preview leaves its surrounding background clear (${brightness.name})',
      (tester) async {
        final controller = _controller(readOnly: true);
        addTearDown(controller.dispose);
        await _pump(tester, controller, brightness);
        expect(tester.getSize(_image), const Size(200, 150));
        final imageRect = tester.getRect(_image);
        final background = expressiveTestTheme(
          brightness,
        ).scaffoldBackgroundColor;
        // 检查图片右侧的真实像素：块级覆盖光标会把整行压成灰色，尺寸断言抓不到。
        expect(
          await _pixelAt(
            tester,
            Offset(imageRect.right + 40, imageRect.center.dy),
          ),
          background,
        );
        expect(controller.state.selection, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unmounting an image while resizing safely releases its preview',
    (tester) async {
      final controller = _controller();
      await _pump(tester, controller, Brightness.light);
      await _openResizer(tester);
      await tester.tapAt(tester.getCenter(find.byType(Slider).first));
      await tester.pump();
      _expectPreviewSize(tester);

      // 返回的面板 Future 晚于正文卸载结束，清理回调不能再调用 setState。
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
