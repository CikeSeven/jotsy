import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/core/services/backup_media_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late BackupMediaPaths paths;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('block_backup_');
    final staging = Directory(p.join(root.path, 'staging'));
    paths = BackupMediaPaths(
      documentsDirectory: Directory(p.join(root.path, 'documents')),
      stagingDirectory: staging,
      targetSubdirectory: 'batch',
    );
    for (final relative in [
      'diary_images/a.png',
      'diary_videos/v.mp4',
      'diary_recordings/a.m4a',
      'diary_attachments/a.pdf',
    ]) {
      final file = File(p.join(staging.path, relative));
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
    }
  });
  tearDown(() => root.delete(recursive: true));

  for (final format in ['blocks', 'delta', 'legacy']) {
    test('$format restores all media and preserves metadata', () async {
      final media = [
        {
          'type': 'image',
          'data': {'url': '/old/diary_images/a.png', 'width': '300'},
        },
        {
          'type': 'video',
          'data': {'url': '/old/diary_videos/v.mp4'},
        },
        {
          'type': 'audio',
          'data': {
            'path': '/old/diary_recordings/a.m4a',
            'durationMs': 120,
            'waveform': [0.2, 0.8],
            'custom': 'audio metadata',
          },
        },
        {
          'type': 'attachment',
          'data': {
            'url': '/old/diary_attachments/a.pdf',
            'name': 'report.pdf',
            'size': 12,
            'custom': 'file metadata',
          },
        },
        {
          'type': 'image',
          'data': {'url': '/old/diary_images/missing.png'},
        },
        {
          'type': 'image',
          'data': {'url': 'https://example.com/diary_images/remote.png'},
        },
      ];
      final document = <String, Object?>{
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'paragraph',
              'data': {
                'delta': [
                  {'insert': '/old/diary_images/a.png'},
                ],
              },
              'children': media,
            },
          ],
        },
      };
      final source = switch (format) {
        'delta' => jsonEncode(diaryBlocksToQuillOps(document)),
        'legacy' => jsonEncode({
          'root': {
            'children': [
              for (final node in media)
                {'type': node['type'], 'attributes': node['data']},
            ],
          },
        }),
        _ => encodeDiaryBlocks(document),
      };
      final restored = await paths.rewriteContent(source);
      expect(isDiaryBlocksDocument(jsonDecode(restored)), isTrue);
      String target(String directory, String name) =>
          p.join(root.path, 'documents', directory, 'batch', name);
      expect(extractDiaryImageSources(restored), [
        target('diary_images', 'a.png'),
        '/old/diary_images/missing.png',
        'https://example.com/diary_images/remote.png',
      ]);
      expect(extractDiaryAudioPaths(restored), {
        target('diary_recordings', 'a.m4a'),
      });
      expect(extractDiaryFilePaths(restored), {
        target('diary_videos', 'v.mp4'),
        target('diary_attachments', 'a.pdf'),
      });
      final nodes = walkDiaryBlocks(decodeStoredDiaryBlocks(restored)).toList();
      final audio = nodes.singleWhere((node) => node.$1['type'] == 'audio').$1;
      final file = nodes
          .singleWhere((node) => node.$1['type'] == 'attachment')
          .$1;
      expect(diaryBlockData(audio)['custom'], 'audio metadata');
      expect(diaryBlockData(audio)['waveform'], [0.2, 0.8]);
      expect(diaryBlockData(file)['custom'], 'file metadata');
      expect(diaryBlockData(file)['size'], 12);
      expect(paths.boundFiles, hasLength(4));
      if (format == 'blocks') {
        expect(nodes.skip(1).map((node) => node.$2), everyElement(1));
        expect(diaryContentToPlainText(restored), '/old/diary_images/a.png');
      }
    });
  }

  test('plain text is restored as text without inventing media', () async {
    final restored = await paths.rewriteContent('old plain text');
    expect(isDiaryBlocksDocument(jsonDecode(restored)), isTrue);
    expect(diaryContentToPlainText(restored), 'old plain text');
    expect(paths.boundFiles, isEmpty);
  });
}
