import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/ai/controllers/ai_save_as_diary_flow.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_diary_images.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';

/// 新建 / 追加日记时把对话里的图片放进正文：按编号换成托管路径，
/// `![](P2)` 放在原位、`images` 里没放的接在最后，代码里的不算，同一张
/// 只放一次；有一个编号不对就整次不写。
void main() {
  const chat = <AiChatImage>[
    AiChatImage(ref: 'P1', messageId: 'm', index: 0, path: '/m/sea.jpg'),
    AiChatImage(ref: 'P2', messageId: 'm', index: 1, path: '/m/hill.jpg'),
    AiChatImage(ref: 'P3', messageId: 'm', index: 2, path: ''),
  ];

  /// 每块的简写：图片写路径，其余写类型与文字。
  List<String> shape(List<Object?> children) => [
    for (final child in children.cast<Map>())
      child['type'] == 'image'
          ? 'image ${(child['data'] as Map)['url']}'
          : '${child['type']} ${_text(child)}',
  ];

  test('a photo on its own line goes exactly there', () {
    final body = aiDiaryBodyWithImages(
      '早上去了海边\n\n![海](P1)\n\n下午爬山',
      images: const <String>[],
      chatImages: chat,
    );
    expect(shape(body.children), [
      'paragraph 早上去了海边',
      'image /m/sea.jpg',
      'paragraph 下午爬山',
    ]);
    expect(body.images, 1);
  });

  test('a photo inside a line follows that line', () {
    final body = aiDiaryBodyWithImages(
      '看这片海 ![](p1) 很蓝\n结束',
      images: const <String>[],
      chatImages: chat,
    );
    expect(shape(body.children), [
      'paragraph 看这片海 很蓝',
      'image /m/sea.jpg',
      'paragraph 结束',
    ]);
  });

  test('listed photos not placed in the text go last, each once', () {
    final body = aiDiaryBodyWithImages(
      '![](P2)\n今天',
      images: const ['P1', 'P2', '[P1]'],
      chatImages: chat,
    );
    expect(shape(body.children), [
      'image /m/hill.jpg',
      'paragraph 今天',
      'image /m/sea.jpg',
    ]);
    expect(body.images, 2);
  });

  test('photo syntax inside code is left as text', () {
    final body = aiDiaryBodyWithImages(
      '```\n![](P1)\n```\n行内 `![](P2)` 也不算',
      images: const <String>[],
      chatImages: chat,
    );
    expect(body.images, 0);
    expect(
      shape(body.children).any((line) => line.startsWith('image')),
      isFalse,
    );
  });

  test('photos alone make a body', () {
    final body = aiDiaryBodyWithImages(
      '',
      images: const ['P1'],
      chatImages: chat,
    );
    expect(shape(body.children), ['image /m/sea.jpg']);
  });

  test('without photos it is the usual Markdown conversion', () {
    const text = '# 标题\n\n- 一\n- 二\n\n正文 [D1]';
    final body = aiDiaryBodyWithImages(
      text,
      images: const <String>[],
      chatImages: chat,
    );
    expect(
      body.children,
      (aiMarkdownDiaryDocument(text)['document']! as Map)['children'],
    );
  });

  test('an unknown or deleted photo stops the whole write', () {
    expect(
      () => aiDiaryBodyWithImages(
        '![](P9)',
        images: const ['P1'],
        chatImages: chat,
      ),
      throwsA(
        isA<AiToolFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains('P9'), contains('P1, P2')),
        ),
      ),
    );
    expect(
      () => aiDiaryBodyWithImages('', images: const ['P3'], chatImages: chat),
      throwsA(
        isA<AiToolFailure>().having(
          (e) => e.message,
          'message',
          contains('P3 was deleted'),
        ),
      ),
    );
  });
}

String _text(Map child) {
  final data = child['data'];
  if (data is! Map) return '';
  final delta = data['delta'];
  if (delta is! List) return '';
  return delta.map((op) => (op as Map)['insert']).join();
}
