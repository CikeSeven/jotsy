// 服务端：监听 TCP、按策略响应握手（信任 = 已配对设备表；核对码只在同步页
// 打开时接受；扫码令牌 = 当前二维码），之后接配对或响应方会话（docs §5.2）。
part of 'lan_sync_service.dart';

/// 同时进行中的入站握手上限：超过的连接直接断开（防止局域网里有人刷连接）。
const int _kMaxIncomingHandshakes = 4;

/// 一条入站连接上可能出现的配对（核对码在策略回调里才知道）。
class _IncomingPairing {
  LanSyncPairing? pairing;
}

extension _Server on LanSyncService {
  /// 依次试首选端口、上次用过的端口、随机端口；都失败时服务端不起来（端口为
  /// null，信标不发），只打印日志。绑定期间不再需要网络（切到后台、关闭、
  /// 最后一个页面离开）时立即关掉。
  Future<void> _startServer() async {
    if (_server != null || _disposed) return;
    ServerSocket? bound;
    for (final port in <int>{hooks.preferredPort, ?_port, 0}) {
      try {
        bound = await hooks.bindServer(port);
        break;
      } on Object catch (error) {
        debugPrint('LAN sync server bind $port failed: $error');
      }
    }
    if (bound == null) return;
    if (_disposed || !_networkWanted || _server != null) {
      await bound.close();
      return;
    }
    _server = bound;
    _port = bound.port;
    _serverSubscription = bound.listen(
      _accept,
      onError: (Object error) => debugPrint('LAN sync server error: $error'),
    );
  }

  Future<void> _stopServer() async {
    final server = _server;
    _server = null;
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await server?.close();
  }

  void _accept(Socket socket) {
    if (_disposed || _handshakesInFlight >= _kMaxIncomingHandshakes) {
      socket.destroy();
      return;
    }
    _handshakesInFlight++;
    unawaited(
      _handleIncoming(socket).whenComplete(() => _handshakesInFlight--),
    );
  }

  Future<void> _handleIncoming(Socket socket) async {
    final slot = _IncomingPairing();
    String? remoteHost;
    try {
      remoteHost = socket.remoteAddress.address;
    } on Object {
      remoteHost = null;
    }
    try {
      final result = await _handshake().respond(
        socket,
        LanSyncResponderPolicy(
          isTrusted: _isTrusted,
          confirmSas: (code, peer) => _confirmIncomingSas(code, peer, slot),
          consumeQrToken: _consumeQrToken,
        ),
      );
      if (result.paired) {
        await _completeIncomingPairing(result, remoteHost, slot);
      } else {
        await _serveSession(result);
      }
    } on LanSyncHandshakeException catch (error) {
      final pairing = slot.pairing;
      pairing?._fail(_pairingFailure(error, pairing._cancelled));
    } on Object catch (error, stack) {
      debugPrint('LAN sync incoming connection failed: $error\n$stack');
      slot.pairing?._fail(LanSyncFailure.unknown);
    } finally {
      if (slot.pairing != null && identical(_pairing, slot.pairing)) {
        _pairing = null;
      }
    }
  }

  /// 传入的核对码配对：只在同步页打开（且没有别的配对）时交给用户，否则
  /// 直接拒绝——没有人在场核对数字，留着只会等到超时（规格 §5.2）。
  Future<bool> _confirmIncomingSas(
    String code,
    LanSyncPeerHello peer,
    _IncomingPairing slot,
  ) {
    if (_attachments == 0 || !_foreground || _pairing != null) {
      return Future<bool>.value(false);
    }
    final pairing = LanSyncPairing._(
      incoming: true,
      peerName: peer.name,
      platform: peer.platform,
    );
    slot.pairing = pairing;
    _pairing = pairing;
    final decision = pairing._awaitUser(code, peer.name);
    _emit(LanSyncPairingStarted(pairing));
    return decision;
  }

  /// 核销扫码令牌（同步完成检查与作废）；用掉即换发新的一张。
  bool _consumeQrToken(String token) {
    final current = _token;
    if (current == null || !current.consume(token, now: _now())) return false;
    _issueQrTicket();
    return true;
  }

