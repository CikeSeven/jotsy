import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 日历打点筛选（按标签或心情）。
///
/// 输入：所选标签 id 与心情 emoji；输出过滤后的打点。不可变、无副作用。
/// 筛选是日历页的临时状态，不写进 `CalendarDisplayOptions`，离开页面即
/// 清空；它只影响日期格与统计（月度概览、年视图、范围统计），那年今日与
/// 选中日的日记列表照常显示全部。
///
/// 口径：同一类里任选其一即可（标签之间、心情之间为“或”），两类都选时
/// 需同时满足（“与”）。未解封的时间胶囊不参与筛选、始终保留：它只贡献
/// 锁角标，若按心情或标签决定锁是否出现，等于提前泄露了胶囊的内容。
@immutable
class CalendarMarkerFilter {
  const CalendarMarkerFilter({
    this.tagIds = const <int>{},
    this.moods = const <String>{},
  });

  final Set<int> tagIds;
  final Set<String> moods;

  bool get isActive => tagIds.isNotEmpty || moods.isNotEmpty;

  bool matches(DiaryCalendarMarker marker, {required DateTime now}) {
    if (marker.isLockedCapsuleAt(now)) {
      return true;
    }
    if (tagIds.isNotEmpty && !marker.tagIds.any(tagIds.contains)) {
      return false;
    }
    return moods.isEmpty || moods.contains(marker.moodEmoji);
  }

  /// 过滤打点；未启用筛选时原样返回同一个列表（页面据此复用聚合缓存）。
  List<DiaryCalendarMarker> apply(
    List<DiaryCalendarMarker> markers, {
    required DateTime now,
  }) {
    if (!isActive) {
      return markers;
    }
    return markers
        .where((DiaryCalendarMarker marker) => matches(marker, now: now))
        .toList(growable: false);
  }

  CalendarMarkerFilter toggleTag(int tagId) =>
      CalendarMarkerFilter(tagIds: _toggled(tagIds, tagId), moods: moods);

  CalendarMarkerFilter toggleMood(String mood) =>
      CalendarMarkerFilter(tagIds: tagIds, moods: _toggled(moods, mood));

  /// 去掉已不存在的标签（标签被删除后筛选不应残留看不见的条件）。
  CalendarMarkerFilter retainTags(Iterable<int> existingTagIds) {
    final existing = existingTagIds.toSet();
    if (tagIds.every(existing.contains)) {
      return this;
    }
    return CalendarMarkerFilter(
      tagIds: tagIds.where(existing.contains).toSet(),
      moods: moods,
    );
  }

  static Set<T> _toggled<T>(Set<T> values, T value) {
    final next = Set<T>.of(values);
    if (!next.remove(value)) {
      next.add(value);
    }
    return Set<T>.unmodifiable(next);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarMarkerFilter &&
      setEquals(other.tagIds, tagIds) &&
      setEquals(other.moods, moods);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tagIds),
    Object.hashAllUnordered(moods),
  );
}
