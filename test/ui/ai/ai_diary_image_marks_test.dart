import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/services/ai/ai_vision.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/tools/ai_tools_images.dart';

/// 发给 AI 的正文里图片的“[图片 n]”标记：与 view_images 的编号
/// （`AiVisionImages.sourcesOf`）处处一致——嵌套在列表里的、旧版多键嵌入
/// 里的、同一张图出现两次的都一样；其余文字与纯文本镜像一字不差。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));

  Map<String, Object?> paragraph(String text) => {
    'type': 'paragraph',
    'data': {
      'delta': [
        {'insert': text},
      ],
    },
  };
  Map<String, Object?> image(String url) => {
    'type': 'image',
    'data': {'url': url},
  };

  test('marks follow the same numbering as view_images', () {
    final document = <String, Object?>{
      'document': {
        'type': 'page',
        'children': [
          paragraph('开头'),
          image('/a.jpg'),
          {
            'type': 'bulleted_list',
            'data': {
              'delta': [
                {'insert': '列表'},
              ],
            },
            'children': [image('/b.jpg')],
          },
          // 旧版多键嵌入：里面的图片同样编号。
          {
            'type': 'quill_embed',
            'data': {
              'value': {'image': '/c.jpg'},
            },
          },
          // 同一张图第二次出现：沿用第一次的编号。
          image('/a.jpg'),
          paragraph('结尾'),
        ],
      },
    };
    final content = jsonEncode(document);
    expect(AiVisionImages.sourcesOf(content), ['/a.jpg', '/b.jpg', '/c.jpg']);
    final diary = AiContextDiary(
      diaryId: 'd',
      title: '',
      contentText: diaryBlocksPlainText(document),
      createdAt: DateTime(2026, 11, 10),
      isArchived: false,
      contentJson: content,
    );
    final text = aiDiaryTextWithImageMarks(zh, diary);
    expect(
      text,
      [
        '开头',
        zh.aiPromptDiaryImage(1),
        '列表',
        zh.aiPromptDiaryImage(2),
        zh.aiPromptDiaryImage(3),
        zh.aiPromptDiaryImage(1),
        '结尾',
      ].join('\n'),
    );
  });

  test('without photos the text is the stored mirror', () {
    final document = <String, Object?>{
      'document': {
        'type': 'page',
        'children': [paragraph('只有字')],
      },
    };
    final diary = AiContextDiary(
      diaryId: 'd',
      title: '',
      contentText: '只有字',
      createdAt: DateTime(2026, 11, 10),
      isArchived: false,
      contentJson: jsonEncode(document),
    );
    expect(aiDiaryTextWithImageMarks(zh, diary), '只有字');
    // 不给回调时与原来的镜像完全相同。
    expect(diaryBlocksPlainText(document), '只有字');
  });
}
