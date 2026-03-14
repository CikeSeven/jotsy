import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

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
  static const Map<String, int> _calendarMoodWeights = <String, int>{
    '😭': 1,
    '😢': 2,
    '😞': 3,
    '😕': 4,
    '😐': 5,
    '🙂': 6,
    '😊': 7,
    '😄': 8,
    '😀': 9,
    '🤩': 10,
  };

  /// 构建探索页整页所需数据。
  ExploreViewData buildViewData(
    List<DiaryWithTags> diaries, {
    required DateTime now,
    required AppLocalizations l10n,
    List<int> orderedTagIds = const <int>[],
  }) {
    final fallbackPrompts = <String>[
      l10n.autoT0049,
      l10n.autoT0050,
      l10n.autoT0051,
      l10n.autoT0196,
    ];
    final stats = _buildStats(diaries, now: now);
    final onThisDayDiaries = _pickOnThisDayList(diaries, now: now, l10n: l10n);
    final fallbackPrompt = fallbackPrompts[now.day % fallbackPrompts.length];

    final moodWeights30 = _buildMoodSeries(diaries, days: 30, now: now);
    final energyValues7 = _buildEnergySeries(diaries, days: 7, now: now);
    final tagUsages = _buildTagCloud(
      diaries,
      orderedTagIds: orderedTagIds,
    );
    final mediaItems = _buildMediaGallery(diaries);
    final backdropTone = resolveBackdropTone(diaries, now: now);

    return ExploreViewData(
      stats: stats,
      onThisDayDiaries: onThisDayDiaries,
      fallbackPrompt: fallbackPrompt,
      moodWeights30: moodWeights30,
      energyValues7: energyValues7,
      tagUsages: tagUsages.take(18).toList(growable: false),
      mediaItems: mediaItems.take(12).toList(growable: false),
      backdropTone: backdropTone,
    );
  }

  /// 复用“日历按天心情均值”的口径生成探索页背景色调：
  /// - 均值 >= 6 视为偏暖；
  /// - 均值 < 6 视为偏冷；
  /// - 今日无有效心情时默认暖色。
  ExploreBackdropTone resolveBackdropTone(
    List<DiaryWithTags> diaries, {
    required DateTime now,
  }) {
    final today = DateUtils.dateOnly(now.toLocal());
    var totalWeight = 0;
    var validCount = 0;

    for (final item in diaries) {
      final createdDay = DateUtils.dateOnly(item.diary.createdAt.toLocal());
      if (createdDay != today) {
        continue;
      }
      final context = contentExtractor.parseContext(item.diary.metadata);
      final mood = context?['moodEmoji']?.toString().trim();
      if (mood == null || mood.isEmpty) {
        continue;
      }
      final weight = _calendarMoodWeights[mood];
      if (weight == null) {
        continue;
      }
      totalWeight += weight;
      validCount += 1;
    }

    if (validCount == 0) {
      return ExploreBackdropTone.warm;
    }

    final averageWeight = totalWeight / validCount;
    return averageWeight >= 6
        ? ExploreBackdropTone.warm
        : ExploreBackdropTone.cool;
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
    required AppLocalizations l10n,
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
            timeLabel: _buildOnThisDayLabel(
              item.diary.createdAt,
              now: now,
              l10n: l10n,
            ),
          ),
        )
        .toList(growable: false);
  }

  /// 生成“那年今日”卡片时间标签。
  ///
  /// 优先使用“X年前的今天”；在无法形成有效年差时，回退到具体日期字符串。
  String _buildOnThisDayLabel(
    DateTime createdAt, {
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final localCreated = createdAt.toLocal();
    final yearDiff = now.year - localCreated.year;
    if (yearDiff > 0) {
      if (l10n.isZh) {
        return '$yearDiff年前的今天';
      }
      return yearDiff == 1 ? '1 year ago today' : '$yearDiff years ago today';
    }
    if (l10n.isZh) {
      return '${localCreated.year}年${localCreated.month}月${localCreated.day}日';
    }
    return DateFormat('MMM d, y', 'en').format(localCreated);
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
  ///
  /// 排序策略：
  /// - 优先遵循用户在“标签管理”中配置的顺序；
  /// - 若存在未命中顺序表的标签，则放在后面并按名称升序兜底。
  List<ExploreTagUsage> _buildTagCloud(
    List<DiaryWithTags> diaries, {
    required List<int> orderedTagIds,
  }) {
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

    final orderRank = <int, int>{
      for (int i = 0; i < orderedTagIds.length; i++) orderedTagIds[i]: i,
    };
    final usages = tagMap.values.toList(growable: false)
      ..sort((a, b) {
        final rankA = orderRank[a.id] ?? 1 << 20;
        final rankB = orderRank[b.id] ?? 1 << 20;
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }
        return a.name.compareTo(b.name);
      });
    final maxCount = usages.isEmpty
        ? 1
        : usages.fold<int>(
            1,
            (currentMax, item) =>
                item.count > currentMax ? item.count : currentMax,
          );
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
