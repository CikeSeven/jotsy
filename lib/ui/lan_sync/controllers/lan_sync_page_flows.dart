// 同步页与设备详情页上的交互流程：弹出面板 / 对话框收集输入，再交给同步控制器执行。
//
// - 输入：页面 context 与 [LanSyncUiController]；
// - 输出：无（结果体现在控制器状态与事件里）；
// - 副作用：打开对话框 / 底部面板、写剪贴板、经 showTrackedSnackBar 提示。
// 每个异步步骤之后都先检查 context.mounted：面板关闭期间页面可能已经退出。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_platform.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_view_state.dart';
import '../pages/lan_sync_scan_page.dart';
import '../widgets/lan_sync_confirm_dialogs.dart';
import '../widgets/lan_sync_labels.dart';
import '../widgets/lan_sync_manual_address_sheet.dart';
import '../widgets/lan_sync_rename_dialog.dart';
import '../widgets/lan_sync_troubleshoot_sheet.dart';

/// 修改本机设备名：对话框确认且名称有变化时调用 `renameDevice`。
Future<void> renameLanSyncDevice(
  BuildContext context,
  LanSyncUiController controller,
) async {
  final current = lanSyncLocalName(
    context.l10n,
    controller.state.value.local.name,
  );
  final name = await showLanSyncRenameDialog(context, initialName: current);
  if (name == null) return;
  await controller.renameDevice(name);
}

/// 复制本机地址（带端口时为“地址:端口”，与手动输入地址的写法对应）。
Future<void> copyLanSyncAddress(
  BuildContext context,
  String address, {
  int? port,
}) async {
  final text = port == null ? address : '$address:$port';
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(context.l10n.lanSyncAddressCopied)),
    ),
  );
}

/// 手动输入地址：面板校验通过后调用 `connectManual`（之后走配对流程）。
Future<void> connectLanSyncByAddress(
  BuildContext context,
  LanSyncUiController controller,
) async {
  final address = await showLanSyncManualAddressSheet(context);
  if (address == null) return;
  await controller.connectManual(address.host, address.port);
}

/// 扫码连接（只在 `AppPlatform.supportsQrScan`）：扫码页认出 Jotsy 码后交给
/// `connectQr`（随即发出配对事件，由配对面板接手）；扫码页里选了“手动输入
/// 地址”时接着打开地址面板。扫码页已用同一套校验认过码，`connectQr` 不会
/// 再返回 false；万一返回 false 也只是什么都不发生。
Future<void> scanLanSyncQr(
  BuildContext context,
  LanSyncUiController controller,
) async {
  if (!AppPlatform.supportsQrScan) return;
  final result = await Navigator.of(context).push(LanSyncScanPage.route());
  if (result == null || !context.mounted) return;
  final payload = result.payload;
  if (payload != null) {
    controller.connectQr(payload);
  } else {
    await connectLanSyncByAddress(context, controller);
  }
}

/// “找不到设备？”：排障面板里选了“手动输入地址”时接着打开地址面板。
Future<void> showLanSyncTroubleshooting(
  BuildContext context,
  LanSyncUiController controller,
) async {
  final action = await showLanSyncTroubleshootSheet(
    context,
    discoveryListening: controller.state.value.local.discoveryListening,
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case LanSyncTroubleshootAction.manualAddress:
      await connectLanSyncByAddress(context, controller);
  }
}

/// 修改已配对设备的备注名（设备详情页）：留空确认即清除，回到显示对方自己
/// 的名字；名称没变或取消时什么都不做。
Future<void> editLanSyncPeerAlias(
  BuildContext context,
  LanSyncUiController controller,
  LanSyncPeerView peer,
) async {
  final l10n = context.l10n;
  final result = await showLanSyncRenameDialog(
    context,
    initialName: peer.alias?.trim() ?? '',
    title: l10n.lanSyncAliasTitle,
    hintText: l10n.lanSyncAliasDialogHint(peer.name),
    allowEmpty: true,
  );
  if (result == null) return;
  await controller.setPeerAlias(peer.deviceId, result.isEmpty ? null : result);
}

/// 取消配对（设备详情页）：确认后调用 `forgetPeer`，返回是否已取消配对，
/// 调用方据此关闭详情页。
Future<bool> forgetLanSyncPeer(
  BuildContext context,
  LanSyncUiController controller,
  LanSyncPeerView peer,
) async {
  final confirmed = await showLanSyncForgetDialog(
    context,
    peerName: peer.displayName,
  );
  if (!confirmed) return false;
  await controller.forgetPeer(peer.deviceId);
  return true;
}
