import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media_edit.dart';

Map<String, Object?> paragraph(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      {'insert': text},
    ],
  },
};

Map<String, Object?> image(String url, {bool thumbnail = false}) => {
  'type': 'image',
  'data': {'url': url, 'width': 320.0, if (thumbnail) 'thumbnail': true},
};

Map<String, Object?> document(List<Object?> children) => {
  'document': {'type': 'page', 'children': children},
};

List<String?> mediaPaths(Map<String, Object?> doc) => [
  for (final media in diaryBlocksMedia(doc)) media.path,
];

void main() {
  test('removes matching media at any depth and keeps the text', () {
    final doc = document([
      paragraph('开头'),
      image('/data/a/diary_images/media_1/a.jpg', thumbnail: true),
      image('/data/a/diary_images/media_1/b.jpg'),
      {
        'type': 'bulleted_list',
        'data': {
          'delta': [
            {'insert': '列表项'},
          ],
        },
        'children': [
          image('/data/a/diary_images/media_1/a.jpg'),
          paragraph('子段落'),
        ],
      },
      {
        'type': 'video',
        'data': {'url': '/data/a/diary_videos/media_2/v.mp4'},
      },
      paragraph('结尾'),
    ]);

    final removed = removeDiaryBlocksMedia(
      doc,
      (kind, path) => path.endsWith('/a.jpg') || path.endsWith('/v.mp4'),
    );

    expect(removed, 3);
    expect(mediaPaths(doc), ['/data/a/diary_images/media_1/b.jpg']);
    expect(diaryBlocksPlainText(doc), contains('列表项'));
    expect(diaryBlocksPlainText(doc), contains('子段落'));
    expect(diaryBlocksPlainText(doc), contains('结尾'));
  });

  test('leaves the document untouched when nothing matches', () {
    final doc = document([paragraph('文字'), image('/x/diary_images/m/a.jpg')]);
    final before = encodeDiaryBlocks(doc);

    expect(removeDiaryBlocksMedia(doc, (_, _) => false), 0);
    expect(encodeDiaryBlocks(doc), before);
  });

  test('adds an empty paragraph when the only block is removed', () {
    final doc = document([image('/x/diary_images/m/a.jpg')]);

    expect(removeDiaryBlocksMedia(doc, (_, _) => true), 1);
    final root = doc['document']! as Map;
    final children = root['children']! as List;
    expect(children, hasLength(1));
    expect((children.single as Map)['type'], 'paragraph');
  });

  test('trims multi-key legacy embeds and drops them once empty', () {
    final doc = document([
      {
        'type': 'quill_embed',
        'data': {
          'value': {
            'image': '/x/diary_images/m/a.jpg',
            'video': '/x/diary_videos/m/v.mp4',
          },
        },
      },
      {
        'type': 'quill_embed',
        'data': {
          'value': {'image': '/x/diary_images/m/a.jpg'},
        },
      },
    ]);

    final removed = removeDiaryBlocksMedia(
      doc,
      (kind, _) => kind == DiaryBlockMediaKind.image,
    );

    expect(removed, 2);
    expect(mediaPaths(doc), ['/x/diary_videos/m/v.mp4']);
  });
}
