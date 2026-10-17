import 'package:flutter/material.dart' show DateUtils;

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import 'explore_content_extractor.dart';

/// 将最近 30 天的日记聚合为心情（30 天）与精力（7 天）趋势，不涉及 UI。
///
/// 先按展示用的本地日期排除历史/未来记录，再为每篇相关日记解析一次 metadata。
/// 两条趋势共用这一遍扫描；每个日期只存和与数量，不保留全历史的逐条值。
/// 日期仍按原有 now.subtract 的口径生成，避免改变时区/夏令时边界上的展示。
class ExploreTrendBuilder {
  const ExploreTrendBuilder({this.extractor = const ExploreContentExtractor()});

  final ExploreContentExtractor extractor;

  ({List<double?> moodWeights30, List<double?> energyValues7}) build(
    List<ExploreDiaryOverview> diaries, {
    required DateTime now,
    required List<String> moodOptions,
  }) {
    final days = <DateTime>[
      for (var i = 29; i >= 0; i--)
        DateUtils.dateOnly(now.subtract(Duration(days: i))),
    ];
    final energyDays = days.skip(23).toSet();
    final buckets = <DateTime, _DayTrends>{
      for (final day in days) day: _DayTrends(),
    };
    final moodScores = SettingsService.buildMoodScoreMap(moodOptions);
    final start = days.first;
    final today = days.last;
    final end = DateTime(today.year, today.month, today.day + 1);
    for (final diary in diaries) {
      // 先比较时间戳：为整库历史记录构造本地零点同样昂贵。日界按自然日
      // 构造（不用 +24h），夏令时切换日仍以展示桶的本地日期为准。
      if (diary.createdAt.isBefore(start) || !diary.createdAt.isBefore(end)) {
        continue;
      }
      final day = DateUtils.dateOnly(diary.createdAt.toLocal());
      final bucket = buckets[day];
      if (bucket == null) continue;
      final context = extractor.parseContext(diary.metadata);
      final mood = context?['moodEmoji']?.toString().trim();
      if (mood != null) {
        final score = moodScores[mood];
        if (score != null) bucket.mood.add(score);
      }
      if (energyDays.contains(day)) {
        final energy = switch (context?['energyLevel']) {
          num value => value.toDouble(),
          String value => double.tryParse(value),
          _ => null,
        };
        if (energy != null) bucket.energy.add(energy);
      }
    }
    return (
      moodWeights30: [for (final day in days) buckets[day]!.mood.value],
      energyValues7: [
        for (final day in days.skip(23)) buckets[day]!.energy.value,
      ],
    );
  }
}

class _DayTrends {
  final mood = _Average();
  final energy = _Average();
}

class _Average {
  double? _sum;
  int _count = 0;

  void add(double value) {
    _sum = _sum == null ? value : _sum! + value;
    _count += 1;
  }

  double? get value => _count == 0 ? null : _sum! / _count;
}
