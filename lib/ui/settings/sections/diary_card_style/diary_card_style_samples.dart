import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/widgets/diary_card/diary_card_cover.dart';

/// 设置页预览用的示例日记（文案来自 ARB，封面为内置示例图）。
///
/// 覆盖样式能影响到的各种情况：置顶 + 封面 + 地点精力、多图 + 录音（拼贴与
/// 媒体角标）、无封面的长标题（占位块）、没写标题的随手记（“无标题”占位）
/// 与未解封的时间胶囊。id 以
/// `__card_style_sample_` 开头，不会与真实日记冲突；时间相对 [now] 生成，
/// 预览里的相对时间读起来自然。
List<DiaryWithTags> buildDiaryCardStyleSamples(
  AppLocalizations l10n, {
  required DateTime now,
}) {
  const base = 'assets/img/diary_card_samples';
  const seaside = '${DiaryCardCoverImage.assetScheme}$base/seaside.webp';
  const hiking = '${DiaryCardCoverImage.assetScheme}$base/hiking.webp';
  const cafe = '${DiaryCardCoverImage.assetScheme}$base/cafe.webp';
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

  Diary diary({
    required int index,
    required String title,
    required String text,
    required DateTime createdAt,
    required List<Object> extraEmbeds,
    required Map<String, Object> context,
    String? cover,
    bool pinned = false,
    DateTime? lockedAt,
    DateTime? unlockAt,
  }) {
    return Diary(
      id: -index,
      diaryId: '__card_style_sample_$index',
      title: title,
      content: jsonEncode(<Object>[
        ...extraEmbeds,
        <String, Object>{'insert': '$text\n'},
      ]),
      contentText: text,
      metadata: jsonEncode(<String, Object>{'context': context}),
      cover: cover,
      createdAt: createdAt,
      updatedAt: createdAt,
      isArchived: false,
      isPinned: pinned,
      isDeleted: false,
      capsuleLockedAt: lockedAt,
      capsuleUnlockAt: unlockAt,
    );
  }

  return <DiaryWithTags>[
    DiaryWithTags(
      diary: diary(
        index: 1,
        title: l10n.diaryCardStyleSampleTitle1,
        text: l10n.diaryCardStyleSampleBody1,
        createdAt: now.subtract(const Duration(hours: 2)),
        cover: seaside,
        pinned: true,
        extraEmbeds: const <Object>[],
        context: <String, Object>{
          'moodEmoji': '😊',
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
        title: l10n.diaryCardStyleSampleTitle2,
        text: l10n.diaryCardStyleSampleBody2,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        extraEmbeds: const <Object>[
          <String, Object>{
            'insert': <String, Object>{'image': hiking},
          },
          <String, Object>{
            'insert': <String, Object>{'image': seaside},
          },
          <String, Object>{
            'insert': <String, Object>{'image': cafe},
          },
          <String, Object>{
            'insert': <String, Object>{'audio': '{}'},
          },
        ],
        context: const <String, Object>{
          'moodEmoji': '🤩',
          'weatherIconCode': '101',
          'energyLevel': 5,
        },
      ),
      tags: <Tag>[travel],
    ),
    DiaryWithTags(
      diary: diary(
        index: 3,
        title: l10n.diaryCardStyleSampleTitle3,
        text: l10n.diaryCardStyleSampleBody3,
        createdAt: now.subtract(const Duration(days: 3, hours: 5)),
        extraEmbeds: const <Object>[],
        context: const <String, Object>{
          'moodEmoji': '😐',
          'weatherIconCode': '305',
        },
      ),
      tags: <Tag>[reading, life, travel],
    ),
    DiaryWithTags(
      diary: diary(
        index: 4,
        title: '',
        text: l10n.diaryCardStyleSampleBody4,
        createdAt: now.subtract(const Duration(days: 4, hours: 2)),
        extraEmbeds: const <Object>[],
        context: const <String, Object>{
          'moodEmoji': '😄',
          'weatherIconCode': '100',
        },
      ),
      tags: <Tag>[life],
    ),
    DiaryWithTags(
      diary: diary(
        index: 5,
        title: l10n.diaryCardStyleSampleCapsuleTitle,
        text: l10n.diaryCardStyleSampleBody3,
        createdAt: now.subtract(const Duration(days: 5)),
        extraEmbeds: const <Object>[],
        context: const <String, Object>{'moodEmoji': '🙂'},
        lockedAt: now.subtract(const Duration(days: 5)),
        unlockAt: now.add(const Duration(days: 200)),
      ),
      tags: const <Tag>[],
    ),
  ];
}
