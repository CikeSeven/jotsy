import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../viewmodels/explore_entry.dart';
import 'explore_module_options.dart';
import 'explore_period.dart';
import 'explore_view_data.dart';

// 各卡片聚合后的只读数据（由 `ExploreDataBuilder` 生成，卡片只负责渲染）。

/// 今日问候：今天写了几篇、多少字。
@immutable
class ExploreGreetingData {
  const ExploreGreetingData({
    required this.todayEntries,
    required this.todayWords,
    required this.totalEntries,
  });

  final int todayEntries;
  final int todayWords;
  final int totalEntries;
}

/// 数据看板：各指标的值。照片数还没读到时为 null。
@immutable
class ExploreMetricValues {
  const ExploreMetricValues({required this.values, this.first});

  final Map<ExploreMetric, int?> values;

  /// 范围内最早一篇的本地日期（时间跨度的写法要用）；没有日记时为 null。
  final DateTime? first;

  int? operator [](ExploreMetric metric) => values[metric];
}

/// 一段时间里的概况（周期回顾的一期）。
@immutable
class ExploreRecapStats {
  const ExploreRecapStats({
    required this.entries,
    required this.words,
    required this.days,
    this.topMood,
    this.topTag,
  });

  final int entries;
  final int words;

  /// 有日记的天数。
  final int days;

  /// 用得最多的心情 emoji。
  final String? topMood;

  /// 用得最多的标签。
  final ExploreTagUsage? topTag;
}

/// 周期回顾：本期与上一期。
@immutable
class ExploreRecapData {
  const ExploreRecapData({
    required this.period,
    required this.range,
    required this.current,
    required this.previous,
  });

  final ExplorePeriod period;
  final ExploreDateRange range;
  final ExploreRecapStats current;
  final ExploreRecapStats previous;
}

/// 一类里程碑的进度：[achieved] 为已达成的最高一档，[next] 为下一档（全部
/// 达成时为 null）。
@immutable
class ExploreMilestone {
  const ExploreMilestone({
    required this.kind,
    required this.value,
    required this.achievedCount,
    this.achieved,
    this.next,
  });

  final ExploreMilestoneKind kind;
  final int value;

  /// 已达成的档数。
  final int achievedCount;
  final int? achieved;
  final int? next;

  /// 向下一档的进度（0~1）；全部达成时为 1。
  double get progress {
    final next = this.next;
    if (next == null) return 1;
    final base = achieved ?? 0;
    if (next <= base) return 1;
    return ((value - base) / (next - base)).clamp(0.0, 1.0);
  }
}

/// 热力图的一天。
@immutable
class ExploreHeatDay {
  const ExploreHeatDay({
    required this.day,
    required this.entries,
    required this.words,
    required this.diaryIds,
    this.moodWeight,
    this.dayMood,
  });

  final DateTime day;
  final int entries;
  final int words;

  /// 当天日记的平均心情档位（1~10）；都没选心情时为 null。
  final double? moodWeight;

  /// 长按日历记下的“这天的心情”。
  final DayMood? dayMood;

  /// 当天的日记，按发表时间先后。
  final List<String> diaryIds;
}

/// 写作热力图：[start] 为第一格（某周第一天），共 [weeks] 列、每列 7 天。
@immutable
class ExploreHeatmapData {
  const ExploreHeatmapData({
    required this.start,
    required this.weeks,
    required this.today,
    required this.firstWeekday,
    required this.days,
  });

  final DateTime start;
  final int weeks;
  final DateTime today;
  final int firstWeekday;

  /// 有日记或有“这天的心情”的日子，按 [exploreDayKey] 索引。
  final Map<int, ExploreHeatDay> days;
}

/// 趋势图的一天：没有数据时 [value] 为 null。
@immutable
class ExploreDayValue {
  const ExploreDayValue(this.day, this.value);

  final DateTime day;
  final double? value;
}

/// 写作节奏的一根柱：从 [start] 起的一个月 / 一周 / 一天。
@immutable
class ExploreRhythmBar {
  const ExploreRhythmBar(this.start, this.value);

  final DateTime start;
  final int value;
}

