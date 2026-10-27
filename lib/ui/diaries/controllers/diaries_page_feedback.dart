// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

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

  /// 多选删除确认弹窗。
  Future<bool> showDeleteSelectedConfirmDialog(int count) async {
    final confirmed = await showAppDialog<bool>(
      context: _state.context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.autoT0070),
          content: Text(l10n.autoT0084(count.toString())),
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

  /// 普通提示条，不带动作按钮。
  Future<void> showInfoSnackBar(
    String message, {
    Duration duration = _DiariesPage._restoreHintDuration,
  }) async {
    await showTrackedSnackBar(
      snackBar: SnackBar(content: Text(message), duration: duration),
    );
  }

  /// 页面内所有提示的统一入口；FAB 避让由 HomeHintVisibilityScope 统一计数。
  ///
  /// 不在这里 setState：提示显隐与日记页渲染无关，此前的本地计数从未被
  /// build 读取，却会在每次提示出现/关闭时重建标签栏与所有可见卡片。
  Future<SnackBarClosedReason> showTrackedSnackBar({
    required SnackBar snackBar,
  }) {
    return HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: snackBar,
    );
  }

  /// 撤销型提示条，返回值表示用户是否触发了撤销动作；`persist: false` 让它
  /// 到时关闭（无障碍场景也一样）。
  Future<bool> showUndoSnackBar({
    required String message,
    required Duration duration,
  }) async {
    var undoRequested = false;
    final closedReason = await showTrackedSnackBar(
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
        persist: false,
        action: SnackBarAction(
          label: _state.context.l10n.commonUndo,
          onPressed: () {
            undoRequested = true;
          },
        ),
      ),
    );

    return undoRequested || closedReason == SnackBarClosedReason.action;
  }
}
