// 核对码配对的确认阶段：本机用户的决定与对方的 pair.confirm / pair.reject
// 谁先到都可以，凑齐两个确认才算配对成功。
//
// 状态：等待（本机、对方都未决定）→ 一方确认（继续等另一方）→ 两方确认（成功）；
// 任一方拒绝、对方断开或计时器到期即失败。计时器在 [_confirmSas] 返回或抛出时
// 取消；之后晚到的本机回调结果与对方消息被丢弃（事件控制器已关闭）。
part of 'lan_sync_handshake.dart';

extension _SasConfirmation on _Run {
  /// 核对码确认：本机用户的决定与对方的决定谁先到都可以；两边都确认才成功。
  ///
  /// 任一方拒绝即失败（本机拒绝时先告知对方）；[LanSyncHandshake.sasTimeout]
  /// 内没有凑齐两个确认即超时。失败时本机回调可能仍在等待用户——调用方随握手
  /// 失败关掉核对码界面即可，回调之后的结果被忽略。
  ///
  /// 两边都发出确认后，若最后一条消息在途中丢失，可能一边成功、一边超时（两军
  /// 问题，无法完全避免）；成功的一边之后同步时会被对方以 untrusted 拒绝，界面
  /// 提示重新配对。
  Future<void> _confirmSas(
    String code,
    LanSyncPeerHello peer,
    LanSyncSasConfirm confirm,
  ) async {
    final channel = this.channel!;
    final events = StreamController<_SasEvent>();
    // 失败退出后另一个来源仍可能晚到：控制器已关闭就丢弃。
    void emit(_SasEvent event) {
      if (!events.isClosed) events.add(event);
    }

    Future.sync(() => confirm(code, peer)).then(
      (ok) => emit(_SasLocal(ok)),
      onError: (Object error) => emit(_SasLocalFailed(error)),
    );
    // 读对方决定的超时比整体超时多一步，保证总是下面的计时器先到、先告知对方。
    channel
        .receiveHandshakeMessage(config.sasTimeout + config.stepTimeout)
        .then(
          (message) => emit(_SasRemote(message)),
          onError: (Object error) => emit(_SasRemoteFailed(error)),
        );
    final timer = Timer(config.sasTimeout, () => emit(const _SasExpired()));
    var localConfirmed = false;
    var remoteConfirmed = false;
    try {
      await for (final event in events.stream) {
        switch (event) {
          case _SasLocal(ok: true):
            localConfirmed = true;
            await channel.send(LanSyncMessage(LanSyncMessageTypes.pairConfirm));
          case _SasLocal(ok: false):
            await _reject(LanSyncHandshakeFailure.sasRejected, pairing: true);
          case _SasLocalFailed(:final error):
            await _sendRejectQuietly(
              LanSyncHandshakeFailure.sasRejected,
              pairing: true,
            );
            throw LanSyncHandshakeException(
              LanSyncHandshakeFailure.sasRejected,
              peer: peer,
              detail: 'confirmSas failed: $error',
            );
          case _SasRemote(:final message):
            _throwIfRejected(message);
            if (message.type != LanSyncMessageTypes.pairConfirm) {
              throw FormatException(
                'expected pair.confirm, got ${message.type}',
              );
            }
            remoteConfirmed = true;
          case _SasRemoteFailed(:final error):
            throw error;
          case _SasExpired():
            await _reject(LanSyncHandshakeFailure.timeout, pairing: true);
        }
        if (localConfirmed && remoteConfirmed) return;
      }
    } finally {
      timer.cancel();
      unawaited(events.close());
    }
  }
}

sealed class _SasEvent {
  const _SasEvent();
}

final class _SasLocal extends _SasEvent {
  const _SasLocal(this.ok);
  final bool ok;
}

final class _SasLocalFailed extends _SasEvent {
  const _SasLocalFailed(this.error);
  final Object error;
}

final class _SasRemote extends _SasEvent {
  const _SasRemote(this.message);
  final LanSyncMessage message;
}

final class _SasRemoteFailed extends _SasEvent {
  const _SasRemoteFailed(this.error);
  final Object error;
}

final class _SasExpired extends _SasEvent {
  const _SasExpired();
}
