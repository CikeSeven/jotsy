import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_platform.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_qr_ticket.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_controller.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';

/// 可由测试驱动的同步控制器：直接改 [stateNotifier] 换状态、[emit] 发事件，
/// 所有指令按调用顺序记在 [calls]（如 `syncNow:peer-1`）。
class FakeLanSyncController implements LanSyncUiController {
  FakeLanSyncController([LanSyncViewState? initial])
    : stateNotifier = ValueNotifier<LanSyncViewState>(
        initial ??
            const LanSyncViewState(
              local: LanSyncLocalDeviceView(
                name: 'Pixel 9',
                platform: LanSyncPlatform.android,
                addresses: <String>['192.168.1.23'],
                port: 47562,
              ),
            ),
      );

  final ValueNotifier<LanSyncViewState> stateNotifier;
  final ValueNotifier<LanSyncQrTicket?> qrTicketNotifier =
      ValueNotifier<LanSyncQrTicket?>(null);
  final StreamController<LanSyncUiEvent> _events =
      StreamController<LanSyncUiEvent>.broadcast(sync: true);
  final List<String> calls = <String>[];

  /// 当前 attach 计数（attachPage +1、detachPage -1）。
  int attachCount = 0;

  /// [connectQr] 的返回值。
  bool acceptQr = true;

  void emit(LanSyncUiEvent event) => _events.add(event);

  @override
  ValueListenable<LanSyncViewState> get state => stateNotifier;

  @override
  Stream<LanSyncUiEvent> get events => _events.stream;

  @override
  ValueListenable<LanSyncQrTicket?> get qrTicket => qrTicketNotifier;

  @override
  void attachPage() {
    attachCount++;
    calls.add('attachPage');
  }

  @override
  void detachPage() {
    attachCount--;
    calls.add('detachPage');
  }

  @override
  Future<void> renameDevice(String name) async => calls.add('rename:$name');

  @override
  Future<void> setDiscoverable(bool discoverable) async =>
      calls.add('discoverable:$discoverable');

  @override
  Future<void> setAutoSync(bool enabled) async =>
      calls.add('autoSync:$enabled');

  @override
  Future<void> setSyncSettings(bool enabled) async =>
      calls.add('syncSettings:$enabled');

  @override
  Future<void> syncNow(String peerId) async => calls.add('syncNow:$peerId');

  @override
  Future<void> cancelSync(String peerId) async =>
      calls.add('cancelSync:$peerId');

  @override
  void reviewPendingConfirmation(String peerId) => calls.add('review:$peerId');

  @override
  Future<void> pairWith(String nearbyDeviceId) async =>
      calls.add('pair:$nearbyDeviceId');

  @override
  Future<void> connectManual(String host, int port) async =>
      calls.add('manual:$host:$port');

  @override
  bool connectQr(String payload) {
    calls.add('qr:$payload');
    return acceptQr;
  }

  @override
  LanSyncQrTicket issueQrTicket() {
    calls.add('issueQrTicket');
    final now = DateTime(2026, 10, 29, 12);
    final ticket = LanSyncQrTicket(
      payload: 'jotsy-lan:v1:test',
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 2)),
    );
    qrTicketNotifier.value = ticket;
    return ticket;
  }

  @override
  void revokeQrTicket() {
    calls.add('revokeQrTicket');
    qrTicketNotifier.value = null;
  }

  @override
  Future<void> setPeerAlias(String peerId, String? alias) async =>
      calls.add('alias:$peerId:$alias');

  @override
  Future<void> setPeerAutoSync(String peerId, bool enabled) async =>
      calls.add('peerAutoSync:$peerId:$enabled');

  @override
  Future<void> forgetPeer(String peerId) async => calls.add('forget:$peerId');
}
