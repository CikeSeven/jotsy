import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/explore/controllers/explore_content_extractor.dart';

import '../explore_test_fixtures.dart';

void main() {
  const extractor = ExploreContentExtractor();

  test('collects the cover and every distinct Delta image in order', () {
    final diary = createExploreTestDiary(
      cover: ' /cover.jpg ',
      content: jsonEncode([
        {'insert': 'A day in pictures\n'},
        {
          'insert': {'image': '/first.jpg'},
        },
        {
          'insert': {'image': ' /cover.jpg '},
        },
        {
          'insert': {'image': 'https://example.com/second.jpg'},
        },
        {
          'insert': {'image': '/first.jpg'},
        },
        {'insert': '\n'},
      ]),
    );

    expect(extractor.resolveMediaSources(diary), [
      '/cover.jpg',
      '/first.jpg',
      'https://example.com/second.jpg',
    ]);
  });

  test('collects all nested legacy images without requiring a cover', () {
    final diary = createExploreTestDiary(
      content: jsonEncode({
        'root': {
          'children': [
            {
              'type': 'image',
              'attributes': {'url': '/first.jpg'},
            },
            {
              'type': 'paragraph',
              'children': [
                {
                  'type': 'image',
                  'attributes': {'url': '/nested.jpg'},
                },
              ],
            },
            {
              'type': 'image',
              'attributes': {'url': '/last.jpg'},
            },
          ],
        },
      }),
    );

    expect(extractor.resolveMediaSources(diary), [
      '/first.jpg',
      '/nested.jpg',
      '/last.jpg',
    ]);
  });

  test('preserves the cover when body content is empty or malformed', () {
    for (final content in ['', 'plain text', '[{"insert":']) {
      final diary = createExploreTestDiary(
        cover: '/cover.jpg',
        content: content,
      );
      expect(extractor.resolveMediaSources(diary), ['/cover.jpg']);
      expect(
        extractor.resolveMediaSources(createExploreTestDiary(content: content)),
        isEmpty,
      );
    }
  });

  test(
    'ignores invalid nodes and empty sources while retaining later images',
    () {
      final diary = createExploreTestDiary(
        cover: ' ',
        content: jsonEncode([
          null,
          42,
          {
            'insert': {'image': ' '},
          },
          {
            'insert': {'image': 123},
          },
          {
            'insert': {'video': '/video.mp4'},
          },
          {
            'type': 'image',
            'attributes': {'url': null},
          },
          {
            'insert': {'image': '/valid.jpg'},
          },
        ]),
      );

      expect(extractor.resolveMediaSources(diary), ['/valid.jpg']);
    },
  );
}
