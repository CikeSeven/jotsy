// 握手的两条主流程：发起方与响应方各自的消息顺序（见 lan_sync_handshake.dart
// 顶部的消息表）。共用的收发、拒绝与密钥步骤在主文件的 [_Run] 里。
part of 'lan_sync_handshake.dart';

extension _HandshakeFlows on _Run {
  // ---------------------------------------------------------------------------
  // 发起方
  // ---------------------------------------------------------------------------

  Future<LanSyncHandshakeResult> _initiate(LanSyncInitiation initiation) async {
    final ephemeral = await X25519().newKeyPair();
    final ephemeralPublic = await _publicBytes(ephemeral);
    final nonce = lanSyncRandomBytes(kLanSyncKeyBytes);
    final (intent, method) = switch (initiation) {
      LanSyncSyncInitiation() => (LanSyncIntent.sync, null),
      LanSyncSasPairing() => (LanSyncIntent.pair, LanSyncPairingMethod.sas),
      LanSyncQrPairing() => (LanSyncIntent.pair, LanSyncPairingMethod.qr),
    };
    final hello = _localHello(
      nonce: nonce,
      intent: intent,
      method: method,
      commitment: lanSyncCommitment(ephemeralPublic, nonce),
    );
    await _writePlain(hello.toMessage());

    final reply = await _readPlain();
    _throwIfRejected(reply);
    if (reply.type != LanSyncMessageTypes.hello) {
      throw FormatException('expected hello, got ${reply.type}');
    }
    await _checkVersion(reply);
    final peer = this.peer = _parseHello(reply, fromInitiator: false);

    switch (initiation) {
      case LanSyncSyncInitiation(:final isTrusted):
        if (!await isTrusted(peer.deviceId, peer.publicKey)) {
          await _reject(LanSyncHandshakeFailure.untrusted);
        }
      case LanSyncQrPairing(:final fingerprint):
        // 先核对指纹再揭示临时公钥：不是二维码上那台设备就不继续往下谈。
        if (!lanSyncBytesEqual(
          utf8.encode(peer.fingerprint),
          utf8.encode(fingerprint.toLowerCase()),
        )) {
          await _reject(LanSyncHandshakeFailure.fingerprintMismatch);
        }
      case LanSyncSasPairing():
        break;
    }
    await _writePlain(
      LanSyncMessage(LanSyncMessageTypes.reveal, {
        'eph': base64.encode(ephemeralPublic),
      }),
    );

    final keys = await _establish(
      initiatorHello: hello,
      initiatorEphemeral: ephemeralPublic,
      responderHello: peer,
      responderEphemeral: peer.ephemeralPublicKey!,
      ephemeral: ephemeral,
    );
    final channel = this.channel!;

    await _verifyAuth(await _receive(), keys.transcript, peer);
    await channel.send(
      LanSyncMessage(LanSyncMessageTypes.auth, {
        'sig': base64.encode(await _sign(keys.transcript)),
        if (initiation is LanSyncQrPairing) 'token': initiation.token,
      }),
    );
    final ok = await _receive();
    _throwIfRejected(ok);
    if (ok.type != LanSyncMessageTypes.ok) {
      throw FormatException('expected ok, got ${ok.type}');
    }
    if (initiation is LanSyncSasPairing) {
      await _confirmSas(keys.sasCode, peer, initiation.confirmSas);
    }
    return LanSyncHandshakeResult(
      role: role,
      peer: peer,
      pairingMethod: method,
      channel: channel,
    );
  }

  // ---------------------------------------------------------------------------
  // 响应方
  // ---------------------------------------------------------------------------

  Future<LanSyncHandshakeResult> _respond(LanSyncResponderPolicy policy) async {
    final first = await _readPlain();
    if (first.type != LanSyncMessageTypes.hello) {
      throw FormatException('expected hello, got ${first.type}');
    }
    await _checkVersion(first);
    final peer = this.peer = _parseHello(first, fromInitiator: true);
    if (peer.intent == LanSyncIntent.sync &&
        !await policy.isTrusted(peer.deviceId, peer.publicKey)) {
      await _reject(LanSyncHandshakeFailure.untrusted);
    }

    final ephemeral = await X25519().newKeyPair();
    final ephemeralPublic = await _publicBytes(ephemeral);
    final hello = _localHello(
      nonce: lanSyncRandomBytes(kLanSyncKeyBytes),
      ephemeralPublicKey: ephemeralPublic,
    );
    await _writePlain(hello.toMessage());

    final reveal = await _readPlain();
    _throwIfRejected(reveal);
    if (reveal.type != LanSyncMessageTypes.reveal) {
      throw FormatException('expected reveal, got ${reveal.type}');
    }
    final peerEphemeral = reveal.requireBytes('eph', length: kLanSyncKeyBytes);
    if (!lanSyncBytesEqual(
      lanSyncCommitment(peerEphemeral, peer.nonce),
      peer.commitment!,
    )) {
      throw LanSyncHandshakeException(
        LanSyncHandshakeFailure.commitmentMismatch,
        peer: peer,
      );
    }

    final keys = await _establish(
      initiatorHello: peer,
      initiatorEphemeral: peerEphemeral,
      responderHello: hello,
      responderEphemeral: ephemeralPublic,
      ephemeral: ephemeral,
    );
    final channel = this.channel!;
    await channel.send(
      LanSyncMessage(LanSyncMessageTypes.auth, {
        'sig': base64.encode(await _sign(keys.transcript)),
      }),
    );
    final auth = await _receive();
    await _verifyAuth(auth, keys.transcript, peer);

    if (peer.pairingMethod == LanSyncPairingMethod.qr) {
      // 签名验证之后才核销：令牌只在确认对方持有其宣告的身份私钥后作废。
      final token = auth.optionalString('token', maxLength: 64);
      if (token == null || !policy.consumeQrToken(token)) {
        await _reject(LanSyncHandshakeFailure.tokenRejected);
      }
    }
    await channel.send(LanSyncMessage(LanSyncMessageTypes.ok));
    if (peer.pairingMethod == LanSyncPairingMethod.sas) {
      await _confirmSas(keys.sasCode, peer, policy.confirmSas);
    }
    return LanSyncHandshakeResult(
      role: role,
      peer: peer,
      pairingMethod: peer.pairingMethod,
      channel: channel,
    );
  }
}
