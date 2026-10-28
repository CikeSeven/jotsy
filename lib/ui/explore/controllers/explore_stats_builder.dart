import '../../../core/database/app_database.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';
import '../models/explore_view_data.dart';
import '../viewmodels/explore_entry.dart';
import 'explore_page_controller.dart';

/// 探索页的数字类聚合：数据看板、连续天数、今日问候、周期回顾、里程碑与
/// 心情分布。纯函数，无副作用；输入为已解析的条目（[ExploreEntry]）。
///
/// 日期一律按本地日期分界，逐日回溯用日期构造（`DateTime(y, m, d - 1)`），
/// 不减 24 小时，夏令时切换日不会多算或少算。
abstract final class ExploreStatsBuilder {
  /// [range] 内的条目；为 null（全部）时原样返回。
  static List<ExploreEntry> inRange(
    List<ExploreEntry> entries,
    ExploreDateRange? range,
  ) {
    if (range == null) return entries;
    return <ExploreEntry>[
      for (final entry in entries)
        if (range.contains(entry.created)) entry,
    ];
  }

  /// 当前连续记录天数：从今天往前数；今天还没写时从昨天数起（连续还没断）。
  static int currentStreak(Set<int> dayKeys, DateTime now) {
    var probe = DateTime(now.year, now.month, now.day);
    if (!dayKeys.contains(exploreDayKey(probe))) {
      probe = DateTime(probe.year, probe.month, probe.day - 1);
    }
    var streak = 0;
    while (dayKeys.contains(exploreDayKey(probe))) {
      streak += 1;
      probe = DateTime(probe.year, probe.month, probe.day - 1);
    }
    return streak;
  }

  /// 一组本地日期里最长的连续天数（日记本统计页同一口径）。
  static int longestStreak(Iterable<DateTime> days) {
    final sorted = days.toSet().toList()..sort();
    var longest = 0;
    var current = 0;
    DateTime? previous;
    for (final day in sorted) {
      final expected = previous == null
          ? null
          : DateTime(previous.year, previous.month, previous.day + 1);
      current = expected == day ? current + 1 : 1;
      if (current > longest) longest = current;
      previous = day;
    }
    return longest;
  }

  /// 首尾两天之间的天数（含首尾）；本地零点按 UTC 日历相减，跨夏令时不差一天。
  static int spanDays(DateTime first, DateTime last) =>
      exploreDaysBetween(first, last) + 1;

  static ExploreGreetingData greeting(List<ExploreEntry> all, DateTime now) {
    final todayKey = exploreDayKey(now);
    var entries = 0;
    var words = 0;
    for (final entry in all) {
      if (entry.dayKey == todayKey) {
        entries += 1;
        words += entry.words;
      }
    }
    return ExploreGreetingData(
      todayEntries: entries,
      todayWords: words,
      totalEntries: all.length,
    );
  }

  /// 数据看板：篇数、字数、记录天数、平均字数、照片、标签与时间跨度按
  /// [range]；连续天数与今日字数始终按全部日记。[photoCounts]（日记 id →
  /// 图片数）还没读到时照片数为 null。
  static ExploreMetricValues overview(
    List<ExploreEntry> all, {
    required ExploreDateRange? range,
    required DateTime now,
    Map<String, int>? photoCounts,
  }) {
    final scoped = inRange(all, range);
    var words = 0;
    final days = <int>{};
    final tagIds = <int>{};
    DateTime? first;
    DateTime? last;
    var photos = 0;
    for (final entry in scoped) {
      words += entry.words;
      days.add(entry.dayKey);
      for (final tag in entry.tags) {
        tagIds.add(tag.id);
      }
      if (first == null || entry.day.isBefore(first)) first = entry.day;
      if (last == null || entry.day.isAfter(last)) last = entry.day;
      photos += photoCounts?[entry.diaryId] ?? 0;
    }
    final allDays = <int>{for (final entry in all) entry.dayKey};
    final allDates = <DateTime>{for (final entry in all) entry.day};
    final todayKey = exploreDayKey(now);
    var todayWords = 0;
    for (final entry in all) {
      if (entry.dayKey == todayKey) todayWords += entry.words;
    }
    return ExploreMetricValues(
      first: first,
      values: <ExploreMetric, int?>{
        ExploreMetric.entries: scoped.length,
        ExploreMetric.words: words,
        ExploreMetric.recordedDays: days.length,
        ExploreMetric.currentStreak: currentStreak(allDays, now),
        ExploreMetric.longestStreak: longestStreak(allDates),
        ExploreMetric.averageWords: scoped.isEmpty
            ? 0
            : (words / scoped.length).round(),
        ExploreMetric.photos: photoCounts == null ? null : photos,
        ExploreMetric.tags: tagIds.length,
        ExploreMetric.span: first == null || last == null
            ? 0
            : spanDays(first, last),
        ExploreMetric.todayWords: todayWords,
      },
    );
  }

  /// 周期回顾：[period] 当前一期与上一期。
  static ExploreRecapData recap(
    List<ExploreEntry> all, {
    required ExplorePeriod period,
    required DateTime now,
    required int firstWeekday,
  }) {
    final range =
        explorePeriodRange(period, now, firstWeekday: firstWeekday) ??
        explorePeriodRange(
          ExplorePeriod.month,
          now,
          firstWeekday: firstWeekday,
        )!;
    final previous = explorePreviousRange(period, range);
    return ExploreRecapData(
      period: period,
      range: range,
      current: _recapStats(inRange(all, range)),
      previous: _recapStats(inRange(all, previous)),
    );
  }

