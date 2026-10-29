import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/core/services/journal_import_block_writer.dart';
import 'package:node_diary/core/services/journal_import_html.dart';
import 'package:node_diary/core/services/journal_import_markdown.dart';
import 'package:node_diary/core/services/journal_import_quill.dart';

/// 导入 HTML / Markdown 后存储的块文档（未经读取修正，原样）。
Map<String, Object?> _html(String html, {JournalEmbedResolver? resolve}) {
  final writer = JournalBlockWriter();
  JournalHtmlConverter(
    writer,
    resolveEmbed: resolve,
    resolveLink: resolve,
  ).appendHtml(html);
  return _stored(writer);
}

Map<String, Object?> _markdown(
  String markdown, {
  JournalEmbedResolver? resolve,
  bool inlineHtml = false,
}) {
  final writer = JournalBlockWriter();
  JournalMarkdownConverter(
    writer,
    resolveEmbed: resolve,
    resolveLink: resolve,
    inlineHtml: inlineHtml,
  ).append(markdown);
  return _stored(writer);
}

Map<String, Object?> _quill(List<Object?> ops) {
  final writer = JournalBlockWriter();
  appendJournalQuillOps(writer, ops, resolveEmbed: (_) => const []);
  return _stored(writer);
}

Map<String, Object?> _stored(JournalBlockWriter writer) =>
    (jsonDecode(writer.build().contentJson) as Map).cast<String, Object?>();

List<Map<String, Object?>> _top(Map<String, Object?> document) =>
    diaryBlockChildren(diaryBlocksRoot(document)!);

/// 每块一行：层级缩进 + 类型 + 文字。
String _outline(Map<String, Object?> document) => [
  for (final (node, depth) in walkDiaryBlocks(document))
    '${'  ' * depth}${node['type']} ${diaryBlockText(node)}'.trimRight(),
].join('\n');

/// 读取时的整理不改动导入写出的结构。
void _expectRoundTrip(Map<String, Object?> document) {
  expect(decodeStoredDiaryBlocks(jsonEncode(document)), document);
}

