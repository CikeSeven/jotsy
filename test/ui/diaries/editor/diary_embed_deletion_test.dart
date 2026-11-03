import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_embed_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_embed_keys.dart';

import '../../../support/expressive_test_theme.dart';

/// 嵌入块（图片、视频、分隔线、卡片……）旁边的退格 / Delete，以及文末是
/// 嵌入块时点正文下方空白处补一行可写的段落。上游的退格会越过嵌入块把
/// 下一行并进它上面那段，嵌入块因此跑到后面（文末时成了最后一块、再也
/// 删不掉）。

Map<String, Object?> _text(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _p(String text) => _text('paragraph', text);

Map<String, Object?> _embed(String type) => {
  'type': type,
  'data': switch (type) {
    'image' => {'url': '/missing/photo.jpg'},
    'video' => {'path': '/missing/clip.mp4', 'name': 'clip.mp4'},
    'link_card' => {'target': 'jotsy://diary/d1', 'title': 'Linked'},
    _ => <String, Object?>{},
  },
};

DiaryEditorController _document(List<Map<String, Object?>> blocks) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

/// 每块一行：`类型:文字`，子块缩进两格。
String _outline(DiaryEditorController controller) {
  final lines = <String>[];
  void visit(af.Node node, int depth) {
    final text = node.delta?.toPlainText();
    lines.add('${'  ' * depth}${node.type}${text == null ? '' : ':$text'}');
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  for (final node in controller.document.root.children) {
    visit(node, 0);
  }
  return lines.join('\n');
}

af.Selection _caret(af.Path path, [int offset = 0]) =>
    af.Selection.collapsed(af.Position(path: path, offset: offset));

void main() {
  group('backspace at the start of a line after an embed', () {
    for (final type in ['divider', 'image', 'video', 'audio', 'link_card']) {
      test('deletes the $type in place instead of moving it', () {
        final controller = _document([_p('before'), _embed(type), _p('after')]);
        final before = controller.contentJson;
        controller.state.selection = _caret([2]);

        expect(deleteDiaryEmbedBeforeCaret(controller.state), isTrue);

        expect(_outline(controller), 'paragraph:before\nparagraph:after');
        expect(controller.state.selection, _caret([1]));
        controller.undo();
        expect(controller.contentJson, before);
      });
    }

    test('deletes the embed and keeps the last empty line writable', () {
      final controller = _document([_p('before'), _embed('image'), _p('')]);
      controller.state.selection = _caret([2]);

      expect(deleteDiaryEmbedBeforeCaret(controller.state), isTrue);

      expect(_outline(controller), 'paragraph:before\nparagraph:');
      expect(controller.state.selection, _caret([1]));
    });

    test('removes an empty line between the embed and more text first', () {
      final controller = _document([
        _p('a'),
        _embed('divider'),
        _p(''),
        _p('b'),
      ]);
      controller.state.selection = _caret([2]);

      expect(deleteDiaryEmbedBeforeCaret(controller.state), isTrue);
      // 空行没了，插入点到下一行开头，仍在分隔线正下方。
      expect(_outline(controller), 'paragraph:a\ndivider\nparagraph:b');
      expect(controller.state.selection, _caret([2]));

      expect(deleteDiaryEmbedBeforeCaret(controller.state), isTrue);
      expect(_outline(controller), 'paragraph:a\nparagraph:b');
      expect(controller.state.selection, _caret([1]));
    });

    test('an empty line followed by another embed deletes the embed above', () {
      final controller = _document([_embed('image'), _p(''), _embed('video')]);
      controller.state.selection = _caret([1]);

      expect(deleteDiaryEmbedBeforeCaret(controller.state), isTrue);
      expect(_outline(controller), 'paragraph:\nvideo');
      expect(controller.state.selection, _caret([0]));
    });

    test('reaches an embed nested as the last child of the block above', () {
      final controller = _document([
        _text('bulleted_list', 'item', children: [_embed('image')]),
        _p('after'),
      ]);
      controller.state.selection = _caret([1]);

      expect(deleteDiaryEmbedBeforeCaret(controller.state), isTrue);
      expect(_outline(controller), 'bulleted_list:item\nparagraph:after');
      expect(controller.state.selection, _caret([1]));
    });

    test('leaves everything else to the upstream rules', () {
      final controller = _document([
        _p('text'),
        _embed('divider'),
        _p('after'),
        _text(
          'toggle_list',
          'closed',
          data: {'collapsed': true},
          children: [_embed('image')],
        ),
        _p('below toggle'),
      ]);
      final before = controller.contentJson;
      // 不在行首。
      controller.state.selection = _caret([2], 2);
      expect(deleteDiaryEmbedBeforeCaret(controller.state), isFalse);
      // 上一块是文字，或在文档开头。
      controller.state.selection = _caret([3]);
      expect(deleteDiaryEmbedBeforeCaret(controller.state), isFalse);
      controller.state.selection = _caret([0]);
      expect(deleteDiaryEmbedBeforeCaret(controller.state), isFalse);
      // 收起的折叠块里的图片看不见，不算紧挨着。
      controller.state.selection = _caret([4]);
      expect(deleteDiaryEmbedBeforeCaret(controller.state), isFalse);
      // 插入点盖在嵌入块上（上游删掉它）与非折叠选区。
      controller.state.selection = _caret([1]);
      expect(deleteDiaryEmbedBeforeCaret(controller.state), isFalse);
      controller.state.selection = af.Selection(
        start: af.Position(path: [2]),
        end: af.Position(path: [2], offset: 3),
      );
      expect(deleteDiaryEmbedBeforeCaret(controller.state), isFalse);
      expect(controller.contentJson, before);
    });
  });

  test('Delete at the end of a line removes the embed below it', () {
    final controller = _document([_p('a'), _embed('image'), _p('b')]);
    controller.state.selection = _caret([0], 1);

    expect(deleteDiaryEmbedAfterCaret(controller.state), isTrue);
    expect(_outline(controller), 'paragraph:a\nparagraph:b');
    expect(controller.state.selection, _caret([0], 1));

    // 不在行末、下一块是文字：交给上游。
    controller.state.selection = _caret([0]);
    expect(deleteDiaryEmbedAfterCaret(controller.state), isFalse);
    controller.state.selection = _caret([0], 1);
    expect(deleteDiaryEmbedAfterCaret(controller.state), isFalse);
  });

  group('soft keyboard deletion', () {
    TextEditingDeltaDeletion deletion(String text) => TextEditingDeltaDeletion(
      oldText: text,
      deletedRange: const TextRange.collapsed(0),
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );

    test('deletes the embed above a line', () async {
      final controller = _document([_embed('divider'), _p('after')]);
      controller.state.selection = _caret([1]);

      final handled = await DiaryEmbedKeyboardInterceptor().interceptDelete(
        deletion('after'),
        controller.state,
      );

      expect(handled, isTrue);
      expect(_outline(controller), 'paragraph:after');
    });

    test('lets upstream turn a heading into a paragraph first', () async {
      final controller = _document([
        _embed('divider'),
        _text('heading', 'title', data: {'level': 2}),
      ]);
      controller.state.selection = _caret([1]);

      final handled = await DiaryEmbedKeyboardInterceptor().interceptDelete(
        deletion('title'),
        controller.state,
      );

      expect(handled, isFalse);
      expect(_outline(controller), 'divider\nheading:title');
    });
  });

  group('appendDiaryTrailingLine', () {
    test('adds a writable line after a trailing embed or table', () {
      for (final last in [
        _embed('image'),
        _embed('divider'),
        _text('bulleted_list', 'item', children: [_embed('video')]),
        {
          'type': 'table',
          'data': {'colsLen': 1, 'rowsLen': 1},
          'children': [
            {
              'type': 'table/cell',
              'data': {'rowPosition': 0, 'colPosition': 0},
              'children': [_p('cell')],
            },
          ],
        },
      ]) {
        final controller = _document([_p('a'), last]);
        final selection = appendDiaryTrailingLine(controller.state);
        expect(selection, _caret([2]));
        expect(controller.document.root.children.last.type, 'paragraph');
        expect(controller.state.selection, selection);
        expect(
          controller.state.selectionUpdateReason,
          af.SelectionUpdateReason.uiEvent,
        );
        controller.undo();
        expect(controller.document.root.children, hasLength(2));
      }
    });

    test('does nothing when the text already ends with a text block', () {
      for (final last in [
        _p('end'),
        _text(
          'toggle_list',
          'closed',
          data: {'collapsed': true},
          children: [_embed('image')],
        ),
      ]) {
        final controller = _document([_embed('image'), last]);
        final before = controller.contentJson;
        expect(appendDiaryTrailingLine(controller.state), isNull);
        expect(controller.contentJson, before);
      }
    });
  });

  group('in the editor', () {
    const appearance = DiaryTextAppearance(typography: DiaryTypography());

    Future<FocusNode> pump(
      WidgetTester tester,
      DiaryEditorController controller,
      af.Selection selection,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      controller.select(selection);
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
              body: DiaryEditor(
                controller: controller,
                appearance: appearance,
                focusNode: focus,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      focus.requestFocus();
      await tester.pumpAndSettle();
      return focus;
    }

    // 光标闪烁让 pumpAndSettle 停不下来，卸载后再收尾；先走完上游撤销
    // 记录的合并计时（上游命令不跳过它）。
    Future<void> unmount(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('Backspace and Delete keys run before the upstream merge', (
      tester,
    ) async {
      final controller = _document([
        _p('before'),
        _embed('divider'),
        _p('after'),
        _embed('divider'),
        _p('end'),
      ]);
      await pump(tester, controller, _caret([2]));

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(
        _outline(controller),
        'paragraph:before\nparagraph:after\ndivider\nparagraph:end',
      );
      expect(controller.selection, _caret([1]));

      controller.select(_caret([1], 5));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(
        _outline(controller),
        'paragraph:before\nparagraph:after\nparagraph:end',
      );
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a heading after an embed becomes a paragraph first', (
      tester,
    ) async {
      final controller = _document([
        _embed('divider'),
        _text('heading', 'title', data: {'level': 2}),
      ]);
      await pump(tester, controller, _caret([1]));

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(_outline(controller), 'divider\nparagraph:title');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(_outline(controller), 'paragraph:title');
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    double lastBlockBottom(DiaryEditorController controller) {
      final box = controller.document.root.children.last.renderBox!;
      return box.localToGlobal(Offset(0, box.size.height)).dy;
    }

    testWidgets(
      'tapping below a trailing embed adds a line and shows the keyboard',
      (tester) async {
        final controller = _document([_p('text'), _embed('divider')]);
        await pump(tester, controller, _caret([0], 4));
        // 用户收起了键盘。
        tester.testTextInput.hide();
        expect(tester.testTextInput.isVisible, isFalse);
        final left = tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx;

        // 点在分隔线上不补行。
        final divider = controller.document.root.children.last.renderBox!;
        await tester.tapAt(
          divider.localToGlobal(divider.size.center(Offset.zero)),
        );
        await tester.pump();
        expect(controller.document.root.children, hasLength(2));

        await tester.tapAt(Offset(left + 40, lastBlockBottom(controller) + 60));
        await tester.pump();

        expect(_outline(controller), 'paragraph:text\ndivider\nparagraph:');
        expect(controller.selection, _caret([2]));
        expect(tester.testTextInput.isVisible, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 最后一块已是文字：再点下方只是把插入点放到末尾，不再补行。
        await tester.tapAt(Offset(left + 40, lastBlockBottom(controller) + 60));
        await tester.pump();
        expect(controller.document.root.children, hasLength(3));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('a desktop click below adds the line, a right click does not', (
      tester,
    ) async {
      final controller = _document([_p('text'), _embed('image')]);
      await pump(tester, controller, _caret([0], 4));
      final below = Offset(
        tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx + 40,
        lastBlockBottom(controller) + 60,
      );

      await tester.tapAt(below);
      await tester.pump();
      expect(_outline(controller), 'paragraph:text\nimage\nparagraph:');
      expect(controller.selection, _caret([2]));

      // 右键是打开正文菜单，不补行（菜单的遮罩会吃掉之后的点按，放在最后）。
      controller.undo();
      await tester.pump();
      expect(controller.document.root.children, hasLength(2));
      await tester.tapAt(below, buttons: kSecondaryMouseButton);
      await tester.pump();
      expect(controller.document.root.children, hasLength(2));
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
