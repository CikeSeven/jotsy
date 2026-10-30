// 发现、在线表、本机地址、二维码与自动同步的接线，以及状态快照的拼装
// （lan_sync_service.dart 的一部分）。
part of 'lan_sync_service.dart';

extension _Discovery on LanSyncService {
  /// 服务端与发现该不该运行（docs §9）：前台，且同步页打开或至少有一台
  /// 已配对设备。从没配对过的用户不该在应用启动时就开 TCP 端口、向局域网
  /// 广播带设备名的信标（隐私，也费电）；有已配对设备时即使关了自动同步也
  /// 保持运行——对方的手动同步要连得上本机。后台一律停止。
  bool get _networkWanted =>
      _foreground && (_attachments > 0 || _store.data.value.peers.isNotEmpty);

  /// 按 [_networkWanted] 起停服务端与发现。串行执行：页面进出、配对变化、
  /// 前后台切换可能接连发生，而绑定是异步的，交错执行可能起两个服务端或
  /// 停掉刚起来的那个。每一步都按执行那一刻的状态判断。
  void _updateNetwork() {
    if (!_started || _disposed) return;
    _networkOp = _networkOp.then((_) => _applyNetwork()).catchError((
      Object error,
      StackTrace stack,
    ) {
      debugPrint('LAN sync network update failed: $error\n$stack');
    });
  }

  Future<void> _applyNetwork() async {
    if (_disposed) return;
    if (_networkWanted) {
      await _startServer();
    } else {
      await _stopServer();
      // 服务端停了，二维码上的端口已连不上（二维码只在同步页上显示）。
      _revokeQrTicket();
    }
    _updateDiscovery();
    _publish();
  }

  /// 发现跟随服务端：需要网络且服务端已起来时运行，同步页打开时 2 秒一拍，
  /// 否则 5 秒。“可被发现”关闭时只听不发（[LanSyncDiscovery.advertise]）：
  /// 照常收信标、维护在线表，已配对设备照样显示在线、上线照样触发自动同步，
  /// 只是别人看不到本机——对方若是先发起的一方，10 秒的双向重试让本机发起。
  void _updateDiscovery() {
    if (!_started || _disposed) return;
    if (!_networkWanted || _server == null) {
      final discovery = _discovery;
      if (discovery != null && discovery.status.value.running) {
        unawaited(discovery.stop());
      }
      return;
    }
    final discovery = _discovery ??= _createDiscovery();
    discovery.advertise = _store.prefs.discoverable;
    unawaited(
      discovery.start(
        beacon: _beacon,
        interval: _attachments > 0
            ? timings.pageBeaconInterval
            : timings.autoBeaconInterval,
      ),
    );
  }

  LanSyncDiscovery _createDiscovery() {
    final discovery = hooks.discovery();
    discovery.peers.addListener(_onPresence);
    discovery.status.addListener(_publish);
    return discovery;
  }

  /// 每拍重新取：改名、端口变化下一拍就生效。
  LanSyncBeacon _beacon() => LanSyncBeacon(
    deviceId: _identity.deviceId,
    name: _deviceName,
    platform: hooks.platformId(),
    port: _server?.port ?? _port ?? kLanSyncPreferredPort,
    fingerprint: _identity.shortFingerprint,
    formatVersion: kSyncFormatVersion,
  );

  /// 在线表变化：新出现的已配对设备触发自动同步。
  void _onPresence() {
    final next = _discovery?.peers.value ?? const <String, LanSyncPresence>{};
    final before = _presence;
    _presence = next;
    for (final id in next.keys) {
      if (!before.containsKey(id) && _store.peer(id) != null) {
        _auto.peerOnline(id);
      }
    }
    _publish();
  }

  /// 本机地址：启动、回到前台、打开同步页时读，同步页打开期间定时再读
  /// （换了 Wi-Fi 时二维码与英雄卡跟着变）。读失败保留旧值。
  Future<void> _refreshAddresses() async {
    try {
      _addresses = List<String>.unmodifiable(await hooks.localAddresses());
    } on Object catch (error) {
      debugPrint('LAN sync local addresses unavailable: $error');
    }
  }

