// 出站连接：与已配对设备同步、核对码配对、按地址连接、扫码配对
// （lan_sync_service.dart 的一部分）。
part of 'lan_sync_service.dart';

typedef _Connected = ({Socket socket, String host, int port});

extension _Outgoing on LanSyncService {
  /// 作为发起方与 [peerId] 同步。不是已配对设备、或已有会话在进行时返回
  /// null（不产生效果）。[established] 是按地址连接时已经握手成功的连接。
  ///
  /// 流程：本机在编辑 → 手动同步以 localEditing 结束（不连接）、自动同步
  /// 静默跳过；否则占住会话位置 → 连接（在线地址优先，其次上次的地址）→
  /// 握手 → 会话。连接与握手阶段的取消经销毁套接字生效。
  Future<LanSyncSessionResult?> _syncWith(
    String peerId, {
    required bool automatic,
    LanSyncHandshakeResult? established,
  }) async {
    final device = _store.peer(peerId);
    if (!_started || _disposed || device == null || _active != null) {
      return null;
    }
    final startedAt = _now();
    final firstSync = device.lastSyncAt == null;
    if (editing.isEditing()) {
      if (automatic) return null;
      final result = _failedResult(
        peerId,
        startedAt,
        LanSyncFailure.localEditing,
        automatic: false,
      );
      await _finishSession(result, firstSync: firstSync);
      return result;
    }
    final active = _active = _ActiveSession(
      peerId,
      role: LanSyncRole.initiator,
      automatic: automatic,
    );
    _publish();
    final LanSyncSessionResult result;
    try {
      result = await _runOutgoing(device, active, startedAt, established);
    } finally {
      _active = null;
      active.finish();
      _publish();
    }
    await _finishSession(result, firstSync: firstSync);
    return result;
  }

  Future<LanSyncSessionResult> _runOutgoing(
    LanSyncPairedDevice device,
    _ActiveSession active,
    DateTime startedAt,
    LanSyncHandshakeResult? established,
  ) async {
    LanSyncSessionResult failed(LanSyncFailure failure) => _failedResult(
      device.deviceId,
      startedAt,
      active.cancelRequested ? LanSyncFailure.cancelled : failure,
      automatic: active.automatic,
    );
    var handshake = established;
    if (handshake == null) {
      final connected = await _connectAny(
        _targetsOf(device),
        () => active.cancelRequested,
      );
      if (connected == null) return failed(LanSyncFailure.unreachable);
      if (active.cancelRequested) {
        connected.socket.destroy();
        return failed(LanSyncFailure.cancelled);
      }
      active.abortConnect = connected.socket.destroy;
      try {
        handshake = await _handshake().initiate(
          connected.socket,
          LanSyncSyncInitiation(isTrusted: _isTrusted),
        );
      } on LanSyncHandshakeException catch (error) {
        return failed(_pairingFailure(error, false));
      }
      await _store.updatePeer(
        device.deviceId,
        (d) => d.copyWith(
          lastHost: () => connected.host,
          lastPort: () => connected.port,
        ),
      );
    }
    await _notePeerHello(handshake.peer);
    _auto.sessionArrived(device.deviceId);
    final session = LanSyncSession.initiator(
      channel: handshake.channel,
      context: _sessionContext(),
      peer: LanSyncSessionPeer(
        deviceId: device.deviceId,
        firstSync: device.lastSyncAt == null,
        restoredPending: device.restoredPending,
      ),
      automatic: active.automatic,
      syncSettings: _syncSettings,
      localLoserTitleSuffix: conflictTitleSuffix(_deviceName),
      remoteLoserTitleSuffix: conflictTitleSuffix(
        device.alias ?? handshake.peer.name,
      ),
      onConfirmation: _onConfirmation,
      timeouts: timings.session,
    );
    active.attach(session, _publish);
    return session.run();
  }

  /// 连接候选：在线时信标的地址与端口在前，其次上次连上的地址。
  List<(String, int)> _targetsOf(LanSyncPairedDevice device) {
    final presence = _presence[device.deviceId];
    final targets = <(String, int)>[
      if (presence != null) (presence.address.address, presence.beacon.port),
    ];
    final host = device.lastHost;
    final port = device.lastPort;
    if (host != null && port != null && !targets.contains((host, port))) {
      targets.add((host, port));
    }
    return targets;
  }

  /// 依次尝试候选地址，返回第一个连上的；都连不上（或期间取消）为 null。
  Future<_Connected?> _connectAny(
    List<(String, int)> targets,
    bool Function() cancelled,
  ) async {
    for (final (host, port) in targets) {
      if (cancelled()) return null;
      try {
        final socket = await hooks.connect(host, port, timings.connectTimeout);
        return (socket: socket, host: host, port: port);
      } on Object catch (error) {
        debugPrint('LAN sync connect $host:$port failed: $error');
      }
    }
    return null;
  }

