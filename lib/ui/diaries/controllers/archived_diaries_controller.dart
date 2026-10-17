// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

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

  /// 多选操作：先播放收起动画，结束后再提交数据库。数据流随后移除条目时
  /// 它已收成 0 高度，列表不会硬跳；减少动画时时长为 0，立即提交。
  Future<void> _collapseBeforeCommit(List<String> diaryIds) async {
    _state.setState(() {
      _state._appearingDiaryIds.removeAll(diaryIds);
      _state._pendingHideDiaryIds.addAll(diaryIds);
    });
    await Future<void>.delayed(
      ExpressiveMotion.duration(
        _state.context,
        DiariesListSection.itemTransitionDuration,
      ),
    );
  }

  /// 失败回滚或撤销：让条目以展开动画重新出现。
  ///
  /// 出现标记只在条目插入/重新可见的那一刻生效，稍后清除即可，无需重建；
  /// 不清除的话条目滚出视口再回来时会重复播放展开。
  void _reveal(List<String> diaryIds) {
    if (!_state.mounted) {
      return;
    }
    _state.setState(() {
      _state._pendingHideDiaryIds.removeAll(diaryIds);
      _state._sweptAwayDiaryIds.removeAll(diaryIds);
      _state._appearingDiaryIds.addAll(diaryIds);
    });
    _state._appearingClearTimer?.cancel();
    _state._appearingClearTimer = Timer(
      DiariesListSection.itemTransitionDuration * 4,
      _state._appearingDiaryIds.clear,
    );
  }

  Future<void> showInfoSnackBar(
    String message, {
    Duration duration = _ArchivedDiariesPageState._restoreHintDuration,
  }) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(content: Text(message), duration: duration),
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
          label: _state.context.l10n.commonUndo,
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
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.autoT0070),
          content: Text(l10n.autoT0200(count.toString())),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  dialogContext,
                ).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
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
    // Dismissible 已播放离场动画，必须在本帧同步移出列表。
    _state.setState(() => _state._sweptAwayDiaryIds.add(diaryId));
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
    final targetIds = diaryIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (targetIds.isEmpty) {
      return;
    }

    // 多选入口触发时先在 UI 层退出选择，降低“操作后仍高亮”错觉，
    // 并先收起条目再写库。
    if (clearSelection) {
      _state.setState(() {
        _state._selectedDiaryIds.removeAll(targetIds);
      });
      await _collapseBeforeCommit(targetIds);
      if (!_state.mounted) {
        return;
      }
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
      final succeededIds = targetIds
          .where((id) => !failedIds.contains(id))
          .toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      _reveal(targetIds);
      if (clearSelection) {
        _state.setState(() {
          _state._selectedDiaryIds.addAll(targetIds);
        });
      }
      await showInfoSnackBar(_state.context.l10n.autoT0071);
      return;
    }

    // 某些调用路径只需要执行动作，不需要撤销入口（例如后续可能的自动流程）。
    if (!showUndoSnack) {
      return;
    }

    final undoRequested = await showUndoSnackBar(
      message: _state.context.l10n.autoT0201(targetIds.length.toString()),
      duration: _ArchivedDiariesPageState._undoSnackDuration,
    );
    if (!_state.mounted || !undoRequested) {
      return;
    }

    // 撤销：条目重新归档后经数据流回到列表，以展开动画出现。
    _reveal(targetIds);
    for (final diaryId in targetIds) {
      await db.archiveDiary(diaryId, touchUpdatedAt: false);
    }
    if (!_state.mounted) {
      return;
    }
    await showInfoSnackBar(_state.context.l10n.autoT0072);
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
    await _collapseBeforeCommit(targetIds);
    if (!_state.mounted) {
      return;
    }

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
      final succeededIds = targetIds
          .where((id) => !failedIds.contains(id))
          .toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      _reveal(targetIds);
      _state.setState(() {
        _state._selectedDiaryIds.addAll(targetIds);
      });
      await showInfoSnackBar(_state.context.l10n.autoT0073);
      return;
    }

    await showInfoSnackBar(
      _state.context.l10n.autoT0074(targetIds.length.toString()),
    );
  }

  /// 打开预览页（归档列表默认入口），[sequence] 为左右滑动的顺序（当前显示
  /// 的归档列表）。
  ///
  /// 若在预览页中删除，返回后补一条轻提示反馈。
  void openPreview(
    String diaryId, {
    DiaryWithTags? initialDetail,
    ImageViewerHero? coverHero,
    DiaryPreviewSequence? sequence,
  }) {
    Navigator.of(_state.context)
        .push<DiaryPreviewResult?>(
          MaterialPageRoute<DiaryPreviewResult?>(
            builder: (BuildContext context) => DiaryPreviewPage(
              diaryId: diaryId,
              initialDetail: initialDetail,
              coverHero: coverHero,
              sequence: sequence,
            ),
          ),
        )
        .then((DiaryPreviewResult? result) async {
          if (!_state.mounted) {
            return;
          }
          // 预览页里可能已滑到别的日记再删除：恢复的是结果里的那一篇。
          if (result case DiaryPreviewResult(:final diaryId)) {
            final undoRequested = await showUndoSnackBar(
              message: _state.context.l10n.autoT0075,
              duration: _ArchivedDiariesPageState._undoSnackDuration,
            );
            if (!_state.mounted || !undoRequested) {
              return;
            }
            try {
              final db = _state.ref.read(appDatabaseProvider);
              _reveal(<String>[diaryId]);
              await db.restoreDiary(diaryId, touchUpdatedAt: false);
              if (!_state.mounted) {
                return;
              }
              await showInfoSnackBar(_state.context.l10n.autoT0076);
            } catch (_) {
              if (!_state.mounted) {
                return;
              }
              await showInfoSnackBar(_state.context.l10n.autoT0077);
            }
          }
        });
  }
}
