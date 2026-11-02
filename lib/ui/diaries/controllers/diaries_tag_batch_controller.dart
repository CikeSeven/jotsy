// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记页多选的批量标签：给所选日记整体加上或去掉若干标签。
///
/// 职责边界：
/// - 读所选日记现有的标签（[AppDatabase.getTagIdsForDiaries]）算出各标签的
///   三态，交给标签面板 [showDiaryTagBatchSheet] 挑选；面板只返回变化；
/// - 写库只经 [AppDatabase.applyDiaryTagBatch]（单事务、只改 `diary_tags`、
///   不改 `updatedAt`），撤销只经 [AppDatabase.restoreDiaryTagBatch]；
/// - 流程与日记本收录（[DiariesNotebookMembershipController]）一致：退出
///   多选 →（需要时）收起卡片 → 写库 → 4 秒撤销提示（`persist: false`，
///   经 `showTrackedSnackBar` 自动登记局域网同步的撤销窗口）→ 撤销即恢复；
/// - 会让卡片离开当前列表的只有一种情况：首页正按标签筛选（多标签为 AND），
///   而这次去掉了其中某个标签——列表里的日记都带着全部筛选标签，去掉其一
///   就全部离开，先播放与归档相同的收起动画，撤销时以出现动画回来。智能
///   日记本按规则现算成员，规则里的标签变化由数据流自然增删卡片，不预判；
/// - 写入失败时回滚界面（卡片回来、恢复选择）并提示，数据不变（事务整体
///   回滚）。
class DiariesTagBatchController {
  DiariesTagBatchController(
    this._state, {
    required this.feedback,
    required this.transitionCoordinator,
  });

  static const Duration _undoSnackDuration = Duration(seconds: 4);

  final _DiariesPage _state;
  final DiariesPageFeedback feedback;
  final DiaryListTransitionCoordinator transitionCoordinator;

  AppDatabase get _database => _state.ref.read(appDatabaseProvider);

  /// 设置标签：三态面板（初始状态按所选日记现有的标签算），一次写入全部
  /// 变化。
  Future<void> editSelectedTags() async {
    final targetIds = _state._selectedDiaryIds.toList(growable: false);
    if (targetIds.isEmpty) return;
    final current = await _database.getTagIdsForDiaries(targetIds);
    if (!_state.mounted) return;
    final result = await showDiaryTagBatchSheet(
      _state.context,
      diaryCount: targetIds.length,
      initial: triStatePicksFor<int>(current.values),
    );
    if (result == null || result.isEmpty || !_state.mounted) return;
    final filterTagIds = _state.ref.read(diaryFilterProvider).selectedTagIds;
    await _run(
      targetIds,
      animateOut: result.remove.any(filterTagIds.contains),
      result: result,
    );
  }

  /// 公共流程：退出多选 →（需要时）收起卡片 → 写库 → 撤销提示。
  Future<void> _run(
    List<String> targetIds, {
    required bool animateOut,
    required TriStatePickResult<int> result,
  }) async {
    _state.setState(_state._resetSelection);
    if (animateOut) {
      transitionCoordinator.startHideAnimations(targetIds);
    }
    final DiaryTagBatchUndo undo;
    try {
      undo = await _database.applyDiaryTagBatch(
        targetIds,
        add: result.add,
        remove: result.remove,
      );
    } catch (error) {
      debugPrint('Batch tag change failed: $error');
      if (!_state.mounted) return;
      _restoreView(targetIds, animateOut: animateOut, reselect: true);
      await feedback.showInfoSnackBar(_state.context.l10n.diaryTagBatchFailed);
      return;
    }
    if (!_state.mounted) return;
    if (undo.isEmpty) {
      // 面板打开期间标签或日记在别处变了，这次实际没有改动：没有可撤销的，
      // 收起的卡片放回来即可。
      _restoreView(targetIds, animateOut: animateOut, reselect: false);
      return;
    }
    final undoRequested = await feedback.showUndoSnackBar(
      message: _state.context.l10n.diaryTagBatchUpdated(undo.before.length),
      duration: _undoSnackDuration,
    );
    if (!_state.mounted) return;
    if (undoRequested) {
      try {
        await _database.restoreDiaryTagBatch(undo);
      } catch (error) {
        debugPrint('Undoing batch tag change failed: $error');
      }
      if (!_state.mounted) return;
      if (animateOut) {
        transitionCoordinator.revealDiaries(targetIds, animate: true);
      }
      return;
    }
    if (!animateOut) return;
    // 不撤销：数据库流已不再包含这些日记，清掉乐观隐藏标记。
    _state.setState(() {
      _state._optimisticHiddenDiaryIds.removeAll(targetIds);
      _state._pendingHideDiaryIds.removeAll(targetIds);
      _state._appearingDiaryIds.removeAll(targetIds);
    });
    transitionCoordinator.clearTransitionTimers(targetIds);
  }

  /// 没写成时把界面放回去：收起的卡片以出现动画回来，[reselect] 时恢复
  /// 多选（写入失败，用户可以再试一次）。
  void _restoreView(
    List<String> targetIds, {
    required bool animateOut,
    required bool reselect,
  }) {
    if (animateOut) {
      transitionCoordinator.revealDiaries(targetIds, animate: true);
    }
    if (reselect) {
      _state.setState(() => _state._selectedDiaryIds.addAll(targetIds));
    }
  }
}
