// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记页多选的“全选 / 取消全选”（顶栏“已选数量”那一块）。
///
/// 职责边界：
/// - 全选：按当前列表的同一查询（[DiaryPageQuery]：范围、标签筛选、排序，
///   排除归档、回收站与私密）一次性取出全部 id（[AppDatabase.getActiveDiaryIds]，
///   与预览页翻页接续未加载部分同一口径），连同还没分页加载的日记一起选中；
///   正在归档 / 删除、等待撤销而暂时隐藏的日记不选（与阅读顺序一致）；
/// - 取消全选：清空选中但留在多选模式（`_selectionKeptOpen`），全选开关
///   仍在顶栏上，可以再点一次全选或逐篇勾选；
/// - 顶栏要显示的派生状态（是否已全选、所选是否全部已置顶）经
///   [summaryOf] 计算，见 [DiarySelectionSummary]。
///
/// 异步保护：全选的读取是一次性的，读的过程中多选被退出（取消、批量操作
/// 完成、切换日记本或章节）或重新进入、列表查询变了（换了筛选或排序）、
/// 页面已卸载时，结果一律丢弃——用世代号 [_generation] 识别“这次读取是否
/// 还是最新的那一次”，[cancelPending] 在退出多选时调用。
class DiariesSelectAllController {
  DiariesSelectAllController(this._state, {required this.feedback});

  final _DiariesPage _state;
  final DiariesPageFeedback feedback;

  /// 每次发起全选读取或作废读取时自增；读完时不等于发起时的值即丢弃。
  int _generation = 0;

  /// 作废进行中的全选读取（退出多选时调用）。
  void cancelPending() => _generation++;

  /// 顶栏的派生状态。[timeline] 为列表的完整时间轴（只在多选且还有未加载
  /// 部分时由顶栏订阅，否则为 null）。
  DiarySelectionSummary summaryOf({
    required List<DiaryWithTags> loadedItems,
    required List<DiaryTimelineEntry>? timeline,
    required bool hasMore,
  }) => DiarySelectionSummary.resolve(
    selectedIds: _state._selectedDiaryIds,
    loadedItems: loadedItems,
    timeline: timeline,
    hasMore: hasMore,
    hiddenIds: _state._controller._readingHiddenIds(),
  );

  /// 点按全选开关：[allSelected] 时取消全选，否则全选。
  Future<void> toggle({required bool allSelected}) async {
    if (!_state._isSelectionMode) {
      return;
    }
    if (allSelected) {
      cancelPending();
      _state.setState(() {
        _state._selectedDiaryIds.clear();
        _state._selectionKeptOpen = true;
      });
      return;
    }
    final query = _state._currentDiaryPageQuery;
    if (query == null) {
      return;
    }
    final generation = ++_generation;
    final List<String> ids;
    try {
      ids = await _state.ref
          .read(appDatabaseProvider)
          .getActiveDiaryIds(
            keyword: query.keyword,
            requiredTagIds: query.requiredTagIds,
            sortMode: query.sortMode,
            scope: query.scope,
            matchComments: query.matchComments,
          );
    } catch (error) {
      debugPrint('Selecting all diaries failed: $error');
      if (_state.mounted && generation == _generation) {
        await feedback.showInfoSnackBar(_state.context.l10n.commonRetry);
      }
      return;
    }
    if (!_state.mounted ||
        generation != _generation ||
        !_state._isSelectionMode ||
        _state._currentDiaryPageQuery?.timelineKey != query.timelineKey) {
      return;
    }
    final hidden = _state._controller._readingHiddenIds();
    // 一次 setState 加入全部 id：几千篇也只重建一次。
    _state.setState(() {
      _state._selectedDiaryIds.addAll(
        ids.where((String id) => !hidden.contains(id)),
      );
      // 选上了才恢复“取消最后一篇即退出多选”；什么都没选上（列表已空）
      // 时保持原样，不把用户踢出多选。
      if (_state._selectedDiaryIds.isNotEmpty) {
        _state._selectionKeptOpen = false;
      }
    });
  }
}
