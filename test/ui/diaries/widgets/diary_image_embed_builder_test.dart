import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

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

Future<void> _pumpEditor(
  WidgetTester tester,
  quill.QuillController controller, {
  void Function(String imageSource)? onImageClicked,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: quill.QuillEditor.basic(
          controller: controller,
          config: quill.QuillEditorConfig(
            embedBuilders: buildDiaryQuillEmbedBuilders(
              onImageClicked: onImageClicked,
            ),
          ),
        ),
      ),
    ),
  );
  // 图片解码/文件读取是真实异步，需离开 FakeAsync 等待完成后再推进帧。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'resized image keeps its aspect ratio inside a centered rounded block',
    (tester) async {
      final source = (await tester.runAsync(() => _pngDataUri(400, 200)))!;
      final controller = quill.QuillController(
        document: quill.Document.fromJson([
          {
            'insert': {'image': source},
            'attributes': {'style': 'width: 100.0; height: 600.0; '},
          },
          {'insert': '\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      addTearDown(controller.dispose);
      String? clicked;

      await _pumpEditor(
        tester,
        controller,
        onImageClicked: (imageSource) => clicked = imageSource,
      );

      final image = find.descendant(
        of: find.byType(DiaryEmbeddedImage),
        matching: find.byType(Image),
      );
      // 宽高只作上限：按 2:1 比例缩进 100 宽内，不会被撑成 100×600 的留白盒子。
      expect(tester.getSize(image), const Size(100, 50));
      // 独占一行时按块级布局水平居中，而不是贴着行首的行内 WidgetSpan。
      expect(
        tester.getCenter(image).dx,
        closeTo(tester.getCenter(find.byType(quill.QuillEditor)).dx, 0.5),
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
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing image file shows a localized placeholder', (
    tester,
  ) async {
    final controller = quill.QuillController(
      document: quill.Document.fromJson([
        {
          'insert': {'image': '/nonexistent/diary_images/missing.jpg'},
        },
        {'insert': '\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);

    await _pumpEditor(tester, controller);

    expect(find.text('图片文件不存在或无法加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
