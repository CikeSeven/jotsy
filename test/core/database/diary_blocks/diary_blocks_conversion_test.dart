import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_from_delta.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';

/// Quill 的规范形式：相邻同属性的 insert 合并。
List<Map<String, dynamic>> _normalized(List<Map<String, Object?>> ops) {
  return Delta.fromJson(jsonDecode(jsonEncode(ops)) as List).toJson();
}

void _expectRoundTrip(List<Map<String, Object?>> ops) {
  final blocks = diaryBlocksFromQuillOps(ops);
  expect(_normalized(diaryBlocksToQuillOps(blocks)), _normalized(ops));
}

List<(String, int)> _shape(Map<String, Object?> document) => [
  for (final (node, depth) in walkDiaryBlocks(document))
    (node[kDiaryBlockTypeKey]! as String, depth),
];

void main() {
  group('Quill Delta round trip', () {
    test('inline formats keep their values', () {
      _expectRoundTrip([
        {'insert': 'plain '},
        {
          'insert': 'bold',
          'attributes': {'bold': true, 'italic': true},
        },
        {
          'insert': ' strike',
          'attributes': {'strike': true, 'underline': true},
        },
        {
          'insert': ' code',
          'attributes': {'code': true},
        },
        {
          'insert': ' link',
          'attributes': {'link': 'https://example.com'},
        },
        {
          'insert': ' colored',
          'attributes': {
            'color': '#FF336699',
            'background': '#80FFEE00',
            'size': 'large',
          },
        },
        {'insert': '\n'},
      ]);
    });

    test('headings, quotes and alignment', () {
      _expectRoundTrip([
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 1, 'align': 'center'},
        },
        {'insert': 'Sub'},
        {
          'insert': '\n',
          'attributes': {'header': 3},
        },
        {'insert': 'quoted'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
        {'insert': 'right\n\njustified'},
        {
          'insert': '\n',
          'attributes': {'align': 'justify'},
        },
      ]);
    });

    test('nested lists become children and come back as indent', () {
      final ops = <Map<String, Object?>>[
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'a.1'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered', 'indent': 1},
        },
        {'insert': 'a.1.1'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked', 'indent': 2},
        },
        {'insert': 'a.2'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked', 'indent': 1},
        },
        {'insert': 'b\n'},
      ];
      final blocks = diaryBlocksFromQuillOps(ops);
      expect(_shape(blocks), [
        (kDiaryBlockBulletedList, 0),
        (kDiaryBlockNumberedList, 1),
        (kDiaryBlockTodoList, 2),
        (kDiaryBlockTodoList, 1),
        (kDiaryBlockParagraph, 0),
      ]);
      _expectRoundTrip(ops);
    });

    test('code blocks merge consecutive lines of the same language', () {
      final ops = <Map<String, Object?>>[
        {'insert': 'def f():'},
        {
          'insert': '\n',
          'attributes': {'code-block': 'python'},
        },
        {'insert': '    return 1'},
        {
          'insert': '\n\n',
          'attributes': {'code-block': 'python'},
        },
        {'insert': 'main() {}'},
        {
          'insert': '\n',
          'attributes': {'code-block': 'dart'},
        },
        {'insert': 'auto'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
        {'insert': 'after\n'},
      ];
      final blocks = diaryBlocksFromQuillOps(ops);
      final codes = [
        for (final (node, _) in walkDiaryBlocks(blocks))
          if (node[kDiaryBlockTypeKey] == kDiaryBlockCode) node,
      ];
      expect(codes, hasLength(3));
      expect(diaryBlockText(codes[0]), 'def f():\n    return 1\n');
      expect(diaryBlockData(codes[0])[kDiaryBlockLanguageKey], 'python');
      expect(
        diaryBlockData(codes[2]).containsKey(kDiaryBlockLanguageKey),
        isFalse,
      );
      _expectRoundTrip(ops);
    });

    test('media, divider and unknown embeds keep their data', () {
      final audio = jsonEncode({
        'path': '/data/audio/a.m4a',
        'durationMs': 1200,
        'waveform': [0.1, 0.5],
      });
      final attachment = jsonEncode({
        'path': '/data/files/b.pdf',
        'name': 'b.pdf',
        'sizeBytes': 10,
        'mime': 'application/pdf',
      });
      _expectRoundTrip([
        {'insert': 'before\n'},
        {
          'insert': {'image': '/data/images/c.jpg'},
          'attributes': {'width': '300', 'style': 'height: 200.0; '},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
        {
          'insert': {'video': '/data/videos/d.mp4'},
        },
        {'insert': '\n'},
        {
          'insert': {'audio': audio},
        },
        {'insert': '\n'},
        {
          'insert': {'attachment': attachment},
        },
        {'insert': '\n'},
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n'},
        {
          'insert': {'formula': 'x^2'},
        },
        {'insert': '\nafter\n'},
      ]);
    });

    test('empty document is a single empty paragraph', () {
      final blocks = diaryBlocksFromQuillOps([
        {'insert': '\n'},
      ]);
      expect(_shape(blocks), [(kDiaryBlockParagraph, 0)]);
      _expectRoundTrip([
        {'insert': '\n'},
      ]);
    });
  });

  group('normalization', () {
    test('media in a code-formatted line keep both code and the embed', () {
      final blocks = diaryBlocksFromQuillOps([
        {'insert': 'before'},
        {
          'insert': {'image': '/code-image.png'},
        },
        {'insert': 'after'},
        {
          'insert': '\n',
          'attributes': {'code-block': 'dart'},
        },
        {'insert': 'next'},
        {
          'insert': '\n',
          'attributes': {'code-block': 'dart'},
        },
      ]);
      expect(_shape(blocks), [
        (kDiaryBlockCode, 0),
        (kDiaryBlockImage, 0),
        (kDiaryBlockCode, 0),
        (kDiaryBlockCode, 0),
      ]);
      final nodes = walkDiaryBlocks(blocks).map((entry) => entry.$1).toList();
      expect(diaryBlockText(nodes[0]), 'before');
      expect(diaryBlockData(nodes[1])['url'], '/code-image.png');
      expect(diaryBlockText(nodes[2]), 'after');
      expect(diaryBlockText(nodes[3]), 'next');
      expect(diaryBlockData(nodes[2])['language'], 'dart');
    });

    test('an embed inside a text line splits the line', () {
      final blocks = diaryBlocksFromQuillOps([
        {'insert': 'left'},
        {
          'insert': {'image': 'x.png'},
        },
        {'insert': 'right'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]);
      expect(_shape(blocks), [
        (kDiaryBlockBulletedList, 0),
        (kDiaryBlockImage, 0),
        (kDiaryBlockBulletedList, 0),
      ]);
    });

    test('indent never skips a level and never nests under headings', () {
      final blocks = diaryBlocksFromQuillOps([
        {'insert': 'h'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {'insert': 'p'},
        {
          'insert': '\n',
          'attributes': {'indent': 1},
        },
        {'insert': 'deep'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 3},
        },
      ]);
      expect(_shape(blocks), [
        (kDiaryBlockHeading, 0),
        (kDiaryBlockParagraph, 0),
        (kDiaryBlockBulletedList, 1),
      ]);
    });

    test('legacy file embeds become attachments', () {
      final blocks = diaryBlocksFromQuillOps([
        {
          'insert': {'file': '/data/files/old.txt'},
        },
        {'insert': '\n'},
      ]);
      final (node, _) = walkDiaryBlocks(blocks).first;
      expect(node[kDiaryBlockTypeKey], kDiaryBlockAttachment);
      expect(diaryBlockData(node)[kDiaryBlockPathKey], '/data/files/old.txt');
    });
  });

  group('stored content', () {
    test('decodes every historical format', () {
      final delta = jsonEncode([
        {'insert': 'hello\n'},
      ]);
      expect(diaryBlocksPlainText(decodeStoredDiaryBlocks(delta)), 'hello');
      final blocks = encodeDiaryBlocks(decodeStoredDiaryBlocks(delta));
      expect(decodeStoredDiaryBlocks(blocks), jsonDecode(blocks));
      expect(
        diaryBlocksPlainText(decodeStoredDiaryBlocks('not json\nline')),
        'not json\nline',
      );
      expect(diaryBlocksPlainText(decodeStoredDiaryBlocks('42')), '42');
      expect(diaryBlocksPlainText(decodeStoredDiaryBlocks('  ')), '');
      final legacy = jsonEncode({
        'root': {
          'children': [
            {
              'type': 'paragraph',
              'attributes': {
                'delta': [
                  {'insert': 'old'},
                ],
              },
            },
          ],
        },
      });
      expect(diaryBlocksPlainText(decodeStoredDiaryBlocks(legacy)), 'old');
    });

    test('plain text matches the Quill plain-text mirror', () {
      final ops = <Map<String, Object?>>[
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {
          'insert': {'image': 'x.png'},
        },
        {'insert': '\ncode'},
        {
          'insert': '\n\n',
          'attributes': {'code-block': true},
        },
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\ntail  \n\n'},
      ];
      expect(
        diaryBlocksPlainText(diaryBlocksFromQuillOps(ops)),
        extractPlainTextFromDiaryDocument(
          decodeDiaryContentToDocument(jsonEncode(ops)),
        ),
      );
    });

    test('visible content and embeds', () {
      expect(
        diaryBlocksHaveVisibleContent(diaryBlocksFromPlainText(' \n ')),
        isFalse,
      );
      final divider = diaryBlocksFromQuillOps([
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n'},
      ]);
      expect(diaryBlocksHaveVisibleContent(divider), isTrue);
      expect(diaryBlocksHaveEmbeds(divider), isTrue);
      expect(diaryBlocksHaveEmbeds(diaryBlocksFromPlainText('x')), isFalse);
    });

    test('the editor reads and writes the same JSON', () {
      final blocks = diaryBlocksFromQuillOps([
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {
          'insert': 'b',
          'attributes': {'strike': true},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'checked', 'indent': 1},
        },
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\nx'},
        {
          'insert': '\n',
          'attributes': {'code-block': 'python'},
        },
      ]);
      final document = af.Document.fromJson(
        jsonDecode(jsonEncode(blocks)) as Map<String, dynamic>,
      );
      expect(jsonEncode(document.toJson()), jsonEncode(blocks));
    });
  });
}
