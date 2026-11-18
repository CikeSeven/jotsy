import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/services/ai/ai_vision.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/tools/ai_diary_markdown.dart';
import 'package:node_diary/ui/ai/tools/ai_diary_markdown_edit.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';

/// 智能体读写日记正文的写法（正文 Markdown）与按它改正文：读到的就是改的；
/// 没改到的块原样保留（写法表达不了的属性也不丢）；格式、块类型、列表、
/// 表格、代码块、媒体标记与对话图片都能改；对不上、不唯一、重叠、没改动
/// 时整次不写并说明原因。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  const chat = <AiChatImage>[
    AiChatImage(ref: 'P1', messageId: 'm', index: 0, path: '/m/sea.jpg'),
    AiChatImage(ref: 'P2', messageId: 'm', index: 1, path: ''),
  ];

  Map<String, Object?> doc(List<Map<String, Object?>> children) => {
    'document': {'type': 'page', 'children': children},
  };
  Map<String, Object?> block(
    String type,
    String text, {
    Map<String, Object?> data = const {},
    Map<String, Object?>? attributes,
    List<Map<String, Object?>>? children,
  }) => {
    'type': type,
    'data': {
      ...data,
      'delta': [
        if (text.isNotEmpty) {'insert': text, 'attributes': ?attributes},
      ],
    },
    'children': ?children,
  };
  Map<String, Object?> para(String text) => block('paragraph', text);
  Map<String, Object?> image(String url, {Map<String, Object?>? extra}) => {
    'type': 'image',
    'data': {'url': url, ...?extra},
  };
  List<Map<String, Object?>> top(Map<String, Object?> document) =>
      ((document['document']! as Map)['children']! as List)
          .cast<Map<String, Object?>>();
  String text(Map<String, Object?> node) => [
    for (final op in ((node['data']! as Map)['delta']! as List))
      (op as Map)['insert'],
  ].join();

  AiDiaryEditResult edit(
    Map<String, Object?> document,
    List<(String, String)> edits, {
    List<AiChatImage> chatImages = chat,
  }) => aiEditDiaryMarkdown(
    document,
    l10n: zh,
    chatImages: chatImages,
    edits: [for (final (old, now) in edits) (oldText: old, newText: now)],
  );
  String markdown(Map<String, Object?> document) =>
      aiDiaryMarkdown(document, zh).text;
  Matcher fails(Object message) => throwsA(
    isA<AiToolFailure>().having((e) => e.message, 'message', message),
  );

  group('reading', () {
    test('blocks, formatting and media are written the way edits take', () {
      final document = doc([
        block('heading', '标题', data: {'level': 2}),
        block(
          'paragraph',
          '红色',
          attributes: {'font_color': '#FFE53935', 'bold': true},
        ),
        block('bulleted_list', '一', children: [block('numbered_list', '子')]),
        image('/a.jpg'),
        {
          'type': 'video',
          'data': {'url': '/v.mp4'},
        },
        {
          'type': 'attachment',
          'data': {'path': '/f.pdf', 'name': '说明书.pdf'},
        },
        {
          'type': 'link_card',
          'data': {'target': 'jotsy://diary/x', 'title': '旧日记'},
        },
        {'type': 'divider'},
        para('# 不是标题'),
        para(''),
        block('callout', '提示', data: {'icon': '💡', 'tone': 'yellow'}),
        block('code', 'a\nb', data: {'language': 'dart'}),
        image('/a.jpg'),
        image('/b.jpg'),
      ]);
      expect(
        markdown(document),
        [
          '## 标题',
          '<span style="color: #E53935">**红色**</span>',
          '- 一',
          '  1. 子',
          '[图片 1]',
          '[视频 1]',
          '[附件 1: 说明书.pdf]',
          '[链接卡片 1: 旧日记]',
          '---',
          r'\# 不是标题',
          '',
          '<callout icon="💡" tone="yellow">提示</callout>',
          '```dart',
          'a',
          'b',
          '```',
          // 同一张图第二次出现沿用第一次的编号（与 view_images 相同）。
          '[图片 1]',
          '[图片 2]',
        ].join('\n'),
      );
      expect(AiVisionImages.sourcesOf(jsonEncode(document)), [
        '/a.jpg',
        '/b.jpg',
      ]);
    });

    test('an empty body is one empty line', () {
      expect(markdown(diaryBlocksFromPlainText('')), '');
      expect(markdown(doc([])), '');
    });
  });

  group('editing text', () {
    test('an edit inside one line keeps every other block exactly', () {
      final heading = block('heading', '周末', data: {'level': 1});
      final red = block(
        'paragraph',
        '红色',
        attributes: {'font_color': '#FFE53935'},
      );
      // 起始号写法里没有：没改到这一行时原样保留。
      final numbered = block('numbered_list', '第五', data: {'number': 5});
      final photo = image('/a.jpg', extra: {'width': 120.0});
      final document = doc([heading, red, para('今天去了公园'), numbered, photo]);
      final result = edit(document, [('公园', '海边')]);
      expect(
        result.document,
        doc([heading, red, para('今天去了海边'), numbered, photo]),
      );
      expect(result.removedMarks, isEmpty);
      expect(result.changes, ['- 今天去了公园', '+ 今天去了海边']);
    });

    test('inline formatting written in Markdown is kept and can change', () {
      final document = doc([
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': '今天'},
              {
                'insert': '很',
                'attributes': {'bold': true},
              },
              {'insert': '开心'},
            ],
          },
        },
      ]);
      expect(markdown(document), '今天**很**开心');
      final kept = top(edit(document, [('开心', '高兴')]).document).single;
      expect((kept['data']! as Map)['delta'], [
        {'insert': '今天'},
        {
          'insert': '很',
          'attributes': {'bold': true},
        },
        {'insert': '高兴'},
      ]);
      final italic = top(edit(document, [('**很**', '*很*')]).document).single;
      expect(((italic['data']! as Map)['delta'] as List)[1], {
        'insert': '很',
        'attributes': {'italic': true},
      });
    });

    test('a block mark changes the block type; block options stay', () {
      final document = doc([
        para('今天的收获'),
        block('bulleted_list', '一项'),
        block('paragraph', '居中', data: {'align': 'center'}),
      ]);
      expect(markdown(document), '今天的收获\n- 一项\n居中 {align=center}');
      final result = edit(document, [
        ('今天的收获', '## 今天的收获'),
        ('- 一项', '一项'),
        ('居中 {', '居中的字 {'),
      ]).document;
      expect(top(result)[0]['type'], 'heading');
      expect((top(result)[0]['data']! as Map)['level'], 2);
      expect(top(result)[1]['type'], 'paragraph');
      expect(text(top(result)[1]), '一项');
      expect((top(result)[2]['data']! as Map)['align'], 'center');
      expect(text(top(result)[2]), '居中的字');
    });

    test('new lines become new blocks and removed lines are deleted', () {
      final first = para('早上起得很早。');
      final second = para('中午吃了面。');
      final third = para('晚上看书。');
      final document = doc([first, second, third]);
      final added = edit(document, [
        ('中午吃了面。', '中午吃了面。\n- 牛肉面\n- 小菜'),
      ]).document;
      expect(top(added), [
        first,
        second,
        block('bulleted_list', '牛肉面'),
        block('bulleted_list', '小菜'),
        third,
      ]);
      // 整行换成空文字：这一行连同换行删掉，不留空段落。
      expect(top(edit(document, [('中午吃了面。', '')]).document), [first, third]);
      expect(top(edit(document, [('晚上看书。', '')]).document), [first, second]);
      // 只删一行里的几个字时照常替换。
      expect(text(top(edit(document, [('很早', '')]).document)[0]), '早上起得。');
    });

    test('an empty line is an empty paragraph', () {
      final document = doc([para('第一段'), para('第二段')]);
      expect(top(edit(document, [('第一段', '第一段\n')]).document), [
        para('第一段'),
        para(''),
        para('第二段'),
      ]);
    });

    test('text can be added after the last line', () {
      final document = doc([para('最后一段。')]);
      expect(top(edit(document, [('最后一段。', '最后一段。\n补一句。')]).document), [
        para('最后一段。'),
        para('补一句。'),
      ]);
    });

    test('nested lists keep their place and can be outdented', () {
      final document = doc([
        block(
          'bulleted_list',
          '水果',
          children: [block('bulleted_list', '苹果'), block('bulleted_list', '梨')],
        ),
      ]);
      expect(markdown(document), '- 水果\n  - 苹果\n  - 梨');
      final renamed = top(edit(document, [('  - 梨', '  - 香梨')]).document);
      expect(renamed.single['children'], [
        block('bulleted_list', '苹果'),
        block('bulleted_list', '香梨'),
      ]);
      final outdented = top(edit(document, [('  - 梨', '- 梨')]).document);
      expect(outdented, hasLength(2));
      expect(outdented[0]['children'], [block('bulleted_list', '苹果')]);
      expect(outdented[1], block('bulleted_list', '梨'));
    });

    test('a rewritten line of the same type keeps options the text cannot '
        'show', () {
      final document = doc([
        block('numbered_list', '第一', data: {'number': 3}),
      ]);
      final result = top(edit(document, [('第一', '第一项')]).document).single;
      expect((result['data']! as Map)['number'], 3);
      expect(text(result), '第一项');
    });

    test('code blocks are edited as raw text', () {
      final document = doc([
        block('code', 'print(1)\nprint(2)', data: {'language': 'python'}),
      ]);
      final result = top(edit(document, [('print(2)', 'print(3)')]).document);
      expect(result.single['type'], 'code');
      expect(text(result.single), 'print(1)\nprint(3)');
      expect((result.single['data']! as Map)['language'], 'python');
    });

    test('table cells can be edited and keep their own options', () {
      Map<String, Object?> cell(int row, int col, {Map<String, Object?>? x}) =>
          {
            'type': 'table/cell',
            'data': {'rowPosition': row, 'colPosition': col, ...?x},
            'children': [para('$row$col')],
          };
      final document = doc([
        {
          'type': 'table',
          'data': {'colsLen': 2, 'rowsLen': 2, 'headerRow': true},
          'children': [
            cell(0, 0, x: {'width': 80}),
            cell(0, 1),
            cell(1, 0),
            cell(1, 1),
          ],
        },
      ]);
      expect(markdown(document), '| 00 | 01 |\n| --- | --- |\n| 10 | 11 |');
      final table = top(edit(document, [('| 11 |', '| 十一 |')]).document).single;
      final cells = (table['children']! as List).cast<Map<String, Object?>>();
      expect(cells, hasLength(4));
      expect((cells[0]['data']! as Map)['width'], 80);
      expect(
        text((cells[3]['children']! as List).single as Map<String, Object?>),
        '十一',
      );
      expect((table['data']! as Map)['headerRow'], isTrue);
    });

    test('links: web links and diary links already there are kept', () {
      final document = doc([
        block('paragraph', '旧文', attributes: {'href': 'jotsy://diary/abc'}),
        para('今天'),
      ]);
      expect(markdown(document), '[旧文](jotsy://diary/abc)\n今天');
      Map<String, Object?>? attributesOf(Map<String, Object?> node) =>
          ((node['data']! as Map)['delta'] as List).first['attributes']
              as Map<String, Object?>?;
      final renamed = top(edit(document, [('旧文', '旧的那篇')]).document);
      expect(attributesOf(renamed[0]), {'href': 'jotsy://diary/abc'});
      final web = top(
        edit(document, [('\n今天', '\n[今天](https://example.com)')]).document,
      );
      expect(attributesOf(web[1]), {'href': 'https://example.com'});
      // 原文里没有的日记链接只留文字，并告诉模型。
      final unknown = edit(document, [('\n今天', '\n[今天](jotsy://diary/zzz)。')]);
      expect(attributesOf(top(unknown.document)[1]), isNull);
      expect(text(top(unknown.document)[1]), '今天。');
      expect(unknown.droppedLinks, ['jotsy://diary/zzz']);
      expect(
        () => edit(document, [('\n今天', '\n[今天](jotsy://diary/zzz)')]),
        fails(allOf(contains('Nothing changed'), contains('plain text'))),
      );
    });

    test('loose matching finds curly quotes and keeps the original ones', () {
      final document = doc([para('他说“你好”。')]);
      final result = edit(document, [('他说"你好"', '他说"您好"')]);
      expect(text(top(result.document).single), '他说“您好”。');
    });

    test('body replaces the whole text and keeps unchanged blocks', () {
      final callout = block(
        'callout',
        '提示',
        data: {'icon': '💡', 'tone': 'yellow', 'custom': 1},
      );
      final document = doc([para('第一段'), callout, para('第三段')]);
      final body = markdown(document).replaceFirst('第三段', '第三段改过');
      final result = aiEditDiaryMarkdown(
        document,
        l10n: zh,
        chatImages: chat,
        body: body,
      );
      expect(top(result.document), [para('第一段'), callout, para('第三段改过')]);
    });
  });

  group('photos and other media', () {
    final document = doc([
      para('文字A'),
      image('/a.jpg', extra: {'width': 100.0}),
      para('文字B'),
      image('/b.jpg'),
    ]);

    test('mark lines can be moved and removed', () {
      expect(markdown(document), '文字A\n[图片 1]\n文字B\n[图片 2]');
      final moved = edit(document, [('[图片 1]\n', ''), ('文字B', '文字B\n[图片 1]')]);
      expect(top(moved.document), [
        para('文字A'),
        para('文字B'),
        image('/a.jpg', extra: {'width': 100.0}),
        image('/b.jpg'),
      ]);
      expect(moved.removedMarks, isEmpty);
      final removed = edit(document, [('[图片 2]', '')]);
      expect(top(removed.document), top(document).take(3).toList());
      expect(removed.removedMarks, ['[图片 2]']);
    });

    test('photos from the chat go where ![](P1) is written', () {
      final result = edit(document, [('文字A', '文字A\n![](P1)')]);
      expect(top(result.document)[1], image('/m/sea.jpg'));
      expect(result.photosAdded, 1);
    });

    test('a wrong photo number or an unknown mark writes nothing', () {
      expect(
        () => edit(document, [('文字A', '![](P9)')]),
        fails(allOf(contains('P9'), contains('Nothing was written'))),
      );
      expect(
        () => edit(document, [('文字A', '![](P2)')]),
        fails(contains('P2 was deleted')),
      );
      expect(
        () => edit(document, [('文字A', '[图片 9]')]),
        fails(contains('[图片 9]')),
      );
    });
  });

  group('refused edits', () {
    final document = doc([para('今天'), para('今天'), para('明天')]);

    test('old_text must match exactly once', () {
      expect(
        () => edit(document, [('后天', 'x')]),
        fails(contains('Could not find')),
      );
      expect(
        () => edit(document, [('今天', 'x')]),
        fails(contains('occurs 2 times')),
      );
      expect(
        () => edit(document, [('今天\n明', 'x'), ('明天', 'y')]),
        fails(contains('overlap')),
      );
    });

    test('an edit that changes nothing is refused', () {
      expect(
        () => edit(document, [('明天', '明天')]),
        fails(contains('Nothing changed')),
      );
      // 编号列表的序号是数出来的：只改序号不算改动。
      final list = doc([
        block('numbered_list', '一'),
        block('numbered_list', '二'),
      ]);
      expect(markdown(list), '1. 一\n2. 二');
      expect(
        () => edit(list, [('2. 二', '5. 二')]),
        fails(contains('Nothing changed')),
      );
    });
  });
}
