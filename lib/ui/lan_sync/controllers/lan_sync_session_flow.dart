// 同步会话的界面编排：确认对话框（以哪边为准 / 删除保护）与完成摘要面板。
//
// - 输入：同步控制器（事件流与指令）、取宿主页面 context 的回调、打开日记
//   的回调（经 `openDiaryPage`）；
// - 输出：无；
// - 副作用：弹对话框 / 底部面板，调用 `respond`、`syncNow`，推入预览页。
//
// 同步页与设备详情页各持有一份（页面创建、销毁时 dispose），都订阅同一条
// 广播事件流，谁的路由是当前路由谁处理——同一时刻只有一个路由是当前的，
// 所以一个事件最多被处理一次。
//
// 确认事件（[LanSyncConfirmationEvent]）：
// 1. 宿主已销毁、宿主不是当前路由（上面盖着别的页面、面板或对话框）、或
//    本宿主已经在显示一个确认对话框 → 什么都不做、不 `respond`。这次同步
//    保持等待，状态里的 `needsAttention` 让设备行显示“查看”，用户点了经
//    `reviewPendingConfirmation` 再发一次事件，那时再弹。不在这里自动
//    `respond(null)`：那会替用户放弃一次本来可以继续的同步。
// 2. 弹对话框；对话框关闭（含点遮罩、返回键）后恰好调用一次 `respond`：
//    选了某项为该项，取消为 null。宿主在对话框打开期间被销毁也照样回应——
//    对话框挂在根 Navigator 上，结果不依赖宿主的 context。
//
// 完成事件（[LanSyncSessionFinishedEvent]，只有手动同步会发）：
// - 用户自己取消的（失败原因为 cancelled）不弹面板：结果就是他刚点的；
// - 宿主不是当前路由时丢弃（摘要只是告知，状态里的同步记录照样更新）；
// - 面板关闭后：“重试”经 `syncNow(peerId)`；点了冲突副本，先关面板再经
//   [_openDiary] 打开副本，每一步 await 之后都先检查 context.mounted。

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/lan_sync_session_view.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_ui_events.dart';
import '../widgets/lan_sync_confirm_dialogs.dart';
import '../widgets/lan_sync_summary_sheet.dart';

/// 见文件头注释。
class LanSyncSessionFlow {
  LanSyncSessionFlow({
    required this.controller,
    required this._contextOf,
    required this._openDiary,
  }) {
    _subscription = controller.events.listen(_handle);
  }

  final LanSyncUiController controller;
  final BuildContext? Function() _contextOf;
  final Future<void> Function(BuildContext context, String diaryId) _openDiary;
  late final StreamSubscription<LanSyncUiEvent> _subscription;

  /// 本宿主正在显示确认对话框。
  bool _confirming = false;

  void dispose() => unawaited(_subscription.cancel());

  /// 宿主仍在且是当前路由时返回它的 context，否则为 null。
  BuildContext? _currentContext() {
    final context = _contextOf();
    if (context == null || !context.mounted) return null;
    final current = ModalRoute.of(context)?.isCurrent ?? false;
    return current ? context : null;
  }

  void _handle(LanSyncUiEvent event) {
    switch (event) {
      case LanSyncChooseSideEvent():
      case LanSyncDeletionGuardEvent():
        if (_confirming) return;
        final context = _currentContext();
        if (context == null) return;
        unawaited(_confirm(context, event as LanSyncConfirmationEvent));
      case LanSyncSessionFinishedEvent(:final peerId, :final summary):
        if (summary.failureReason == LanSyncFailureReason.cancelled) return;
        final context = _currentContext();
        if (context == null) return;
        unawaited(_showSummary(context, peerId, event));
      default:
        return;
    }
  }

  Future<void> _confirm(
    BuildContext context,
    LanSyncConfirmationEvent event,
  ) async {
    _confirming = true;
    try {
      switch (event) {
        case LanSyncChooseSideEvent(:final respond):
          final choice = await showLanSyncChooseSideDialog(
            context,
            peerName: event.peerName,
            items: event.items,
          );
          await respond(choice);
        case LanSyncDeletionGuardEvent(:final respond):
          final choice = await showLanSyncDeletionGuardDialog(
            context,
            peerName: event.peerName,
            deleteCount: event.deleteCount,
            onSide: event.onSide,
          );
          await respond(choice);
      }
    } finally {
      _confirming = false;
    }
  }

  Future<void> _showSummary(
    BuildContext context,
    String peerId,
    LanSyncSessionFinishedEvent event,
  ) async {
    final outcome = await showLanSyncSummarySheet(
      context,
      summary: event.summary,
    );
    switch (outcome) {
      case LanSyncSummaryRetry():
        await controller.syncNow(peerId);
      case LanSyncSummaryOpenCopy(:final diaryId):
        if (!context.mounted) return;
        await _openDiary(context, diaryId);
      case null:
        break;
    }
  }
}
