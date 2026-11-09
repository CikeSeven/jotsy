import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/ai_message_images.dart';

/// AI 消息图片列：位置有意义（对话里的图片按位置编号），所以不去重、
/// 不丢墓碑；坏数据按“没有图片”处理。
void main() {
  test('round-trips paths in order and keeps tombstones in place', () {
    final raw = encodeAiMessageImages(['/a.jpg', '', ' /b.jpg ', '/a.jpg']);
    expect(decodeAiMessageImages(raw), ['/a.jpg', '', '/b.jpg', '/a.jpg']);
    expect(liveAiMessageImages(decodeAiMessageImages(raw)), [
      '/a.jpg',
      '/b.jpg',
      '/a.jpg',
    ]);
  });

  test('no images is NULL; all removed still keeps the positions', () {
    expect(encodeAiMessageImages(const <String>[]), isNull);
    expect(decodeAiMessageImages(null), isEmpty);
    expect(decodeAiMessageImages(encodeAiMessageImages(['', ''])), ['', '']);
  });

  test('broken data reads as no images; odd items read as removed', () {
    expect(decodeAiMessageImages(''), isEmpty);
    expect(decodeAiMessageImages('not json'), isEmpty);
    expect(decodeAiMessageImages('{"a":1}'), isEmpty);
    expect(decodeAiMessageImages('["/a.jpg", 3, null]'), ['/a.jpg', '', '']);
  });
}
