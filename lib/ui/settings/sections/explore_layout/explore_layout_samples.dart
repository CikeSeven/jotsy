import 'dart:convert';
import 'dart:math';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/widgets/diary_image_source.dart';
import '../../../explore/controllers/explore_comment_stats.dart';

/// 自定义页预览用的示例日记：最近约两年里的 150 篇，带心情、精力、天气、
/// 地点、标签与几张内置示例封面，让每张卡片都有内容可看。
///
/// 文案取自日记卡片样式的示例（ARB），按固定种子伪随机生成，同一天打开看到
/// 的完全一样；id 以 `__explore_sample_` 开头，不会与真实日记冲突。时间相对
/// [now] 生成。
List<ExploreDiaryOverview> buildExploreLayoutSamples(
  AppLocalizations l10n, {
  required DateTime now,
  List<String> moodOptions = SettingsService.defaultMoodOptions,
}) {
  const base = 'assets/img/diary_card_samples';
  const covers = <String>[
    '$diaryAssetImageScheme$base/seaside.webp',
    '$diaryAssetImageScheme$base/hiking.webp',
    '$diaryAssetImageScheme$base/cafe.webp',
  ];
  final tags = <Tag>[
    Tag(id: -1, name: l10n.diaryCardStyleSampleTag1, color: 0xFF4CAF50),
    Tag(id: -2, name: l10n.diaryCardStyleSampleTag2, color: 0xFF2196F3),
    Tag(id: -3, name: l10n.diaryCardStyleSampleTag3, color: 0xFFE91E63),
  ];
  final titles = <String>[
    l10n.diaryCardStyleSampleTitle1,
    l10n.diaryCardStyleSampleTitle2,
    l10n.diaryCardStyleSampleTitle3,
    '',
  ];
  final bodies = <String>[
    l10n.diaryCardStyleSampleBody1,
    l10n.diaryCardStyleSampleBody2,
    l10n.diaryCardStyleSampleBody3,
  ];
  final weathers = <(String, String)>[
    ('100', l10n.exploreSampleWeatherSunny),
    ('101', l10n.exploreSampleWeatherCloudy),
    ('104', l10n.exploreSampleWeatherOvercast),
    ('305', l10n.exploreSampleWeatherRain),
    ('501', l10n.exploreSampleWeatherFog),
  ];
  final places = <String>[
    l10n.diaryCardStyleSampleLocation,
    l10n.exploreSamplePlaceHome,
    l10n.exploreSamplePlaceOffice,
  ];
  final random = Random(20260601);
  final today = DateTime(now.year, now.month, now.day);
  final samples = <ExploreDiaryOverview>[];
  var dayOffset = 0;
  for (var i = 0; i < 150; i++) {
    // 越近越密：最近两个月几乎每天都写，往前隔得越来越久（跨过一年多，
    // 那年今日与里程碑也有内容）。
    dayOffset += i < 50 ? random.nextInt(2) : 1 + random.nextInt(8);
    final created = DateTime(
      today.year,
      today.month,
      today.day - dayOffset,
      7 + random.nextInt(16),
      random.nextInt(60),
    );
    final mood = 3 + random.nextInt(7);
    final (weatherCode, weatherText) =
        weathers[random.nextInt(weathers.length)];
    samples.add(
      ExploreDiaryOverview(
        diaryId: '__explore_sample_$i',
        title: titles[i % titles.length],
        contentText: bodies[i % bodies.length],
        metadata: jsonEncode(<String, Object>{
          'context': <String, Object>{
            'moodEmoji': moodOptions[mood],
            'energyLevel': 2 + random.nextInt(4),
            'weatherIconCode': weatherCode,
            'weather': weatherText,
            if (i % 3 != 0) 'location': places[random.nextInt(places.length)],
          },
        }),
        createdAt: created,
        updatedAt: created,
        tags: <Tag>[
          for (final tag in tags)
            if (random.nextInt(3) == 0) tag,
        ],
        cover: i % 7 == 0 ? covers[(i ~/ 7) % covers.length] : null,
      ),
    );
  }
  return List<ExploreDiaryOverview>.unmodifiable(samples);
}

/// 自定义页预览的示例留言（“最近的留言”卡片）：最近几篇（新 → 旧）与据此
/// 现算的回看统计。
typedef ExploreCommentSamples = ({
  List<DiaryCommentSummary> recent,
  ExploreCommentStats stats,
});

/// 示例留言挂在 [diaries]（[buildExploreLayoutSamples] 的示例日记）里远近不一
/// 的几篇上：有的隔几天、有的隔一年多才回看，其中一篇有两条，统计里的“回应
/// 了几篇”与条数因此不同；留言写在最近十来天里。文案取自 ARB，心情取自
/// [moodOptions]，部分留言不带心情（卡片画小圆点）。
///
/// 留言时间不晚于 [now]；早于日记时挪到日记之后两小时，保证“写下后 N 天”
/// 不为负。
ExploreCommentSamples buildExploreCommentSamples(
  AppLocalizations l10n, {
  required DateTime now,
  required List<ExploreDiaryOverview> diaries,
  List<String> moodOptions = SettingsService.defaultMoodOptions,
}) {
  final texts = <String>[
    l10n.exploreSampleComment,
    l10n.diaryPreviewSampleComment1,
    l10n.diaryPreviewSampleComment2,
  ];
  // （第几篇示例日记，几天前写的留言，心情选项的序号；-1 为不带心情）
  const plan = <(int, int, int)>[
    (4, 0, 8),
    (30, 1, -1),
    (60, 2, 6),
    (4, 3, 7),
    (95, 5, -1),
    (120, 7, 5),
    (140, 9, 8),
    (18, 12, 4),
  ];
  final today = DateTime(now.year, now.month, now.day);
  final comments = <DiaryCommentSummary>[];
  for (var i = 0; i < plan.length; i++) {
    final (index, daysAgo, moodIndex) = plan[i];
    if (diaries.isEmpty) break;
    final diary = diaries[index % diaries.length];
    var created = DateTime(
      today.year,
      today.month,
      today.day - daysAgo,
      21 - i % 3,
      12 + i * 5,
    );
    if (created.isAfter(now)) created = now;
    if (!created.isAfter(diary.createdAt)) {
      created = diary.createdAt.add(const Duration(hours: 2));
    }
    comments.add(
      DiaryCommentSummary(
        commentId: '__explore_sample_comment_$i',
        diaryId: diary.diaryId,
        content: texts[i % texts.length],
        mood: moodIndex < 0 || moodOptions.isEmpty
            ? null
            : moodOptions[moodIndex % moodOptions.length],
        createdAt: created,
        diaryTitle: diary.title,
        diaryCreatedAt: diary.createdAt,
      ),
    );
  }
  comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return (
    recent: List<DiaryCommentSummary>.unmodifiable(comments),
    stats: ExploreCommentStats.of(<DiaryCommentTiming>[
      for (final comment in comments)
        DiaryCommentTiming(
          diaryId: comment.diaryId,
          createdAt: comment.createdAt,
          diaryCreatedAt: comment.diaryCreatedAt,
        ),
    ]),
  );
}
