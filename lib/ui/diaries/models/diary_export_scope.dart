import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

enum DiaryExportRange { all, thisYear, last30Days, custom }

/// “导出日记”页的筛选条件：日期范围、标签与是否包含归档。
///
/// 日期按发表日（createdAt 的本地日期）比较，自定义范围首尾两天都包含；
/// 选了多个标签时带有任一标签即可（与日历筛选“同组任选其一”一致）。
/// 未解封的时间胶囊在查询层已经排除（`watchAllActiveDiaries`），导出控制器
/// 还会再兜底一次。
@immutable
class DiaryExportScope {
  const DiaryExportScope({
    this.range = DiaryExportRange.all,
    this.customRange,
    this.tagIds = const <int>{},
    this.includeArchived = true,
  });

  final DiaryExportRange range;

  /// 自定义范围；[range] 不是 custom 时保留，方便来回切换。
  final DateTimeRange? customRange;
  final Set<int> tagIds;
  final bool includeArchived;

  DiaryExportScope copyWith({
    DiaryExportRange? range,
    DateTimeRange? customRange,
    Set<int>? tagIds,
    bool? includeArchived,
  }) {
    return DiaryExportScope(
      range: range ?? this.range,
      customRange: customRange ?? this.customRange,
      tagIds: tagIds ?? this.tagIds,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  /// 当前范围的起止日期（含）；全部日记为 null。
  DateTimeRange? resolveDates(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      DiaryExportRange.all => null,
      DiaryExportRange.thisYear => DateTimeRange(
        start: DateTime(now.year),
        end: today,
      ),
      DiaryExportRange.last30Days => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      DiaryExportRange.custom => customRange,
    };
  }

  List<DiaryWithTags> apply(List<DiaryWithTags> diaries, DateTime now) {
    final dates = resolveDates(now);
    final start = dates == null
        ? null
        : DateTime(dates.start.year, dates.start.month, dates.start.day);
    final endExclusive = dates == null
        ? null
        : DateTime(dates.end.year, dates.end.month, dates.end.day + 1);
    return diaries.where((DiaryWithTags detail) {
      final diary = detail.diary;
      if (!includeArchived && diary.isArchived) {
        return false;
      }
      final created = diary.createdAt.toLocal();
      if (start != null && created.isBefore(start)) {
        return false;
      }
      if (endExclusive != null && !created.isBefore(endExclusive)) {
        return false;
      }
      return tagIds.isEmpty ||
          detail.tags.any((Tag tag) => tagIds.contains(tag.id));
    }).toList();
  }
}
