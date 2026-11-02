import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 首页多选顶栏要显示的两项派生状态：是否已全选（全选开关实心）与所选是否
/// 全部已置顶（“更多”里显示“取消置顶”）。
///
/// 输入：所选 id、已加载的列表项、列表的完整时间轴（与列表同一筛选、范围
/// 与排序的全部篇目，只带 id 与排序依据，见 `watchDiaryTimeline`）、列表是
/// 否还有没加载的部分，以及正在归档 / 删除而暂时隐藏的 id。纯计算，无副作用。
///
/// 为什么用时间轴而不是另做一次“总数”查询：全选会选中还没分页加载的日记，
/// “已全选”必须对照列表的全部 id，“全部已置顶”也要看到未加载日记的置顶
/// 状态；时间轴正好是这份只带键、不带正文的实时清单（快速滚动条已在用），
/// 由页面只在多选且列表还有未加载部分时订阅，列表全部加载时直接用已加载项，
/// 不多一条查询。
@immutable
class DiarySelectionSummary {
  const DiarySelectionSummary({
    required this.allSelected,
    required this.allPinned,
  });

  static const DiarySelectionSummary none = DiarySelectionSummary(
    allSelected: false,
    allPinned: false,
  );

  /// 当前列表的每一篇（除暂时隐藏的）都已选中；列表为空时为 false。
  final bool allSelected;

  /// 所选的每一篇都已置顶；有任何一篇查不到置顶状态时为 false（显示“置顶”，
  /// 再置顶一次不会出错）。
  final bool allPinned;

  /// [timeline] 为 null 表示还没读到（或没订阅）：[hasMore] 时无法确认已全选，
  /// 按未全选处理。
  static DiarySelectionSummary resolve({
    required Set<String> selectedIds,
    required List<DiaryWithTags> loadedItems,
    required List<DiaryTimelineEntry>? timeline,
    required bool hasMore,
    Set<String> hiddenIds = const <String>{},
  }) {
    if (selectedIds.isEmpty) {
      return none;
    }
    return DiarySelectionSummary(
      allSelected: _allSelected(
        selectedIds: selectedIds,
        listIds: hasMore
            ? timeline?.map((DiaryTimelineEntry entry) => entry.diaryId)
            : loadedItems.map((DiaryWithTags item) => item.diary.diaryId),
        hiddenIds: hiddenIds,
      ),
      allPinned: _allPinned(
        selectedIds: selectedIds,
        loadedItems: loadedItems,
        timeline: timeline,
      ),
    );
  }

  static bool _allSelected({
    required Set<String> selectedIds,
    required Iterable<String>? listIds,
    required Set<String> hiddenIds,
  }) {
    if (listIds == null) {
      return false;
    }
    var counted = 0;
    for (final id in listIds) {
      if (hiddenIds.contains(id)) {
        continue;
      }
      if (!selectedIds.contains(id)) {
        return false;
      }
      counted += 1;
    }
    return counted > 0;
  }

  static bool _allPinned({
    required Set<String> selectedIds,
    required List<DiaryWithTags> loadedItems,
    required List<DiaryTimelineEntry>? timeline,
  }) {
    // 已加载项与时间轴都来自实时查询，两者合起来覆盖所选日记的置顶状态；
    // 时间轴在后，同一篇以它为准（更完整的那一份）。
    final pinnedById = <String, bool>{
      for (final item in loadedItems)
        if (selectedIds.contains(item.diary.diaryId))
          item.diary.diaryId: item.diary.isPinned,
      if (timeline != null)
        for (final entry in timeline)
          if (selectedIds.contains(entry.diaryId))
            entry.diaryId: entry.isPinned,
    };
    for (final id in selectedIds) {
      if (pinnedById[id] != true) {
        return false;
      }
    }
    return true;
  }
}
