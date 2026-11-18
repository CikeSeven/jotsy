import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/tools/ai_diary_markdown_edit.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_diary_images.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';

/// 把对话里的图片写进正文（新建与修改同一套写法）：`![](P2)` 按编号换成
/// 托管路径、放在那一行之后（单独一行时就在那里），代码里的不算，同一张
/// 只放一次；有一个编号不对就整次不写并列出全部问题。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  const chat = <AiChatImage>[
    AiChatImage(ref: 'P1', messageId: 'm', index: 0, path: '/m/sea.jpg'),
    AiChatImage(ref: 'P2', messageId: 'm', index: 1, path: '/m/hill.jpg'),
    AiChatImage(ref: 'P3', messageId: 'm', index: 2, path: ''),
  ];

  /// 新建日记的正文（对空正文整段替换），每块写成简写：图片写路径，其余
  /// 写类型与文字。
  List<String> shape(String body) {
    final document = aiEditDiaryMarkdown(
      diaryBlocksFromPlainText(''),
      l10n: zh,
      chatImages: chat,
      body: body,
    ).document;
    return [
      for (final child
          in ((document['document']! as Map)['children']! as List).cast<Map>())
        child['type'] == 'image'
            ? 'image ${(child['data'] as Map)['url']}'
            : '${child['type']} ${_text(child)}',
    ];
  }

  test('a photo on its own line goes exactly there', () {
    expect(shape('早上去了海边\n![海](P1)\n下午爬山'), [
      'paragraph 早上去了海边',
      'image /m/sea.jpg',
      'paragraph 下午爬山',
    ]);
  });

  test('a photo inside a line follows that line', () {
    expect(shape('看这片海 ![](p1) 很蓝\n结束'), [
      'paragraph 看这片海 很蓝',
      'image /m/sea.jpg',
      'paragraph 结束',
    ]);
    expect(shape('- 一项 ![](P2)'), ['bulleted_list 一项', 'image /m/hill.jpg']);
  });

  test('each photo is placed once', () {
    expect(shape('![](P2)\n今天\n![](P1)\n![](P2)\n![]([P1])'), [
      'image /m/hill.jpg',
      'paragraph 今天',
      'image /m/sea.jpg',
    ]);
  });

  test('photo syntax inside code is left as text', () {
    final lines = shape('```\n![](P1)\n```\n行内 `![](P2)` 也不算');
    expect(lines.any((line) => line.startsWith('image')), isFalse);
    expect(lines, ['code ![](P1)', 'paragraph 行内 ![](P2) 也不算']);
  });

  test('other image syntax is refused instead of silently dropped', () {
    for (final body in [
      '![](/sdcard/a.jpg)\n文字',
      '看 ![](https://a.com/x.png)',
    ]) {
      expect(
        () => shape(body),
        throwsA(
          isA<AiToolFailure>().having(
            (e) => e.message,
            'message',
            contains('![](P1)'),
          ),
        ),
      );
    }
    // 行内代码里的是文字。
    expect(shape('`![](/a.jpg)`'), ['paragraph ![](/a.jpg)']);
  });

  test('an unknown or deleted photo stops the whole write', () {
    expect(
      () => shape('![](P9)\n![](P1)'),
      throwsA(
        isA<AiToolFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains('P9'), contains('P1, P2'), contains('Nothing')),
        ),
      ),
    );
    expect(
      () => shape('![](P3)'),
      throwsA(
        isA<AiToolFailure>().having(
          (e) => e.message,
          'message',
          contains('P3 was deleted'),
        ),
      ),
    );
  });

  test('photo references are found outside inline code only', () {
    final found = aiChatPhotoRefsInLine('a ![](P1) b `![](P2)`');
    expect(found.rest, 'a b `![](P2)`');
    expect(found.refs, ['P1']);
    final none = aiChatPhotoRefsInLine('没有图片');
    expect(none.rest, '没有图片');
    expect(none.refs, isEmpty);
  });
}

String _text(Map child) {
  final data = child['data'];
  if (data is! Map) return '';
  final delta = data['delta'];
  if (delta is! List) return '';
  return delta.map((op) => (op as Map)['insert']).join();
}
