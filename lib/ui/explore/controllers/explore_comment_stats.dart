import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../diaries/viewmodels/diary_comment_timeline.dart';

/// 探索页“最近的留言”卡片顶部的回看统计：一共写了几条留言、回应了几篇日记、
/// 平均隔多少天回看。
///
/// 纯计算：输入为全部可见留言的时间（`watchDiaryCommentTimings`，已排除回收站、
/// 未解封的胶囊与私密日记），输出不可变的统计值，无副作用。不跟随统计范围：
/// 留言是对旧日记的回应，按范围切开后“隔多久回看”就失去了意义。
@immutable
class ExploreCommentStats {
  const ExploreCommentStats({
    required this.total,
    required this.diaryCount,
    this.averageGapDays,
  });

  /// 没有留言时的统计。
  static const ExploreCommentStats empty = ExploreCommentStats(
    total: 0,
    diaryCount: 0,
  );

  /// 汇总 [timings]。
  ///
  /// 每条留言的间隔经 [diaryCommentDayGap] 按日历日计算（与预览页留言旁的
  /// “写下后 N 天”同一口径，跨夏令时不多不少），平均值四舍五入到整天；
  /// 同一篇的多条留言各算一次——每一次回看都是一次回应。
  static ExploreCommentStats of(List<DiaryCommentTiming> timings) {
    if (timings.isEmpty) return empty;
    final diaries = <String>{};
    var gapSum = 0;
    for (final timing in timings) {
      diaries.add(timing.diaryId);
      gapSum += diaryCommentDayGap(timing.diaryCreatedAt, timing.createdAt);
    }
    return ExploreCommentStats(
      total: timings.length,
      diaryCount: diaries.length,
      averageGapDays: (gapSum / timings.length).round(),
    );
  }

  /// 留言总条数。
  final int total;

  /// 有留言的日记篇数。
  final int diaryCount;

  /// 从日记写下到留言平均隔几天（四舍五入）；没有留言时为 null，卡片不显示
  /// 这一项。
  final int? averageGapDays;

  @override
  bool operator ==(Object other) =>
      other is ExploreCommentStats &&
      other.total == total &&
      other.diaryCount == diaryCount &&
      other.averageGapDays == averageGapDays;

  @override
  int get hashCode => Object.hash(total, diaryCount, averageGapDays);

  @override
  String toString() =>
      'ExploreCommentStats(total: $total, diaryCount: $diaryCount, '
      'averageGapDays: $averageGapDays)';
}
