part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 列表页反馈协调器。
///
/// 职责边界：
/// - 统一管理对话框与 SnackBar 展示；
/// - 维护本地提示可见计数，供 FAB 位移联动；
/// - 不处理业务数据写入，仅做反馈层协调。
class DiariesPageFeedback {
  const DiariesPageFeedback(this._state);

  /// 页面状态引用，用于访问 `context` 以及提示计数状态。
  final _DiariesPage _state;

  /// 新建时发现草稿后的分流弹窗。
  Future<_CreateDraftDecision?> showCreateDraftDecisionDialog() {
    return showDialog<_CreateDraftDecision>(
      context: _state.context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('发现未完成日记'),
          content: const Text('检测到你上次有未保存的日记，是否继续编辑？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(_CreateDraftDecision.newEmpty),
              child: const Text('新建空笔记'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.primary,
              ),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(_CreateDraftDecision.continueEditing),
              child: const Text('继续编辑'),
            ),
          ],
        );
      },
    );
  }

  /// 多选删除确认弹窗。
  Future<bool> showDeleteSelectedConfirmDialog(int count) async {
    final confirmed = await showDialog<bool>(
      context: _state.context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: Text('确认删除已选择的 $count 条日记吗？'),
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

  /// 普通提示条，不带动作按钮。
  Future<void> showInfoSnackBar(
    String message, {
    Duration duration = _DiariesPage._restoreHintDuration,
  }) async {
    await showTrackedSnackBar(
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  /// 带可见计数追踪的 SnackBar。
  ///
  /// 该方法是页面内所有提示的统一入口，确保 FAB 避让状态与提示一致。
  Future<SnackBarClosedReason> showTrackedSnackBar({
    required SnackBar snackBar,
    Duration? forceCloseAfter,
  }) async {
    if (_state.mounted) {
      _state.setState(() {
        _state._localHintVisibleCount += 1;
      });
    }

    final closedReason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: snackBar,
      forceCloseAfter: forceCloseAfter,
    );

    if (_state.mounted) {
      _state.setState(() {
        if (_state._localHintVisibleCount > 0) {
          _state._localHintVisibleCount -= 1;
        }
      });
    }
    return closedReason;
  }

  /// 统一展示“可撤销”提示，并在无障碍场景下强制到时关闭。
  /// 撤销型提示条，返回值表示用户是否触发了撤销动作。
  Future<bool> showUndoSnackBar({
    required String message,
    required Duration duration,
  }) async {
    var undoRequested = false;
    final closedReason = await showTrackedSnackBar(
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
}