void main() {
  group('heading levels', () {
    test('HTML h5 keeps level 5', () {
      final heading = _top(_html('<h5>Five</h5>')).single;
      expect(heading['type'], 'heading');
      expect(diaryBlockData(heading)['level'], 5);
    });

    test('Markdown and Quill headings keep levels up to 6', () {
      final markdown = _top(_markdown('###### Six'));
      expect(diaryBlockData(markdown.single)['level'], 6);
      final quill = _quill([
        {'insert': 'Four'},
        {
          'insert': '\n',
          'attributes': {'header': 4},
        },
      ]);
      expect(diaryBlockData(_top(quill).single)['level'], 4);
    });
  });

  group('superscript and subscript', () {
    test('HTML sup and sub become the script attribute', () {
      final delta = diaryBlockDelta(
        _top(_html('<p>x<sup>2</sup> H<sub>2</sub>O</p>')).single,
      );
      expect(delta, [
        {'insert': 'x'},
        {
          'insert': '2',
          'attributes': {'script': 'super'},
        },
        {'insert': ' H'},
        {
          'insert': '2',
          'attributes': {'script': 'sub'},
        },
        {'insert': 'O'},
      ]);
    });

    test('CSS vertical-align super and sub are read too', () {
      final delta = diaryBlockDelta(
        _top(
          _html(
            '<p><span style="vertical-align: super">a</span>'
            '<span style="vertical-align:sub">b</span></p>',
          ),
        ).single,
      );
      expect(delta, [
        {
          'insert': 'a',
          'attributes': {'script': 'super'},
        },
        {
          'insert': 'b',
          'attributes': {'script': 'sub'},
        },
      ]);
    });

    test('Markdown inline HTML sup is kept only with inline HTML on', () {
      final on = diaryBlockDelta(
        _top(_markdown('m<sup>3</sup>', inlineHtml: true)).single,
      );
      expect(on.last, {
        'insert': '3',
        'attributes': {'script': 'super'},
      });
      final off = _markdown('m<sup>3</sup>');
      expect(diaryBlocksPlainText(off), contains('<sup>'));
    });

    test('third-party Quill script is kept, unknown values dropped', () {
      final document = _quill([
        {
          'insert': 'a',
          'attributes': {'script': 'super'},
        },
        {
          'insert': 'b',
          'attributes': {'script': 'mid'},
        },
        {'insert': '\n'},
      ]);
      expect(diaryBlockDelta(_top(document).single), [
        {
          'insert': 'a',
          'attributes': {'script': 'super'},
        },
        {'insert': 'b'},
      ]);
    });
  });

  group('details become toggle lists', () {
    test('open details is an expanded toggle with its content as children', () {
      final document = _html(
        '<details open><summary>T</summary><p>a</p></details><p>after</p>',
      );
      final toggle = _top(document).first;
      expect(toggle['type'], 'toggle_list');
      expect(diaryBlockText(toggle), 'T');
      expect(diaryBlockData(toggle)['collapsed'], false);
      expect(
        _outline(document),
        'toggle_list T\n  paragraph a\nparagraph after',
      );
      _expectRoundTrip(document);
    });

    test('details without open is collapsed and nested lists stay nested', () {
      final document = _html(
        '<details><summary><b>Title</b></summary>'
        '<ul><li>one<ul><li>deep</li></ul></li></ul>'
        '<details><summary>inner</summary>x</details></details>',
      );
      final toggle = _top(document).single;
      expect(diaryBlockData(toggle)['collapsed'], true);
      expect(diaryBlockDelta(toggle), [
        {
          'insert': 'Title',
          'attributes': {'bold': true},
        },
      ]);
      expect(
        _outline(document),
        'toggle_list Title\n'
        '  bulleted_list one\n'
        '    bulleted_list deep\n'
        '  toggle_list inner\n'
        '    paragraph x',
      );
      _expectRoundTrip(document);
    });

    test('details without summary stays plain text like a div', () {
      final document = _html('<details><p>a</p></details>');
      expect(_outline(document), 'paragraph a');
    });
  });

  group('HTML tables', () {
    test('a regular table with th becomes a table with a header row', () {
      final document = _html(
        '<p>before</p><table>'
        '<tr><th>Name</th><th>Qty</th></tr>'
        '<tr><td><b>Apple</b></td><td align="right">3</td></tr>'
        '<tr><td>Pear</td><td></td></tr>'
        '</table><p>after</p>',
      );
      final top = _top(document);
      expect(top.map((node) => node['type']), [
        'paragraph',
        'table',
        'paragraph',
      ]);
      final grid = DiaryTableGrid.of(top[1])!;
      expect((grid.rows, grid.cols, grid.headerRow), (3, 2, true));
      expect(grid.rowTexts().toList(), ['Name | Qty', 'Apple | 3', 'Pear | ']);
      final apple = grid.textBlocksAt(1, 0).single;
      expect(diaryBlockDelta(apple), [
        {
          'insert': 'Apple',
          'attributes': {'bold': true},
        },
      ]);
      expect(diaryBlockData(grid.textBlocksAt(1, 1).single)['align'], 'right');
      // 空格子有一个空段落，读取时不需要补。
      expect(grid.textBlocksAt(2, 1).single['type'], 'paragraph');
      _expectRoundTrip(document);
    });

    test('a thead makes the first row a header; plain td does not', () {
      final withHead = _top(
        _html(
          '<table><thead><tr><td>h</td></tr></thead>'
          '<tbody><tr><td>b</td></tr></tbody></table>',
        ),
      ).single;
      expect(DiaryTableGrid.of(withHead)!.headerRow, isTrue);
      final plain = _top(_html('<table><tr><td>a</td></tr></table>')).single;
      expect(DiaryTableGrid.of(plain)!.headerRow, isFalse);
      expect(diaryBlockData(plain).containsKey('headerRow'), isFalse);
    });

    test('a table with colspan stays flattened text', () {
      final document = _html(
        '<table><tr><td colspan="2">wide</td></tr>'
        '<tr><td>a</td><td>b</td></tr></table>',
      );
      expect(_top(document).any((node) => node['type'] == 'table'), isFalse);
      expect(diaryBlocksPlainText(document), contains('wide'));
      expect(diaryBlocksPlainText(document), contains('a b'));
    });

    test('ragged rows, images or nested tables keep the flattened text', () {
      for (final html in [
        '<table><tr><td>a</td><td>b</td></tr><tr><td>c</td></tr></table>',
        '<table><tr><td><img src="https://x/y.png">a</td></tr></table>',
        '<table><tr><td><ul><li>a</li></ul></td></tr></table>',
        '<table><tr><td><table><tr><td>a</td></tr></table></td></tr></table>',
        '<table><caption>cap</caption><tr><td>a</td></tr></table>',
      ]) {
        final document = _html(html);
        expect(
          walkDiaryBlocks(document).any((entry) => entry.$1['type'] == 'table'),
          isFalse,
          reason: html,
        );
        expect(diaryBlocksPlainText(document), contains('a'), reason: html);
      }
    });

    test('a cell link to a local file never calls the resolver twice', () {
      var calls = 0;
      final document = _html(
        '<table><tr><td><a href="file.pdf">doc</a></td></tr></table>',
        resolve: (source) {
          calls++;
          return {
            'file': {'path': source, 'name': source},
          };
        },
      );
      expect(calls, 1);
      expect(_top(document).any((node) => node['type'] == 'table'), isFalse);
    });

    test('more than 12 columns stays flattened text', () {
      final cells = List.generate(13, (i) => '<td>$i</td>').join();
      final document = _html('<table><tr>$cells</tr></table>');
      expect(_top(document).any((node) => node['type'] == 'table'), isFalse);
    });
  });

  group('Markdown pipe tables', () {
    test('a GFM pipe table becomes a table with a header row', () {
      final document = _markdown(
        'intro\n'
        '| Name | Note |\n'
        '| :--- | ---: |\n'
        '| **a** | x \\| y |\n'
        '| b |\n'
        'after',
      );
      final top = _top(document);
      expect(top.map((node) => node['type']), [
        'paragraph',
        'table',
        'paragraph',
      ]);
      final grid = DiaryTableGrid.of(top[1])!;
      expect((grid.rows, grid.cols, grid.headerRow), (3, 2, true));
      expect(grid.rowTexts().toList(), ['Name | Note', 'a | x | y', 'b | ']);
      expect(diaryBlockDelta(grid.textBlocksAt(1, 0).single), [
        {
          'insert': 'a',
          'attributes': {'bold': true},
        },
      ]);
      _expectRoundTrip(document);
    });

    test('tables without leading pipes and ending at a blank line', () {
      final document = _markdown('a | b\n--|--\n1 | 2\n\nnext');
      final grid = DiaryTableGrid.of(_top(document).first)!;
      expect(grid.rowTexts().toList(), ['a | b', '1 | 2']);
      expect(diaryBlockText(_top(document).last), 'next');
    });

    test('a malformed pipe table stays plain lines', () {
      for (final markdown in [
        '| a | b |\n| --- |\n| 1 | 2 |',
        '| a | b |\n| x | y |',
        '| a |\n| --- |\n| 1 | 2 |',
        '| a |\n| --- |\n| ![](https://x/y.png) |',
      ]) {
        final document = _markdown(markdown);
        expect(
          _top(document).any((node) => node['type'] == 'table'),
          isFalse,
          reason: markdown,
        );
        expect(
          diaryBlocksPlainText(document),
          contains('| a |'),
          reason: markdown,
        );
      }
    });
  });
}