  Future<void> _completeIncomingPairing(
    LanSyncHandshakeResult result,
    String? remoteHost,
    _IncomingPairing slot,
  ) async {
    final peer = result.peer;
    await _savePairedPeer(
      peer,
      host: remoteHost,
      port: _presence[peer.deviceId]?.beacon.port,
    );
    await result.channel.close();
    final pairing = slot.pairing;
    if (pairing != null) {
      pairing._succeed(peer.deviceId);
      return;
    }
    // 扫码配对：令牌在握手里核销，配对到这里才算成立，直接以成功告知界面。
    _emit(
      LanSyncPairingStarted(
        LanSyncPairing._(
          incoming: true,
          peerName: peer.name,
          platform: peer.platform,
          initial: LanSyncPairingState(
            LanSyncPairingStatus.succeeded,
            peerId: peer.deviceId,
          ),
        ),
      ),
    );
  }

  /// 已配对设备发来的同步：正有会话时以 busy 拒绝（会话层回 `sync.reject`），
  /// 否则作为响应方运行。是否接受自动同步取本机全局与这台设备的开关；这台
  /// 设备还有没处理的“需要确认”时也拒绝自动同步，等用户手动处理。
  Future<void> _serveSession(LanSyncHandshakeResult result) async {
    final peerId = result.peer.deviceId;
    final device = _store.peer(peerId);
    if (device == null) {
      await result.channel.close();
      return;
    }
    // 忙不忙的判断与占位之间不能有 await：否则一次出站同步可能插进来，两个
    // 会话并发使用同一个 SyncLocalState。
    _auto.sessionArrived(peerId);
    final busy = _active != null;
    final prefs = _store.prefs;
    final session = LanSyncSession.responder(
      channel: result.channel,
      context: _sessionContext(),
      peer: LanSyncSessionPeer(
        deviceId: peerId,
        restoredPending: device.restoredPending,
      ),
      syncSettings: _syncSettings,
      acceptAutomatic:
          _foreground &&
          prefs.autoSync &&
          device.autoSync &&
          !device.needsAttention,
      busy: busy,
      timeouts: timings.session,
    );
    if (busy) {
      await session.run();
      return;
    }
    final active = _active = _ActiveSession(
      peerId,
      role: LanSyncRole.responder,
      automatic: false,
    );
    active.attach(session, _publish);
    final LanSyncSessionResult outcome;
    try {
      await _notePeerHello(result.peer);
      outcome = await session.run();
    } finally {
      _active = null;
      active.finish();
      _publish();
    }
    await _finishSession(outcome, firstSync: device.lastSyncAt == null);
  }
}

/// 握手失败 → 配对 / 同步失败原因。[cancelledLocally] 为本机用户已放弃
/// （之后的任何失败都按取消处理）。
LanSyncFailure _pairingFailure(
  LanSyncHandshakeException error,
  bool cancelledLocally,
) {
  if (cancelledLocally) return LanSyncFailure.cancelled;
  return switch (error.reason) {
    LanSyncHandshakeFailure.versionMismatch =>
      LanSyncFailure.incompatibleVersion,
    LanSyncHandshakeFailure.untrusted ||
    LanSyncHandshakeFailure.badSignature ||
    LanSyncHandshakeFailure.commitmentMismatch ||
    LanSyncHandshakeFailure.fingerprintMismatch => LanSyncFailure.untrusted,
    LanSyncHandshakeFailure.sasRejected =>
      error.byPeer ? LanSyncFailure.declined : LanSyncFailure.cancelled,
    LanSyncHandshakeFailure.timeout => LanSyncFailure.timedOut,
    LanSyncHandshakeFailure.tokenRejected => LanSyncFailure.ticketExpired,
    LanSyncHandshakeFailure.protocolError => LanSyncFailure.protocolError,
    LanSyncHandshakeFailure.connectionClosed =>
      error.nothingReceived
          ? LanSyncFailure.unreachable
          : LanSyncFailure.connectionLost,
  };
}
