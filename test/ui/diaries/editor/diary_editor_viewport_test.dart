import 'dart:convert';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_long_image_fold.dart';

import '../../../support/diary_content_test_helpers.dart';

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

/// 图片尺寸经引擎异步读取：离开 FakeAsync 等它，再推进帧。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

ScrollPosition _scrollPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(DiaryEditor),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    )
    .position;

void main() {
  setUp(ImageDimensions.debugReset);

  // 编辑页揭示光标时，图片这类整块嵌入的“光标”就是整个块。块比可见区域
  // 还高时，露出底边就藏住顶边、露出顶边又藏住底边：以前每帧来回跳，
  // 整页一直闪。
  testWidgets(
    'a caret on an embed taller than the visible area settles instead of '
    'scrolling back and forth every frame',
    (tester) async {
      tester.view.physicalSize = const Size(400, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = (await tester.runAsync(() => _pngDataUri(300, 1500)))!;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final controller = DiaryEditorController(
        document: documentFromLegacyDelta([
          {'insert': List.generate(12, (i) => 'line $i').join('\n')},
          {'insert': '\n'},
          {
            'insert': {'image': source},
          },
          {'insert': '\n'},
          {'insert': List.generate(12, (i) => 'tail $i').join('\n')},
          {'insert': '\n'},
        ]),
        selection: af.Selection.collapsed(af.Position(path: [0])),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: nativeTestEditor(controller: controller, focusNode: focus),
          ),
        ),
      );
      focus.requestFocus();
      await _settle(tester);
      final imagePath = controller.document.root.children
          .firstWhere((node) => node.type == 'image')
          .path;
      final fold = find.byType(DiaryLongImageFold);
      expect(fold, findsOneWidget);
      final position = _scrollPosition(tester);
      // 折叠长图（含上下留白）比可见区域（视口减去底部遮挡）还高。
      expect(
        tester.getSize(fold).height,
        greaterThan(position.viewportDimension - 80),
      );

      // 光标从图片上方一行移到图片上（键盘下移就是这样落到块上）。
      controller.select(af.Selection.collapsed(af.Position(path: imagePath)));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      final settled = position.pixels;
      final offsets = <double>[];
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        offsets.add(position.pixels);
      }
      expect(offsets, everyElement(settled));
      // 停住时画面铺满可见区域：顶边对齐可见区域顶端，不是只露出一截。块上
      // 的插入点与画面等高（DiaryEmbedSelectable），揭示的是画面而非整块。
      final viewportTop = tester.getTopLeft(find.byType(af.AppFlowyEditor)).dy;
      expect(
        tester.getRect(fold).top,
        moreOrLessEquals(viewportTop, epsilon: 1),
      );

      // 光标从图片下方往上移回图片：同样停住，画面底边对齐可见区域底端。
      controller.select(
        af.Selection.collapsed(af.Position(path: imagePath.next)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      position.jumpTo(position.pixels + 600);
      await tester.pump();
      controller.select(
        af.Selection.collapsed(af.Position(path: imagePath, offset: 1)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      final back = position.pixels;
      offsets.clear();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        offsets.add(position.pixels);
      }
      expect(offsets, everyElement(back));
      final visibleBottom =
          tester.getBottomLeft(find.byType(af.AppFlowyEditor)).dy - 80;
      expect(
        tester.getRect(fold).bottom,
        moreOrLessEquals(visibleBottom, epsilon: 1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