  /// 按地址连接：先当作已配对设备握手——对方认得本机且本机认得对方就直接
  /// 同步；任一方不认得（untrusted）就改走核对码配对；连不上或其他失败以
  /// 失败的配对告知界面。
  Future<void> _connectManual(String host, int port) async {
    if (!_started || _disposed) return;
    final connected = await _connectAny([(host, port)], () => _disposed);
    if (connected == null) {
      _emitFailedPairing(host, LanSyncFailure.unreachable);
      return;
    }
    final LanSyncHandshakeResult result;
    try {
      result = await _handshake().initiate(
        connected.socket,
        LanSyncSyncInitiation(isTrusted: _isTrusted),
      );
    } on LanSyncHandshakeException catch (error) {
      if (error.reason == LanSyncHandshakeFailure.untrusted) {
        final peer = error.peer;
        _startOutgoingPairing(
          name: peer?.name ?? host,
          platform: peer?.platform ?? 'unknown',
          targets: [(host, port)],
          initiation: _sasInitiation,
        );
      } else {
        _emitFailedPairing(host, _pairingFailure(error, false));
      }
      return;
    }
    final peerId = result.peer.deviceId;
    await _store.updatePeer(
      peerId,
      (d) => d.copyWith(lastHost: () => host, lastPort: () => port),
    );
    final outcome = await _syncWith(
      peerId,
      automatic: false,
      established: result,
    );
    if (outcome == null) await result.channel.close();
  }

  LanSyncInitiation _sasInitiation(LanSyncPairing pairing) => LanSyncSasPairing(
    confirmSas: (code, peer) => pairing._awaitUser(code, peer.name),
  );

  /// 开始一次出站配对；同一时刻只能有一个配对，已有时以 busy 失败告知。
  LanSyncPairing _startOutgoingPairing({
    required String name,
    required String platform,
    required List<(String, int)> targets,
    required LanSyncInitiation Function(LanSyncPairing pairing) initiation,
  }) {
    if (_pairing != null || !_started || _disposed) {
      return _emitFailedPairing(name, LanSyncFailure.busy, platform: platform);
    }
    final pairing = _pairing = LanSyncPairing._(
      incoming: false,
      peerName: name,
      platform: platform,
    );
    _emit(LanSyncPairingStarted(pairing));
    unawaited(
      _runOutgoingPairing(pairing, targets, initiation(pairing)).whenComplete(
        () {
          if (identical(_pairing, pairing)) _pairing = null;
        },
      ),
    );
    return pairing;
  }

  Future<void> _runOutgoingPairing(
    LanSyncPairing pairing,
    List<(String, int)> targets,
    LanSyncInitiation initiation,
  ) async {
    final connected = await _connectAny(targets, () => pairing._cancelled);
    if (connected == null || pairing._cancelled) {
      connected?.socket.destroy();
      pairing._fail(
        pairing._cancelled
            ? LanSyncFailure.cancelled
            : LanSyncFailure.unreachable,
      );
      return;
    }
    pairing._onCancel = connected.socket.destroy;
    try {
      final result = await _handshake().initiate(connected.socket, initiation);
      pairing._onCancel = null;
      await _savePairedPeer(
        result.peer,
        host: connected.host,
        port: connected.port,
      );
      await result.channel.close();
      pairing._peerName = result.peer.name;
      pairing._succeed(result.peer.deviceId);
    } on LanSyncHandshakeException catch (error) {
      pairing._fail(_pairingFailure(error, pairing._cancelled));
    }
  }

  /// 扫码：不是 Jotsy 的码返回 false、什么都不做；Jotsy 的码但版本不支持或
  /// 损坏，以失败的配对告知；否则按码上的地址逐个连接、扫码配对。
  bool _connectQr(String text) {
    final LanSyncQrPayload payload;
    try {
      payload = LanSyncQrPayload.decode(text.trim());
    } on LanSyncQrFormatException catch (error) {
      if (error.error == LanSyncQrError.notLanSync) return false;
      _emitFailedPairing(
        '',
        error.error == LanSyncQrError.unsupportedVersion
            ? LanSyncFailure.incompatibleVersion
            : LanSyncFailure.protocolError,
      );
      return true;
    }
    _startOutgoingPairing(
      name: payload.name,
      platform: 'unknown',
      targets: [for (final host in payload.hosts) (host, payload.port)],
      initiation: (_) => LanSyncQrPairing(
        fingerprint: payload.fingerprint,
        token: payload.token,
      ),
    );
    return true;
  }

  LanSyncPairing _emitFailedPairing(
    String name,
    LanSyncFailure failure, {
    String platform = 'unknown',
  }) {
    final pairing = LanSyncPairing._(
      incoming: false,
      peerName: name,
      platform: platform,
      initial: LanSyncPairingState(
        LanSyncPairingStatus.failed,
        failure: failure,
      ),
    );
    _emit(LanSyncPairingStarted(pairing));
    return pairing;
  }
}
