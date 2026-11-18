import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_thumbnail_reorder.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/models/diary_thumbnail_reorder_slots.dart';
import 'package:node_diary/ui/diaries/models/diary_thumbnail_rows.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_thumbnail_reorder_cell.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_thumbnail_reorder_float.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_thumbnail.dart';

import '../../../support/expressive_test_theme.dart';

/// 长按拖动小图排序：挪动后的顺序、格位推算与落点、排序事务，以及编辑页
/// 里长按拿起、让位、松手写入的整条链路。
///
/// 图片指向不存在的文件：小图在读出尺寸前先占好方格，拖动按方格进行。

Map<String, Object?> _p(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

Map<String, Object?> _image(String name, {bool thumbnail = true}) => {
  'type': 'image',
  'data': {
    'url': '/missing/$name.jpg',
    if (thumbnail) kDiaryImageThumbnailKey: true,
  },
};

DiaryEditorController _document(
  List<Map<String, Object?>> blocks, {
  bool readOnly = false,
}) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
    readOnly: readOnly,
  );
  addTearDown(controller.dispose);
  return controller;
}

/// 每块一项：段落为文字，图片为文件名（小图带 `*`）。
List<String> _outline(DiaryEditorController controller) => [
  for (final node in controller.document.root.children)
    switch (node.type) {
      'image' =>
        '${(node.attributes['url'] as String).split('/').last.split('.').first}'
            '${diaryImageIsThumbnail(node) ? '*' : ''}',
      _ => node.delta?.toPlainText() ?? node.type,
    },
];

af.Node _block(DiaryEditorController controller, int index) =>
    controller.document.root.children[index];

List<af.Node> _blocks(DiaryEditorController controller, int start, int end) =>
    controller.document.root.children.sublist(start, end);

af.Selection _caret(af.Path path, [int offset = 0]) =>
    af.Selection.collapsed(af.Position(path: path, offset: offset));

/// 第 [index] 块的小图方格（含拖动中的平移）。
Rect _squareOf(WidgetTester tester, DiaryEditorController controller, int i) =>
    tester.getRect(
      find.descendant(
        // 列表在视口外还建着的缓存项也要量（拖动后核对整串的格位）。
        of: find.byKey(_block(controller, i).key, skipOffstage: false),
        matching: find.byType(DiaryImageThumbnail, skipOffstage: false),
        skipOffstage: false,
      ),
    );

/// 拖动中让位的格子停在 [slot] 的左上角（弹簧停稳前的亚像素差不计）。
Matcher _near(Rect slot) => offsetMoreOrLessEquals(slot.topLeft, epsilon: 0.5);

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}

