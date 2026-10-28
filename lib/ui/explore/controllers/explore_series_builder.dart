import '../../../core/database/app_database.dart';
import '../../widgets/mood_band_palette.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../viewmodels/explore_entry.dart';
import 'explore_stats_builder.dart';

/// 探索页的按日 / 周 / 月序列：心情与精力趋势、写作节奏、写作习惯与写作
/// 热力图。纯函数，无副作用。
///
/// 日期一律按本地日期分桶（[ExploreEntry.dayKey]），逐日生成用日期构造，
/// 不加减 24 小时。心情统一用十档的档位（1~10，[moodWeights]）；“这天的
/// 心情”（五档）换算为每段的代表档位（[MoodBandPalette.bandWeights]）。
abstract final class ExploreSeriesBuilder {
  /// 最近 [days] 天（含今天）的日期，旧 → 新。
  static List<DateTime> lastDays(DateTime now, int days) => <DateTime>[
    for (var i = days - 1; i >= 0; i--)
      DateTime(now.year, now.month, now.day - i),
  ];

  /// “这天的心情”对应的十档档位。
  static int dayMoodWeight(DayMood mood) =>
      MoodBandPalette.bandWeights[mood.index];

  /// 心情趋势：每天日记心情档位的平均；[dayMoods] 给出时，记了“这天的心情”
  /// 的日子以它为准（与日历年视图一致）。
  static List<ExploreDayValue> moodSeries(
    List<ExploreEntry> all, {
    required DateTime now,
    required int days,
    required Map<String, int> moodWeights,
    Map<DateTime, DayMood>? dayMoods,
  }) {
    final dates = lastDays(now, days);
    final sums = <int, _Average>{
      for (final day in dates) exploreDayKey(day): _Average(),
    };
    for (final entry in all) {
      final bucket = sums[entry.dayKey];
      final mood = entry.mood;
      if (bucket == null || mood == null) continue;
      final weight = moodWeights[mood];
      if (weight != null) bucket.add(weight.toDouble());
    }
    return <ExploreDayValue>[
      for (final day in dates)
        ExploreDayValue(
          day,
          dayMoods?[day] != null
              ? dayMoodWeight(dayMoods![day]!).toDouble()
              : sums[exploreDayKey(day)]!.value,
        ),
    ];
  }

  /// 精力趋势：每天日记精力（1~5）的平均。
  static List<ExploreDayValue> energySeries(
    List<ExploreEntry> all, {
    required DateTime now,
    required int days,
  }) {
    final dates = lastDays(now, days);
    final sums = <int, _Average>{
      for (final day in dates) exploreDayKey(day): _Average(),
    };
    for (final entry in all) {
      final energy = entry.energy;
      if (energy == null) continue;
      sums[entry.dayKey]?.add(energy.clamp(1, 5).toDouble());
    }
    return <ExploreDayValue>[
      for (final day in dates)
        ExploreDayValue(day, sums[exploreDayKey(day)]!.value),
    ];
  }

