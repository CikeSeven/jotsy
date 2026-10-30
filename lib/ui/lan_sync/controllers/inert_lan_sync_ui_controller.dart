// 不联网的同步控制器：不支持局域网同步的平台（`AppPlatform.supportsLanSync`
// 为 false，即 iOS）上 `lanSyncControllerProvider` 给出的实现。
//
// - 输入：无（本机平台取自 `AppPlatform`）；
// - 输出：没有已配对与附近设备的状态，本机名为空（界面显示默认名）；
// - 副作用：无。开关与改名只改内存里的状态，让界面前后一致；不发现、不
//   连接，也从不发出事件。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_platform.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_qr_ticket.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_ui_events.dart';
import '../models/lan_sync_view_state.dart';

/// 本机所在的平台（按 `AppPlatform` 换算）。
LanSyncPlatform currentLanSyncPlatform() {
  if (AppPlatform.isAndroid) return LanSyncPlatform.android;
  if (AppPlatform.isIOS) return LanSyncPlatform.ios;
  if (AppPlatform.isLinux) return LanSyncPlatform.linux;
  if (AppPlatform.isWindows) return LanSyncPlatform.windows;
  if (AppPlatform.isMacOS) return LanSyncPlatform.macos;
  return LanSyncPlatform.unknown;
}

/// 见文件头注释。
class InertLanSyncUiController implements LanSyncUiController {
  InertLanSyncUiController()
    : _state = ValueNotifier<LanSyncViewState>(
        LanSyncViewState(
          local: LanSyncLocalDeviceView(
            name: '',
            platform: currentLanSyncPlatform(),
          ),
        ),
      );

  /// 二维码令牌的有效期（docs/lan_sync.md §5.2）。
  static const Duration _ticketLifetime = Duration(minutes: 2);

  final ValueNotifier<LanSyncViewState> _state;
  final ValueNotifier<LanSyncQrTicket?> _qrTicket =
      ValueNotifier<LanSyncQrTicket?>(null);
  final StreamController<LanSyncUiEvent> _events =
      StreamController<LanSyncUiEvent>.broadcast();

  @override
  ValueListenable<LanSyncViewState> get state => _state;

  @override
  Stream<LanSyncUiEvent> get events => _events.stream;

  @override
  ValueListenable<LanSyncQrTicket?> get qrTicket => _qrTicket;

  void _updateLocal(LanSyncLocalDeviceView local) {
    _state.value = _state.value.copyWith(local: local);
  }

  @override
  void attachPage() {}

  @override
  void detachPage() {}

  @override
  Future<void> renameDevice(String name) async {
    _updateLocal(_state.value.local.copyWith(name: name.trim()));
  }

  @override
  Future<void> setDiscoverable(bool discoverable) async {
    _updateLocal(_state.value.local.copyWith(discoverable: discoverable));
  }

  @override
  Future<void> setAutoSync(bool enabled) async {
    _state.value = _state.value.copyWith(autoSyncEnabled: enabled);
  }

  @override
  Future<void> setSyncSettings(bool enabled) async {
    _state.value = _state.value.copyWith(syncSettingsEnabled: enabled);
  }

  @override
  Future<void> syncNow(String peerId) async {}

  @override
  Future<void> cancelSync(String peerId) async {}

  @override
  void reviewPendingConfirmation(String peerId) {}

  @override
  Future<void> pairWith(String nearbyDeviceId) async {}

  @override
  Future<void> connectManual(String host, int port) async {}

  @override
  bool connectQr(String payload) => false;

  @override
  LanSyncQrTicket issueQrTicket() {
    final now = DateTime.now();
    final ticket = LanSyncQrTicket(
      payload: '',
      issuedAt: now,
      expiresAt: now.add(_ticketLifetime),
    );
    _qrTicket.value = ticket;
    return ticket;
  }

  @override
  void revokeQrTicket() {
    _qrTicket.value = null;
  }

  @override
  Future<void> setPeerAlias(String peerId, String? alias) async {}

  @override
  Future<void> setPeerAutoSync(String peerId, bool enabled) async {}

  @override
  Future<void> forgetPeer(String peerId) async {}

  /// 释放通知器与事件流（provider 销毁时）。
  void dispose() {
    _state.dispose();
    _qrTicket.dispose();
    unawaited(_events.close());
  }
}
