import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_blocks.dart';

Map<String, Object?> _page(List<Map<String, Object?>> children) => {
  'document': {'type': 'page', 'children': children},
};

Map<String, Object?> _paragraph(List<Map<String, Object?>> delta) => {
  'type': 'paragraph',
  'data': {'delta': delta},
};

void main() {
  group('DiaryLinkTarget', () {
    test('round-trips diary and notebook addresses', () {
      for (final target in const [
        DiaryLinkTarget.diary('6f1c2b'),
        DiaryLinkTarget.notebook('nb-01'),
      ]) {
        expect(DiaryLinkTarget.tryParse(target.toHref()), target);
      }
      expect(
        const DiaryLinkTarget.diary('6f1c2b').toHref(),
        'jotsy://diary/6f1c2b',
      );
      expect(
        DiaryLinkTarget.tryParse(' JOTSY://Notebook/abc '),
        const DiaryLinkTarget.notebook('abc'),
      );
      // id 里不安全的字符编码后仍然原样读回。
      const odd = DiaryLinkTarget.diary('a b/c');
      expect(DiaryLinkTarget.tryParse(odd.toHref()), odd);
    });

    test('rejects web links and malformed addresses', () {
      for (final href in <Object?>[
        null,
        42,
        '',
        'https://example.com/diary/abc',
        'jotsy:diary/abc',
        'jotsy://diary',
        'jotsy://diary/',
        'jotsy://tag/abc',
        'jotsy://diary/abc/def',
        'jotsy://diary/abc?x=1',
        'jotsy://diary/abc#top',
        'jotsy://user@diary/abc',
        'jotsy://diary:80/abc',
      ]) {
        expect(DiaryLinkTarget.tryParse(href), isNull, reason: '$href');
        expect(DiaryLinkTarget.isLink(href), isFalse);
      }
    });

    test('backlink pattern quotes and escapes the address', () {
      expect(
        const DiaryLinkTarget.diary('abc').backlinkLikePattern(),
        '%"jotsy://diary/abc"%',
      );
      expect(
        const DiaryLinkTarget.notebook('a_b%c').backlinkLikePattern(),
        r'%"jotsy://notebook/a\_b\%25c"%',
      );
    });
  });

  group('link cards', () {
    const target = DiaryLinkTarget.diary('d-1');

    test('card data holds the address and a single-line title', () {
      final data = diaryLinkCardData(target, '  第一行\r\n第二行 ');
      expect(data, {'target': 'jotsy://diary/d-1', 'title': '第一行 第二行'});
      expect(diaryLinkCardTarget(data), target);
      expect(diaryLinkCardTitle(data), '第一行 第二行');
      expect(diaryLinkCardData(target, '  '), {'target': 'jotsy://diary/d-1'});
      expect(diaryLinkCardTitle(const {'title': 3}), isNull);
      expect(diaryLinkCardTarget(const {'target': 'https://x.y'}), isNull);
    });

    test('cards count as visible content and take a blank text line', () {
      final document = _page([
        _paragraph([
          {'insert': 'before'},
        ]),
        {'type': 'link_card', 'data': diaryLinkCardData(target, '旧标题')},
        _paragraph([
          {'insert': 'after'},
        ]),
      ]);
      expect(diaryBlocksPlainText(document), 'before\n\nafter');
      final onlyCard = _page([
        {'type': 'link_card', 'data': diaryLinkCardData(target, 'x')},
      ]);
      expect(diaryBlocksHaveVisibleContent(onlyCard), isTrue);
      expect(diaryBlocksHaveEmbeds(onlyCard), isTrue);
    });

    test('children stored under a card are lifted after it', () {
      final document = _page([
        {
          'type': 'link_card',
          'data': diaryLinkCardData(target, 'x'),
          'children': [
            _paragraph([
              {'insert': 'hidden'},
            ]),
          ],
        },
      ]);
      // 与库里读出的正文一样经 JSON 往返（列表元素类型为 dynamic）。
      final lifted = liftHiddenDiaryBlockChildren(
        (jsonDecode(jsonEncode(document)) as Map).cast<String, Object?>(),
      );
      final top = diaryBlockChildren(diaryBlocksRoot(lifted)!);
      expect(top.map((node) => node['type']), ['link_card', 'paragraph']);
      expect(top.first.containsKey('children'), isFalse);
    });
  });

  test('templates drop diary links and link cards but keep the text', () {
    final sanitized = sanitizeDiaryTemplateBlocks(
      _page([
        _paragraph([
          {
            'insert': '那天',
            'attributes': {'href': 'jotsy://diary/d-1', 'bold': true},
          },
          {
            'insert': '官网',
            'attributes': {'href': 'https://example.com'},
          },
        ]),
        {
          'type': 'link_card',
          'data': diaryLinkCardData(const DiaryLinkTarget.notebook('n'), 'x'),
        },
      ]),
    );
    final children = diaryBlockChildren(diaryBlocksRoot(sanitized)!);
    expect(children.map((node) => node['type']), ['paragraph']);
    expect(diaryBlockDelta(children.single), [
      {
        'insert': '那天',
        'attributes': {'bold': true},
      },
      {
        'insert': '官网',
        'attributes': {'href': 'https://example.com'},
      },
    ]);
  });
}
