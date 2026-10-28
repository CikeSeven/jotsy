import 'package:flutter/foundation.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';
import '../../explore/controllers/explore_content_extractor.dart';
import '../../explore/controllers/explore_page_controller.dart';
import '../../explore/controllers/explore_stats_builder.dart';
import '../../explore/models/explore_view_data.dart';

/// 日记本统计页的聚合数据：总览、心情分布、常用标签、写作节奏、那年今日。
///
/// 输入：本子里日记的轻量概览（`watchExploreDiaryOverviews(scope:
/// notebookStatsScope(…))`：含归档，不含已删除与未解封的胶囊）与当前时刻；
/// 输出页面直接渲染的数据。纯计算，无副作用。
///
/// 与探索页共用规则而不另写一份：字数经 [DiaryWordCounts]（DESIGN §3.3），
/// 那年今日与标签频次经 [ExplorePageController]（同一筛选与排序），心情经
/// [ExploreContentExtractor] 解析 metadata。照片数要扫正文，概览里没有，由
/// 页面另算后传入 [NotebookInsightsData.photoCount]。
@immutable
class NotebookInsightsData {
  const NotebookInsightsData({
    required this.entryCount,
    required this.wordCount,
    required this.recordedDays,
    required this.longestStreak,
    required this.first,
    required this.last,
    required this.moods,
    required this.topTags,
    required this.months,
    required this.onThisDay,
  });

  /// 常用标签最多显示几个。
  static const int maxTopTags = 8;

  /// 写作节奏最多统计几个月（第一篇晚于此时从第一篇所在月起）。
  static const int maxMonths = 12;

  factory NotebookInsightsData.build(
    List<ExploreDiaryOverview> diaries, {
    required DateTime now,
    required AppLocalizations l10n,
    ExplorePageController explore = const ExplorePageController(),
  }) {
    var words = 0;
    DateTime? first;
    DateTime? last;
    final days = <DateTime>{};
    final moodCounts = <String, int>{};
    final monthCounts = <DateTime, int>{};
    for (final diary in diaries) {
      words += DiaryWordCounts.of(
        diaryId: diary.diaryId,
        updatedAt: diary.updatedAt,
        text: diary.contentText,
      );
      final created = diary.createdAt.toLocal();
      if (first == null || created.isBefore(first)) first = created;
      if (last == null || created.isAfter(last)) last = created;
      days.add(DateTime(created.year, created.month, created.day));
      final month = DateTime(created.year, created.month);
      monthCounts[month] = (monthCounts[month] ?? 0) + 1;
      final mood = explore.contentExtractor
          .parseContext(diary.metadata)?['moodEmoji']
          ?.toString()
          .trim();
      if (mood != null && mood.isNotEmpty) {
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }

    final moodTotal = moodCounts.values.fold<int>(0, (a, b) => a + b);
    final moods =
        <NotebookMoodShare>[
          for (final MapEntry(key: emoji, value: count) in moodCounts.entries)
            NotebookMoodShare(emoji: emoji, count: count, total: moodTotal),
        ]..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.emoji.compareTo(b.emoji);
        });

    final tags = explore.buildTagUsages(diaries, orderedTagIds: const <int>[])
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });

    return NotebookInsightsData(
      entryCount: diaries.length,
      wordCount: words,
      recordedDays: days.length,
      longestStreak: longestDayStreak(days),
      first: first,
      last: last,
      moods: List<NotebookMoodShare>.unmodifiable(moods),
      topTags: List<ExploreTagUsage>.unmodifiable(tags.take(maxTopTags)),
      months: _monthBuckets(monthCounts, first: first, now: now),
      onThisDay: explore.pickOnThisDayList(diaries, now: now, l10n: l10n),
    );
  }

  final int entryCount;
  final int wordCount;

  /// 有日记的不同本地日期数。
  final int recordedDays;

  /// 最长连续记录天数。
  final int longestStreak;

  /// 最早 / 最晚一篇的发表时间（本地）；没有日记时为 null。
  final DateTime? first;
  final DateTime? last;

  /// 用过的心情，按次数从多到少。
  final List<NotebookMoodShare> moods;

  /// 次数最多的标签（最多 [maxTopTags] 个）。
  final List<ExploreTagUsage> topTags;

  /// 写作节奏：旧 → 新，最后一个是本月。
  final List<NotebookMonthCount> months;
  final List<ExploreOnThisDayItem> onThisDay;

  bool get isEmpty => entryCount == 0;

  /// 首尾两篇之间的天数（含首尾），供总览的“时间跨度”递增动画；没有日记为 0。
  int get spanDays {
    final first = this.first;
    final last = this.last;
    if (first == null || last == null) return 0;
    final a = DateTime(first.year, first.month, first.day);
    final b = DateTime(last.year, last.month, last.day);
    // 本地零点相减再四舍五入：跨夏令时的 23/25 小时日不会少算一天。
    return (b.difference(a).inHours / 24).round() + 1;
  }

  /// 一组本地日期里最长的连续天数（与探索页同一口径，见
  /// [ExploreStatsBuilder.longestStreak]）。
  static int longestDayStreak(Iterable<DateTime> days) =>
      ExploreStatsBuilder.longestStreak(days);

  static List<NotebookMonthCount> _monthBuckets(
    Map<DateTime, int> counts, {
    required DateTime? first,
    required DateTime now,
  }) {
    if (first == null) return const <NotebookMonthCount>[];
    final thisMonth = DateTime(now.year, now.month);
    final earliest = DateTime(now.year, now.month - (maxMonths - 1));
    final firstMonth = DateTime(first.year, first.month);
    var start = firstMonth.isAfter(earliest) ? firstMonth : earliest;
    // 第一篇在未来（改过发表时间）时至少显示本月这一根。
    if (start.isAfter(thisMonth)) start = thisMonth;
    return List<NotebookMonthCount>.unmodifiable(<NotebookMonthCount>[
      for (
        var month = start;
        !month.isAfter(thisMonth);
        month = DateTime(month.year, month.month + 1)
      )
        NotebookMonthCount(month: month, count: counts[month] ?? 0),
    ]);
  }
}

/// 一种心情的次数与占比。
@immutable
class NotebookMoodShare {
  const NotebookMoodShare({
    required this.emoji,
    required this.count,
    required this.total,
  });

  final String emoji;
  final int count;

  /// 填了心情的日记总数（占比的分母）。
  final int total;

  double get share => total == 0 ? 0 : count / total;

  /// 四舍五入的百分比。
  int get percent => (share * 100).round();
}

/// 写作节奏的一根柱：某月的篇数。
@immutable
class NotebookMonthCount {
  const NotebookMonthCount({required this.month, required this.count});

  /// 当月 1 日本地零点。
  final DateTime month;
  final int count;
}

/// 时间跨度的写法：不满一个月写天数（“12 天”），否则“3 年 2 个月”（零的
/// 部分省略）。从 [first] 起数 [days] 天（含首尾），递增动画的中间值同样可用。
String notebookSpanDurationLabel(
  AppLocalizations l10n,
  DateTime first,
  int days,
) {
  if (days <= 0) return l10n.notebookInsightsDays(0);
  final start = DateTime(first.year, first.month, first.day);
  final end = DateTime(start.year, start.month, start.day + days - 1);
  var months = (end.year - start.year) * 12 + end.month - start.month;
  if (end.day < start.day) months -= 1;
  if (months <= 0) return l10n.notebookInsightsDays(days);
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return l10n.notebookInsightsSpanMonths(rest);
  if (rest == 0) return l10n.notebookInsightsSpanYears(years);
  return l10n.notebookInsightsSpanYearsMonths(years, rest);
}