  /// 写作节奏：最近 12 个月 / 12 周（从每周第一天起）/ 30 天，每段的篇数或
  /// 字数，旧 → 新。
  static List<ExploreRhythmBar> rhythm(
    List<ExploreEntry> all, {
    required DateTime now,
    required ExploreRhythmUnit unit,
    required ExploreCountMetric metric,
    required int firstWeekday,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final starts = switch (unit) {
      ExploreRhythmUnit.month => <DateTime>[
        for (var i = 11; i >= 0; i--) DateTime(today.year, today.month - i),
      ],
      ExploreRhythmUnit.week => () {
        final offset = (today.weekday - firstWeekday + 7) % 7;
        return <DateTime>[
          for (var i = 11; i >= 0; i--)
            DateTime(today.year, today.month, today.day - offset - 7 * i),
        ];
      }(),
      ExploreRhythmUnit.day => lastDays(now, 30),
    };
    final values = List<int>.filled(starts.length, 0);
    final end = switch (unit) {
      ExploreRhythmUnit.month => DateTime(today.year, today.month + 1),
      ExploreRhythmUnit.week => DateTime(
        starts.last.year,
        starts.last.month,
        starts.last.day + 7,
      ),
      ExploreRhythmUnit.day => DateTime(today.year, today.month, today.day + 1),
    };
    for (final entry in all) {
      final day = entry.day;
      if (day.isBefore(starts.first) || !day.isBefore(end)) continue;
      final index = switch (unit) {
        ExploreRhythmUnit.month =>
          (day.year - starts.first.year) * 12 + day.month - starts.first.month,
        ExploreRhythmUnit.week => exploreDaysBetween(starts.first, day) ~/ 7,
        ExploreRhythmUnit.day => exploreDaysBetween(starts.first, day),
      };
      if (index < 0 || index >= values.length) continue;
      values[index] += metric == ExploreCountMetric.words ? entry.words : 1;
    }
    return <ExploreRhythmBar>[
      for (var i = 0; i < starts.length; i++)
        ExploreRhythmBar(starts[i], values[i]),
    ];
  }

  /// 写作习惯：[entries] 按发表时间落在哪个时段、星期几。
  static ExploreHabitsData habits(
    List<ExploreEntry> entries, {
    required ExploreCountMetric metric,
    required int firstWeekday,
  }) {
    final slots = List<int>.filled(ExploreDaySlot.values.length, 0);
    final order = <int>[
      for (var i = 0; i < 7; i++) (firstWeekday - 1 + i) % 7 + 1,
    ];
    final weekdays = List<int>.filled(7, 0);
    for (final entry in entries) {
      final amount = metric == ExploreCountMetric.words ? entry.words : 1;
      slots[ExploreDaySlot.ofHour(entry.created.hour).index] += amount;
      weekdays[order.indexOf(entry.created.weekday)] += amount;
    }
    return ExploreHabitsData(
      slots: List<int>.unmodifiable(slots),
      weekdays: List<int>.unmodifiable(weekdays),
      weekdayOrder: List<int>.unmodifiable(order),
    );
  }

  /// 写作热力图：最近 [weeks] 周（含本周），每周从 [firstWeekday] 起。
  static ExploreHeatmapData heatmap(
    List<ExploreEntry> all, {
    required DateTime now,
    required int weeks,
    required int firstWeekday,
    required Map<String, int> moodWeights,
    Map<DateTime, DayMood>? dayMoods,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final offset = (today.weekday - firstWeekday + 7) % 7;
    final start = DateTime(
      today.year,
      today.month,
      today.day - offset - 7 * (weeks - 1),
    );
    final end = DateTime(today.year, today.month, today.day + 1);
    final buckets = <int, _HeatBucket>{};
    for (final entry in all) {
      if (entry.day.isBefore(start) || !entry.day.isBefore(end)) continue;
      final bucket = buckets.putIfAbsent(
        entry.dayKey,
        () => _HeatBucket(entry.day),
      );
      bucket.entries.add(entry);
      bucket.words += entry.words;
      final mood = entry.mood;
      final weight = mood == null ? null : moodWeights[mood];
      if (weight != null) bucket.mood.add(weight.toDouble());
    }
    if (dayMoods != null) {
      for (final MapEntry(key: day, value: _) in dayMoods.entries) {
        if (day.isBefore(start) || !day.isBefore(end)) continue;
        buckets.putIfAbsent(exploreDayKey(day), () => _HeatBucket(day));
      }
    }
    return ExploreHeatmapData(
      start: start,
      weeks: weeks,
      today: today,
      firstWeekday: firstWeekday,
      days: <int, ExploreHeatDay>{
        for (final MapEntry(key: key, value: bucket) in buckets.entries)
          key: ExploreHeatDay(
            day: bucket.day,
            entries: bucket.entries.length,
            words: bucket.words,
            moodWeight: bucket.mood.value,
            dayMood: dayMoods?[bucket.day],
            diaryIds: <String>[
              for (final entry
                  in bucket.entries
                    ..sort((a, b) => a.created.compareTo(b.created)))
                entry.diaryId,
            ],
          ),
      },
    );
  }
}

class _HeatBucket {
  _HeatBucket(this.day);

  final DateTime day;
  final List<ExploreEntry> entries = <ExploreEntry>[];
  final _Average mood = _Average();
  int words = 0;
}

/// 只存和与数量的平均值累加器（不保留逐条值）。
class _Average {
  double _sum = 0;
  int _count = 0;

  void add(double value) {
    _sum += value;
    _count += 1;
  }

  double? get value => _count == 0 ? null : _sum / _count;
}
