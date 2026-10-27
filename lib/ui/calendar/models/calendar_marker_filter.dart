import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../notebooks/viewmodels/notebook_view.dart';

/// 日历筛选面板可选的日记本：普通、可见性为 normal 的本子，保持书架顺序，
/// 已合上的排在最后（合上了也仍装着日记）。
///
/// 私密本子（隐藏 / 上锁）里的日记不进日历打点，列出来也筛不出任何东西，
/// 还会在日历页露出它的名字；智能日记本见 [CalendarMarkerFilter] 的说明。
List<NotebookView> calendarFilterNotebooks(Iterable<NotebookView> notebooks) {
  final eligible = notebooks
      .where(
        (NotebookView notebook) =>
            notebook.isManual &&
            notebook.effectiveVisibility == NotebookVisibility.normal,
      )
      .toList(growable: false);
  return List<NotebookView>.unmodifiable(<NotebookView>[
    ...eligible.where((NotebookView notebook) => !notebook.isClosed),
    ...eligible.where((NotebookView notebook) => notebook.isClosed),
  ]);
}

/// 日历打点筛选（按心情、标签或日记本）。
///
/// 输入：所选标签 id、心情 emoji 与普通日记本业务 id；输出过滤后的打点。
/// 不可变、无副作用。
/// 筛选是日历页的临时状态，不写进 `CalendarDisplayOptions`，离开页面即
/// 清空；它只影响日期格与统计（月度概览、年视图、范围统计），那年今日与
/// 选中日的日记列表照常显示全部。
///
/// 口径：同一类里任选其一即可（标签之间、心情之间、日记本之间为“或”），
/// 多类都选时需同时满足（“与”）。未解封的时间胶囊不参与筛选、始终保留：它
/// 只贡献锁角标，若按心情、标签或所在本子决定锁是否出现，等于提前泄露了
/// 胶囊的内容（与心情、标签一视同仁，即便本子是用户自己放的）。
///
/// 只能按普通日记本筛选：智能日记本的规则要对整篇日记求值，打点上没有这些
/// 字段，在 UI 层重算一遍规则也会与数据库口径分叉，所以不提供。选了有子本的
/// 日记本时，与首页列表一样连同子本里的日记（[withSubNotebooks]；智能子本
/// 同理不算）。
@immutable
class CalendarMarkerFilter {
  const CalendarMarkerFilter({
    this.tagIds = const <int>{},
    this.moods = const <String>{},
    this.notebookIds = const <String>{},
    this.subNotebookIds = const <String>{},
  });

  final Set<int> tagIds;
  final Set<String> moods;

  /// 所选普通日记本的业务 id（筛选面板的选中态）。
  final Set<String> notebookIds;

  /// 所选日记本一并汇总的普通子本（只参与匹配，不是选中态），由
  /// [withSubNotebooks] 按书架的嵌套现算。
  final Set<String> subNotebookIds;

  bool get isActive =>
      tagIds.isNotEmpty || moods.isNotEmpty || notebookIds.isNotEmpty;

  bool matches(DiaryCalendarMarker marker, {required DateTime now}) {
    if (marker.isLockedCapsuleAt(now)) {
      return true;
    }
    if (tagIds.isNotEmpty && !marker.tagIds.any(tagIds.contains)) {
      return false;
    }
    if (notebookIds.isNotEmpty &&
        !marker.notebookIds.any(
          (id) => notebookIds.contains(id) || subNotebookIds.contains(id),
        )) {
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
      _copyWith(tagIds: _toggled(tagIds, tagId));

  CalendarMarkerFilter toggleMood(String mood) =>
      _copyWith(moods: _toggled(moods, mood));

  CalendarMarkerFilter toggleNotebook(String notebookId) =>
      _copyWith(notebookIds: _toggled(notebookIds, notebookId));

  /// 去掉已不存在的标签（标签被删除后筛选不应残留看不见的条件）。
  CalendarMarkerFilter retainTags(Iterable<int> existingTagIds) {
    final existing = existingTagIds.toSet();
    if (tagIds.every(existing.contains)) {
      return this;
    }
    return _copyWith(tagIds: tagIds.where(existing.contains).toSet());
  }

  /// 只保留仍可筛选的日记本（[eligibleNotebookIds]：存在、普通、非私密）。
  /// 本子被删除、改成智能或设为隐藏 / 上锁后，筛选条里不应残留看不见的
  /// 条件，否则日历会无声地变空。
  CalendarMarkerFilter retainNotebooks(Iterable<String> eligibleNotebookIds) {
    final eligible = eligibleNotebookIds.toSet();
    if (notebookIds.every(eligible.contains)) {
      return this;
    }
    return _copyWith(notebookIds: notebookIds.where(eligible.contains).toSet());
  }

  /// 带上所选日记本汇总的子本：[subNotebooksOf] 给出某本连同汇总的普通子本
  /// （首页列表同一口径：比它更私密的不算）。没选日记本时原样返回。
  CalendarMarkerFilter withSubNotebooks(
    Iterable<String> Function(String notebookId) subNotebooksOf,
  ) {
    if (notebookIds.isEmpty) return this;
    final subs = <String>{for (final id in notebookIds) ...subNotebooksOf(id)}
      ..removeAll(notebookIds);
    if (setEquals(subs, subNotebookIds)) return this;
    return _copyWith(subNotebookIds: Set<String>.unmodifiable(subs));
  }

  CalendarMarkerFilter _copyWith({
    Set<int>? tagIds,
    Set<String>? moods,
    Set<String>? notebookIds,
    Set<String>? subNotebookIds,
  }) => CalendarMarkerFilter(
    tagIds: tagIds ?? this.tagIds,
    moods: moods ?? this.moods,
    notebookIds: notebookIds ?? this.notebookIds,
    subNotebookIds: subNotebookIds ?? this.subNotebookIds,
  );

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
      setEquals(other.moods, moods) &&
      setEquals(other.notebookIds, notebookIds) &&
      setEquals(other.subNotebookIds, subNotebookIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tagIds),
    Object.hashAllUnordered(moods),
    Object.hashAllUnordered(notebookIds),
    Object.hashAllUnordered(subNotebookIds),
  );
}
