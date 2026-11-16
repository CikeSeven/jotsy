import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../core/database/diary_list_scope.dart';

/// 媒体画廊右上角菜单的筛选：日记本范围、发表时间范围与排序。只在页面内
/// 存活，不持久化（每次进入画廊都是全部日记、不限时间、最新在前）。
@immutable
class ExploreMediaGalleryFilter {
  const ExploreMediaGalleryFilter({
    this.scope = DiaryListScope.all,
    this.range,
    this.newestFirst = true,
  });

  /// “日记本图片”：全部 / 未收录 / 某本日记本（经 `resolveNotebookScope`）。
  final DiaryListScope scope;

  /// “时间选择”：按天的发表日期范围（含两端），null 为不限。
  final DateTimeRange? range;

  /// “排序”：true 为最新在前（默认），false 为最早在前。
  final bool newestFirst;

  /// 范围起点：起始那天的零点。
  DateTime? get from {
    final start = range?.start;
    return start == null ? null : DateTime(start.year, start.month, start.day);
  }

  /// 范围终点：结束那天的最后一毫秒（含这一天）。
  DateTime? get to {
    final end = range?.end;
    return end == null
        ? null
        : DateTime(
            end.year,
            end.month,
            end.day + 1,
          ).subtract(const Duration(milliseconds: 1));
  }

  ExploreMediaGalleryFilter copyWith({
    DiaryListScope? scope,
    DateTimeRange? Function()? range,
    bool? newestFirst,
  }) {
    return ExploreMediaGalleryFilter(
      scope: scope ?? this.scope,
      range: range == null ? this.range : range(),
      newestFirst: newestFirst ?? this.newestFirst,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExploreMediaGalleryFilter &&
      other.scope == scope &&
      other.range == range &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode => Object.hash(scope, range, newestFirst);
}
