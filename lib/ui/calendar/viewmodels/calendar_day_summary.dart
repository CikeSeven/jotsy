import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../models/calendar_display_options.dart';

/// 一天的日期格展示数据，由当天的打点聚合而来。
///
/// 输入：同一本地日期的 [DiaryCalendarMarker]（按创建时间升序）、当前时刻与
/// 心情配置；输出各种日期格样式要画的数据。纯计算，无副作用。
///
/// 未解封的时间胶囊只贡献 [hasLockedCapsule]：篇数、字数、心情、封面、
/// 标签色、天气都只统计已解封或普通日记，日历上不提前泄露胶囊内容。
@immutable
class CalendarDaySummary {
  const CalendarDaySummary({
    required this.day,
    required this.entryCount,
    required this.wordCount,
    required this.hasLockedCapsule,
    required this.moods,
    required this.averageMood,
    required this.averageMoodWeight,
    required this.tagColors,
    required this.weather,
    required this.weatherIconCode,
    required this.explicitCover,
    required this.diaryIds,
  });

  /// 逐篇心情最多显示几个：40dp 宽的日期格里放 3 个 9sp emoji 已是上限。
  static const int maxMoods = 3;
  static const int maxTagColors = 3;

  final DateTime day;

  /// 已解封/普通日记的篇数。
  final int entryCount;
  final int wordCount;
  final bool hasLockedCapsule;

  /// 逐篇心情（按时间顺序，跳过未填心情的日记）；日期格只画前 [maxMoods]
  /// 个，月度概览统计全部。
  final List<String> moods;

  /// 当天所有心情的平均权重四舍五入后映射回当前心情配置的 emoji。
  final String? averageMood;

  /// [averageMood] 对应的心情档位（1~10），年视图按它着色。
  final int? averageMoodWeight;

  /// 去重后的标签色，按首次出现顺序，最多 [maxTagColors] 个。
  final List<int> tagColors;
  final String? weather;
  final String? weatherIconCode;

  /// 当天最早一篇带显式封面的日记的封面。
  final String? explicitCover;

  /// 已解封/普通日记的 id（按时间顺序），用于查找正文首图。
  final List<String> diaryIds;

  bool get hasEntries => entryCount > 0;

  /// 照片样式的代表图：显式封面是用户特意挑的，优先于正文插图；都没有时
  /// 取当天最早一篇带正文图片的日记的首图。
  String? representativeImage(Map<String, String> inlineImages) {
    final cover = explicitCover;
    if (cover != null) {
      return cover;
    }
    for (final id in diaryIds) {
      final image = inlineImages[id];
      if (image != null) {
        return image;
      }
    }
    return null;
  }

  /// 热力等级 0~4。阈值固定而不是按当月最大值归一：同样的篇数/字数在
  /// 不同月份显示同样的深浅，翻月对比才有意义。
  int heatLevel(CalendarHeatBasis basis) {
    if (!hasEntries) {
      return 0;
    }
    return switch (basis) {
      CalendarHeatBasis.entries => entryCount.clamp(1, 4),
      CalendarHeatBasis.words => switch (wordCount) {
        < 200 => 1,
        < 600 => 2,
        < 1500 => 3,
        _ => 4,
      },
    };
  }

  /// 把一个月（或任意区间）的打点按本地日期分桶并聚合。
  static Map<DateTime, CalendarDaySummary> groupByDay(
    List<DiaryCalendarMarker> markers, {
    required DateTime now,
    required List<String> moodOptions,
  }) {
    final buckets = <DateTime, List<DiaryCalendarMarker>>{};
    for (final marker in markers) {
      final day = DateUtils.dateOnly(marker.createdAt.toLocal());
      buckets.putIfAbsent(day, () => <DiaryCalendarMarker>[]).add(marker);
    }
    final weights = SettingsService.buildMoodWeightMap(moodOptions);
    return buckets.map(
      (DateTime day, List<DiaryCalendarMarker> dayMarkers) => MapEntry(
        day,
        _summarize(
          day,
          dayMarkers,
          now: now,
          weights: weights,
          moodOptions: moodOptions,
        ),
      ),
    );
  }

  static CalendarDaySummary _summarize(
    DateTime day,
    List<DiaryCalendarMarker> markers, {
    required DateTime now,
    required Map<String, int> weights,
    required List<String> moodOptions,
  }) {
    var entryCount = 0;
    var wordCount = 0;
    var hasLockedCapsule = false;
    var weightTotal = 0;
    var weightCount = 0;
    final moods = <String>[];
    final tagColors = <int>[];
    final diaryIds = <String>[];
    String? weather;
    String? weatherIconCode;
    String? explicitCover;

    for (final marker in markers) {
      if (marker.isLockedCapsuleAt(now)) {
        hasLockedCapsule = true;
        continue;
      }
      entryCount += 1;
      wordCount += marker.wordCount;
      diaryIds.add(marker.diaryId);
      final mood = marker.moodEmoji;
      if (mood != null) {
        moods.add(mood);
        final weight = weights[mood];
        if (weight != null) {
          weightTotal += weight;
          weightCount += 1;
        }
      }
      for (final color in marker.tagColors) {
        if (tagColors.length < maxTagColors && !tagColors.contains(color)) {
          tagColors.add(color);
        }
      }
      if (weather == null && marker.weather != null) {
        weather = marker.weather;
        weatherIconCode = marker.weatherIconCode;
      }
      explicitCover ??= marker.cover;
    }

    final averageMoodWeight = weightCount == 0
        ? null
        : (weightTotal / weightCount).round().clamp(
            1,
            SettingsService.moodOptionCount,
          );
    final averageMood = averageMoodWeight == null
        ? null
        : SettingsService.moodForWeight(averageMoodWeight, moodOptions);
    return CalendarDaySummary(
      day: day,
      entryCount: entryCount,
      wordCount: wordCount,
      hasLockedCapsule: hasLockedCapsule,
      moods: List<String>.unmodifiable(moods),
      averageMood: averageMood,
      averageMoodWeight: averageMoodWeight,
      tagColors: List<int>.unmodifiable(tagColors),
      weather: weather,
      weatherIconCode: weatherIconCode,
      explicitCover: explicitCover,
      diaryIds: List<String>.unmodifiable(diaryIds),
    );
  }
}
