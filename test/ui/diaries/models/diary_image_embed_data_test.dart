import 'package:flutter/painting.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';

quill.Leaf _imageNode(Map<String, dynamic>? attributes) {
  final document = quill.Document.fromJson([
    {
      'insert': {'image': '/documents/diary_images/a.jpg'},
      if (attributes != null) 'attributes': attributes,
    },
    {'insert': '\n'},
  ]);
  // 样式挂在 Embed 叶子上，与 EmbedContext.node 一致。
  return document.querySegmentLeafNode(0).leaf!;
}

void main() {
  test('image without size attributes is only bounded by layout', () {
    final bounds = diaryImageEmbedBounds(_imageNode(null));

    expect(bounds.maxWidth, double.infinity);
    expect(bounds.maxHeight, double.infinity);
  });

  test('resize menu style string becomes the display upper bound', () {
    final bounds = diaryImageEmbedBounds(
      _imageNode({'style': 'width: 240.0; height: 812.0; '}),
    );

    expect(bounds.maxWidth, 240);
    expect(bounds.maxHeight, 812);
  });

  test('style overrides px attributes and ignores unsupported units', () {
    final bounds = diaryImageEmbedBounds(
      _imageNode({'width': '320px', 'height': '200px', 'style': 'height: 50%'}),
    );

    expect(bounds.maxWidth, 320);
    expect(bounds.maxHeight, 200);
  });

  test('data URI with invalid base64 falls back to a file provider', () {
    expect(
      resolveDiaryImageProvider('data:image/png;base64,@@@'),
      isA<FileImage>(),
    );
    expect(
      resolveDiaryImageProvider('https://example.com/a.png'),
      isA<NetworkImage>(),
    );
  });
}
