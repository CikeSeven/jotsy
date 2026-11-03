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
  af.Node? armed(DiaryEditorController controller) =>
      DiaryArmedEmbed.of(controller.state).node.value;

  group('backspace at the start of a line after an embed', () {
    // 所有嵌入块类型（图片、视频、音频、附件、分隔线、卡片、未识别的旧
    // 嵌入）同一条规则；以后新增的类型登记进集合即自动覆盖。
    for (final type in kDiaryEmbedBlockTypes) {
      test('selects the $type first, then deletes it in place', () {
        final controller = _document([_p('before'), _embed(type), _p('after')]);
        final before = controller.contentJson;
        final embed = controller.document.root.children[1];
        controller.state.selection = _caret([2]);

        // 第一次：只选中，正文与插入点都不动。
        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(controller.contentJson, before);
        expect(controller.state.selection, _caret([2]));
        expect(armed(controller), same(embed));

        // 第二次：删掉它，本行原地上移，选中随之取消。
        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(_outline(controller), 'paragraph:before\nparagraph:after');
        expect(controller.state.selection, _caret([1]));
        expect(armed(controller), isNull);
        controller.undo();
        expect(controller.contentJson, before);
      });
    }

    for (final type in kDiaryEmbedBlockTypes) {
      test('on an empty line removes that line and selects the $type', () {
        // 嵌入块下面连着几个空行：第一次退格删掉紧挨着的空行并选中嵌入块，
        // 第二次删掉嵌入块，下面的空行原样留着。
        final controller = _document([
          _p('a'),
          _embed(type),
          _p(''),
          _p(''),
          _p(''),
          _p('b'),
        ]);
        final embed = controller.document.root.children[1];
        controller.state.selection = _caret([2]);

        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(
          _outline(controller),
          'paragraph:a\n$type\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(controller.state.selection, _caret([2]));
        expect(armed(controller), same(embed));

        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(
          _outline(controller),
          'paragraph:a\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(controller.state.selection, _caret([1]));
        expect(armed(controller), isNull);
      });
    }

    test('keeps the empty line when nothing writable follows it', () {
      for (final tail in [
        <Map<String, Object?>>[],
        [_embed('video')],
      ]) {
        final controller = _document([
          _p('before'),
          _embed('image'),
          _p(''),
          ...tail,
        ]);
        controller.state.selection = _caret([2]);

        // 空行是插入点唯一能放的地方：不删，只选中上面的图片。
        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(controller.document.root.children, hasLength(3 + tail.length));
        expect(armed(controller)?.type, 'image');

        expect(backspaceDiaryEmbed(controller.state), isTrue);
        expect(
          _outline(controller),
          [
            'paragraph:before',
            'paragraph:',
            ...tail.map((_) => 'video'),
          ].join('\n'),
        );
        expect(controller.state.selection, _caret([1]));
      }
    });

    test('anything else in between cancels the selection', () {
      final controller = _document([_p('a'), _embed('image'), _p('after')]);
      controller.state.selection = _caret([2]);

      // 插入点挪开再回来：重新选中，不删除。
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      controller.state.selection = _caret([2], 3);
      expect(armed(controller), isNull);
      controller.state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(controller.document.root.children, hasLength(3));

      // 上游重设同一选区不算挪开。
      controller.state.selection = _caret([2]);
      expect(armed(controller)?.type, 'image');

      // 正文有改动（打字）即取消。
      final transaction = controller.state.transaction
        ..insertText(controller.document.root.children[0], 1, 'x');
      controller.apply(transaction, updateSelection: false);
      expect(armed(controller), isNull);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(controller.document.root.children, hasLength(3));
      expect(armed(controller)?.type, 'image');
    });

    test('reaches an embed nested as the last child of the block above', () {
      final controller = _document([
        _text('bulleted_list', 'item', children: [_embed('image')]),
        _p('after'),
      ]);
      controller.state.selection = _caret([1]);

      expect(backspaceDiaryEmbed(controller.state), isTrue);
      expect(backspaceDiaryEmbed(controller.state), isTrue);
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
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      // 上一块是文字，或在文档开头。
      controller.state.selection = _caret([3]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      controller.state.selection = _caret([0]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      // 收起的折叠块里的图片看不见，不算紧挨着。
      controller.state.selection = _caret([4]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      // 插入点盖在嵌入块上（上游删掉它）与非折叠选区。
      controller.state.selection = _caret([1]);
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      controller.state.selection = af.Selection(
        start: af.Position(path: [2]),
        end: af.Position(path: [2], offset: 3),
      );
      expect(backspaceDiaryEmbed(controller.state), isFalse);
      expect(controller.contentJson, before);
      expect(armed(controller), isNull);
    });
  });

  test('Delete at the end of a line selects, then removes the embed below', () {
    final controller = _document([_p('a'), _embed('image'), _p('b')]);
    controller.state.selection = _caret([0], 1);

    expect(deleteForwardDiaryEmbed(controller.state), isTrue);
    expect(controller.document.root.children, hasLength(3));
    expect(armed(controller)?.type, 'image');
    expect(deleteForwardDiaryEmbed(controller.state), isTrue);
    expect(_outline(controller), 'paragraph:a\nparagraph:b');
    expect(controller.state.selection, _caret([0], 1));

    // 不在行末、下一块是文字：交给上游。
    controller.state.selection = _caret([0]);
    expect(deleteForwardDiaryEmbed(controller.state), isFalse);
    controller.state.selection = _caret([0], 1);
    expect(deleteForwardDiaryEmbed(controller.state), isFalse);
  });

  group('soft keyboard deletion', () {
    TextEditingDeltaDeletion deletion(String text) => TextEditingDeltaDeletion(
      oldText: text,
      deletedRange: const TextRange.collapsed(0),
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );

    test('selects, then deletes the embed above a line', () async {
      final controller = _document([_embed('divider'), _p('after')]);
      controller.state.selection = _caret([1]);
      final interceptor = DiaryEmbedKeyboardInterceptor();

      expect(
        await interceptor.interceptDelete(deletion('after'), controller.state),
        isTrue,
      );
      expect(armed(controller)?.type, 'divider');
      expect(
        await interceptor.interceptDelete(deletion('after'), controller.state),
        isTrue,
      );
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
      expect(armed(controller), isNull);
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

    /// 嵌入块上选中样式的不透明度（0 为没有选中）。
    double selectedLook(WidgetTester tester, af.Node node) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey('diary-armed-embed-${node.id}')),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    testWidgets('Backspace and Delete keys select, then delete the embed', (
      tester,
    ) async {
      final controller = _document([
        _p('before'),
        _embed('divider'),
        _p('after'),
        _embed('divider'),
        _p('end'),
      ]);
      final first = controller.document.root.children[1];
      await pump(tester, controller, _caret([2]));
      expect(selectedLook(tester, first), 0);

      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller.document.root.children, hasLength(5));
      expect(controller.selection, _caret([2]));
      expect(selectedLook(tester, first), 1);

      await press(tester, LogicalKeyboardKey.backspace);
      expect(
        _outline(controller),
        'paragraph:before\nparagraph:after\ndivider\nparagraph:end',
      );
      expect(controller.selection, _caret([1]));

      controller.select(_caret([1], 5));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.delete);
      expect(controller.document.root.children, hasLength(4));
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

    Future<void> imeEdit(
      WidgetTester tester,
      String Function(String text, int caret) edit,
      int Function(int caret) caretAfter,
    ) async {
      final text = ime(tester)['text'] as String;
      final caret = ime(tester)['selectionBase'] as int;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: edit(text, caret),
          selection: TextSelection.collapsed(offset: caretAfter(caret)),
        ),
      );
      // 拦截后的输入法同步是零时长计时器：pump 要带时长才会推进假时钟。
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
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
      'soft keyboard: below an image followed by empty lines the first '
      'backspace removes the line and selects the image',
      (tester) async {
        final controller = _document([
          _p('a'),
          _embed('image'),
          _p(''),
          _p(''),
          _p(''),
          _p('b'),
        ]);
        final image = controller.document.root.children[1];
        await pump(tester, controller, _caret([2]));
        expect(ime(tester)['text'], ' ');

        await imeBackspace(tester);
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(controller.selection, _caret([2]));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        expect(selectedLook(tester, image), 1);

        // 插入点一直在文字行里，输入法连着它：打字照常写进这一行并取消
        // 选中。
        await imeType(tester, 'n');
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:n\nparagraph:\nparagraph:b',
        );
        expect(controller.selection, _caret([2], 1));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        expect(selectedLook(tester, image), 0);

        // 删掉刚打的字、回到行首：这一行又是空行，再退格同样删掉它并选中
        // 图片；再按一次删掉图片，剩下的空行原样留着。
        await imeBackspace(tester);
        expect(controller.selection, _caret([2]));
        expect(DiaryArmedEmbed.of(controller.state).node.value, isNull);
        await imeBackspace(tester);
        expect(DiaryArmedEmbed.of(controller.state).node.value, same(image));
        expect(
          _outline(controller),
          'paragraph:a\nimage\nparagraph:\nparagraph:b',
        );
        await imeBackspace(tester);
        expect(_outline(controller), 'paragraph:a\nparagraph:\nparagraph:b');
        expect(controller.selection, _caret([1]));
        expect(ime(tester)['text'], ' ');
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'soft keyboard: after the empty line goes the input follows the next '
      'line',
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
        expect(controller.selection, _caret([2]));
        // 拦截后上游把输入法退回了空行的编辑值，随后按新的一行重新同步。
        expect(ime(tester)['text'], ' world');
        expect(ime(tester)['selectionBase'], 1);

        await imeType(tester, 'n');
        expect(_outline(controller), 'paragraph:a\ndivider\nparagraph:nworld');
        expect(controller.selection, _caret([2], 1));
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
      await press(tester, LogicalKeyboardKey.backspace);
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
