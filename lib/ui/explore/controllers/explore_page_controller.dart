import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import 'explore_content_extractor.dart';
import '../models/explore_view_data.dart';

/// 探索页控制器。
///
/// 职责边界：
/// - 负责从日记列表聚合探索页所需的数据模型；
/// - 负责 metadata 解析、趋势计算、标签/媒体归并；
/// - 不负责 Widget 构建与导航。
class ExplorePageController {
  const ExplorePageController();

  final ExploreContentExtractor contentExtractor = const ExploreContentExtractor();
  static const int _onThisDayMaxEntries = 12;

  static const Map<String, double> _moodWeight = <String, double>{
    '😭': 1,
    '😢': 1.5,
    '😞': 2,
    '😕': 2.5,
    '😐': 3,
    '🙂': 3.5,
    '😊': 4,
    '😄': 4.5,
    '😀': 4.8,
    '🤩': 5,
  };

  static const List<String> _fallbackPrompts = <String>[
    '今天发生了什么意料之外的好事？',
    '如果给今天取个标题，你会写什么？',
    '今天最值得记住的一瞬间是什么？',
    '今天你最想感谢的人或事是什么？',
  ];

  /// 构建探索页整页所需数据。
  ExploreViewData buildViewData(
    List<DiaryWithTags> diaries, {
    required DateTime now,
  }) {
    final stats = _buildStats(diaries, now: now);
    final onThisDayDiaries = _pickOnThisDayList(diaries, now: now);
    final fallbackPrompt = _fallbackPrompts[now.day % _fallbackPrompts.length];

    final moodWeights30 = _buildMoodSeries(diaries, days: 30, now: now);
    final energyValues7 = _buildEnergySeries(diaries, days: 7, now: now);
    final tagUsages = _buildTagCloud(diaries);
    final mediaItems = _buildMediaGallery(diaries);

    return ExploreViewData(
      stats: stats,
      onThisDayDiaries: onThisDayDiaries,
      fallbackPrompt: fallbackPrompt,
      moodWeights30: moodWeights30,
      energyValues7: energyValues7,
      tagUsages: tagUsages.take(18).toList(growable: false),
      mediaItems: mediaItems.take(12).toList(growable: false),
    );
  }

  /// 生成顶部看板统计。
  ExploreStats _buildStats(List<DiaryWithTags> diaries, {required DateTime now}) {
    final monthStart = DateTime(now.year, now.month);
    final monthChars = diaries
        .where(
          (item) =>
              item.diary.createdAt.isAfter(monthStart.subtract(const Duration(seconds: 1))),
        )
        .fold<int>(
          0,
          (sum, item) => sum + item.diary.contentText.trim().length,
        );

    final daySet =
        diaries
            .map((item) => DateUtils.dateOnly(item.diary.createdAt.toLocal()))
            .toSet();
    var streak = 0;
    var probe = DateUtils.dateOnly(now);
    while (daySet.contains(probe)) {
      streak += 1;
      probe = probe.subtract(const Duration(days: 1));
    }

    return ExploreStats(
      totalRecords: diaries.length,
      streakDays: streak,
      currentMonthChars: monthChars,
    );
  }

  /// 选择“那年今日”候选列表：
  /// - 同月同日；
  /// - 年份早于当前年；
  /// - 按创建时间倒序，最近年份优先；
  /// - 默认最多展示 12 条，避免轮播过长影响浏览体验。
  List<ExploreOnThisDayItem> _pickOnThisDayList(
    List<DiaryWithTags> diaries, {
    required DateTime now,
  }) {
    final candidates =
        diaries.where((item) {
          final created = item.diary.createdAt.toLocal();
          return created.month == now.month &&
              created.day == now.day &&
              created.year < now.year;
        }).toList()
          ..sort((a, b) => b.diary.createdAt.compareTo(a.diary.createdAt));

    return candidates
        .take(_onThisDayMaxEntries)
        .map(
          (item) => ExploreOnThisDayItem(
            diary: item,
            timeLabel: _buildOnThisDayLabel(item.diary.createdAt, now: now),
          ),
        )
        .toList(growable: false);
  }

