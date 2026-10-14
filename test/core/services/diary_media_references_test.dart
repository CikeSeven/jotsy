import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_references.dart';

void main() {
  group('diaryMediaKeyOf', () {
    test('keys a path by its managed directory regardless of root', () {
      expect(
        diaryMediaKeyOf(
          '/data/user/0/com.jotsy.diary/app_flutter/diary_images/media_1/a.jpg',
        ),
        'diary_images/media_1/a.jpg',
      );
      expect(
        diaryMediaKeyOf(r'C:\Users\me\Documents\diary_videos\media_2\b.mp4'),
        'diary_videos/media_2/b.mp4',
      );
    });

    test('ignores unmanaged, bare-directory and escaping paths', () {
      expect(diaryMediaKeyOf('/sdcard/DCIM/a.jpg'), isNull);
      expect(diaryMediaKeyOf('/docs/diary_images'), isNull);
      expect(diaryMediaKeyOf('/docs/diary_images/../secret.txt'), isNull);
    });
  });

  test('collects every embed format, nested JSON and file URIs', () {
    final content = jsonEncode([
      {
        'insert': {'image': '/old/root/diary_images/media_1/a.jpg'},
      },
      {
        'insert': {
          diaryAttachmentEmbedType: const DiaryFileAttachment(
            path: '/old/root/diary_attachments/media_2/b.pdf',
            name: 'b.pdf',
          ).encode(),
        },
      },
      {
        'insert': {
          diaryAudioEmbedType: const DiaryAudioAttachment(
            path: '/old/root/diary_recordings/recording_1.m4a',
            duration: Duration(seconds: 3),
          ).encode(),
        },
      },
      {
        'insert': {
          'video': 'file:///old/root/diary_videos/media_3/my%20clip.mp4',
        },
      },
      {'insert': '\n'},
    ]);
    final legacy = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'image',
            'attributes': {'url': '/old/root/diary_images/media_4/legacy.png'},
          },
        ],
      },
    });
    final draft = jsonEncode({
      'contentDocJson': jsonEncode([
        {
          'insert': {'image': '/root/diary_images/media_5/draft.jpg'},
        },
      ]),
      'cover': '/root/diary_covers/cover_1.jpg',
    });

    final references = DiaryMediaReferences([content, legacy, draft, null]);

    for (final key in [
      'diary_images/media_1/a.jpg',
      'diary_attachments/media_2/b.pdf',
      'diary_recordings/recording_1.m4a',
      'diary_videos/media_3/my clip.mp4',
      'diary_images/media_4/legacy.png',
      'diary_images/media_5/draft.jpg',
      'diary_covers/cover_1.jpg',
    ]) {
      expect(references.contains(key), isTrue, reason: key);
    }
    expect(references.contains('diary_images/media_9/orphan.jpg'), isFalse);
  });

  test('free text that mentions a media path still protects the file', () {
    final references = DiaryMediaReferences([
      'see /root/diary_images/media_1/a.jpg (old note)',
    ]);

    expect(references.contains('diary_images/media_1/a.jpg'), isTrue);
  });
}
