// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 宽窗口日记页（双栏）里“正在阅读”的选中：哪一篇显示在右栏。
///
/// 职责边界：
/// - 选中只是页面的内存状态（`_DiariesPage._readingDiaryId`），不持久化，启动
///   时不自动选中；与多选（`_selectedDiaryIds`）互不影响，多选模式下点卡片
///   仍是勾选；
/// - 顺序与预览页左右翻页同一口径（[DiariesPageController.readingOrder]）；
/// - 窗口不是双栏时选中保留但不显示，点卡片照旧推入预览页；回到双栏时
///   重新显示；
/// - 删除后的去向、列表里不见了时的清除、离开私密日记本时的清除都在这里；
/// - 不构建 UI（右栏见 `DiaryDetailPane`）。
class DiariesReadingSelectionController {
  DiariesReadingSelectionController(this._state);

  final _DiariesPage _state;

  /// 交给右栏嵌入预览的宿主：删除与“日记不见了”都回到这里。只建一次，
  /// 右栏重建时不必换。
  late final DiaryPreviewHost host = DiaryPreviewHost(
    onDeleted: handleDeleted,
    onVanished: clear,
  );

  String? get selectedId => _state._readingDiaryId;

  /// 选中 [diaryId] 在右栏阅读。
  void select(String diaryId) {
    if (_state._readingDiaryId == diaryId) {
      return;
    }
    _state.setState(() => _state._readingDiaryId = diaryId);
  }

  /// 清除选中，右栏回到“选一篇日记来读”。
  void clear() {
    if (_state._readingDiaryId == null || !_state.mounted) {
      return;
    }
    _state.setState(() => _state._readingDiaryId = null);
  }

  /// 右栏里删除了一篇（“更多”、编辑页或封存页里删除）：先把选中移到列表里的
  /// 下一篇（它是最后一篇时移到上一篇，都没有时清除），再给出与预览页删除
  /// 相同的撤销提示；撤销只恢复日记，选中不跳回去。
  ///
  /// 顺序在删除写库之后、列表数据推送之前读取，这时被删的一篇通常还在列表
  /// 里；已经不在时（推送更快）选中由 [syncWithList] 清除。
  void handleDeleted(String diaryId) {
    if (_state._readingDiaryId == diaryId) {
      final order = _state._controller.readingOrder();
      final index = order.indexWhere(
        (DiaryWithTags item) => item.diary.diaryId == diaryId,
      );
      String? next;
      if (index >= 0 && index + 1 < order.length) {
        next = order[index + 1].diary.diaryId;
      } else if (index > 0) {
        next = order[index - 1].diary.diaryId;
      }
      _state.setState(() => _state._readingDiaryId = next);
    }
    unawaited(_state._controller.offerUndoForDeletedDiary(diaryId));
  }

  /// 列表拿到新数据后对一次选中：选中的一篇不在 [items] 里了（换了筛选、
  /// 日记本或排序后不在已加载的部分，或被归档、删除）就清除。
  ///
  /// 只在页面 build 里、数据不是筛选过渡冻结的旧列表时调用：直接改字段，
  /// 同一次 build 随后读取，不另起重建。
  void syncWithList(List<DiaryWithTags> items) {
    final selected = _state._readingDiaryId;
    if (selected == null) {
      return;
    }
    for (final item in items) {
      if (item.diary.diaryId == selected) {
        return;
      }
    }
    _state._readingDiaryId = null;
  }

  /// 日记本范围变了：离开的是私密日记本（隐藏或上锁）时立即清除，不等新
  /// 范围的数据到达——重锁遮罩里选了“回到全部日记”之后，右栏不应再露出
  /// 那本里的日记（独立的预览页此时会随 popUntil 关掉）。其余情况交给
  /// [syncWithList]：选中的一篇还在新范围里就保留。
  void handleScopeChanged() {
    if (_state._readingScopePrivate) {
      clear();
    }
  }

  /// 右栏的位置：顶栏“位置”标题与正文末尾的上一篇 / 下一篇（在列表里换选）。
  DiaryPreviewPaging? pagingFor(BuildContext context, String diaryId) {
    final order = _state._controller.readingOrder();
    final index = order.indexWhere(
      (DiaryWithTags item) => item.diary.diaryId == diaryId,
    );
    if (index < 0) {
      return null;
    }
    final hasMore = _state._hasMoreDiaries;
    return DiaryPreviewPaging.of(
      context.l10n,
      DiaryPagerPosition(
        index: index,
        count: order.length,
        onPrevious: index > 0
            ? () => select(order[index - 1].diary.diaryId)
            : null,
        onNext: index + 1 < order.length
            ? () => select(order[index + 1].diary.diaryId)
            : null,
      ),
      hasMore: hasMore,
      titleAt: (int at) =>
          at >= 0 && at < order.length ? order[at].diary.title : null,
    );
  }
}
