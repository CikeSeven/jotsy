import 'dart:convert';
import 'dart:math';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/widgets/diary_image_source.dart';

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
