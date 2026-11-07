import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_embed_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/models/diary_thumbnail_rows.dart';
import 'package:node_diary/ui/diaries/models/image_insertion.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_drop_targets.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_thumbnail.dart';

import '../../../support/expressive_test_theme.dart';

/// 小图并排（顶层连续的小图三张一排）与点在嵌入块旁空白处时插入点的去处。
///
/// 图片指向不存在的文件：小图在读出尺寸前先占好方格（读文件头是真实 IO，
/// 测试的假时钟里不会完成），排版与点按都按方格进行。

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

Map<String, Object?> _divider() => {'type': 'divider', 'data': {}};

DiaryEditorController _document(List<Map<String, Object?>> blocks) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

/// 4:3 的示例照片。
final _photo = File('assets/img/diary_card_samples/cafe.webp').absolute.path;

/// 每块一行：`类型:文字`（图片为 `image:文件名`，小图带 `*`）。
String _outline(DiaryEditorController controller) => [
  for (final node in controller.document.root.children)
    switch (node.type) {
      'image' =>
        'image:${(node.attributes['url'] as String).split('/').last.split('.').first}'
            '${diaryImageIsThumbnail(node) ? '*' : ''}',
      _ =>
        '${node.type}${node.delta == null ? '' : ':${node.delta!.toPlainText()}'}',
    },
].join('\n');

af.Selection _caret(af.Path path, [int offset = 0]) =>
    af.Selection.collapsed(af.Position(path: path, offset: offset));

af.Node _block(DiaryEditorController controller, int index) =>
    controller.document.root.children[index];

Rect _rectOf(DiaryEditorController controller, int index) =>
    _block(controller, index).rect;

/// 小图方格（不含块的上下留白）。
Rect _squareOf(WidgetTester tester, DiaryEditorController controller, int i) {
  final square = find.descendant(
    of: find.byKey(_block(controller, i).key),
    matching: find.byType(DiaryImageThumbnail),
  );
  return tester.getRect(square);
}