void main() {
  setUp(ImageDimensions.debugReset);

  group('diaryThumbnailReorderedIndex', () {
    test('the lifted one lands on the target, those between shift by one', () {
      // 第 1 张挪到第 3 张：0 1 2 3 4 → 0 2 3 1 4。
      expect(
        [
          for (var i = 0; i < 5; i++)
            diaryThumbnailReorderedIndex(i, from: 1, to: 3),
        ],
        [0, 3, 1, 2, 4],
      );
      // 往前挪：第 3 张挪到第 0 张。
      expect(
        [
          for (var i = 0; i < 5; i++)
            diaryThumbnailReorderedIndex(i, from: 3, to: 0),
        ],
        [1, 2, 3, 0, 4],
      );
      expect(diaryThumbnailReorderedIndex(2, from: 2, to: 2), 2);
    });
  });

  group('DiaryThumbnailSlots', () {
    const cell = Size(120, 132);

    test('measured slots win, the rest follow the gap and the row pitch', () {
      const slots = DiaryThumbnailSlots(
        count: 7,
        known: {0: Offset(10, 100), 1: Offset(138, 100)},
        cell: cell,
      );
      expect(slots.origin(0), const Offset(10, 100));
      // 同一排：差一格的格距（120 + 8）。
      expect(slots.origin(2), const Offset(266, 100));
      // 下一排：只量到一排时行距取一格的高度。
      expect(slots.origin(3), const Offset(10, 232));
      expect(slots.origin(5), const Offset(266, 232));
      expect(slots.origin(6), const Offset(10, 364));
      expect(slots.origin(7), isNull);
      expect(slots.origin(-1), isNull);
    });

    test('two measured rows give the real pitch', () {
      const slots = DiaryThumbnailSlots(
        count: 9,
        // 第二排里有张图解码失败、占位更高：行距按实测 150。
        known: {1: Offset(138, 0), 4: Offset(138, 150)},
        cell: cell,
      );
      expect(slots.origin(7), const Offset(138, 300));
      expect(slots.origin(6), const Offset(10, 300));
    });

    test('nothing measured gives nothing', () {
      const slots = DiaryThumbnailSlots(count: 3, known: {}, cell: cell);
      expect(slots.origin(1), isNull);
      expect(slots.nearest(Offset.zero, anchor: Offset.zero), isNull);
    });

    test('nearest picks the closest slot and holds on near a border', () {
      const slots = DiaryThumbnailSlots(
        count: 3,
        known: {0: Offset(0, 0), 1: Offset(128, 0), 2: Offset(256, 0)},
        cell: cell,
      );
      const anchor = Offset(60, 66);
      expect(slots.nearest(const Offset(70, 70), anchor: anchor), 0);
      expect(slots.nearest(const Offset(300, 40), anchor: anchor), 2);
      // 刚过两格中线（124）：没近出迟滞，留在原来的格。
      expect(
        slots.nearest(
          const Offset(126, 66),
          anchor: anchor,
          current: 0,
          hysteresis: 6,
        ),
        0,
      );
      expect(
        slots.nearest(
          const Offset(140, 66),
          anchor: anchor,
          current: 0,
          hysteresis: 6,
        ),
        1,
      );
    });
  });

  group('runs', () {
    test('a run spans rows and stops at the first non-thumbnail', () {
      final controller = _document([
        _p('a'),
        _image('1'),
        _image('2'),
        _image('3'),
        _image('4'),
        _image('5', thumbnail: false),
        _image('6'),
      ]);
      expect(diaryThumbnailRunOf(_block(controller, 3)), (start: 1, end: 5));
      expect(diaryThumbnailRunOf(_block(controller, 6)), (start: 6, end: 7));
      expect(diaryThumbnailRunOf(_block(controller, 0)), isNull);
      expect(diaryThumbnailRunOf(_block(controller, 5)), isNull);

      final children = controller.document.root.children.toList();
      final rows = diaryThumbnailRows(children);
      // 三张一排；末尾只剩一张的那排也画成格子；独自一张的不画。
      expect(diaryThumbnailRowInGrid(children, rows[1]), isTrue);
      expect(diaryThumbnailRowInGrid(children, rows[4]), isTrue);
      expect(diaryThumbnailRowInGrid(children, rows[6]), isFalse);
      expect(diaryThumbnailRowInGrid(children, rows[0]), isFalse);
      expect(diaryThumbnailRowInGrid(children, rows[5]), isFalse);
    });
  });

  group('moveDiaryThumbnail', () {
    test('moves within the run in one undo step, the caret follows', () {
      final controller = _document([
        _p('a'),
        _image('1'),
        _image('2'),
        _image('3'),
        _image('4'),
        _p('b'),
      ]);
      // 光标停在第 1 张右侧。
      controller.select(_caret([1], 1));
      final run = _blocks(controller, 1, 5);
      expect(moveDiaryThumbnail(controller, run, from: 0, to: 2), isTrue);
      expect(_outline(controller), ['a', '2*', '3*', '1*', '4*', 'b']);
      expect(controller.selection, _caret([3], 1));

      expect(
        moveDiaryThumbnail(
          controller,
          _blocks(controller, 1, 5),
          from: 3,
          to: 0,
        ),
        isTrue,
      );
      expect(_outline(controller), ['a', '4*', '2*', '3*', '1*', 'b']);

      controller.undo();
      expect(_outline(controller), ['a', '2*', '3*', '1*', '4*', 'b']);
      controller.undo();
      expect(_outline(controller), ['a', '1*', '2*', '3*', '4*', 'b']);
      expect(controller.hasUndo, isFalse);
    });

    test('gives up when the run changed under the drag', () {
      final controller = _document([_image('1'), _image('2'), _image('3')]);
      final run = _blocks(controller, 0, 3);
      // 拖动途中有一段文字插进了这一串。
      final transaction = controller.state.transaction
        ..insertNode([1], af.paragraphNode(text: 'x'));
      controller.apply(transaction);
      expect(moveDiaryThumbnail(controller, run, from: 0, to: 2), isFalse);
      expect(_outline(controller), ['1*', 'x', '2*', '3*']);
      expect(moveDiaryThumbnail(controller, run, from: 1, to: 1), isFalse);
    });
  });

  group('editor', () {
    const appearance = DiaryTextAppearance(typography: DiaryTypography());

    Future<FocusNode> pump(
      WidgetTester tester,
      DiaryEditorController controller, {
      af.Selection? selection,
      bool shrinkWrap = false,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      if (selection != null) controller.select(selection);
      final editor = DiaryEditor(
        controller: controller,
        appearance: appearance,
        focusNode: focus,
        shrinkWrap: shrinkWrap,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              af.AppFlowyEditorLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: shrinkWrap ? SingleChildScrollView(child: editor) : editor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!controller.readOnly) {
        focus.requestFocus();
        await tester.pumpAndSettle();
      }
      return focus;
    }

    // 光标闪烁让 pumpAndSettle 停不下来，卸载后再收尾。
    Future<void> unmount(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    /// 长按第 [index] 块的小图，拿起后经几步挪到 [to]。
    Future<TestGesture> liftAndMove(
      WidgetTester tester,
      DiaryEditorController controller,
      int index,
      Offset to,
    ) async {
      final grab = _squareOf(tester, controller, index).center;
      final gesture = await tester.startGesture(grab);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var step = 1; step <= 4; step++) {
        await gesture.moveTo(Offset.lerp(grab, to, step / 4)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    testWidgets('long-press lifts a thumbnail, the others make room and '
        'letting go writes the new order in one undo step', (tester) async {
      final controller = _document([
        _p('a'),
        _image('1'),
        _image('2'),
        _image('3'),
        _image('4'),
        _p('b'),
      ]);
      await pump(tester, controller, selection: _caret([0], 1));
      expect(find.byType(DiaryThumbnailReorderCell), findsNWidgets(4));
      final slots = [
        for (var i = 1; i <= 4; i++) _squareOf(tester, controller, i),
      ];

      // 拿着第 1 张拖到第 3 张的位置。
      final gesture = await liftAndMove(tester, controller, 1, slots[2].center);
      await settle(tester);
      // 截图浮在上面；正文还没变，第 2、3 张往前让了一格。
      expect(find.byType(DiaryThumbnailFloat), findsOneWidget);
      expect(_outline(controller), ['a', '1*', '2*', '3*', '4*', 'b']);
      // 拖动中的让位是弹簧，停稳前差着不到半个像素。
      expect(_squareOf(tester, controller, 2).topLeft, _near(slots[0]));
      expect(_squareOf(tester, controller, 3).topLeft, _near(slots[1]));
      // 第 4 张（下一排）不动；被拿起的那一格跟着落点。
      expect(_squareOf(tester, controller, 4).topLeft, slots[3].topLeft);
      expect(_squareOf(tester, controller, 1).topLeft, _near(slots[2]));
      expect(controller.hasUndo, isFalse);

      await gesture.up();
      await settle(tester);
      expect(find.byType(DiaryThumbnailFloat), findsNothing);
      expect(_outline(controller), ['a', '2*', '3*', '1*', '4*', 'b']);
      // 写入后格子就在让位后的位置上，不再有平移。
      for (var i = 1; i <= 4; i++) {
        expect(
          _squareOf(tester, controller, i).topLeft,
          slots[i - 1].topLeft,
          reason: 'block $i',
        );
      }
      // 光标原样留在段落里。
      expect(controller.selection, _caret([0], 1));

      controller.undo();
      await tester.pump();
      expect(_outline(controller), ['a', '1*', '2*', '3*', '4*', 'b']);
      expect(controller.hasUndo, isFalse);
      await unmount(tester);
    });

    testWidgets('the last thumbnail alone on its row can move to the front', (
      tester,
    ) async {
      final controller = _document([
        _image('1'),
        _image('2'),
        _image('3'),
        _image('4'),
        _p('b'),
      ]);
      await pump(tester, controller, selection: _caret([4], 1));
      final first = _squareOf(tester, controller, 0);
      final gesture = await liftAndMove(
        tester,
        controller,
        3,
        first.center + const Offset(-20, 10),
      );
      await settle(tester);
      // 第一排整体往后让一格，第 3 张挤到下一排行首。
      expect(_squareOf(tester, controller, 0).left, greaterThan(first.left));
      expect(_squareOf(tester, controller, 2).top, greaterThan(first.bottom));
      await gesture.up();
      await settle(tester);
      expect(_outline(controller), ['4*', '1*', '2*', '3*', 'b']);
      await unmount(tester);
    });

    testWidgets(
      'a drag cancelled by the system flies back and keeps the order',
      (tester) async {
        final controller = _document([_image('1'), _image('2'), _image('3')]);
        await pump(tester, controller);
        final slots = [
          for (var i = 0; i < 3; i++) _squareOf(tester, controller, i),
        ];
        final gesture = await liftAndMove(
          tester,
          controller,
          0,
          slots[2].center,
        );
        await settle(tester);
        expect(_squareOf(tester, controller, 1).topLeft, _near(slots[0]));

        await gesture.cancel();
        await settle(tester);
        expect(find.byType(DiaryThumbnailFloat), findsNothing);
        expect(_outline(controller), ['1*', '2*', '3*']);
        for (var i = 0; i < 3; i++) {
          expect(_squareOf(tester, controller, i).topLeft, slots[i].topLeft);
        }
        expect(controller.hasUndo, isFalse);
        await unmount(tester);
      },
    );

    testWidgets('holding near the bottom edge scrolls on and drops further '
        'down the run', (tester) async {
      final names = [for (var i = 0; i < 30; i++) 'p$i'];
      final controller = _document([
        _p('top'),
        for (final name in names) _image(name),
        _p('end'),
      ]);
      await pump(tester, controller, selection: _caret([0], 1));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, 0);
      final grab = _squareOf(tester, controller, 1).center;
      final gesture = await tester.startGesture(grab);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final bottom = tester.getRect(find.byType(af.AppFlowyEditor)).bottom;
      final edge = Offset(grab.dx, bottom - 8);
      for (var step = 1; step <= 6; step++) {
        await gesture.moveTo(Offset.lerp(grab, edge, step / 6)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 停在底边：正文一路往上滚，截图留在手指下。
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(scrollable.position.pixels, greaterThan(300));
      // 往回挪进可见区域再松手，落在这一串后面的某一格。
      await gesture.moveTo(Offset(grab.dx, bottom - 200));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);
      expect(find.byType(DiaryThumbnailFloat), findsNothing);
      final order = _outline(controller);
      final landed = order.indexOf('p0*');
      expect(landed, greaterThan(6));
      // 其余的按原来的先后排着，只是让出了一格。
      expect(
        [
          for (final item in order)
            if (item != 'p0*') item,
        ],
        ['top', for (final name in names.skip(1)) '$name*', 'end'],
      );
      // 落定后每张都在三张一排的格位上，没有残留的平移。
      final rows = [
        for (var i = 1; i <= 30; i++)
          if (_block(controller, i).rect != Rect.zero)
            (i, _squareOf(tester, controller, i)),
      ];
      expect(rows, isNotEmpty);
      for (final (i, square) in rows) {
        final column = (i - 1) % 3;
        expect(
          square.left,
          moreOrLessEquals(
            column * (square.width + kDiaryThumbnailRowGap),
            epsilon: 0.01,
          ),
          reason: 'block $i',
        );
      }
      await unmount(tester);
    });

    testWidgets('a tap still opens the image menu instead of lifting', (
      tester,
    ) async {
      final controller = _document([_image('1'), _image('2')]);
      await pump(tester, controller);
      await tester.tap(
        find.descendant(
          of: find.byKey(_block(controller, 0).key),
          matching: find.byType(DiaryImageThumbnail),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DiaryThumbnailFloat), findsNothing);
      expect(find.text('恢复正常显示'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('screen reader actions move a thumbnail one place', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = _document([_image('1'), _image('2'), _image('3')]);
      await pump(tester, controller);

      void perform(int block, String label) {
        final cell = find
            .ancestor(
              of: find.byKey(_block(controller, block).key),
              matching: find.byType(DiaryThumbnailReorderCell),
            )
            .first;
        tester
            .renderObject(cell)
            .owner!
            .semanticsOwner!
            .performAction(
              tester.getSemantics(cell).id,
              SemanticsAction.customAction,
              CustomSemanticsAction.getIdentifier(
                CustomSemanticsAction(label: label),
              ),
            );
      }

      perform(0, '后移');
      await tester.pump();
      expect(_outline(controller), ['2*', '1*', '3*']);
      perform(2, '前移');
      await tester.pump();
      expect(_outline(controller), ['2*', '3*', '1*']);
      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('read-only text and lone thumbnails have nothing to drag', (
      tester,
    ) async {
      final readOnly = _document([_image('1'), _image('2')], readOnly: true);
      await pump(tester, readOnly, shrinkWrap: true);
      expect(find.byType(DiaryThumbnailReorderCell), findsNothing);
      await unmount(tester);

      final lone = _document([_p('a'), _image('1'), _p('b')]);
      await pump(tester, lone);
      expect(find.byType(DiaryThumbnailReorderCell), findsNothing);
      await unmount(tester);
    });
  });
}
