// 真正的同步控制器：把同步引擎 [LanSyncService] 适配成界面接口
// [LanSyncUiController]（对照见 lan_sync_service.dart 顶部，换算在
// models/lan_sync_engine_mapping.dart 与 lan_sync_engine_events.dart）。
//
// - 输入：建引擎的异步工厂（生产装配见 providers/lan_sync_engine_assembly.dart，
//   测试传已建好的引擎）、本机平台、应用一开始是否在前台；
// - 输出：[state]（引擎状态每次变化给出新的视图快照）、[events]（换算后的
//   界面事件）、[qrTicket]；
// - 副作用：启动 / 关闭引擎（它负责网络、写库与 stateDir），转发界面指令与
//   应用前后台（[setForeground]）。
//
// 异步启动窗口：provider 必须同步返回控制器，而引擎要先解析数据目录、
// 读身份与 store 才能用。启动完成之前：
// - 状态为初始快照（本机名为空串，界面显示默认名；没有设备）；
// - `attachPage` / `detachPage` 只记引用计数，`setForeground` 只记前后台，
//   启动完成时按当时的计数与前后台补给引擎（前后台在 `start` 之前先交给
//   引擎，后台启动的应用不会先开端口再关）；
// - 返回 Future 的指令（改名、开关、备注、同步、配对、按地址连接、取消
//   配对）排队等启动完成后再执行；启动失败时不产生效果，其中配对类
//   （`pairWith` / `connectManual` / `connectQr`）发一个失败的配对事件，
//   免得界面一直等；
// - 不返回 Future 的 `cancelSync` / `reviewPendingConfirmation` 直接忽略
//   （启动前没有会话、没有设备可看）；
// - `connectQr` 先在本地判断是不是 Jotsy 的码（同步返回），是就排队；
// - `issueQrTicket` 接口要求立即返回一张码：引擎还没起来、或服务端还没
//   监听 / 没有局域网地址时先返回准备中的占位码（`LanSyncQrTicket.pending`，
//   面板只显示加载），之后每次引擎状态
//   变化都再试着签发，签到即经 [qrTicket] 换上真码（面板监听它）。
//
// 失败：所有方法都不抛出（接口约定），引擎的异常只记日志，结果体现在状态
// 与事件里。释放：[dispose] 取消订阅、关闭引擎；启动途中被释放时，启动
// 完成后立即关闭刚建好的引擎。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../../../core/services/lan_sync/lan_sync_qr_payload.dart';
import '../../../core/services/lan_sync/lan_sync_service.dart';
import '../models/lan_sync_engine_events.dart';
import '../models/lan_sync_engine_mapping.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_qr_ticket.dart';
import '../models/lan_sync_session_view.dart';
import '../models/lan_sync_ui_controller.dart';
import '../models/lan_sync_ui_events.dart';
import '../models/lan_sync_view_state.dart';

part 'engine_lan_sync_ui_controller_link.dart';

/// 应用生命周期 → 引擎的前后台：resumed 为前台；paused / hidden / detached
/// 为后台；inactive（桌面窗口失焦、来电浮层）界面仍看得见，不改变。
bool? lanSyncForegroundOf(AppLifecycleState? state) {
  return switch (state) {
    AppLifecycleState.resumed => true,
    AppLifecycleState.paused ||
    AppLifecycleState.hidden ||
    AppLifecycleState.detached => false,
    AppLifecycleState.inactive || null => null,
  };
}

/// 见文件头注释。
class EngineLanSyncUiController implements LanSyncUiController {
  EngineLanSyncUiController({
    required Future<LanSyncService> Function() createService,
    required LanSyncPlatform platform,
    this._foreground = true,
  }) : _state = ValueNotifier<LanSyncViewState>(
         LanSyncViewState(
           local: LanSyncLocalDeviceView(name: '', platform: platform),
         ),
       ) {
    _ready = _boot(createService);
  }

  final ValueNotifier<LanSyncViewState> _state;
  final ValueNotifier<LanSyncQrTicket?> _qr = ValueNotifier<LanSyncQrTicket?>(
    null,
  );
  final StreamController<LanSyncUiEvent> _events =
      StreamController<LanSyncUiEvent>.broadcast();

  /// 启动完成时为引擎，启动失败或启动途中被释放时为 null。
  late final Future<LanSyncService?> _ready;

  /// 已启动、可直接调用的引擎；启动完成之前与释放之后为 null。
  LanSyncService? _service;
  StreamSubscription<LanSyncEngineEvent>? _engineEvents;
  bool _disposed = false;
  bool _foreground;
  int _attachments = 0;

  /// 二维码面板开着、要一张码（[issueQrTicket] 之后、[revokeQrTicket] 之前）。
  bool _qrWanted = false;

  @override
  ValueListenable<LanSyncViewState> get state => _state;

  @override
  Stream<LanSyncUiEvent> get events => _events.stream;

  @override
  ValueListenable<LanSyncQrTicket?> get qrTicket => _qr;

  /// 启动完成（成功或失败）后完成；测试与装配处可等它。
  Future<bool> get ready async => await _ready != null;

  LanSyncService? get _engineOrNull => _disposed ? null : _service;

  void _onEngineState() {
    if (_disposed) return;
    final service = _service;
    // 启动完成之前引擎还是空快照（没有身份与设置），不覆盖初始状态。
    if (service == null) return;
    _state.value = lanSyncViewStateOf(service.state.value);
    if (_qrWanted && service.qrTicket.value == null) _tryIssueQr(service);
  }

