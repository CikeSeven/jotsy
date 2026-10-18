import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';
import 'package:node_diary/core/services/journal_import_html.dart';
import 'package:node_diary/core/services/journal_import_markdown.dart';
import 'package:node_diary/core/services/journal_import_style.dart';

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

    test('maps lists, headings, quotes and drops fonts', () {
      final ops = _html(
        '<h1>Title</h1><p>Hi <span style="font-family:Serif;font-weight:bold">'
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

    test('keeps colours, highlights, sizes, alignment and dividers', () {
      final ops = _html(
        '<p style="text-align: center">'
        '<span style="color: rgb(250, 42, 45)">红</span>'
        '<span style="color:#333333">墨</span>'
        '<font color="#00aaee" size="5">蓝</font>'
        '<mark>荧光</mark>'
        '<span style="background-color: rgba(255, 191, 0, 0.38)">黄底</span>'
        '<span style="background-color:#ffffff">白底</span>'
        '<span style="font-size: 12px">小</span>'
        '<big>大</big></p>'
        '<hr>'
        '<div align="right"><p>右<b style="font-size:2em">特大</b></p>'
        '<p style="text-align:left">取消</p></div>'
        '<center><img src="https://a.b/c.png"></center>',
      );
      expect(ops, [
        {
          'insert': '红',
          'attributes': {'color': '#FFFA2A2D'},
        },
        {'insert': '墨'},
        {
          'insert': '蓝',
          'attributes': {'color': '#FF00AAEE', 'size': 'large'},
        },
        {
          'insert': '荧光',
          'attributes': {'background': journalHighlightColor},
        },
        {
          'insert': '黄底',
          'attributes': {'background': '#61FFBF00'},
        },
        {'insert': '白底'},
        {
          'insert': '小',
          'attributes': {'size': 'small'},
        },
        {
          'insert': '大',
          'attributes': {'size': 'large'},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n右'},
        {
          'insert': '特大',
          'attributes': {'bold': true, 'size': 'huge'},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'right'},
        },
        {'insert': '取消\n'},
        {
          'insert': {'image': 'https://a.b/c.png'},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]);
    });

    test('an inner default colour or size resets the outer one', () {
      final ops = _html(
        '<p>这是一段普通正文</p>'
        '<p><span style="color:#fa2a2d;font-size:20px;background:#ffbf00">'
        '外<span style="color:black;font-size:16px;background:transparent">'
        '内</span><span style="color:var(--x)">变量</span></span></p>',
      );
      expect(ops, [
        {'insert': '这是一段普通正文\n'},
        {
          'insert': '外',
          'attributes': {
            'color': '#FFFA2A2D',
            'size': 'large',
            'background': '#FFFFBF00',
          },
        },
        {
          'insert': '内',
          'attributes': {'background': '#FFFFBF00'},
        },
        {
          'insert': '变量',
          'attributes': {
            'color': '#FFFA2A2D',
            'size': 'large',
            'background': '#FFFFBF00',
          },
        },
        {'insert': '\n'},
      ]);
    });

    test('the dominant font size of a note counts as its body size', () {
      final ops = _html(
        '<div style="font-size:12px"><p>整篇剪藏都是小号字</p>'
        '<p><span style="font-size:18px">大</span>'
        '<span style="font-size:9px">小</span></p></div>',
      );
      expect(ops, [
        {'insert': '整篇剪藏都是小号字\n'},
        {
          'insert': '大',
          'attributes': {'size': 'huge'},
        },
        {
          'insert': '小',
          'attributes': {'size': 'small'},
        },
        {'insert': '\n'},
      ]);
    });

    test('code blocks are never aligned', () {
      final ops = _html('<div style="text-align:center"><pre>x</pre></div>');
      expect(ops, [
        {'insert': 'x'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
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
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\ncode  kept'},
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

    test('inline HTML colours, highlights and rules in Markdown notes', () {
      final writer = JournalDeltaWriter();
      JournalMarkdownConverter(writer, inlineHtml: true).append(
        '<span style="color:#e03e2d">红</span>与<mark>亮</mark>'
        '<font color="#00aaee"><b>蓝</b></font>\n<hr>\n***',
      );
      final ops = jsonDecode(writer.build().contentJson) as List<Object?>;
      expect(ops, [
        {
          'insert': '红',
          'attributes': {'color': '#FFE03E2D'},
        },
        {'insert': '与'},
        {
          'insert': '亮',
          'attributes': {'background': journalHighlightColor},
        },
        {
          'insert': '蓝',
          'attributes': {'bold': true, 'color': '#FF00AAEE'},
        },
        {'insert': '\n'},
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n'},
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n'},
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
