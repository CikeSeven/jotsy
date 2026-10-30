// 同步页上的配对编排：收到 `LanSyncPairingEvent` 时弹配对面板，面板关闭后
// 按结果放弃配对、立即同步或导出备份；二维码面板也经这里打开，以便扫码
// 配对开始时把它换成配对面板。
//
// - 输入：同步控制器（事件流与指令）、取同步页 context 的回调、身份验证门、
//   “先导出完整备份”的执行回调；
// - 输出：无；
// - 副作用：打开 / 关闭底部面板，调用 `respond`、`syncNow`，弹系统验证。
//
// 流程（事件 → 面板）：
// 1. 收到配对事件：页面已销毁、已有一个配对面板、或同步页不是当前路由
//    （上面盖着别的页面或面板）→ 立即 `respond(false)`，不弹面板；
//    二维码面板是同步页自己的面板，扫码配对开始时它正盖在上面：先关掉它，
//    再弹配对面板。
// 2. 面板跟随 phase 切换（见 lan_sync_pairing_sheet.dart）；“一致，配对”经
//    [LanSyncPairingAuthGate] 按需验证身份，通过才 `respond(true)`。
// 3. 面板关闭：若配对还没有结束（连接中 / 等本机确认 / 等对方确认），一律
//    `respond(false)`——“不一致”、下滑关掉、“先导出完整备份”都走这里；
//    结束后再按面板返回的动作立即同步或开始导出。
//
// 只在同步页打开时接受配对请求：对方发来的请求要有人当场核对数字，同步页
// 不在前台时没人看得见面板，留着只会等到超时。同步引擎同样只在同步页可见
// （`attachPage` 期间）接受传入的配对请求，这里的拒绝是界面一侧的兜底。
//
// “先导出完整备份”先放弃这次配对再导出：配对有 60 秒时限，选密码、选保存
// 位置与生成 ZIP 很容易超过它；导出完成后用户再从附近的设备重新发起配对。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/lan_sync_pairing_auth.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_ui_events.dart';
import '../widgets/lan_sync_pairing_sheet.dart';
import '../widgets/lan_sync_qr_sheet.dart';
import '../widgets/lan_sync_labels.dart';
import 'lan_sync_pairing_auth_gate.dart';

/// 见文件头注释。
class LanSyncPairingFlow {
  LanSyncPairingFlow({
    required this.controller,
    required this._contextOf,
    required this._authGate,
    required this._exportBackup,
    this._clock = DateTime.now,
  }) {
    _subscription = controller.events.listen(_handle);
  }

  final LanSyncUiController controller;
  final BuildContext? Function() _contextOf;
  final LanSyncPairingAuthGate Function() _authGate;
  final Future<void> Function() _exportBackup;
  final DateTime Function() _clock;
  late final StreamSubscription<LanSyncUiEvent> _subscription;

  /// 正在显示的配对面板对应的事件；同一时刻只有一个。
  LanSyncPairingEvent? _active;

  /// 正在显示的二维码面板的路由（面板挂载时登记，关闭后清空）。
  ModalRoute<Object?>? _qrRoute;

  void dispose() => unawaited(_subscription.cancel());

  void _handle(LanSyncUiEvent event) {
    if (event is! LanSyncPairingEvent) return;
    final context = _contextOf();
    if (context == null || !context.mounted || _active != null) {
      unawaited(event.respond(false));
      return;
    }
    final qrRoute = _qrRoute;
    final pageCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    final qrCurrent = qrRoute != null && qrRoute.isCurrent;
    if (!pageCurrent && !qrCurrent) {
      unawaited(event.respond(false));
      return;
    }
    // 二维码面板在最上面：关掉它（它关闭时会作废当前的码），换成配对面板。
    if (qrCurrent) Navigator.of(context).pop();
    unawaited(_showSheet(context, event));
  }

  Future<void> _showSheet(
    BuildContext context,
    LanSyncPairingEvent event,
  ) async {
    _active = event;
    final localPlatform = controller.state.value.local.platform;
    final LanSyncPairingSheetAction? action;
    try {
      action = await showAppModalBottomSheet<LanSyncPairingSheetAction>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 640),
        sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (BuildContext sheetContext) => LanSyncPairingSheet(
          event: event,
          localPlatform: localPlatform,
          onConfirm: () => _confirm(sheetContext, event),
        ),
      );
    } finally {
      _active = null;
    }
    final phase = event.phase.value;
    final finished =
        phase is LanSyncPairingSucceeded || phase is LanSyncPairingFailed;
    if (!finished) await event.respond(false);
    switch (action) {
      case LanSyncPairingSheetAction.syncNow:
        if (phase is LanSyncPairingSucceeded) {
          await controller.syncNow(phase.peerId);
        }
      case LanSyncPairingSheetAction.exportBackup:
        await _exportBackup();
      case null:
        break;
    }
  }

  /// “一致，配对”：按需验证身份，通过才把确认交给对方。
  Future<LanSyncPairingAuthOutcome> _confirm(
    BuildContext sheetContext,
    LanSyncPairingEvent event,
  ) async {
    final reason = sheetContext.l10n.lanSyncPairAuthReason(
      event.phase.value.peerName ?? event.peerName,
    );
    final outcome = await _authGate().authorize(reason: reason);
    if (outcome == LanSyncPairingAuthOutcome.allowed) {
      await event.respond(true);
    }
    return outcome;
  }

  /// 打开二维码面板（“显示二维码”）。面板里选了“改用核对码配对”时，关闭后
  /// 用提示条说明在另一台设备的附近设备列表里找到本机并点“配对”。
  Future<void> showQr(BuildContext context) async {
    final useCode = await showLanSyncQrSheet(
      context,
      controller: controller,
      clock: _clock,
      onRoute: (ModalRoute<Object?>? route) => _qrRoute = route,
    );
    _qrRoute = null;
    if (useCode != true || !context.mounted) return;
    final l10n = context.l10n;
    final name = lanSyncLocalName(l10n, controller.state.value.local.name);
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(l10n.lanSyncQrUseCodeHint(name))),
      ),
    );
  }
}