  void _onEngineQr() {
    if (_disposed) return;
    final issued = _service?.qrTicket.value;
    if (issued == null) {
      // 引擎作废了码（服务端停下等）：面板保留上一张的画面，[_onEngineState]
      // 在服务端恢复后补签。
      _qr.value = null;
      return;
    }
    _qr.value = lanSyncQrTicketOf(issued);
  }

  /// 应用前后台（由装配处的生命周期监听转来，见 [lanSyncForegroundOf]）。
  void setForeground(bool foreground) {
    _foreground = foreground;
    _engineOrNull?.setForeground(foreground);
  }

  @override
  void attachPage() {
    _attachments++;
    _engineOrNull?.attachPage();
  }

  @override
  void detachPage() {
    if (_attachments == 0) return;
    _attachments--;
    _engineOrNull?.detachPage();
  }

  @override
  Future<void> renameDevice(String name) =>
      _run('rename', (s) => s.renameDevice(name));

  @override
  Future<void> setDiscoverable(bool discoverable) =>
      _run('setDiscoverable', (s) => s.setDiscoverable(discoverable));

  @override
  Future<void> setAutoSync(bool enabled) =>
      _run('setAutoSync', (s) => s.setAutoSync(enabled));

  @override
  Future<void> setSyncSettings(bool enabled) =>
      _run('setSyncSettings', (s) => s.setSyncSettings(enabled));

  /// 结果经状态里的会话进度与 [LanSyncSessionFinishedEvent] 告知；不等会话
  /// 结束——界面调用后不需要等它（完成摘要由事件弹出）。
  @override
  Future<void> syncNow(String peerId) => _run('syncNow', (s) {
    s.syncNow(peerId).ignore();
  });

  @override
  Future<void> cancelSync(String peerId) async {
    try {
      _engineOrNull?.cancelSync(peerId);
    } on Object catch (error, stack) {
      debugPrint('LAN sync cancelSync failed: $error\n$stack');
    }
  }

  @override
  void reviewPendingConfirmation(String peerId) {
    try {
      _engineOrNull?.reviewPendingConfirmation(peerId);
    } on Object catch (error, stack) {
      debugPrint('LAN sync review failed: $error\n$stack');
    }
  }

  @override
  Future<void> pairWith(String nearbyDeviceId) {
    LanSyncNearbyView? nearby() {
      for (final device in _state.value.nearby) {
        if (device.deviceId == nearbyDeviceId) return device;
      }
      return null;
    }

    void failed(LanSyncFailureReason reason) {
      final device = nearby();
      _emitFailedPairing(
        device?.name ?? '',
        device?.platform ?? LanSyncPlatform.unknown,
        reason,
      );
    }

    return _run('pairWith', (s) {
      // 引擎在对方已不在线时返回 null、什么都不发：界面按接口要等一个配对
      // 事件，这里补一个“连不上”。
      if (s.pairWith(nearbyDeviceId) == null) {
        failed(LanSyncFailureReason.unreachable);
      }
    }, onUnavailable: () => failed(LanSyncFailureReason.unknown));
  }

  @override
  Future<void> connectManual(String host, int port) => _run(
    'connectManual',
    (s) => s.connectManual(host, port),
    onUnavailable: () => _emitFailedPairing(
      host.trim(),
      LanSyncPlatform.unknown,
      LanSyncFailureReason.unknown,
    ),
  );

  @override
  bool connectQr(String payload) {
    final service = _engineOrNull;
    if (service != null) {
      try {
        return service.connectQr(payload);
      } on Object catch (error, stack) {
        debugPrint('LAN sync connectQr failed: $error\n$stack');
        return false;
      }
    }
    if (_disposed || !lanSyncLooksLikeJotsyQr(payload)) return false;
    unawaited(
      _run(
        'connectQr',
        (s) => s.connectQr(payload),
        onUnavailable: () => _emitFailedPairing(
          '',
          LanSyncPlatform.unknown,
          LanSyncFailureReason.unknown,
        ),
      ),
    );
    return true;
  }

  @override
  LanSyncQrTicket issueQrTicket() {
    _qrWanted = true;
    final service = _engineOrNull;
    if (service != null) {
      final issued = _tryIssueQr(service);
      if (issued != null) return issued;
    }
    // 准备中的占位码：面板只显示加载，引擎能签发时经 [qrTicket] 立即换上
    // 真码；有效期照常，到期时面板补签一次（再试一次签发）。
    final now = DateTime.now();
    return LanSyncQrTicket.pending(
      issuedAt: now,
      expiresAt: now.add(LanSyncQrToken.validity),
    );
  }

  @override
  void revokeQrTicket() {
    _qrWanted = false;
    try {
      _engineOrNull?.revokeQrTicket();
    } on Object catch (error, stack) {
      debugPrint('LAN sync revokeQrTicket failed: $error\n$stack');
    }
    if (!_disposed) _qr.value = null;
  }

  @override
  Future<void> setPeerAlias(String peerId, String? alias) =>
      _run('setPeerAlias', (s) => s.setPeerAlias(peerId, alias));

  @override
  Future<void> setPeerAutoSync(String peerId, bool enabled) =>
      _run('setPeerAutoSync', (s) => s.setPeerAutoSync(peerId, enabled));

  @override
  Future<void> forgetPeer(String peerId) =>
      _run('forgetPeer', (s) => s.forgetPeer(peerId));

  /// 关闭引擎、释放通知器与事件流（provider 销毁时）。启动还没完成时由
  /// [_boot] 在完成后关闭引擎。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final service = _service;
    _service = null;
    if (service != null) await _close(service);
    _state.dispose();
    _qr.dispose();
    await _events.close();
  }
}