  static ExploreRecapStats _recapStats(List<ExploreEntry> entries) {
    var words = 0;
    final days = <int>{};
    final moods = <String, int>{};
    for (final entry in entries) {
      words += entry.words;
      days.add(entry.dayKey);
      final mood = entry.mood;
      if (mood != null) moods[mood] = (moods[mood] ?? 0) + 1;
    }
    String? topMood;
    var topCount = 0;
    for (final MapEntry(key: emoji, value: count) in moods.entries) {
      if (count > topCount) {
        topMood = emoji;
        topCount = count;
      }
    }
    final tags = const ExplorePageController().buildTagUsages(
      <ExploreDiaryOverview>[for (final entry in entries) entry.source],
      orderedTagIds: const <int>[],
    );
    ExploreTagUsage? topTag;
    for (final tag in tags) {
      if (topTag == null || tag.count > topTag.count) topTag = tag;
    }
    return ExploreRecapStats(
      entries: entries.length,
      words: words,
      days: days.length,
      topMood: topMood,
      topTag: topTag,
    );
  }

  /// 各类里程碑的档位（升序）。
  static const Map<ExploreMilestoneKind, List<int>> milestoneSteps =
      <ExploreMilestoneKind, List<int>>{
        ExploreMilestoneKind.entries: <int>[
          1,
          10,
          30,
          50,
          100,
          200,
          365,
          500,
          1000,
          2000,
          5000,
        ],
        ExploreMilestoneKind.words: <int>[
          1000,
          10000,
          50000,
          100000,
          300000,
          500000,
          1000000,
          2000000,
          5000000,
        ],
        ExploreMilestoneKind.streak: <int>[
          3,
          7,
          14,
          30,
          60,
          100,
          180,
          365,
          1000,
        ],
        ExploreMilestoneKind.days: <int>[7, 30, 100, 200, 365, 500, 1000, 2000],
        ExploreMilestoneKind.years: <int>[1, 2, 3, 5, 10, 15, 20],
      };

  /// 里程碑进度：篇数、总字数、最长连续、记录天数与记录年数（从第一篇起
  /// 满几年）。
  static List<ExploreMilestone> milestones(
    List<ExploreEntry> all, {
    required List<ExploreMilestoneKind> kinds,
    required DateTime now,
  }) {
    var words = 0;
    final days = <DateTime>{};
    DateTime? first;
    for (final entry in all) {
      words += entry.words;
      days.add(entry.day);
      if (first == null || entry.day.isBefore(first)) first = entry.day;
    }
    int value(ExploreMilestoneKind kind) => switch (kind) {
      ExploreMilestoneKind.entries => all.length,
      ExploreMilestoneKind.words => words,
      ExploreMilestoneKind.streak => longestStreak(days),
      ExploreMilestoneKind.days => days.length,
      ExploreMilestoneKind.years => first == null ? 0 : _fullYears(first, now),
    };
    return <ExploreMilestone>[
      for (final kind in kinds) _milestone(kind, value(kind)),
    ];
  }

  static ExploreMilestone _milestone(ExploreMilestoneKind kind, int value) {
    final steps = milestoneSteps[kind]!;
    int? achieved;
    int? next;
    var count = 0;
    for (final step in steps) {
      if (value >= step) {
        achieved = step;
        count += 1;
      } else {
        next = step;
        break;
      }
    }
    return ExploreMilestone(
      kind: kind,
      value: value,
      achievedCount: count,
      achieved: achieved,
      next: next,
    );
  }

  /// 从 [first] 到 [now] 满了几年（按日历年月日）。
  static int _fullYears(DateTime first, DateTime now) {
    var years = now.year - first.year;
    if (now.month < first.month ||
        (now.month == first.month && now.day < first.day)) {
      years -= 1;
    }
    return years < 0 ? 0 : years;
  }

  /// 心情分布：[entries] 里用过的心情，按次数（或心情档位由高到低）排序。
  /// [moodWeights] 为心情 emoji → 档位（1~10）。
  static List<ExploreMoodShare> moodShare(
    List<ExploreEntry> entries, {
    required ExploreMoodSort sort,
    required Map<String, int> moodWeights,
  }) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final mood = entry.mood;
      if (mood != null) counts[mood] = (counts[mood] ?? 0) + 1;
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final shares = <ExploreMoodShare>[
      for (final MapEntry(key: emoji, value: count) in counts.entries)
        ExploreMoodShare(
          emoji: emoji,
          count: count,
          total: total,
          weight: moodWeights[emoji],
        ),
    ];
    int byCount(ExploreMoodShare a, ExploreMoodShare b) {
      final diff = b.count.compareTo(a.count);
      return diff != 0 ? diff : a.emoji.compareTo(b.emoji);
    }

    shares.sort(switch (sort) {
      ExploreMoodSort.count => byCount,
      ExploreMoodSort.mood => (a, b) {
        final diff = (b.weight ?? 0).compareTo(a.weight ?? 0);
        return diff != 0 ? diff : byCount(a, b);
      },
    });
    return List<ExploreMoodShare>.unmodifiable(shares);
  }
}

/// 两个本地日期相差的天数（[b] − [a]），按日历日计，不受夏令时影响。
int exploreDaysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
