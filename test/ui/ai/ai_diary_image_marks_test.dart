import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/services/ai/ai_vision.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/tools/ai_diary_markdown.dart';

/// 发给智能体的正文（正文 Markdown）里图片的“[图片 n]”标记：与 view_images
/// 的编号（`AiVisionImages.sourcesOf`）处处一致——嵌套在列表里的、旧版多键
/// 嵌入里的、同一张图出现两次的都一样。
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
  AiContextDiary diaryOf(Map<String, Object?> document) => AiContextDiary(
    diaryId: 'd',
    title: '',
    contentText: diaryBlocksPlainText(document),
    createdAt: DateTime(2026, 11, 10),
    isArchived: false,
    contentJson: jsonEncode(document),
  );

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
    expect(AiVisionImages.sourcesOf(jsonEncode(document)), [
      '/a.jpg',
      '/b.jpg',
      '/c.jpg',
    ]);
    expect(
      aiDiaryMarkdownText(zh, diaryOf(document)),
      [
        '开头',
        zh.aiPromptDiaryImage(1),
        '- 列表',
        '  ${zh.aiPromptDiaryImage(2)}',
        zh.aiPromptDiaryImage(3),
        zh.aiPromptDiaryImage(1),
        '结尾',
      ].join('\n'),
    );
  });

  test('plain text is written as it is; without block JSON the mirror', () {
    final document = <String, Object?>{
      'document': {
        'type': 'page',
        'children': [paragraph('只有字')],
      },
    };
    expect(aiDiaryMarkdownText(zh, diaryOf(document)), '只有字');
    final mirrorOnly = AiContextDiary(
      diaryId: 'd',
      title: '',
      contentText: '只有镜像',
      createdAt: DateTime(2026, 11, 10),
      isArchived: false,
    );
    expect(aiDiaryMarkdownText(zh, mirrorOnly), '只有镜像');
    // 原文为空、镜像有字的异常数据：按镜像读，改的也是这些字。
    final emptyContent = AiContextDiary(
      diaryId: 'd',
      title: '',
      contentText: '镜像里的字',
      createdAt: DateTime(2026, 11, 10),
      isArchived: false,
      contentJson: '',
    );
    expect(aiDiaryMarkdownText(zh, emptyContent), '镜像里的字');
  });
}
