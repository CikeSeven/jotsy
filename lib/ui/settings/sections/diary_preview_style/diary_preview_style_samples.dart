import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/widgets/diary_image_source.dart';

/// 预览页样式设置的示例日记（文案来自 ARB，封面为内置示例图）。
///
/// 覆盖样式能影响到的各种情况：
/// 1. 带封面、心情、天气、地点、精力与标签，正文有小标题、引用、待办与列表，
///    且编辑过（显示“最后编辑于”）；
/// 2. 没写标题、没有封面的随手记（“无标题”占位、无头图时的版式）；
/// 3. 长标题 + 中英混排的长正文（字数、阅读时长与边距）。
///
/// id 以 `__preview_style_sample_` 开头，不会与真实日记冲突；时间相对 [now]
/// 生成，预览里的相对时间读起来自然。
List<DiaryWithTags> buildDiaryPreviewStyleSamples(
  AppLocalizations l10n, {
  required DateTime now,
}) {
  const base = 'assets/img/diary_card_samples';
  const seaside = '$diaryAssetImageScheme$base/seaside.webp';
  const cafe = '$diaryAssetImageScheme$base/cafe.webp';
  final travel = Tag(
    id: -1,
    name: l10n.diaryCardStyleSampleTag1,
    color: 0xFF4CAF50,
  );
  final life = Tag(
    id: -2,
    name: l10n.diaryCardStyleSampleTag2,
    color: 0xFF2196F3,
  );
  final reading = Tag(
    id: -3,
    name: l10n.diaryCardStyleSampleTag3,
    color: 0xFFE91E63,
  );

  Map<String, Object> line(String text) => <String, Object>{'insert': text};
  Map<String, Object> block(Map<String, Object> attributes) => <String, Object>{
    'insert': '\n',
    'attributes': attributes,
  };

  Diary diary({
    required int index,
    required String title,
    required List<Object> ops,
    required String text,
    required DateTime createdAt,
    required Map<String, Object> context,
    DateTime? updatedAt,
    String? cover,
  }) {
    return Diary(
      id: -index,
      diaryId: '__preview_style_sample_$index',
      title: title,
      content: jsonEncode(ops),
      contentText: text,
      metadata: jsonEncode(<String, Object>{'context': context}),
      cover: cover,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    );
  }

  final body1 = l10n.diaryCardStyleSampleBody1;
  final heading = l10n.diaryPreviewStyleSampleHeading;
  final quote = l10n.diaryPreviewStyleSampleQuote;
  final todo1 = l10n.diaryPreviewStyleSampleTodo1;
  final todo2 = l10n.diaryPreviewStyleSampleTodo2;
  final body4 = l10n.diaryCardStyleSampleBody4;
  final body3 = l10n.diaryCardStyleSampleBody3;
  final long = l10n.diaryPreviewStyleSampleLong;
  final firstCreated = now.subtract(const Duration(days: 3, hours: 2));

  return <DiaryWithTags>[
    DiaryWithTags(
      diary: diary(
        index: 1,
        title: l10n.diaryCardStyleSampleTitle1,
        cover: seaside,
        createdAt: firstCreated,
        updatedAt: firstCreated.add(const Duration(hours: 5)),
        ops: <Object>[
          line('$body1\n$heading'),
          block(<String, Object>{'header': 2}),
          line(quote),
          block(<String, Object>{'blockquote': true}),
          line(todo1),
          block(<String, Object>{'list': 'checked'}),
          line(todo2),
          block(<String, Object>{'list': 'unchecked'}),
          line('$body4\n'),
        ],
        text: '$body1\n$heading\n$quote\n$todo1\n$todo2\n$body4',
        context: <String, Object>{
          'moodEmoji': '😊',
          'weather': l10n.diaryPreviewStyleSampleWeather,
          'weatherIconCode': '100',
          'location': l10n.diaryCardStyleSampleLocation,
          'energyLevel': 4,
        },
      ),
      tags: <Tag>[travel, life],
    ),
    DiaryWithTags(
      diary: diary(
        index: 2,
        title: '',
        createdAt: now.subtract(const Duration(hours: 4)),
        ops: <Object>[line('$body4\n')],
        text: body4,
        context: const <String, Object>{'moodEmoji': '😄'},
      ),
      tags: <Tag>[life],
    ),
    DiaryWithTags(
      diary: diary(
        index: 3,
        title: l10n.diaryCardStyleSampleTitle3,
        cover: cafe,
        createdAt: now.subtract(const Duration(days: 9, hours: 1)),
        ops: <Object>[line('$body3\n$long\n')],
        text: '$body3\n$long',
        context: const <String, Object>{
          'moodEmoji': '😐',
          'weatherIconCode': '305',
        },
      ),
      tags: <Tag>[reading],
    ),
  ];
}
