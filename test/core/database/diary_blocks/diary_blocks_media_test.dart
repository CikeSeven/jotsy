import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';

void main() {
  test('nested media keep order and duplicates without reading text links', () {
    final content = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {
                  'insert': 'image /text.png',
                  'attributes': {'href': '/link.png'},
                },
              ],
            },
            'children': [
              {
                'type': 'image',
                'data': {'url': ' /first.png '},
              },
              {
                'type': 'audio',
                'data': {'path': '/a.m4a', 'durationMs': 12},
              },
              {
                'type': 'video',
                'data': {'url': '/a.mp4'},
              },
              {
                'type': 'attachment',
                'data': {'url': '/a.pdf', 'name': 'old file'},
              },
            ],
          },
          {
            'type': 'image',
            'data': {'url': '/first.png'},
          },
          {'type': 'image', 'data': null},
        ],
      },
    });
    expect(extractDiaryImageSources(content), ['/first.png', '/first.png']);
    expect(extractDiaryAudioPaths(content), {'/a.m4a'});
    expect(extractDiaryFilePaths(content), {'/a.mp4', '/a.pdf'});
    expect(diaryContentMedia(content), hasLength(5));
  });

  test(
    'legacy media keep all metadata while rebinding to block data',
    () async {
      final content = jsonEncode({
        'root': {
          'children': [
            {
              'type': 'video',
              'attributes': {'url': '/v.mp4', 'width': 320},
            },
            {
              'type': 'audio',
              'attributes': {
                'path': '/a.m4a',
                'durationMs': 12,
                'waveform': [0.2, 0.8],
                'custom': 'audio metadata',
              },
            },
            {
              'type': 'file',
              'attributes': {
                'url': '/a.pdf',
                'name': 'report',
                'size': 12,
                'custom': 'file metadata',
              },
            },
          ],
        },
      });
      final document = decodeStoredDiaryBlocks(content);
      await rewriteDiaryBlocksMediaPaths(
        document,
        (_, path) async => '/new$path',
      );
      final nodes = walkDiaryBlocks(document).map((entry) => entry.$1).toList();
      expect(diaryBlockData(nodes[0]), {'width': 320, 'url': '/new/v.mp4'});
      expect(diaryBlockData(nodes[1]), {
        'path': '/new/a.m4a',
        'durationMs': 12,
        'waveform': [0.2, 0.8],
        'custom': 'audio metadata',
      });
      expect(diaryBlockData(nodes[2]), {
        'url': '/new/a.pdf',
        'name': 'report',
        'size': 12,
        'custom': 'file metadata',
      });
      expect(
        DiaryAudioAttachment.tryDecode(diaryBlockData(nodes[1]))?.duration,
        const Duration(milliseconds: 12),
      );
    },
  );

  test(
    'unknown embeds preserve recognized references and their metadata',
    () async {
      final document = decodeStoredDiaryBlocks(
        jsonEncode([
          {
            'insert': {
              'image': '/a.png',
              'file': {'url': '/a.pdf', 'custom': 'keep'},
              'formula': 'x',
            },
          },
          {'insert': '\n'},
        ]),
      );
      await rewriteDiaryBlocksMediaPaths(
        document,
        (_, path) async => '/new$path',
      );
      final content = encodeDiaryBlocks(document);
      expect(extractDiaryImageSources(content), ['/new/a.png']);
      expect(extractDiaryFilePaths(content), {'/new/a.pdf'});
      expect(diaryBlockData(walkDiaryBlocks(document).single.$1)['value'], {
        'image': '/new/a.png',
        'file': {'url': '/new/a.pdf', 'custom': 'keep'},
        'formula': 'x',
      });
    },
  );

  test('invalid media fields and malformed sources are ignored safely', () {
    for (final content in ['', 'text', '{broken', '[1,2,3]']) {
      expect(diaryContentMedia(content), isEmpty);
    }
    final content = jsonEncode([
      {
        'insert': {'image': 123},
      },
      {
        'insert': {'audio': '{}'},
      },
      {
        'insert': {'file': '{broken'},
      },
      {'insert': '\n'},
    ]);
    expect(extractDiaryImageSources(content), isEmpty);
    expect(extractDiaryAudioPaths(content), isEmpty);
    expect(extractDiaryFilePaths(content), isEmpty);
    expect(diaryContentMedia(content), hasLength(2));
  });
}
