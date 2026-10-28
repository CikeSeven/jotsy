import 'dart:math';

import '../../../core/database/app_database.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../models/explore_view_data.dart';
import '../viewmodels/explore_entry.dart';
import 'explore_page_controller.dart';

/// 探索页的“生活记录”与回忆类聚合：标签、媒体（封面）、常去地点、天气、
/// 随机回顾的候选与最近解封的胶囊。纯函数，无副作用。
abstract final class ExploreLifeBuilder {
  /// 标签：[entries] 里用过的标签，按 [sort] 排序后取前 [limit] 个（0 为
  /// 全部）。手动顺序即标签管理里的顺序（[orderedTagIds]）。
  static List<ExploreTagUsage> tags(
    List<ExploreEntry> entries, {
    required ExploreTagSort sort,
    required int limit,
    required List<int> orderedTagIds,
  }) {
    final usages = const ExplorePageController().buildTagUsages(
      <ExploreDiaryOverview>[for (final entry in entries) entry.source],
      orderedTagIds: orderedTagIds,
    ).toList();
    switch (sort) {
      case ExploreTagSort.manual:
        break;
      case ExploreTagSort.count:
        usages.sort((a, b) {
          final diff = b.count.compareTo(a.count);
          return diff != 0 ? diff : a.name.compareTo(b.name);
        });
      case ExploreTagSort.recent:
        usages.sort((a, b) {
          final diff = b.latestAt.compareTo(a.latestAt);
          return diff != 0 ? diff : a.name.compareTo(b.name);
        });
    }
    return List<ExploreTagUsage>.unmodifiable(
      limit <= 0 ? usages : usages.take(limit),
    );
  }

  /// 封面图：最近更新的在前，同一来源只出现一次。
  static List<ExploreMediaItem> covers(
    List<ExploreEntry> entries, {
    required int limit,
  }) {
    final seen = <String>{};
    final items = <ExploreMediaItem>[];
    final sorted = <ExploreEntry>[...entries]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final entry in sorted) {
      final cover = entry.cover;
      if (cover == null || !seen.add(cover)) continue;
      items.add(
        ExploreMediaItem(
          source: cover,
          diaryId: entry.diaryId,
          updatedAt: entry.updatedAt,
        ),
      );
      if (items.length >= limit) break;
    }
    return List<ExploreMediaItem>.unmodifiable(items);
  }

  /// 常去地点：按地点文字分组（去首尾空白），次数多的在前，同次数时最近
  /// 去过的在前；每组的日记新 → 旧。
  static List<ExploreGroupCount> places(
    List<ExploreEntry> entries, {
    required int limit,
  }) {
    return _group(entries, limit: limit, keyOf: (entry) => entry.location);
  }

  /// 天气：按天气图标代码分组（没有代码时按天气文字），标签取最近一篇的
  /// 天气文字。
  static List<ExploreGroupCount> weather(List<ExploreEntry> entries) {
    return _group(
      entries,
      limit: 0,
      keyOf: (entry) => entry.weatherIconCode ?? entry.weather,
      labelOf: (entry) => entry.weather ?? '',
      iconOf: (entry) => entry.weatherIconCode,
    );
  }

  static List<ExploreGroupCount> _group(
    List<ExploreEntry> entries, {
    required int limit,
    required String? Function(ExploreEntry entry) keyOf,
    String Function(ExploreEntry entry)? labelOf,
    String? Function(ExploreEntry entry)? iconOf,
  }) {
    final groups = <String, List<ExploreEntry>>{};
    for (final entry in entries) {
      final key = keyOf(entry);
      if (key == null) continue;
      groups.putIfAbsent(key, () => <ExploreEntry>[]).add(entry);
    }
    final result =
        <({String key, List<ExploreEntry> items})>[
          for (final MapEntry(:key, :value) in groups.entries)
            (
              key: key,
              items: value..sort((a, b) => b.created.compareTo(a.created)),
            ),
        ]..sort((a, b) {
          final diff = b.items.length.compareTo(a.items.length);
          if (diff != 0) return diff;
          return b.items.first.created.compareTo(a.items.first.created);
        });
    final limited = limit <= 0 ? result : result.take(limit);
    return List<ExploreGroupCount>.unmodifiable(<ExploreGroupCount>[
      for (final group in limited)
        ExploreGroupCount(
          label: () {
            final label = labelOf?.call(group.items.first) ?? group.key;
            return label.isEmpty ? group.key : label;
          }(),
          count: group.items.length,
          iconCode: iconOf?.call(group.items.first),
          diaryIds: <String>[for (final entry in group.items) entry.diaryId],
        ),
    ]);
  }

  /// 随机回顾的候选：按 [source] 只要足够久以前的，[photosOnly] 时只要有封面
  /// 的；新 → 旧。
  static List<ExploreEntry> randomPool(
    List<ExploreEntry> all, {
    required DateTime now,
    required ExploreRandomSource source,
    required bool photosOnly,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = switch (source) {
      ExploreRandomSource.all => null,
      ExploreRandomSource.monthAgo => DateTime(
        today.year,
        today.month - 1,
        today.day,
      ),
      ExploreRandomSource.yearAgo => DateTime(
        today.year - 1,
        today.month,
        today.day,
      ),
    };
    return List<ExploreEntry>.unmodifiable(
      <ExploreEntry>[
        for (final entry in all)
          if ((cutoff == null || !entry.day.isAfter(cutoff)) &&
              (!photosOnly || entry.cover != null))
            entry,
      ]..sort((a, b) {
        final diff = b.created.compareTo(a.created);
        return diff != 0 ? diff : b.diaryId.compareTo(a.diaryId);
      }),
    );
  }

  /// 从 [pool] 里按 [seed] 抽一篇；同一个种子总抽到同一篇（“每日一篇”用
  /// 当天日期作种子）。
  static ExploreEntry? pick(List<ExploreEntry> pool, int seed) {
    if (pool.isEmpty) return null;
    return pool[Random(seed).nextInt(pool.length)];
  }

  /// 最近 30 天里解封的时间胶囊（新 → 旧，最多 3 篇）。
  static List<ExploreEntry> recentCapsules(
    List<ExploreEntry> all, {
    required DateTime now,
  }) {
    final since = DateTime(now.year, now.month, now.day - 30);
    final items = <ExploreEntry>[
      for (final entry in all)
        if (entry.capsuleLockedAt != null &&
            !entry.created.isAfter(now) &&
            !entry.created.isBefore(since))
          entry,
    ]..sort((a, b) => b.created.compareTo(a.created));
    return List<ExploreEntry>.unmodifiable(items.take(3));
  }
}