/// 一天里的时段。
enum ExploreDaySlot {
  lateNight(0),
  morning(6),
  forenoon(9),
  afternoon(12),
  evening(18),
  night(21);

  const ExploreDaySlot(this.startHour);

  final int startHour;

  static ExploreDaySlot ofHour(int hour) {
    var slot = lateNight;
    for (final candidate in values) {
      if (hour >= candidate.startHour) slot = candidate;
    }
    return slot;
  }
}

/// 写作习惯：各时段与星期的篇数（或字数）。
@immutable
class ExploreHabitsData {
  const ExploreHabitsData({
    required this.slots,
    required this.weekdays,
    required this.weekdayOrder,
  });

  /// 按 [ExploreDaySlot] 顺序。
  final List<int> slots;

  /// 按 [weekdayOrder] 顺序。
  final List<int> weekdays;

  /// `DateTime.monday`…`DateTime.sunday`，从每周第一天起。
  final List<int> weekdayOrder;

  /// 最多的时段；都为 0 时为 null。
  ExploreDaySlot? get topSlot {
    final index = _maxIndex(slots);
    return index == null ? null : ExploreDaySlot.values[index];
  }

  /// 最多的星期（`DateTime.weekday`）；都为 0 时为 null。
  int? get topWeekday {
    final index = _maxIndex(weekdays);
    return index == null ? null : weekdayOrder[index];
  }

  static int? _maxIndex(List<int> values) {
    int? best;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0 && (best == null || values[i] > values[best])) {
        best = i;
      }
    }
    return best;
  }
}

/// 一种心情的次数与占比。
@immutable
class ExploreMoodShare {
  const ExploreMoodShare({
    required this.emoji,
    required this.count,
    required this.total,
    this.weight,
  });

  final String emoji;
  final int count;

  /// 填了心情的日记总数（占比的分母）。
  final int total;

  /// 心情档位（1~10）；不在心情选项里时为 null。
  final int? weight;

  double get share => total == 0 ? 0 : count / total;

  /// 四舍五入的百分比。
  int get percent => (share * 100).round();
}

/// 按某个值分组的计数（地点、天气）：[diaryIds] 新 → 旧。
@immutable
class ExploreGroupCount {
  const ExploreGroupCount({
    required this.label,
    required this.count,
    required this.diaryIds,
    this.iconCode,
  });

  final String label;
  final int count;
  final List<String> diaryIds;

  /// 天气图标代码（和风天气）；地点为 null。
  final String? iconCode;
}

/// 探索页整页聚合的数据：只算可见的卡片，其余为 null。
@immutable
class ExploreData {
  const ExploreData({
    required this.totalEntries,
    this.greeting,
    this.onThisDay,
    this.randomPool,
    this.recap,
    this.milestones,
    this.overview,
    this.heatmap,
    this.rhythm,
    this.habits,
    this.moodTrend,
    this.moodShare,
    this.energy,
    this.tags,
    this.media,
    this.places,
    this.weather,
    this.recentCapsules,
  });

  /// 全部可统计的日记篇数（不受统计范围影响）。
  final int totalEntries;
  final ExploreGreetingData? greeting;
  final List<ExploreOnThisDayItem>? onThisDay;

  /// 随机回顾的候选（按发表时间新 → 旧）。
  final List<ExploreEntry>? randomPool;
  final ExploreRecapData? recap;
  final List<ExploreMilestone>? milestones;
  final ExploreMetricValues? overview;
  final ExploreHeatmapData? heatmap;
  final List<ExploreRhythmBar>? rhythm;
  final ExploreHabitsData? habits;
  final List<ExploreDayValue>? moodTrend;
  final List<ExploreMoodShare>? moodShare;
  final List<ExploreDayValue>? energy;
  final List<ExploreTagUsage>? tags;
  final List<ExploreMediaItem>? media;
  final List<ExploreGroupCount>? places;
  final List<ExploreGroupCount>? weather;

  /// 最近 30 天解封的胶囊（新 → 旧，最多 3 篇）。
  final List<ExploreEntry>? recentCapsules;
}
