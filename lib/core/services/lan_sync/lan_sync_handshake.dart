// 局域网同步的双向认证握手（SIGMA 式）与配对（docs/lan_sync.md §5.2）。
//
// 职责边界：
// - 输入：已连接的 [Socket]、本机身份与 hello 信息、会话层给的回调（是否受信、
//   核对码确认、扫码令牌核销）；
// - 输出：[LanSyncHandshakeResult]（对方 hello、是否在本次完成配对、加密信道），
//   或带原因的 [LanSyncHandshakeException]；
// - 副作用：读写套接字；失败时关闭套接字。不存任何东西：配对成功后由调用方保存
//   对方公钥。这里不碰界面。
//
// 消息顺序（I = 发起方 / 连接方，R = 响应方 / 监听方；前三条为明文帧）：
//   1. I→R hs.hello  {v, f, intent, method?, id, name, platform, pk, nonce,
//                     commit = H(临时公钥_I ‖ nonce_I)}
//   2. R→I hs.hello  {v, f, id, name, platform, pk, nonce, eph = 临时公钥_R}
//   3. I→R hs.reveal {eph = 临时公钥_I}（R 校验承诺）
//      —— 双方算出 transcript 哈希、X25519 共享密钥与方向密钥，之后全部为密文帧 ——
//   4. R→I hs.auth   {sig = Sig_R("…sig responder" ‖ TH)}
//   5. I→R hs.auth   {sig = Sig_I("…sig initiator" ‖ TH), token?（扫码配对）}
//   6. R→I hs.ok
//   7. （仅核对码配对）双方各自显示核对码，用户确认后互发 pair.confirm，
//      拒绝或超时发 pair.reject。
// 任何一步都可能以 hs.reject{reason} 代替：1 之后 R 的版本 / 信任检查、2 之后 I
// 的版本 / 信任 / 指纹检查以明文发出；之后的拒绝在信道里加密发出。R 发现承诺
// 不符时直接断开（只有恶意或损坏的对端才会这样）。
//
// 为什么核对码需要承诺：核对码只有 10^6 种。中间人若能先看到一方的临时公钥再
// 挑选自己的，就能离线尝试约 2^20 个密钥，让两边算出相同的核对码，用户“核对
// 一致”也拦不住。承诺让 I 在看到 R 的临时公钥之前就锁定自己的；R 的临时公钥
// 又是在收到承诺之后才发出的。于是中间人在任一侧都必须在不知道对方值的情况下
// 先定下自己的值，两侧核对码相同的概率只剩 10^-6。
//
// 为什么签名覆盖整个 transcript：transcript 包含双方身份公钥、随机数与临时公钥，
// 签名把“谁”与“这次的密钥交换”绑在一起（防止身份错配）；签名本身在信道里
// 加密传输，能解开即证明对方算出了同一组方向密钥。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'lan_sync_channel.dart';
import 'lan_sync_crypto.dart';
import 'lan_sync_frames.dart';
import 'lan_sync_handshake_types.dart';
import 'lan_sync_identity.dart';
import 'lan_sync_messages.dart';

export 'lan_sync_handshake_types.dart';

part 'lan_sync_handshake_flows.dart';
part 'lan_sync_handshake_sas.dart';

/// 握手。一个实例可以反复用于多条连接（无连接状态）。
class LanSyncHandshake {
  LanSyncHandshake({
    required this.identity,
    required this.local,
    this.stepTimeout = const Duration(seconds: 15),
    this.sasTimeout = const Duration(seconds: 60),
    this.lingerTimeout = const Duration(seconds: 2),
  });

  final LanSyncIdentity identity;
  final LanSyncLocalInfo local;

  /// 每一步等待对方消息的上限。
  final Duration stepTimeout;

  /// 核对码确认阶段（从显示核对码到收到双方决定）的上限。
  final Duration sasTimeout;

  /// 发出拒绝或关闭帧后等对方收尾的上限。
  final Duration lingerTimeout;

  /// 作为发起方握手。
  Future<LanSyncHandshakeResult> initiate(
    Socket socket,
    LanSyncInitiation initiation,
  ) {
    return _Run(
      this,
      socket,
      LanSyncRole.initiator,
    )._guard((run) => run._initiate(initiation));
  }

  /// 作为响应方握手。
  Future<LanSyncHandshakeResult> respond(
    Socket socket,
    LanSyncResponderPolicy policy,
  ) {
    return _Run(
      this,
      socket,
      LanSyncRole.responder,
    )._guard((run) => run._respond(policy));
  }
}

/// 一条连接上的一次握手。
class _Run {
  _Run(this.config, this.socket, this.role)
    : reader = LanSyncFrameReader(socket) {
    socket.done.ignore();
  }

