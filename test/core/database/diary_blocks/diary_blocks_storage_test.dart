import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';

void main() {
  test('all historical formats open and save as an AppFlowy document', () {
    final sources = [
      'first\nsecond',
      jsonEncode([
        {'insert': 'first\nsecond\n'},
      ]),
      jsonEncode({
        'root': {
          'children': [
            for (final text in ['first', 'second'])
              {
                'type': 'paragraph',
                'attributes': {
                  'delta': [
                    {'insert': text},
                  ],
                },
              },
          ],
        },
      }),
      encodeDiaryBlocks(diaryBlocksFromPlainText('first\nsecond')),
    ];
    for (final source in sources) {
      final document = decodeDiaryContentToDocument(source);
      expect(document.toPlainText(), 'first\nsecond\n');
      final saved = encodeDiaryDocumentToJson(document);
      expect(isDiaryBlocksDocument(jsonDecode(saved)), isTrue);
      expect(
        jsonEncode(af.Document.fromJson(jsonDecode(saved)).toJson()),
        saved,
      );
      expect(diaryContentToPlainText(saved), 'first\nsecond');
      expect(
        encodeDiaryDocumentToJson(decodeDiaryContentToDocument(saved)),
        saved,
      );
    }
  });

  test('formatted nested text and code keep their semantics after saving', () {
    final source = jsonEncode([
      {
        'insert': 'colored',
        'attributes': {'bold': true, 'color': '#FF112233'},
      },
      {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      },
      {'insert': 'done'},
      {
        'insert': '\n',
        'attributes': {'list': 'checked', 'indent': 1},
      },
      {'insert': 'void main() {}'},
      {
        'insert': '\n',
        'attributes': {'code-block': 'dart'},
      },
      {'insert': '\n'},
    ]);
    final original = decodeDiaryContentToDocument(source);
    var saved = encodeDiaryDocumentToJson(original);
    for (var i = 0; i < 3; i++) {
      final restored = decodeDiaryContentToDocument(saved);
      expect(restored.toDelta().toJson(), original.toDelta().toJson());
      expect(
        diaryContentToPlainText(saved),
        extractPlainTextFromDiaryDocument(restored),
      );
      saved = encodeDiaryDocumentToJson(restored);
    }
  });

  test('media-only drafts survive while unrelated metadata stays empty', () {
    for (final embed in [
      {'image': '/a.png'},
      {'video': '/a.mp4'},
      {
        'audio': {'path': '/a.m4a', 'durationMs': 100},
      },
      {'attachment': '/a.pdf'},
      {'divider': 'hr'},
    ]) {
      final saved = encodeDiaryDocumentToJson(
        decodeDiaryContentToDocument(
          jsonEncode([
            {'insert': embed},
            {'insert': '\n'},
          ]),
        ),
      );
      expect(diaryContentToPlainText(saved), isEmpty);
      expect(diaryContentHasEmbeddedContent(saved), isTrue);
    }
    expect(diaryContentHasEmbeddedContent('{"path":"/a.pdf"}'), isFalse);
    expect(diaryContentHasEmbeddedContent('{broken'), isFalse);
  });

  test('bad node fields do not hide valid later text', () {
    final saved = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          null,
          {'type': 'paragraph', 'data': 'bad', 'children': 123},
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                null,
                {'insert': 123},
                {'insert': 'kept'},
              ],
            },
          },
        ],
      },
    });
    expect(diaryContentToPlainText(saved), '\nkept');
    expect(decodeDiaryContentToDocument(saved).toPlainText(), '\nkept\n');
    expect(diaryContentToPlainText('broken [json'), 'broken [json');
  });
}