  /// 签发一张二维码（2 分钟一次性令牌），到期自动换发；被扫用掉时由
  /// `_consumeQrToken` 立即换发。没有地址或服务端没起来时为 null。
  LanSyncIssuedQr? _issueQrTicket() {
    _cancelQrTimer();
    final port = _server?.port;
    final hosts = _addresses.take(LanSyncQrPayload.maxHosts).toList();
    if (!_started || _disposed || port == null || hosts.isEmpty) {
      _token = null;
      _qr.value = null;
      return null;
    }
    final token = LanSyncQrToken.generate(now: _now());
    final String payload;
    try {
      payload = LanSyncQrPayload(
        hosts: hosts,
        port: port,
        deviceId: _identity.deviceId,
        fingerprint: _identity.fingerprint,
        token: token.value,
        name: _deviceName,
      ).encode();
    } on ArgumentError catch (error) {
      debugPrint('LAN sync QR payload rejected: $error');
      _token = null;
      _qr.value = null;
      return null;
    }
    _token = token;
    final issued = LanSyncIssuedQr(
      payload: payload,
      issuedAt: token.createdAt,
      expiresAt: token.expiresAt,
    );
    _qr.value = issued;
    _qrTimer = hooks.timer(LanSyncQrToken.validity, () {
      if (identical(_token, token)) _issueQrTicket();
    });
    return issued;
  }

  void _revokeQrTicket() {
    _cancelQrTimer();
    _token = null;
    _qr.value = null;
  }

  void _cancelQrTimer() {
    _qrTimer?.cancel();
    _qrTimer = null;
  }

  LanSyncAutoScheduler _createScheduler() => LanSyncAutoScheduler(
    localDeviceId: _identity.deviceId,
    canSync: _canAutoSync,
    isBusy: () => _active != null,
    isEditing: editing.isEditing,
    onlinePeers: () => [
      for (final id in _presence.keys)
        if (_store.peer(id) != null) id,
    ],
    start: (peerId) => unawaited(_syncWith(peerId, automatic: true)),
    timings: timings.auto,
    clock: hooks.clock,
    timer: hooks.timer,
  );

  /// 能否与 [peerId] 自动同步：前台、全局与单设备开关、在线、没有待处理的
  /// “需要确认”（那要用户手动处理）、不在编辑。
  bool _canAutoSync(String peerId) {
    final device = _store.peer(peerId);
    return !_disposed &&
        _foreground &&
        _store.prefs.autoSync &&
        device != null &&
        device.autoSync &&
        !device.needsAttention &&
        _presence.containsKey(peerId) &&
        !editing.isEditing();
  }

  /// 同步范围内的表变了。会话期间（任一方向）的变化一律当作同步自己的写入
  /// 忽略：否则每次同步写完都会在去抖之后再触发一轮空同步。代价是会话
  /// 进行中用户的改动要等下一次触发才同步（会话通常只有几秒）。
  void _onTablesChanged(Set<TableUpdate> _) {
    if (_active != null) return;
    _auto.localDataChanged();
  }

  /// 由店、在线表、会话进度与页面引用计数重新拼出状态快照。
  void _publish() {
    if (!_started || _disposed) return;
    final data = _store.data.value;
    final sessions = _store.sessions.value;
    final status = _discovery?.status.value;
    final running = status?.running ?? false;
    _state.value = LanSyncEngineState(
      local: LanSyncLocalDevice(
        deviceId: _identity.deviceId,
        name: _deviceName,
        platform: hooks.platformId(),
        addresses: _addresses,
        port: _server?.port,
        discoverable: data.prefs.discoverable,
        discoveryListening: !running || status!.listening,
      ),
      peers: [
        for (final device in data.peers)
          _peerState(device, [
            for (final record in sessions)
              if (record.peerId == device.deviceId) record,
          ]),
      ],
      nearby: _attachments == 0
          ? const <LanSyncNearbyDevice>[]
          : [
              for (final presence in _presence.values)
                if (data.peer(presence.beacon.deviceId) == null)
                  LanSyncNearbyDevice(
                    deviceId: presence.beacon.deviceId,
                    name: presence.beacon.name,
                    platform: presence.beacon.platform,
                    address: presence.address.address,
                  ),
            ],
      autoSync: data.prefs.autoSync,
      syncSettings: data.prefs.syncSettings,
      searching: _attachments > 0 && running,
    );
  }

  LanSyncPeerState _peerState(
    LanSyncPairedDevice device,
    List<LanSyncSessionRecord> history,
  ) {
    final presence = _presence[device.deviceId];
    final active = _active;
    final mine = active != null && active.peerId == device.deviceId;
    return LanSyncPeerState(
      device: device,
      online: presence != null,
      address: presence?.address.address ?? device.lastHost,
      session: mine && active.visible ? active.progress.value : null,
      awaitingConfirmation:
          mine && (active.session?.pendingConfirmation?.isPending ?? false),
      history: history,
    );
  }
}