  /// 生成“那年今日”卡片时间标签。
  ///
  /// 优先使用“X年前的今天”；在无法形成有效年差时，回退到具体日期字符串。
  String _buildOnThisDayLabel(DateTime createdAt, {required DateTime now}) {
    final localCreated = createdAt.toLocal();
    final yearDiff = now.year - localCreated.year;
    if (yearDiff > 0) {
      return '$yearDiff年前的今天';
    }
    return '${localCreated.year}年${localCreated.month}月${localCreated.day}日';
  }

  List<double?> _buildMoodSeries(
    List<DiaryWithTags> diaries, {
    required int days,
    required DateTime now,
  }) {
    return _buildDailySeries(
      diaries,
      days: days,
      now: now,
      extractor: (context) {
        final mood = context?['moodEmoji']?.toString().trim();
        if (mood == null) {
          return null;
        }
        return _moodWeight[mood];
      },
    );
  }

  List<double?> _buildEnergySeries(
    List<DiaryWithTags> diaries, {
    required int days,
    required DateTime now,
  }) {
    return _buildDailySeries(
      diaries,
      days: days,
      now: now,
      extractor: (context) {
        final raw = context?['energyLevel'];
        return switch (raw) {
          num value => value.toDouble(),
          String value => double.tryParse(value),
          _ => null,
        };
      },
    );
  }

  /// 通用“按日聚合平均值”序列构建器。
  ///
  /// 用于情绪和精力这类“同一天多条记录需要均值化”的趋势数据。
  List<double?> _buildDailySeries(
    List<DiaryWithTags> diaries, {
    required int days,
    required DateTime now,
    required double? Function(Map<String, dynamic>? context) extractor,
  }) {
    final buckets = <DateTime, List<double>>{};
    for (final item in diaries) {
      final context = contentExtractor.parseContext(item.diary.metadata);
      final value = extractor(context);
      if (value == null) {
        continue;
      }
      final day = DateUtils.dateOnly(item.diary.createdAt.toLocal());
      final bucket = buckets.putIfAbsent(day, () => <double>[]);
      bucket.add(value);
    }

    final result = <double?>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateUtils.dateOnly(now.subtract(Duration(days: i)));
      final values = buckets[day];
      if (values == null || values.isEmpty) {
        result.add(null);
        continue;
      }
      result.add(values.reduce((a, b) => a + b) / values.length);
    }
    return result;
  }

  /// 标签频次统计 + 最近关联日记定位。
  List<ExploreTagUsage> _buildTagCloud(List<DiaryWithTags> diaries) {
    final tagMap = <int, ExploreTagUsage>{};
    for (final item in diaries) {
      for (final tag in item.tags) {
        final previous = tagMap[tag.id];
        if (previous == null) {
          tagMap[tag.id] = ExploreTagUsage(
            id: tag.id,
            name: tag.name,
            color: tag.color,
            count: 1,
            latestDiaryId: item.diary.diaryId,
            latestAt: item.diary.updatedAt,
            maxCount: 1,
          );
          continue;
        }

        final shouldReplaceLatest = item.diary.updatedAt.isAfter(previous.latestAt);
        tagMap[tag.id] = previous.copyWith(
          count: previous.count + 1,
          latestDiaryId:
              shouldReplaceLatest ? item.diary.diaryId : previous.latestDiaryId,
          latestAt: shouldReplaceLatest ? item.diary.updatedAt : previous.latestAt,
        );
      }
    }

    final usages = tagMap.values.toList(growable: false)
      ..sort((a, b) => b.count.compareTo(a.count));
    final maxCount = usages.isEmpty ? 1 : usages.first.count;
    return usages
        .map((item) => item.copyWith(maxCount: maxCount))
        .toList(growable: false);
  }

  /// 提取媒体画廊数据（封面优先，正文首图兜底）。
  List<ExploreMediaItem> _buildMediaGallery(List<DiaryWithTags> diaries) {
    final seen = <String>{};
    final items = <ExploreMediaItem>[];
    for (final item in diaries) {
      final source = contentExtractor.resolveMediaSource(item.diary);
      if (source == null || !seen.add(source)) {
        continue;
      }
      items.add(
        ExploreMediaItem(
          source: source,
          diaryId: item.diary.diaryId,
          updatedAt: item.diary.updatedAt,
        ),
      );
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

}