  final LanSyncHandshake config;
  final Socket socket;
  final LanSyncRole role;
  final LanSyncFrameReader reader;

  /// 方向密钥派生之后才有；之后的消息都经它加密收发。
  LanSyncChannel? channel;

  /// 已知的对方 hello（用于异常里告诉界面是谁）。
  LanSyncPeerHello? peer;

  bool get _isInitiator => role == LanSyncRole.initiator;

  Future<LanSyncHandshakeResult> _guard(
    Future<LanSyncHandshakeResult> Function(_Run run) body,
  ) async {
    try {
      final result = await body(this);
      result.channel.start();
      return result;
    } catch (error) {
      final failure = _mapError(error);
      _destroy();
      throw failure;
    }
  }

  // ---------------------------------------------------------------------------
  // 共用步骤
  // ---------------------------------------------------------------------------

  LanSyncPeerHello _localHello({
    required Uint8List nonce,
    LanSyncIntent? intent,
    LanSyncPairingMethod? method,
    Uint8List? commitment,
    Uint8List? ephemeralPublicKey,
  }) {
    return LanSyncPeerHello(
      protocolVersion: kLanSyncProtocolVersion,
      formatVersion: config.local.formatVersion,
      deviceId: config.identity.deviceId,
      name: config.local.name,
      platform: config.local.platform,
      publicKey: config.identity.publicKey,
      nonce: nonce,
      intent: intent,
      pairingMethod: method,
      commitment: commitment,
      ephemeralPublicKey: ephemeralPublicKey,
    );
  }

  /// 先只看协议版本：版本不同时其余字段可能根本不同，不能按本版规则严格解析。
  Future<void> _checkVersion(LanSyncMessage hello) async {
    final version = hello.fields['v'];
    if (version != kLanSyncProtocolVersion) {
      await _reject(
        LanSyncHandshakeFailure.versionMismatch,
        peerProtocolVersion: version is int ? version : null,
      );
    }
  }

  LanSyncPeerHello _parseHello(
    LanSyncMessage message, {
    required bool fromInitiator,
  }) {
    final hello = LanSyncPeerHello.parse(message, fromInitiator: fromInitiator);
    if (hello.deviceId == config.identity.deviceId ||
        lanSyncBytesEqual(hello.publicKey, config.identity.publicKey)) {
      throw const FormatException('connected to itself');
    }
    return hello;
  }

  /// 拼出 transcript，算共享密钥与方向密钥，建立信道。
  Future<({Uint8List transcript, String sasCode})> _establish({
    required LanSyncPeerHello initiatorHello,
    required List<int> initiatorEphemeral,
    required LanSyncPeerHello responderHello,
    required List<int> responderEphemeral,
    required SimpleKeyPair ephemeral,
  }) async {
    final transcript = LanSyncTranscript();
    initiatorHello.addToTranscript(transcript, initiatorEphemeral);
    responderHello.addToTranscript(transcript, responderEphemeral);
    final hash = transcript.hash;
    final shared = await lanSyncSharedSecret(
      ephemeral: ephemeral,
      peerEphemeralPublicKey: _isInitiator
          ? responderEphemeral
          : initiatorEphemeral,
    );
    final keys = await LanSyncSessionKeys.derive(
      sharedSecret: shared,
      transcriptHash: hash,
    );
    channel = LanSyncChannel.establish(
      socket: socket,
      reader: reader,
      sendCipher: LanSyncFrameCipher(key: keys.sendKey(role), sender: role),
      receiveCipher: LanSyncFrameCipher(
        key: keys.receiveKey(role),
        sender: _isInitiator ? LanSyncRole.responder : LanSyncRole.initiator,
      ),
      lingerTimeout: config.lingerTimeout,
    );
    return (transcript: hash, sasCode: keys.sasCode);
  }

  Future<Uint8List> _sign(Uint8List transcript) {
    return config.identity.sign(lanSyncSignaturePayload(role, transcript));
  }

