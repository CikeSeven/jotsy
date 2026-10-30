// 控制器与引擎之间的连接：启动、关闭、事件换算、指令排队与二维码签发
// （engine_lan_sync_ui_controller.dart 的一部分；时序说明在主文件顶部）。
part of 'engine_lan_sync_ui_controller.dart';

extension _EngineLink on EngineLanSyncUiController {
  /// 建引擎 → 挂监听 → 交前后台 → 启动 → 补页面计数。监听在启动之前挂上：
  /// 启动过程中发出的状态与事件不漏。任一步失败都只记日志，控制器保持初始
  /// 状态（界面上没有设备，指令不产生效果）。
  Future<LanSyncService?> _boot(
    Future<LanSyncService> Function() createService,
  ) async {
    final LanSyncService service;
    try {
      service = await createService();
    } on Object catch (error, stack) {
      debugPrint('LAN sync engine unavailable: $error\n$stack');
      return null;
    }
    if (_disposed) {
      await _close(service);
      return null;
    }
    service.state.addListener(_onEngineState);
    service.qrTicket.addListener(_onEngineQr);
    _engineEvents = service.events.listen(
      (LanSyncEngineEvent event) => _onEngineEvent(event, service),
    );
    service.setForeground(_foreground);
    try {
      await service.start();
    } on Object catch (error, stack) {
      debugPrint('LAN sync engine failed to start: $error\n$stack');
      await _close(service);
      return null;
    }
    if (_disposed) {
      await _close(service);
      return null;
    }
    _service = service;
    // 启动期间前后台可能又变了（start 里 `_started` 一置位，之前那次就
    // 不再是“启动前的设置”）：按现在的值再交一次，相同时引擎不做事。
    service.setForeground(_foreground);
    for (var i = 0; i < _attachments; i++) {
      service.attachPage();
    }
    _onEngineState();
    return service;
  }

  /// 摘掉监听并关闭引擎（启动失败、启动途中被释放、[dispose]）。
  Future<void> _close(LanSyncService service) async {
    service.state.removeListener(_onEngineState);
    service.qrTicket.removeListener(_onEngineQr);
    final subscription = _engineEvents;
    _engineEvents = null;
    await subscription?.cancel();
    try {
      await service.dispose();
    } on Object catch (error, stack) {
      debugPrint('LAN sync engine dispose failed: $error\n$stack');
    }
  }

  /// 引擎事件 → 界面事件；对方的显示名取事件发生时引擎的快照。
  void _onEngineEvent(LanSyncEngineEvent event, LanSyncService service) {
    if (_disposed || _events.isClosed) return;
    final LanSyncUiEvent? mapped;
    try {
      mapped = lanSyncUiEventOf(event, service.state.value);
    } on Object catch (error, stack) {
      debugPrint('LAN sync event mapping failed: $error\n$stack');
      return;
    }
    if (mapped != null) _events.add(mapped);
  }

  /// 排队执行一条指令：等启动完成后交给引擎；启动失败或已释放时不产生
  /// 效果（[onUnavailable] 给配对类指令发失败事件）。异常只记日志。
  Future<void> _run(
    String label,
    FutureOr<void> Function(LanSyncService service) action, {
    VoidCallback? onUnavailable,
  }) async {
    final service = _engineOrNull ?? await _ready;
    if (service == null || _disposed) {
      if (!_disposed) onUnavailable?.call();
      return;
    }
    try {
      await action(service);
    } on Object catch (error, stack) {
      debugPrint('LAN sync $label failed: $error\n$stack');
    }
  }

  /// 引擎之外的配对失败（引擎不可用、附近设备已离开）：发一个已经失败的
  /// 配对事件，界面照常弹面板说明原因。
  void _emitFailedPairing(
    String peerName,
    LanSyncPlatform platform,
    LanSyncFailureReason reason,
  ) {
    if (_disposed || _events.isClosed) return;
    _events.add(
      LanSyncPairingEvent(
        direction: LanSyncPairingDirection.outgoing,
        peerName: peerName,
        platform: platform,
        phase: _FixedPhase(LanSyncPairingFailed(reason)),
        respond: (_) async {},
      ),
    );
  }

  LanSyncQrTicket? _tryIssueQr(LanSyncService service) {
    try {
      final issued = service.issueQrTicket();
      return issued == null ? null : lanSyncQrTicketOf(issued);
    } on Object catch (error, stack) {
      debugPrint('LAN sync issueQrTicket failed: $error\n$stack');
      return null;
    }
  }
}

/// 与引擎同一口径：认不出前缀的不是 Jotsy 的码；前缀对但版本或内容不对的
/// 仍算 Jotsy 的码（引擎会以失败的配对说明）。
bool lanSyncLooksLikeJotsyQr(String payload) {
  try {
    LanSyncQrPayload.decode(payload.trim());
    return true;
  } on LanSyncQrFormatException catch (error) {
    return error.error != LanSyncQrError.notLanSync;
  }
}

/// 不会再变的配对阶段（控制器自己判定的失败）。
class _FixedPhase implements ValueListenable<LanSyncPairingPhase> {
  const _FixedPhase(this.value);

  @override
  final LanSyncPairingPhase value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
