// 握手的公开类型：发起方式、响应方回调、结果与失败原因（由
// lan_sync_handshake.dart 导出，调用方只需导入那一个文件）。
import 'dart:async';

import 'lan_sync_channel.dart';
import 'lan_sync_crypto.dart';
import 'lan_sync_messages.dart';

/// 是否信任某台设备：会话层查已配对设备表，deviceId 与身份公钥都一致才返回 true。
typedef LanSyncTrustCheck =
    FutureOr<bool> Function(String deviceId, List<int> publicKey);

/// 核对码确认：界面显示 [code]（6 位数字，按 3+3 分组）与对方信息，用户确认一致
/// 返回 true，拒绝返回 false。超时由握手处理，回调不必自己计时。
typedef LanSyncSasConfirm =
    Future<bool> Function(String code, LanSyncPeerHello peer);

/// 核销扫码令牌：令牌一致且有效时作废并返回 true（即 `LanSyncQrToken.consume`）。
/// 必须同步完成检查与作废，保证同一令牌只能用一次。
typedef LanSyncQrTokenCheck = bool Function(String token);

/// 本机在 hello 里宣告的信息。
class LanSyncLocalInfo {
  const LanSyncLocalInfo({
    required this.name,
    required this.platform,
    required this.formatVersion,
  });

  /// 设备名，1..[LanSyncPeerHello.maxNameLength] 个字符（调用方负责截断）。
  final String name;

  /// 平台名（小写字母、数字与下划线，如 `android`、`linux`、`windows`）。
  final String platform;

  /// 同步格式版本（`kSyncFormatVersion`）。握手只交换、不比较。
  final int formatVersion;
}

/// 发起方这次连接要做什么。
sealed class LanSyncInitiation {
  const LanSyncInitiation();
}

/// 与已配对设备同步：双方都必须信任对方的身份公钥。
final class LanSyncSyncInitiation extends LanSyncInitiation {
  const LanSyncSyncInitiation({required this.isTrusted});

  final LanSyncTrustCheck isTrusted;
}

/// 核对码配对：不看已有信任关系，双方用户确认 6 位核对码一致才成功（重新配对
/// 时用新的公钥替换旧的）。
final class LanSyncSasPairing extends LanSyncInitiation {
  const LanSyncSasPairing({required this.confirmSas});

  final LanSyncSasConfirm confirmSas;
}

/// 扫码配对：对方身份公钥的指纹必须等于二维码里的 [fingerprint]，并在加密信道里
/// 出示一次性 [token]；不需要核对码。
final class LanSyncQrPairing extends LanSyncInitiation {
  const LanSyncQrPairing({required this.fingerprint, required this.token});

  final String fingerprint;
  final String token;
}

/// 响应方的决策回调。
class LanSyncResponderPolicy {
  const LanSyncResponderPolicy({
    required this.isTrusted,
    required this.confirmSas,
    required this.consumeQrToken,
  });

  /// 对方意图为同步时检查信任。
  final LanSyncTrustCheck isTrusted;

  /// 对方发起核对码配对时请用户确认（不想接受配对时直接返回 false）。
  final LanSyncSasConfirm confirmSas;

  /// 对方发起扫码配对时核销令牌（没有显示二维码时返回 false）。
  final LanSyncQrTokenCheck consumeQrToken;
}

/// 握手成功的结果。
class LanSyncHandshakeResult {
  const LanSyncHandshakeResult({
    required this.role,
    required this.peer,
    required this.pairingMethod,
    required this.channel,
  });

  final LanSyncRole role;

  /// 对方的 hello：deviceId、名称、平台、身份公钥、同步格式版本；对方是发起方
  /// 时还有它的意图（[LanSyncPeerHello.intent]）。
  final LanSyncPeerHello peer;

  /// 本次完成配对的方式；为 null 表示是已配对设备之间的同步连接。
  final LanSyncPairingMethod? pairingMethod;

  /// 本次是否完成了配对：为 true 时调用方保存 [peer] 的 deviceId 与公钥。
  bool get paired => pairingMethod != null;

  /// 已开始分发的加密信道；用完由调用方 [LanSyncChannel.close]。
  final LanSyncChannel channel;
}

/// 握手失败的原因。[wire] 是写在 hs.reject / pair.reject 里的原因码。
enum LanSyncHandshakeFailure {
  /// 握手协议版本不同。
  versionMismatch('version'),

  /// 同步连接中有一方不信任对方（未配对或公钥已变）：界面提示重新配对。
  untrusted('untrusted'),

  /// 核对码配对被一方用户拒绝。
  sasRejected('sas_rejected'),

  /// 对方或用户在时限内没有响应。
  timeout('timeout'),

  /// 对方签名验证失败（冒充身份或中间人改动了握手内容）。
  badSignature('signature'),

  /// 发起方揭示的临时公钥与承诺不符。
  commitmentMismatch('commitment'),

  /// 扫码配对时对方身份与二维码上的指纹不符。
  fingerprintMismatch('fingerprint'),

  /// 扫码令牌不对、过期或已用过。
  tokenRejected('token'),

  /// 消息格式不对、顺序不对或无法解密。
  protocolError('protocol'),

  /// 连接在握手完成前断开。
  connectionClosed('closed');

  const LanSyncHandshakeFailure(this.wire);

  final String wire;

  /// 解析对方给的原因码；认不出的按协议错误处理。
  static LanSyncHandshakeFailure fromWire(Object? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return protocolError;
  }
}

class LanSyncHandshakeException implements Exception {
  const LanSyncHandshakeException(
    this.reason, {
    this.byPeer = false,
    this.peer,
    this.peerProtocolVersion,
    this.detail,
    this.nothingReceived = false,
  });

  final LanSyncHandshakeFailure reason;

  /// 原因是否由对方报告（对方拒绝了本机），否则为本机判定。
  final bool byPeer;

  /// 失败前已收到的对方 hello（界面据此显示是哪台设备）。
  final LanSyncPeerHello? peer;

  /// 版本不同时对方的协议版本（对方告知或其 hello 里的值）。
  final int? peerProtocolVersion;

  final String? detail;

  /// 连接断开（[LanSyncHandshakeFailure.connectionClosed]）时对方一个字节都
  /// 还没发过来：多半根本没连到对方——本机或对方的 VPN / 代理先接下了连接
  /// 又断开，或地址、端口指向了别的程序。界面按“连不上”说明，而不是
  /// “连接中断了”。
  final bool nothingReceived;

  @override
  String toString() =>
      'LanSyncHandshakeException(${reason.name}'
      '${byPeer ? ', by peer' : ''}'
      '${nothingReceived ? ', nothing received' : ''}'
      '${detail == null ? '' : ': $detail'})';
}
