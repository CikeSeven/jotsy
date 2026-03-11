part of 'package:node_diary/ui/diaries/pages/archived_diaries_page.dart';

/// 归档页业务控制器。
///
/// 职责边界：
/// - 处理多选、删除、取消归档与撤销提示流程；
/// - 与数据库与提示层交互；
/// - 不包含任何 UI 组件构建代码。
class ArchivedDiariesController {
  const ArchivedDiariesController(this._state);

  /// 页面状态持有者。
  ///
  /// 控制器通过它读取当前选择集、调用 `setState` 以及访问 `context/ref`。
  final _ArchivedDiariesPageState _state;

  /// 归档页不提供“新建”入口，这里用于占位对齐列表组件回调签名。
  void noopCreate() {}

  /// 退出多选模式并清空当前选中项。
  void clearSelection() {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }
    _state.setState(_state._selectedDiaryIds.clear);
  }

  void toggleSelection(String diaryId, bool forceSelect) {
    _state.setState(() {
      if (forceSelect) {
        _state._selectedDiaryIds.add(diaryId);
        return;
      }
      if (_state._selectedDiaryIds.contains(diaryId)) {
        _state._selectedDiaryIds.remove(diaryId);
      } else {
        _state._selectedDiaryIds.add(diaryId);
      }
    });
  }

  Future<void> showInfoSnackBar(
    String message, {
    Duration duration = _ArchivedDiariesPageState._restoreHintDuration,
  }) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  Future<bool> showUndoSnackBar({
    required String message,
    required Duration duration,
  }) async {
    var undoRequested = false;
    final closedReason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            undoRequested = true;
          },
        ),
      ),
      forceCloseAfter: duration,
    );

    return undoRequested || closedReason == SnackBarClosedReason.action;
  }

  Future<bool> showDeleteSelectedConfirmDialog(int count) async {
    final confirmed = await showDialog<bool>(
      context: _state.context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: Text('确认删除已选择的 $count 条归档日记吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> unarchiveSelectedDiaries() async {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }
    await _unarchiveDiaries(
      _state._selectedDiaryIds.toList(growable: false),
      clearSelection: true,
      showUndoSnack: true,
    );
  }

  Future<void> unarchiveDiaryBySwipe(String diaryId) async {
    await _unarchiveDiaries(
      <String>[diaryId],
      clearSelection: false,
      showUndoSnack: true,
    );
  }

  Future<void> _unarchiveDiaries(
    List<String> diaryIds, {
    required bool clearSelection,
    required bool showUndoSnack,
  }) async {
    // 统一做一次 ID 归一化，避免空字符串或重复值进入数据库操作链路。
    final targetIds =
        diaryIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false);
    if (targetIds.isEmpty) {
      return;
    }

    // 多选入口触发时先在 UI 层退出选择，降低“操作后仍高亮”错觉。
    if (clearSelection) {
      _state.setState(() {
        _state._selectedDiaryIds.removeAll(targetIds);
      });
    }

    final db = _state.ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.unarchiveDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!_state.mounted) {
      return;
    }

    // 任意失败都做“全量回滚”，保证这次批处理对用户来说要么全成功要么不生效。
    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      if (clearSelection) {
        _state.setState(() {
          _state._selectedDiaryIds.addAll(targetIds);
        });
      }
      await showInfoSnackBar('取消归档失败，请重试');
      return;
    }

    // 某些调用路径只需要执行动作，不需要撤销入口（例如后续可能的自动流程）。
    if (!showUndoSnack) {
      return;
    }

    final undoRequested = await showUndoSnackBar(
      message: '已取消归档 ${targetIds.length} 条日记',
      duration: _ArchivedDiariesPageState._undoSnackDuration,
    );
    if (!_state.mounted || !undoRequested) {
      return;
    }

    for (final diaryId in targetIds) {
      await db.archiveDiary(diaryId, touchUpdatedAt: false);
    }
    if (!_state.mounted) {
      return;
    }
    await showInfoSnackBar('已恢复归档状态');
  }

  Future<void> deleteSelectedDiaries() async {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }

    final targetIds = _state._selectedDiaryIds.toList(growable: false);
    final confirmed = await showDeleteSelectedConfirmDialog(targetIds.length);
    if (!_state.mounted || !confirmed) {
      return;
    }

    _state.setState(() {
      _state._selectedDiaryIds.clear();
    });

    // 删除归档日记时不刷新 updatedAt，避免恢复后冲到列表最前面。
    final db = _state.ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.softDeleteDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!_state.mounted) {
      return;
    }

    // 失败时将已成功删除的日记恢复并重新归档，维持归档页数据一致性。
    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._selectedDiaryIds.addAll(targetIds);
      });
      await showInfoSnackBar('删除失败，请重试');
      return;
    }

    await showInfoSnackBar('已删除 ${targetIds.length} 条日记');
  }

  /// 打开预览页（归档列表默认入口）。
  ///
  /// 若在预览页中删除，返回后补一条轻提示反馈。
  void openPreview(String diaryId) {
    Navigator.of(_state.context)
        .push<DiaryPreviewResult?>(
          MaterialPageRoute<DiaryPreviewResult?>(
            builder:
                (BuildContext context) => DiaryPreviewPage(diaryId: diaryId),
          ),
        )
        .then((DiaryPreviewResult? result) async {
          if (!_state.mounted) {
            return;
          }
          if (result == DiaryPreviewResult.deleted) {
            await showInfoSnackBar('已删除日记');
          }
        });
  }
}
