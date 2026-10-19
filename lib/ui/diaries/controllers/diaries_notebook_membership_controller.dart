// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记页多选的日记本操作：收进日记本、从本日记本移出、移动到另一本。
///
/// 职责边界：
/// - 选择器经 [showNotebookPickerSheet]，读写经 [NotebookMembershipOps]
///   （撤销信息在写入时一并取得）；
/// - 会让卡片离开当前列表的变更（移出、移走、在全部日记里收进私密日记本、
///   在本子里取消勾选这本）先播放与归档相同的收起动画，再写库；
/// - 统一 4 秒撤销提示（`persist: false`），撤销后卡片以出现动画回来；
/// - 写入失败时回滚界面（卡片回来、恢复选择）并提示，不改动数据。
class DiariesNotebookMembershipController {
  DiariesNotebookMembershipController(
    this._state, {
    required this.feedback,
    required this.transitionCoordinator,
  });

  static const Duration _undoSnackDuration = Duration(seconds: 4);

  final _DiariesPage _state;
  final DiariesPageFeedback feedback;
  final DiaryListTransitionCoordinator transitionCoordinator;

  NotebookMembershipOps get _ops =>
      NotebookMembershipOps(_state.ref.read(appDatabaseProvider));

  List<NotebookView> get _notebooks =>
      _state.ref.read(notebooksProvider).value ?? const <NotebookView>[];

  /// 当前所在的普通日记本（全部日记或智能日记本时为 null）：只有它支持
  /// “从本日记本移出”与“移动到…”。
  NotebookView? get currentManualNotebook {
    final notebook = _state._scopeController.resolution.notebook;
    return notebook != null && notebook.isManual ? notebook : null;
  }

  /// 收进日记本：三态选择器（初始状态按所选日记现在所在的本子算），一次
  /// 写入全部变化。
  Future<void> addSelectedToNotebooks() async {
    final targetIds = _state._selectedDiaryIds.toList(growable: false);
    if (targetIds.isEmpty) return;
    final database = _state.ref.read(appDatabaseProvider);
    final membership = await database.getNotebookIdsForDiaries(targetIds);
    if (!_state.mounted) return;
    final result = await showNotebookPickerSheet(
      _state.context,
      initial: notebookPickStatesFor(membership),
    );
    if (result == null || !_state.mounted) return;

    final l10n = _state.context.l10n;
    final notebooks = _notebooks;
    final privateHint = notebookPrivateAddedHint(l10n, result.add, notebooks);
    final current = currentManualNotebook;
    final isAll = _state.ref.read(homeNotebookScopeProvider).isAll;
    // 收进私密日记本的日记不再出现在全部日记里；在本子里取消勾选这本则离开
    // 这本的列表：两种情况都先让卡片收起。
    final leaves =
        (isAll && privateHint != null) ||
        (current != null && result.remove.contains(current.id));
    await _run(
      targetIds,
      animateOut: leaves,
      write: () => _ops.apply(result, targetIds),
      message:
          privateHint ??
          (result.remove.isEmpty
              ? l10n.notebookAddedToCount(result.add.length)
              : l10n.notebookMembershipUpdated),
    );
  }

  /// 从当前日记本移出（不确认，给撤销）。
  Future<void> removeSelectedFromCurrent() async {
    final current = currentManualNotebook;
    final targetIds = _state._selectedDiaryIds.toList(growable: false);
    if (current == null || targetIds.isEmpty) return;
    final l10n = _state.context.l10n;
    await _run(
      targetIds,
      animateOut: true,
      write: () => _ops.remove(current.id, targetIds),
      message: l10n.notebookRemovedFrom(current.name, targetIds.length),
    );
  }

  /// 移动到另一本：单选选择器（不列出当前这本），选定即移。
  Future<void> moveSelectedToNotebook() async {
    final current = currentManualNotebook;
    final targetIds = _state._selectedDiaryIds.toList(growable: false);
    if (current == null || targetIds.isEmpty) return;
    final l10n = _state.context.l10n;
    final result = await showNotebookPickerSheet(
      _state.context,
      mode: NotebookPickerMode.single,
      title: l10n.notebookMoveTo,
      excludedIds: <String>{current.id},
    );
    if (result == null || result.add.isEmpty || !_state.mounted) return;
    final targetId = result.add.first;
    final notebooks = _notebooks;
    final target = notebooks.where((n) => n.id == targetId).firstOrNull;
    await _run(
      targetIds,
      animateOut: true,
      write: () =>
          _ops.move(fromId: current.id, toId: targetId, diaryIds: targetIds),
      message:
          notebookPrivateAddedHint(l10n, <String>{targetId}, notebooks) ??
          l10n.notebookMovedTo(target?.name ?? '', targetIds.length),
    );
  }

  /// 公共流程：退出多选 →（需要时）收起卡片 → 写库 → 撤销提示。
  Future<void> _run(
    List<String> targetIds, {
    required bool animateOut,
    required Future<NotebookMembershipUndo> Function() write,
    required String message,
  }) async {
    _state.setState(_state._selectedDiaryIds.clear);
    if (animateOut) {
      transitionCoordinator.startHideAnimations(targetIds);
    }
    final NotebookMembershipUndo undo;
    try {
      undo = await write();
    } catch (error) {
      debugPrint('Notebook membership change failed: $error');
      if (!_state.mounted) return;
      if (animateOut) {
        transitionCoordinator.revealDiaries(targetIds, animate: true);
      }
      _state.setState(() => _state._selectedDiaryIds.addAll(targetIds));
      await feedback.showInfoSnackBar(_state.context.l10n.notebookActionFailed);
      return;
    }
    if (!_state.mounted) return;
    final undoRequested = await feedback.showUndoSnackBar(
      message: message,
      duration: _undoSnackDuration,
    );
    if (!_state.mounted) return;
    if (undoRequested) {
      try {
        await _ops.undo(undo);
      } catch (error) {
        debugPrint('Undoing notebook membership change failed: $error');
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
}
