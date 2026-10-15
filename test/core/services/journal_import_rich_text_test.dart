import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';
import 'package:node_diary/core/services/journal_import_html.dart';
import 'package:node_diary/core/services/journal_import_markdown.dart';

List<Object?> _html(String html, {JournalEmbedResolver? resolve}) {
  final writer = JournalDeltaWriter();
  JournalHtmlConverter(writer, resolveEmbed: resolve).appendHtml(html);
  return jsonDecode(writer.build().contentJson) as List<Object?>;
}

List<Object?> _markdown(String markdown, {JournalEmbedResolver? resolve}) {
  final writer = JournalDeltaWriter();
  JournalMarkdownConverter(writer, resolveEmbed: resolve).append(markdown);
  return jsonDecode(writer.build().contentJson) as List<Object?>;
}

void main() {
  group('JournalHtmlConverter', () {
    test('keeps Journey paragraphs and blank lines, trims the edges', () {
      final ops = _html(
        '<p dir="auto">Rode my new bike!&nbsp;</p>\n<p dir="auto"></p>\n'
        '<p dir="auto">It looks <em>very dark grey</em>!</p>\n'
        '<p dir="auto"></p>',
      );
      expect(ops, [
        {'insert': 'Rode my new bike!\n\nIt looks '},
        {
          'insert': 'very dark grey',
          'attributes': {'italic': true},
        },
        {'insert': '!\n'},
      ]);
    });

    test('maps lists, headings, quotes and drops unsupported styles', () {
      final ops = _html(
        '<h1>Title</h1><p>Hi <span style="color:red;font-weight:bold">'
        'there</span> <a href="https://a.b">link</a></p>'
        '<ul><li>one</li><li>two<ul><li>nested</li></ul></li></ul>'
        '<ol><li>first</li></ol>'
        '<ul><li data-checked="true">done</li></ul>'
        '<blockquote>quote</blockquote>',
      );
      expect(ops, [
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {'insert': 'Hi '},
        {
          'insert': 'there',
          'attributes': {'bold': true},
        },
        {'insert': ' '},
        {
          'insert': 'link',
          'attributes': {'link': 'https://a.b'},
        },
        {'insert': '\none'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'two'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'nested'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
        {'insert': 'first'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'done'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
        {'insert': 'quote'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ]);
    });

    test('turns br into line breaks and gives media their own lines', () {
      final ops = _html(
        'A&nbsp;B<br>C <img src="a.jpg"> after<div><br></div>end',
        resolve: (source) => {'image': '/staged/$source'},
      );
      expect(ops, [
        {'insert': 'A B\nC\n'},
        {
          'insert': {'image': '/staged/a.jpg'},
        },
        {'insert': '\nafter\n\nend\n'},
      ]);
    });

    test('drops unresolved local media but keeps remote images', () {
      final ops = _html(
        '<p>x</p><img src="missing.jpg"><img src="https://e.x/p.png">',
        resolve: (_) => null,
      );
      expect(ops, [
        {'insert': 'x\n'},
        {
          'insert': {'image': 'https://e.x/p.png'},
        },
        {'insert': '\n'},
      ]);
    });

    test('produces an editable empty document for empty input', () {
      expect(_html('<p></p>  '), [
        {'insert': '\n'},
      ]);
    });
  });

  group('JournalMarkdownConverter', () {
    test('keeps every source line and maps Day One block syntax', () {
      final ops = _markdown(
        'Line one\nLine two\n\n## Sub\n- a\n  - b\n1. c\n- [x] done\n'
        '> quote\n---\n```\ncode  kept\n```',
      );
      expect(ops, [
        {'insert': 'Line one\nLine two\n\nSub'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'b'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
        {'insert': 'c'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'done'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
        {'insert': 'quote'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
        {'insert': 'code  kept'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
      ]);
    });

    test('parses inline formatting and Day One escapes', () {
      final ops = _markdown(
        r'**bold** *it* ~~gone~~ `code` [web](https://x.y) 1\. not a list\!',
      );
      expect(ops, [
        {
          'insert': 'bold',
          'attributes': {'bold': true},
        },
        {'insert': ' '},
        {
          'insert': 'it',
          'attributes': {'italic': true},
        },
        {'insert': ' '},
        {
          'insert': 'gone',
          'attributes': {'strike': true},
        },
        {'insert': ' '},
        {
          'insert': 'code',
          'attributes': {'code': true},
        },
        {'insert': ' '},
        {
          'insert': 'web',
          'attributes': {'link': 'https://x.y'},
        },
        {'insert': ' 1. not a list!\n'},
      ]);
    });

    test('a media-only line becomes one embed without an extra blank line', () {
      final ops = _markdown(
        'Before\n![](dayone-moment://ABC)\nAfter',
        resolve: (source) => source == 'dayone-moment://ABC'
            ? {'image': '/staged/abc.jpeg'}
            : null,
      );
      expect(ops, [
        {'insert': 'Before\n'},
        {
          'insert': {'image': '/staged/abc.jpeg'},
        },
        {'insert': '\nAfter\n'},
      ]);
    });

    test('the plain-text mirror matches the stored document', () {
      final writer = JournalDeltaWriter();
      JournalMarkdownConverter(
        writer,
        resolveEmbed: (_) => {'image': '/staged/x.jpg'},
      ).append('# Head\n![](dayone-moment://X)\n- item **b**\n\n');
      final built = writer.build();
      expect(built.contentText, deltaJsonToPlainText(built.contentJson));
      expect(built.contentText, 'Head\n\nitem b');
    });
  });
}
