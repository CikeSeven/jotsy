// 配对句柄：一次配对的进展与用户应答（lan_sync_service.dart 的一部分）。
//
// 状态机：连接中 →（核对码）等本机确认 → 等对方确认 → 成功 / 失败；扫码
// 配对没有核对码阶段。成功或失败之后状态冻结，之后的应答不再有效果。服务
// 在握手的回调里推进它（[LanSyncPairing._awaitUser]、`_succeed`、`_fail`），
// 用户经 [LanSyncPairing.respond] 应答。
part of 'lan_sync_service.dart';

/// 配对进展的阶段。
enum LanSyncPairingStatus {
  connecting,
  awaitingUser,
  awaitingPeer,
  succeeded,
  failed,
}

/// 配对进展（不可变快照）。
@immutable
class LanSyncPairingState {
  const LanSyncPairingState(
    this.status, {
    this.code,
    this.peerId,
    this.failure,
  });

  final LanSyncPairingStatus status;

  /// 核对码（等用户 / 等对方时）。
  final String? code;

  /// 成功时对方的 deviceId。
  final String? peerId;

  /// 失败原因。
  final LanSyncFailure? failure;

  bool get isFinal =>
      status == LanSyncPairingStatus.succeeded ||
      status == LanSyncPairingStatus.failed;

  @override
  bool operator ==(Object other) =>
      other is LanSyncPairingState &&
      other.status == status &&
      other.code == code &&
      other.peerId == peerId &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, code, peerId, failure);
}

/// 一次配对。状态：连接中 →（核对码）等本机确认 → 等对方确认 → 成功 / 失败；
/// 扫码配对没有核对码阶段。成功或失败之后不再变化，[respond] 不再有效果。
class LanSyncPairing {
  LanSyncPairing._({
    required this.incoming,
    required this._peerName,
    required this.platform,
    LanSyncPairingState initial = const LanSyncPairingState(
      LanSyncPairingStatus.connecting,
    ),
  }) : _state = ValueNotifier<LanSyncPairingState>(initial) {
    if (initial.isFinal) _finished.complete(initial);
  }

  /// 对方发起（本机被请求）为 true。
  final bool incoming;
  final String platform;
  String _peerName;
  final ValueNotifier<LanSyncPairingState> _state;
  final Completer<LanSyncPairingState> _finished =
      Completer<LanSyncPairingState>();
  Completer<bool>? _decision;
  bool _cancelled = false;
  void Function()? _onCancel;

  /// 对方的设备名（连接前取自信标或二维码，握手后换成对方自报的名字）。
  String get peerName => _peerName;

  ValueListenable<LanSyncPairingState> get state => _state;

  /// 成功或失败时完成。
  Future<LanSyncPairingState> get finished => _finished.future;

  /// 用户的决定：true 为“一致，配对”（只在等本机确认时有效）；false 为
  /// 不一致、取消或关掉面板——放弃这次配对。
  Future<void> respond(bool accept) async {
    final current = _state.value;
    if (current.isFinal) return;
    final decision = _decision;
    if (accept) {
      if (current.status == LanSyncPairingStatus.awaitingUser &&
          decision != null &&
          !decision.isCompleted) {
        _set(
          LanSyncPairingState(
            LanSyncPairingStatus.awaitingPeer,
            code: current.code,
          ),
        );
        decision.complete(true);
      }
      return;
    }
    _cancelled = true;
    if (decision != null && !decision.isCompleted) {
      decision.complete(false);
    } else {
      _onCancel?.call();
    }
  }

  /// 握手算出核对码：等本机用户决定。
  Future<bool> _awaitUser(String code, String peerName) {
    _peerName = peerName;
    final decision = _decision = Completer<bool>();
    _set(LanSyncPairingState(LanSyncPairingStatus.awaitingUser, code: code));
    return decision.future;
  }

  void _succeed(String peerId) =>
      _set(LanSyncPairingState(LanSyncPairingStatus.succeeded, peerId: peerId));

  void _fail(LanSyncFailure failure) =>
      _set(LanSyncPairingState(LanSyncPairingStatus.failed, failure: failure));

  void _set(LanSyncPairingState next) {
    if (_state.value.isFinal) return;
    _state.value = next;
    if (next.isFinal && !_finished.isCompleted) _finished.complete(next);
  }
}