  Future<void> _verifyAuth(
    LanSyncMessage auth,
    Uint8List transcript,
    LanSyncPeerHello peer,
  ) async {
    _throwIfRejected(auth);
    if (auth.type != LanSyncMessageTypes.auth) {
      throw FormatException('expected auth, got ${auth.type}');
    }
    final signature = auth.requireBytes('sig', length: 64);
    final signer = _isInitiator ? LanSyncRole.responder : LanSyncRole.initiator;
    final valid = await Ed25519().verify(
      lanSyncSignaturePayload(signer, transcript),
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(peer.publicKey, type: KeyPairType.ed25519),
      ),
    );
    if (!valid) await _reject(LanSyncHandshakeFailure.badSignature);
  }

  // ---------------------------------------------------------------------------
  // 收发与拒绝
  // ---------------------------------------------------------------------------

  Future<LanSyncMessage> _readPlain() async {
    final payload = await reader
        .next(maxLength: kLanSyncHandshakeFrameMax)
        .timeout(config.stepTimeout);
    if (payload == null) {
      throw LanSyncHandshakeException(
        LanSyncHandshakeFailure.connectionClosed,
        peer: peer,
      );
    }
    return LanSyncMessage.decode(payload);
  }

  Future<void> _writePlain(LanSyncMessage message) async {
    socket.add(lanSyncPlainFrame(message.encode()));
    await socket.flush().timeout(config.stepTimeout);
  }

  Future<LanSyncMessage> _receive() =>
      channel!.receiveHandshakeMessage(config.stepTimeout);

  /// 对方发来的拒绝：按原因抛出（标记为对方报告）。
  void _throwIfRejected(LanSyncMessage message) {
    if (message.type == LanSyncMessageTypes.reject ||
        message.type == LanSyncMessageTypes.pairReject) {
      final reason = LanSyncHandshakeFailure.fromWire(message.fields['reason']);
      final version = message.fields['v'];
      throw LanSyncHandshakeException(
        message.type == LanSyncMessageTypes.pairReject &&
                reason != LanSyncHandshakeFailure.timeout
            ? LanSyncHandshakeFailure.sasRejected
            : reason,
        byPeer: true,
        peer: peer,
        peerProtocolVersion: version is int ? version : null,
      );
    }
  }

  /// 告诉对方拒绝原因、等对方收尾后关闭，然后抛出同一原因。
  Future<Never> _reject(
    LanSyncHandshakeFailure reason, {
    int? peerProtocolVersion,
    bool pairing = false,
  }) async {
    await _sendRejectQuietly(reason, pairing: pairing);
    final channel = this.channel;
    if (channel != null) {
      await channel.close();
    } else {
      // 关闭写方向（FIN），读完对方已发来的字节再销毁：带着未读数据关闭会触发
      // RST，对方可能来不及读到这条拒绝。
      try {
        socket.close().ignore();
      } on StateError {
        // 写方向还卡在没完成的 flush 上（对方不收）：直接销毁。
      }
      await reader.drain(config.lingerTimeout);
    }
    throw LanSyncHandshakeException(
      reason,
      peer: peer,
      peerProtocolVersion: peerProtocolVersion,
    );
  }

  /// 发出拒绝消息；发不出去（对方已断开）时忽略。[pairing] 为核对码确认阶段
  /// 的拒绝（pair.reject），其余为 hs.reject。
  Future<void> _sendRejectQuietly(
    LanSyncHandshakeFailure reason, {
    bool pairing = false,
  }) async {
    final message = LanSyncMessage(
      pairing ? LanSyncMessageTypes.pairReject : LanSyncMessageTypes.reject,
      {
        'reason': reason.wire,
        if (reason == LanSyncHandshakeFailure.versionMismatch)
          'v': kLanSyncProtocolVersion,
      },
    );
    try {
      final channel = this.channel;
      if (channel != null) {
        await channel.send(message);
      } else {
        await _writePlain(message);
      }
    } on Object {
      // 拒绝只是礼貌性的告知，送不到不改变本机的结果。
    }
  }

  LanSyncHandshakeException _mapError(Object error) {
    return switch (error) {
      LanSyncHandshakeException() => error,
      TimeoutException() => LanSyncHandshakeException(
        LanSyncHandshakeFailure.timeout,
        peer: peer,
      ),
      LanSyncChannelException(
        error: LanSyncChannelError.connectionLost || LanSyncChannelError.closed,
      ) ||
      LanSyncFrameException(
        error: LanSyncFrameError.truncated || LanSyncFrameError.connectionError,
      ) ||
      SocketException() => LanSyncHandshakeException(
        LanSyncHandshakeFailure.connectionClosed,
        peer: peer,
        detail: '$error',
      ),
      _ => LanSyncHandshakeException(
        LanSyncHandshakeFailure.protocolError,
        peer: peer,
        detail: '$error',
      ),
    };
  }

  void _destroy() {
    final channel = this.channel;
    if (channel != null) {
      channel.destroy();
    } else {
      socket.destroy();
      unawaited(reader.cancel());
    }
  }
}

Future<Uint8List> _publicBytes(SimpleKeyPair keyPair) async {
  final publicKey = await keyPair.extractPublicKey();
  return Uint8List.fromList(publicKey.bytes);
}