void main() {
  setUp(ImageDimensions.debugReset);

  group('diaryThumbnailRows', () {
    af.Node node(Map<String, Object?> json) =>
        af.Node.fromJson(json.cast<String, Object>());

    test('puts consecutive thumbnails three to a row', () {
      final rows = diaryThumbnailRows([
        node(_p('a')),
        node(_image('1')),
        node(_image('2')),
        node(_image('3')),
        node(_image('4')),
        node(_image('5', thumbnail: false)),
        node(_image('6')),
      ]);
      expect(rows, [
        (start: 0, end: 1),
        (start: 1, end: 4),
        (start: 1, end: 4),
        (start: 1, end: 4),
        (start: 4, end: 5),
        (start: 5, end: 6),
        (start: 6, end: 7),
      ]);
    });

    test('rowOf agrees with the full grouping and ignores nested blocks', () {
      final controller = _document([
        _image('1'),
        _image('2'),
        _image('3'),
        _image('4'),
        _image('5'),
        _p('x'),
        {
          'type': 'bulleted_list',
          'data': {
            'delta': [
              {'insert': 'item'},
            ],
          },
          'children': [_image('n1'), _image('n2')],
        },
      ]);
      final children = controller.document.root.children;
      final rows = diaryThumbnailRows(children.toList());
      for (var i = 0; i < children.length; i++) {
        expect(diaryThumbnailRowOf(children[i]), rows[i], reason: 'block $i');
      }
      expect(diaryThumbnailRowOf(children.last.children.first), isNull);
      expect(diaryThumbnailRowLeader(controller.document.root, 4), 3);
      expect(diaryThumbnailRowLeader(controller.document.root, 2), 0);
      expect(diaryThumbnailRowLeader(controller.document.root, 5), 5);
    });

    test('three thumbnails always fit the column, at most 120dp each', () {
      expect(diaryThumbnailExtentFor(800), kDiaryImageThumbnailExtent);
      // 常见手机正文列（约 345dp）：三张加两道间距正好铺满。
      final side = diaryThumbnailExtentFor(345);
      expect(side * 3 + kDiaryThumbnailRowGap * 2, closeTo(345, 0.001));
      expect(diaryThumbnailExtentFor(0), 0);
    });
  });

  group('in the editor', () {
    const appearance = DiaryTextAppearance(typography: DiaryTypography());

    Future<FocusNode> pump(
      WidgetTester tester,
      DiaryEditorController controller, {
      af.Selection? selection,
      bool shrinkWrap = false,
      double width = 400,
    }) async {
      tester.view.physicalSize = Size(width, 800);
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

    /// 一排里各张方格：同一行、等大、间距 [kDiaryThumbnailRowGap]。
    void expectRow(
      WidgetTester tester,
      DiaryEditorController controller,
      List<int> blocks,
    ) {
      final first = _squareOf(tester, controller, blocks.first);
      expect(first.width, lessThanOrEqualTo(kDiaryImageThumbnailExtent));
      expect(first.width, closeTo(first.height, 0.01));
      for (var i = 1; i < blocks.length; i++) {
        final square = _squareOf(tester, controller, blocks[i]);
        expect(square.top, first.top, reason: 'block ${blocks[i]} top');
        expect(square.width, closeTo(first.width, 0.01));
        expect(square.height, closeTo(first.height, 0.01));
        expect(
          square.left,
          closeTo(first.left + i * (first.width + kDiaryThumbnailRowGap), 0.01),
          reason: 'block ${blocks[i]} left',
        );
      }
    }

    for (final width in [400.0, 320.0]) {
      testWidgets('consecutive thumbnails sit three to a row at ${width}dp', (
        tester,
      ) async {
        final controller = _document([
          _p('a'),
          _image('1'),
          _image('2'),
          _image('3'),
          _image('4'),
          _p('b'),
        ]);
        await pump(tester, controller, selection: _caret([0], 1), width: width);

        expectRow(tester, controller, [1, 2, 3]);
        final first = _squareOf(tester, controller, 1);
        final third = _squareOf(tester, controller, 3);
        // 窄屏上也放得下：第三张不超出正文列。
        final column = tester.getRect(find.byType(af.AppFlowyEditor));
        expect(third.right, lessThanOrEqualTo(column.right));
        // 第四张另起一排，靠行首。
        final fourth = _squareOf(tester, controller, 4);
        expect(fourth.top, greaterThan(first.bottom));
        expect(fourth.left, first.left);
        expect(_rectOf(controller, 5).top, greaterThan(fourth.bottom));
        await unmount(tester);
      });
    }

    testWidgets(
      'turning one image back to normal splits the row, undo joins it again',
      (tester) async {
        final controller = _document([
          _p('a'),
          _image('1'),
          _image('2'),
          _image('3'),
          _image('4'),
        ]);
        await pump(tester, controller, selection: _caret([0], 1));
        expectRow(tester, controller, [1, 2, 3]);

        final transaction = controller.state.transaction
          ..updateNode(_block(controller, 2), {kDiaryImageThumbnailKey: null});
        controller.apply(transaction);
        await tester.pumpAndSettle();

        // 第二张恢复为正文图片，独占一行；后面两张接着排成一排。
        expect(diaryImageIsThumbnail(_block(controller, 2)), isFalse);
        expect(
          _rectOf(controller, 2).top,
          greaterThanOrEqualTo(_rectOf(controller, 1).bottom),
        );
        expect(
          _rectOf(controller, 3).top,
          greaterThanOrEqualTo(_rectOf(controller, 2).bottom),
        );
        expectRow(tester, controller, [3, 4]);

        controller.undo();
        await tester.pumpAndSettle();
        expectRow(tester, controller, [1, 2, 3]);
        expect(
          _squareOf(tester, controller, 4).top,
          greaterThan(_squareOf(tester, controller, 1).bottom),
        );
        await unmount(tester);
      },
    );

    testWidgets('the read-only text lays out the same rows', (tester) async {
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [_p('a'), _image('1'), _image('2'), _p('b')],
          },
        }),
        readOnly: true,
      );
      addTearDown(controller.dispose);
      await pump(tester, controller, shrinkWrap: true);

      expectRow(tester, controller, [1, 2]);
      expect(
        _rectOf(controller, 3).top,
        greaterThan(_squareOf(tester, controller, 1).bottom),
      );
      await unmount(tester);
    });

    testWidgets(
      'tapping the blank right of a row puts the caret below it and shows '
      'the keyboard',
      (tester) async {
        final controller = _document([
          _p('a'),
          _image('1'),
          _image('2'),
          _p('b'),
        ]);
        await pump(tester, controller, selection: _caret([0], 1));
        // 用户收起了键盘。
        tester.testTextInput.hide();
        expect(tester.testTextInput.isVisible, isFalse);
        final second = _squareOf(tester, controller, 2);
        final blank = Offset(second.right + 40, second.center.dy);

        await tester.tapAt(blank);
        await tester.pump();

        // 下一段有字：在这一排后面补一行，插入点放进去。
        expect(
          _outline(controller),
          'paragraph:a\nimage:1*\nimage:2*\nparagraph:\nparagraph:b',
        );
        expect(controller.selection, _caret([3]));
        expect(tester.testTextInput.isVisible, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 再点一次：下面已是空行，只把插入点放进去，不再补行。
        await tester.tapAt(blank);
        await tester.pump();
        expect(controller.document.root.children, hasLength(5));
        expect(controller.selection, _caret([3]));

        // 补的那行是一步撤销。
        controller.undo();
        await tester.pump();
        expect(
          _outline(controller),
          'paragraph:a\nimage:1*\nimage:2*\nparagraph:b',
        );
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'tapping the gap between two thumbnails also moves the caret below '
      'the row',
      (tester) async {
        final controller = _document([_image('1'), _image('2'), _p('')]);
        await pump(tester, controller, selection: _caret([2]));
        final first = _squareOf(tester, controller, 0);

        await tester.tapAt(
          Offset(first.right + kDiaryThumbnailRowGap / 2, first.center.dy),
        );
        await tester.pump();

        expect(_outline(controller), 'image:1*\nimage:2*\nparagraph:');
        expect(controller.selection, _caret([2]));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'tapping the thumbnail itself opens the image menu and leaves the '
      'caret alone',
      (tester) async {
        // 真实的照片：方格在画面解码之前只占位、点不中。
        final controller = _document([
          _p('a'),
          {
            'type': 'image',
            'data': {'url': _photo, kDiaryImageThumbnailKey: true},
          },
          _p('b'),
        ]);
        await pump(tester, controller, selection: _caret([0], 1));
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          final raw = find.byType(RawImage);
          if (raw.evaluate().isNotEmpty &&
              tester.renderObject<RenderImage>(raw).image != null) {
            break;
          }
        }
        final before = controller.contentJson;

        await tester.tapAt(_squareOf(tester, controller, 1).center);
        await tester.pumpAndSettle();

        expect(find.byType(SimpleDialog), findsOneWidget);
        expect(controller.contentJson, before);
        expect(controller.selection, isNot(_caret([2])));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('tapping a divider puts the caret on a line below it', (
      tester,
    ) async {
      final controller = _document([_p('text'), _divider(), _p('end')]);
      await pump(tester, controller, selection: _caret([0], 4));
      final divider = _block(controller, 1).renderBox!;

      await tester.tapAt(
        divider.localToGlobal(divider.size.center(Offset.zero)),
      );
      await tester.pump();

      expect(
        _outline(controller),
        'paragraph:text\ndivider\nparagraph:\nparagraph:end',
      );
      expect(controller.selection, _caret([2]));
      expect(tester.testTextInput.hasAnyClients, isTrue);
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'dragging a block onto the lower half of a row drops it after the '
      'whole row',
      (tester) async {
        final controller = _document([
          _p('a'),
          _image('1'),
          _image('2'),
          _image('3'),
          _p('b'),
        ]);
        await pump(tester, controller, selection: _caret([4], 1));
        final row = _rectOf(controller, 1);

        expect(
          resolveDiaryBlockDrop(
            controller.document.root,
            _block(controller, 0),
            row.top + row.height * 0.75,
            depth: 1,
          ),
          [4],
        );
        await unmount(tester);
      },
    );
  });

  group('placeDiaryCaretAfterEmbed', () {
    test('reuses an empty line below, otherwise adds one', () {
      final controller = _document([
        _image('1', thumbnail: false),
        _p(''),
        _divider(),
        _p('after'),
      ]);
      final state = controller.state;

      expect(
        placeDiaryCaretAfterEmbed(state, _block(controller, 0)),
        _caret([1]),
      );
      expect(controller.document.root.children, hasLength(4));
      expect(state.selection, _caret([1]));

      expect(
        placeDiaryCaretAfterEmbed(state, _block(controller, 2)),
        _caret([3]),
      );
      expect(
        _outline(controller),
        'image:1\nparagraph:\ndivider\nparagraph:\nparagraph:after',
      );
      expect(state.selectionUpdateReason, af.SelectionUpdateReason.uiEvent);

      // 文字块不是嵌入块，不处理。
      expect(placeDiaryCaretAfterEmbed(state, _block(controller, 4)), isNull);
    });

    test('a thumbnail in a row places the caret after the whole row', () {
      final controller = _document([_image('1'), _image('2'), _image('3')]);
      expect(
        placeDiaryCaretAfterEmbed(controller.state, _block(controller, 0)),
        _caret([3]),
      );
      expect(_outline(controller), 'image:1*\nimage:2*\nimage:3*\nparagraph:');
    });
  });

  group('insertDiaryImages', () {
    test('right after a thumbnail inserts thumbnails that join its row', () {
      final controller = _document([_image('1'), _p('')]);
      controller.state.selection = _caret([1]);

      insertDiaryImages(
        controller: controller,
        imagePaths: ['/missing/2.jpg', '/missing/3.jpg'],
      );

      expect(_outline(controller), 'image:1*\nimage:2*\nimage:3*\nparagraph:');
      expect(controller.state.selection, _caret([3]));
    });

    test('after a normal image or text keeps the inserted image normal', () {
      for (final before in [_image('1', thumbnail: false), _p('text')]) {
        final controller = _document([before, _p('')]);
        controller.state.selection = _caret([1]);

        insertDiaryImages(
          controller: controller,
          imagePaths: ['/missing/2.jpg'],
        );

        expect(diaryImageIsThumbnail(_block(controller, 1)), isFalse);
      }
    });
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
