import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
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

/// 嵌入块（图片、视频、分隔线、卡片……）上的插入点，以及它旁边的退格 /
/// Delete / 回车 / 打字（diary_embed_editing.dart）。插入点可以停在块的左右
/// 两侧，输入法照常连着；上游的退格会越过嵌入块把下一行并进它上面那段，
/// 嵌入块因此跑到后面。

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
  group('backspace', () {
    // 所有嵌入块类型（图片、视频、音频、附件、分隔线、卡片、未识别的旧
    // 嵌入）同一条规则；以后新增的类型登记进集合即自动覆盖。
    for (final type in kDiaryEmbedBlockTypes) {
      test('a line of text below a $type: the caret moves to its right, '
          'the next backspace deletes it', () {
        final controller = _document([_p('before'), _embed(type), _p('after')]);
        final before = controller.contentJson;
        controller.state.selection = _caret([2]);

        // 第一次：插入点挪到块右侧，正文不动（块里没有字可以并进去）。
        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(controller.contentJson, before);
        expect(controller.state.selection, _caret([1], 1));
        expect(diaryEmbedAtCaret(controller.state)?.type, type);

        // 第二次：删掉它，插入点退到上一段末尾。
        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(_outline(controller), 'paragraph:before\nparagraph:after');
        expect(controller.state.selection, _caret([0], 6));
        controller.undo();
        expect(controller.contentJson, before);
      });
    }

    for (final type in kDiaryEmbedBlockTypes) {
      test('an empty line below a $type is deleted, the caret lands on its '
          'right', () {
        final controller = _document([
          _p('a'),
          _embed(type),
          _p(''),
          _p(''),
          _p(''),
          _p('b'),
        ]);
        controller.state.selection = _caret([2]);

        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(
          _outline(controller),
          'paragraph:a\n$type\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(controller.state.selection, _caret([1], 1));

        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(
          _outline(controller),
          'paragraph:a\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(controller.state.selection, _caret([0], 1));
      });
    }

    test('an empty line between two embeds, or at the very end, goes too', () {
      final between = _document([
        _p('top'),
        _embed('image'),
        _p(''),
        _embed('video'),
        _p('end'),
      ]);
      between.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(between.state), isTrue);
      expect(_outline(between), 'paragraph:top\nimage\nvideo\nparagraph:end');
      expect(between.state.selection, _caret([1], 1));

      final trailing = _document([_p('before'), _embed('divider'), _p('')]);
      trailing.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(trailing.state), isTrue);
      expect(_outline(trailing), 'paragraph:before\ndivider');
      expect(trailing.state.selection, _caret([1], 1));
    });

    test('at the left of an embed acts like backspace at a line start', () {
      final controller = _document([
        _p('a'),
        _p(''),
        _embed('image'),
        _embed('video'),
      ]);
      // 上一块是空段落：删掉它，插入点仍在块左侧。
      controller.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(_outline(controller), 'paragraph:a\nimage\nvideo');
      expect(controller.state.selection, _caret([1]));
      // 上一块有字：挪到它末尾。
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(controller.state.selection, _caret([0], 1));
      // 上一块是嵌入块：挪到它右侧。
      controller.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(controller.state.selection, _caret([1], 1));
      expect(_outline(controller), 'paragraph:a\nimage\nvideo');

      // 文首：什么都不做，也不交给上游。
      final first = _document([_embed('image')]);
      first.state.selection = _caret([0]);
      final before = first.contentJson;
      expect(backspaceDiaryEmbed(first.state), isTrue);
      expect(first.contentJson, before);
    });

    test('deleting an embed with nothing before it moves the caret forward, '
        'deleting the last block leaves an empty line', () {
      final controller = _document([_embed('image'), _embed('divider')]);
      controller.state.selection = _caret([0], 1);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(_outline(controller), 'divider');
      expect(controller.state.selection, _caret([0]));

      controller.state.selection = _caret([0], 1);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(_outline(controller), 'paragraph:');
      expect(controller.state.selection, _caret([0]));
    });

    test('the middle one of three thumbnails in a row can be deleted', () {
      Map<String, Object?> thumb(String name) => {
        'type': 'image',
        'data': {'url': '/missing/$name.jpg', kDiaryImageThumbnailKey: true},
      };
      final controller = _document([thumb('1'), thumb('2'), thumb('3')]);
      controller.state.selection = _caret([1], 1);

      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(
        controller.document.root.children.map((n) => n.attributes['url']),
        ['/missing/1.jpg', '/missing/3.jpg'],
      );
      expect(controller.state.selection, _caret([0], 1));
    });

    test('below a table an empty line is deleted, a line of text only moves '
        'the caret into the last cell', () {
      Map<String, Object?> table() => {
        'type': 'table',
        'data': {'colsLen': 2, 'rowsLen': 1},
        'children': [
          {
            'type': 'table/cell',
            'data': {'rowPosition': 0, 'colPosition': 0},
            'children': [_p('first')],
          },
          {
            'type': 'table/cell',
            'data': {'rowPosition': 0, 'colPosition': 1},
            'children': [_p('cell')],
          },
        ],
      };
      final controller = _document([_p('top'), table(), _p(''), _p('end')]);
      controller.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(_outline(controller).split('\n').last, 'paragraph:end');
      expect(controller.document.root.children, hasLength(3));
      expect(controller.state.selection, _caret([1, 1, 0], 4));

      final before = controller.contentJson;
      controller.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(controller.contentJson, before);
      expect(controller.state.selection, _caret([1, 1, 0], 4));

      // Delete 对称：表格上一行的空行删掉，插入点进第一格开头。
      final above = _document([_p('top'), _p(''), table()]);
      above.state.selection = _caret([1]);
      expect(deleteForwardDiaryEmbed(above.state), isTrue);
      expect(above.document.root.children, hasLength(2));
      expect(above.state.selection, _caret([1, 0, 0]));
    });

    test('reaches an embed nested as the last child of the block above', () {
      final controller = _document([
        _text('bulleted_list', 'item', children: [_embed('image')]),
        _p('after'),
      ]);
      controller.state.selection = _caret([1]);

      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(controller.state.selection, _caret([0, 0], 1));
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(_outline(controller), 'bulleted_list:item\nparagraph:after');
      expect(controller.state.selection, _caret([0], 4));
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
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      // 上一块是文字，或在文档开头。
      controller.state.selection = _caret([3]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      controller.state.selection = _caret([0]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      // 收起的折叠块里的图片看不见，不算紧挨着。
      controller.state.selection = _caret([4]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      // 非折叠选区。
      controller.state.selection = af.Selection(
        start: af.Position(path: [2]),
        end: af.Position(path: [2], offset: 3),
      );
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      expect(controller.contentJson, before);
    });
  });

  test('Delete mirrors backspace on the other side', () {
    final controller = _document([_p('a'), _p(''), _embed('image'), _p('b')]);
    // 行末、下一块是嵌入块：空段落删掉，插入点到块左侧。
    controller.state.selection = _caret([1]);
    expect(deleteForwardDiaryEmbed(controller.state), isTrue);
    expect(_outline(controller), 'paragraph:a\nimage\nparagraph:b');
    expect(controller.state.selection, _caret([1]));
    // 有字的行只挪过去。
    controller.state.selection = _caret([0], 1);
    expect(deleteForwardDiaryEmbed(controller.state), isTrue);
    expect(controller.state.selection, _caret([1]));
    // 块右侧：挪到下一块开头；块左侧：删掉它，插入点到下一块开头。
    controller.state.selection = _caret([1], 1);
    expect(deleteForwardDiaryEmbed(controller.state), isTrue);
    expect(controller.state.selection, _caret([2]));
    controller.state.selection = _caret([1]);
    expect(deleteForwardDiaryEmbed(controller.state), isTrue);
    expect(_outline(controller), 'paragraph:a\nparagraph:b');
    expect(controller.state.selection, _caret([1]));

    // 不在行末、下一块是文字：交给上游。
    controller.state.selection = _caret([0]);
    expect(deleteForwardDiaryEmbed(controller.state), isFalse);
    controller.state.selection = _caret([0], 1);
    expect(deleteForwardDiaryEmbed(controller.state), isFalse);
  });

  group('enter and typing on an embed', () {
    test('enter on the right adds a line after it, on the left one before '
        'it', () {
      final right = _document([_embed('image')]);
      right.state.selection = _caret([0], 1);
      expect(insertDiaryLineAtEmbed(right.state), isTrue);
      expect(_outline(right), 'image\nparagraph:');
      expect(right.state.selection, _caret([1]));

      final left = _document([_embed('image')]);
      left.state.selection = _caret([0]);
      expect(insertDiaryLineAtEmbed(left.state), isTrue);
      expect(_outline(left), 'paragraph:\nimage');
      expect(left.state.selection, _caret([1]));
    });

    test('typing opens a line on the caret side without reconnecting the '
        'input', () {
      final controller = _document([_embed('image'), _p('b')]);
      controller.state.selection = _caret([0], 1);
      expect(openDiaryLineAtEmbedCaret(controller.state), isTrue);
      expect(_outline(controller), 'image\nparagraph:\nparagraph:b');
      expect(controller.state.selection, _caret([1]));
      expect(
        controller.state.selectionExtraInfo?[af
            .selectionExtraInfoDoNotAttachTextService],
        isTrue,
      );

      controller.state.selection = _caret([2], 1);
      expect(openDiaryLineAtEmbedCaret(controller.state), isFalse);
    });
  });

  group('soft keyboard deletion', () {
    TextEditingDeltaDeletion deletion(String text) => TextEditingDeltaDeletion(
      oldText: text,
      deletedRange: const TextRange.collapsed(0),
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );

    test('moves onto the embed above a line, then deletes it', () async {
      final controller = _document([_embed('divider'), _p('after')]);
      controller.state.selection = _caret([1]);
      final interceptor = DiaryEmbedKeyboardInterceptor();

      expect(
        await interceptor.interceptDelete(deletion('after'), controller.state),
        isTrue,
      );
      expect(controller.state.selection, _caret([0], 1));
      expect(
        await interceptor.interceptDelete(deletion(''), controller.state),
        isTrue,
      );
      expect(_outline(controller), 'paragraph:after');
      expect(controller.state.selection, _caret([0]));
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
      expect(controller.state.selection, _caret([1]));
    });
  });

  group('appendDiaryTrailingLine', () {
    test('adds a writable line after a trailing table', () {
      final controller = _document([
        _p('a'),
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
      ]);
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
    });

    test('does nothing after text or an embed (the caret can stop there)', () {
      for (final last in [
        _p('end'),
        _embed('image'),
        _embed('divider'),
        _text('bulleted_list', 'item', children: [_embed('video')]),
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

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    testWidgets('Backspace and Delete keys move onto, then delete the embed', (
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

      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller.document.root.children, hasLength(5));
      expect(controller.selection, _caret([1], 1));

      await press(tester, LogicalKeyboardKey.backspace);
      expect(
        _outline(controller),
        'paragraph:before\nparagraph:after\ndivider\nparagraph:end',
      );
      expect(controller.selection, _caret([0], 6));

      controller.select(_caret([1], 5));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.delete);
      expect(controller.selection, _caret([2]));
      await press(tester, LogicalKeyboardKey.delete);
      expect(
        _outline(controller),
        'paragraph:before\nparagraph:after\nparagraph:end',
      );
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    // 手机上的软键盘：上游在输入法的编辑值前垫了一个空格占位，段首退格删的
    // 是这个占位，经输入法删除（拦截器）而不是退格键。这里照输入法的做法
    // 改编辑值。
    Map<String, dynamic> ime(WidgetTester tester) =>
        tester.testTextInput.editingState!;

    // 输入法那边当前的编辑值：测试输入法只记框架发来的值，自己发出去的
    // （打字、组字）不回写；框架之后没再发新值时，输入法里就是最后发出的那个。
    TextEditingValue? sent;
    Map<String, dynamic>? sentOver;
    TextEditingValue imeValue(WidgetTester tester) {
      final state = ime(tester);
      if (sent != null && identical(state, sentOver)) return sent!;
      return TextEditingValue(
        text: state['text'] as String,
        selection: TextSelection.collapsed(
          offset: state['selectionBase'] as int,
        ),
      );
    }

    Future<void> imeSet(
      WidgetTester tester,
      String text,
      int caret, {
      TextRange composing = TextRange.empty,
    }) async {
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
        composing: composing,
      );
      sentOver = ime(tester);
      sent = value;
      tester.testTextInput.updateEditingValue(value);
      // 上游合并输入的 10ms 防抖与拦截后的同步（零时长计时器）：pump 要带
      // 时长才会推进假时钟。
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(Duration.zero);
    }

    Future<void> imeEdit(
      WidgetTester tester,
      String Function(String text, int caret) edit,
      int Function(int caret) caretAfter,
    ) async {
      final current = imeValue(tester);
      final caret = current.selection.baseOffset;
      await imeSet(tester, edit(current.text, caret), caretAfter(caret));
    }

    Future<void> imeBackspace(WidgetTester tester) => imeEdit(
      tester,
      (text, caret) => text.replaceRange(caret - 1, caret, ''),
      (caret) => caret - 1,
    );

    Future<void> imeType(WidgetTester tester, String typed) => imeEdit(
      tester,
      (text, caret) => text.replaceRange(caret, caret, typed),
      (caret) => caret + typed.length,
    );

    testWidgets(
      'soft keyboard: backspace below an image removes the empty line and '
      'stops on the image, typing there starts a new line',
      (tester) async {
        final controller = _document([
          _p('a'),
          _embed('image'),
          _p(''),
          _p(''),
          _p('b'),
        ]);
        await pump(tester, controller, _caret([2]));
        expect(ime(tester)['text'], ' ');

        await imeBackspace(tester);
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:\nparagraph:b',
        );
        expect(controller.selection, _caret([1], 1));
        // 输入法连着块上的插入点：空行的编辑值。
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(ime(tester)['text'], ' ');
        expect(ime(tester)['selectionBase'], 1);

        // 拼音组字：第一个字母就补出新的一行，组字照常进行、上屏。
        await imeSet(
          tester,
          ' n',
          2,
          composing: const TextRange(start: 1, end: 2),
        );
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:n\nparagraph:\nparagraph:b',
        );
        await imeSet(
          tester,
          ' ni',
          3,
          composing: const TextRange(start: 1, end: 3),
        );
        await imeSet(tester, ' 你', 2);
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:你\nparagraph:\nparagraph:b',
        );
        expect(controller.selection, _caret([2], 1));

        // 删掉刚打的字，再退格：删掉这一行、回到图片右侧；再退格删掉图片。
        await imeBackspace(tester);
        expect(controller.selection, _caret([2]));
        await imeBackspace(tester);
        expect(controller.selection, _caret([1], 1));
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:\nparagraph:b',
        );
        await imeBackspace(tester);
        expect(_outline(controller), 'paragraph:a\nparagraph:\nparagraph:b');
        expect(controller.selection, _caret([0], 1));
        expect(ime(tester)['text'], ' a');
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'soft keyboard: an empty line between a divider and text goes, the '
      'caret stops on the divider and typing goes right after it',
      (tester) async {
        final controller = _document([
          _p('a'),
          _embed('divider'),
          _p(''),
          _p('world'),
        ]);
        await pump(tester, controller, _caret([2]));

        await imeBackspace(tester);
        expect(_outline(controller), 'paragraph:a\ndivider\nparagraph:world');
        expect(controller.selection, _caret([1], 1));
        expect(ime(tester)['text'], ' ');

        await imeType(tester, 'n');
        expect(
          _outline(controller),
          'paragraph:a\ndivider\nparagraph:n\nparagraph:world',
        );
        expect(controller.selection, _caret([2], 1));

        // 回车同样只在块后补一行。
        controller.select(_caret([1], 1));
        await tester.pump(Duration.zero);
        await imeType(tester, '\n');
        expect(
          _outline(controller),
          'paragraph:a\ndivider\nparagraph:\nparagraph:n\nparagraph:world',
        );
        expect(controller.selection, _caret([2]));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('a heading after an embed becomes a paragraph first', (
      tester,
    ) async {
      final controller = _document([
        _embed('divider'),
        _text('heading', 'title', data: {'level': 2}),
      ]);
      await pump(tester, controller, _caret([1]));

      await press(tester, LogicalKeyboardKey.backspace);
      expect(_outline(controller), 'divider\nparagraph:title');
      await press(tester, LogicalKeyboardKey.backspace);
      expect(_outline(controller), 'divider\nparagraph:title');
      expect(controller.selection, _caret([0], 1));
      await press(tester, LogicalKeyboardKey.backspace);
      expect(_outline(controller), 'paragraph:title');
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    double lastBlockBottom(DiaryEditorController controller) {
      final box = controller.document.root.children.last.renderBox!;
      return box.localToGlobal(Offset(0, box.size.height)).dy;
    }

    testWidgets(
      'tapping below a trailing embed stops the caret on its right and shows '
      'the keyboard, without adding a line',
      (tester) async {
        final controller = _document([_p('text'), _embed('divider')]);
        await pump(tester, controller, _caret([0], 4));
        // 用户收起了键盘。
        tester.testTextInput.hide();
        expect(tester.testTextInput.isVisible, isFalse);
        final left = tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx;

        await tester.tapAt(Offset(left + 40, lastBlockBottom(controller) + 60));
        await tester.pump();

        expect(_outline(controller), 'paragraph:text\ndivider');
        expect(controller.selection, _caret([1], 1));
        expect(tester.testTextInput.isVisible, isTrue);
        expect(ime(tester)['text'], ' ');

        await imeType(tester, 'x');
        expect(_outline(controller), 'paragraph:text\ndivider\nparagraph:x');
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'a desktop click below an image stops the caret on it, a right click '
      'does not',
      (tester) async {
        final controller = _document([_p('text'), _embed('image')]);
        await pump(tester, controller, _caret([0], 4));
        final below = Offset(
          tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx + 40,
          lastBlockBottom(controller) + 60,
        );

        await tester.tapAt(below);
        await tester.pump();
        expect(_outline(controller), 'paragraph:text\nimage');
        expect(controller.selection, _caret([1], 1));
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 右键是打开正文菜单，不动插入点（菜单的遮罩会吃掉之后的点按，放在
        // 最后）。
        controller.select(_caret([0], 4));
        await tester.pump();
        await tester.tapAt(below, buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(controller.selection, _caret([0], 4));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
