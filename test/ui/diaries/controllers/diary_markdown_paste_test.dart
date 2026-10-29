import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_clipboard.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_markdown_paste.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 粘贴纯文字时识别 Markdown 并转为块；代码块、表格格子与桌面的
/// Ctrl + Shift + V 粘贴原文。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;
  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboardText};
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });

  group('looksLikeDiaryMarkdown', () {
    for (final text in [
      '# 标题',
      '正文\n### 三级标题',
      '```\ncode\n```',
      '| a | b |\n|---|:-:|\n| 1 | 2 |',
      '> 引用',
      '- a\n- b',
      '* a\n+ b',
      '1. 一\n2. 二',
      '- [ ] 待办\n- [x] 完成',
      '这是**粗**体',
      '删掉~~这些~~字',
      '运行 `flutter test`',
      '见[文档](https://example.com/a)',
    ]) {
      test('true for ${jsonEncode(text)}', () {
        expect(looksLikeDiaryMarkdown(text), isTrue);
      });
    }
    for (final text in [
      '今天天气很好，去公园散步。\n晚上看了一部电影。',
      '- 只有一行破折号',
      '#话题 没有空格',
      '#',
      '星号 * 单独出现，下划线 _ 也是',
      'a * b * c',
      'https://example.com/path?q=1',
      '没有配对的 **粗体',
      '空心的 ** 星号 ** 不算',
      'a | b 只有竖线',
    ]) {
      test('false for ${jsonEncode(text)}', () {
        expect(looksLikeDiaryMarkdown(text), isFalse);
      });
    }
  });

  group('escapeLocalMarkdownImages', () {
    test('keeps remote images and code, escapes local images', () {
      expect(
        escapeLocalMarkdownImages(
          '![a](https://x.com/a.png) ![b](img/b.png) `![c](c.png)`\n'
          '```\n![d](d.png)\n```',
        ),
        '![a](https://x.com/a.png) !\\[b](img/b.png) `![c](c.png)`\n'
        '```\n![d](d.png)\n```',
      );
    });

    test('local images survive conversion as literal text', () {
      final nodes = diaryMarkdownPasteNodes('**看** ![图](./a.png)');
      expect(nodes, hasLength(1));
      final document = _document(nodes);
      expect(
        document.root.children.single.delta!.toPlainText(),
        '看 ![图](./a.png)',
      );
    });

    test('remote images become image blocks like HTML paste', () {
      final nodes = diaryMarkdownPasteNodes(
        '# 题\n![图](https://example.com/a.png)',
      );
      expect(nodes.map((node) => node['type']), contains('image'));
    });
  });

  DiaryEditorController editor([String text = '']) {
    final controller = DiaryEditorController.fromContent(text);
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> paste(DiaryEditorController controller, String text) async {
    clipboardText = text;
    await DiaryEditorClipboard.paste(controller);
  }

  test('markdown paste builds heading, bullets and bold paragraph', () async {
    final controller = editor();
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await paste(controller, '# 标题\n- a\n- b\n**粗**体');
    final children = controller.document.root.children.toList();
    expect(children.map((node) => node.type), [
      'heading',
      'bulleted_list',
      'bulleted_list',
      'paragraph',
    ]);
    expect(children[0].attributes['level'], 1);
    expect(children[0].delta!.toPlainText(), '标题');
    expect(children[1].delta!.toPlainText(), 'a');
    expect(children[2].delta!.toPlainText(), 'b');
    expect(children[3].delta!.toJson(), [
      {
        'insert': '粗',
        'attributes': {'bold': true},
      },
      {'insert': '体'},
    ]);
    controller.undo();
    expect(controller.plainText, isEmpty);
    expect(controller.document.root.children, hasLength(1));
  });

  test('a pipe table pastes as a valid table block', () async {
    final controller = editor();
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await paste(controller, '| a | b |\n|---|---|\n| 1 | **2** |');
    final table = controller.document.root.children.firstWhere(
      (node) => node.type == 'table',
    );
    final grid = DiaryTableGrid.of(
      jsonDecode(jsonEncode(table.toJson())) as Map<String, Object?>,
    );
    expect(grid, isNotNull);
    expect(grid!.rows, 2);
    expect(grid.cols, 2);
  });

  test('plain prose stays plain paragraphs', () async {
    final controller = editor();
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await paste(controller, '今天 * 天气好\n- 没别的');
    final children = controller.document.root.children.toList();
    expect(children.map((node) => node.type), ['paragraph', 'paragraph']);
    expect(controller.plainText, '今天 * 天气好\n- 没别的');
  });

  test('markdown pasted into a code block stays literal', () async {
    final controller = DiaryEditorController.fromContent(
      jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'code',
              'data': {
                'delta': [
                  {'insert': 'x'},
                ],
              },
            },
          ],
        },
      }),
    );
    addTearDown(controller.dispose);
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    await paste(controller, '**粗**');
    final code = controller.document.root.children.first;
    expect(code.type, 'code');
    expect(code.delta!.toJson(), [
      {'insert': 'x**粗**'},
    ]);
  });

  test('markdown pasted into a table cell stays literal', () async {
    final controller = editor();
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await paste(controller, '| a | b |\n|---|---|\n| 1 | 2 |');
    final table = controller.document.root.children.firstWhere(
      (node) => node.type == 'table',
    );
    final cell = table.children.first;
    final paragraph = cell.children.first;
    controller.select(
      af.Selection.collapsed(
        af.Position(path: paragraph.path, offset: paragraph.delta!.length),
      ),
    );
    await paste(controller, '**粗**');
    expect(paragraph.delta!.toJson().last['insert'], endsWith('**粗**'));
    expect(
      DiaryTableGrid.of(
        jsonDecode(jsonEncode(table.toJson())) as Map<String, Object?>,
      ),
      isNotNull,
    );
  });

  test('single-line markdown merges into the current paragraph', () async {
    final controller = editor('前后');
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    await paste(controller, '**粗**体');
    expect(controller.document.root.children, hasLength(1));
    expect(controller.document.root.children.first.delta!.toJson(), [
      {'insert': '前'},
      {
        'insert': '粗',
        'attributes': {'bold': true},
      },
      {'insert': '体后'},
    ]);
    controller.undo();
    expect(controller.plainText, '前后');
  });

  testWidgets('Ctrl+Shift+V on desktop pastes the literal text', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    harness.editorFocus.requestFocus();
    final controller = harness.controller;
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    await tester.pumpAndSettle();
    clipboardText = '\n# 标题\n**粗**';
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.plainText, 'hello\n# 标题\n**粗**');
    expect(
      controller.document.root.children.map((node) => node.type),
      everyElement('paragraph'),
    );

    // 普通 Ctrl + V 照常转换（开头的空行不产出段落；光标前的文字与首个
    // 块合并，与 HTML 粘贴同一上游规则）。
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.plainText, 'hello');
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.document.root.children.map((node) => node.type), [
      'heading',
      'paragraph',
    ]);
    expect(controller.plainText, 'hello标题\n粗');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

af.Document _document(List<Map<String, dynamic>> nodes) =>
    af.Document.fromJson({
      'document': {'type': 'page', 'children': nodes},
    });
