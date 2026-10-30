// 接收侧的帧分拣：把解密后的明文帧按种类交给消息流、数据块公告与各块的字节
// 流（帧格式见 lan_sync_channel.dart 顶部）。
//
// 每一帧都经 [LanSyncOutlet.push] 交付，消费者没在读时在这里等待，形成接收侧
// 背压。任何越界（未知种类、未公告的块、长度超出声明、提前结束）都抛
// FormatException，由分发循环当作协议错误终止信道。
part of 'lan_sync_channel.dart';

class _IncomingBlob {
  _IncomingBlob(this.length, this.outlet);

  final int length;
  final LanSyncOutlet<Uint8List> outlet;
  int received = 0;
}

extension _Inbound on LanSyncChannel {
  Future<void> _dispatch(Uint8List plain) async {
    final kind = plain[0];
    switch (kind) {
      case _Kind.message:
      case _Kind.messagePart:
        if (_messageParts.length + plain.length - 1 > kLanSyncMaxMessageBytes) {
          throw const FormatException('message too large');
        }
        _messageParts.add(Uint8List.sublistView(plain, 1));
        if (kind == _Kind.message) {
          final message = LanSyncMessage.decode(_messageParts.takeBytes());
          await _messages.push(message);
        }
      case _Kind.blobBegin:
        if (plain.length != 13) throw const FormatException('bad blob begin');
        final view = ByteData.sublistView(plain);
        final id = view.getUint32(1);
        final length = view.getUint32(5) * 0x100000000 + view.getUint32(9);
        if (_incoming.containsKey(id)) {
          throw FormatException('blob $id started twice');
        }
        final outlet = LanSyncOutlet<Uint8List>(() => _terminated);
        _incoming[id] = _IncomingBlob(length, outlet);
        await _blobs.push(LanSyncBlob(id, length, outlet.stream));
      case _Kind.blobData:
        final blob = _blobFor(plain);
        final data = Uint8List.sublistView(plain, 5);
        blob.received += data.length;
        if (blob.received > blob.length) {
          throw const FormatException('blob longer than announced');
        }
        await blob.outlet.push(data);
      case _Kind.blobEnd:
        final blob = _blobFor(plain);
        if (plain.length != 5 || blob.received != blob.length) {
          throw const FormatException('blob ended early');
        }
        _incoming.remove(ByteData.sublistView(plain).getUint32(1));
        blob.outlet.finish();
      case _Kind.blobAbort:
        final blob = _blobFor(plain);
        _incoming.remove(ByteData.sublistView(plain).getUint32(1));
        final reason = utf8.decode(
          Uint8List.sublistView(plain, 5),
          allowMalformed: true,
        );
        blob.outlet.finish(
          LanSyncChannelException(LanSyncChannelError.blobAborted, reason),
        );
      default:
        throw FormatException('unknown frame kind $kind');
    }
  }

  _IncomingBlob _blobFor(Uint8List plain) {
    if (plain.length < 5) throw const FormatException('bad blob frame');
    final id = ByteData.sublistView(plain).getUint32(1);
    final blob = _incoming[id];
    if (blob == null) throw FormatException('unknown blob $id');
    return blob;
  }

  LanSyncChannelException _mapReceiveError(Object error) {
    return switch (error) {
      LanSyncChannelException() => error,
      LanSyncAuthenticationException() => const LanSyncChannelException(
        LanSyncChannelError.authenticationFailed,
      ),
      LanSyncFrameException(error: LanSyncFrameError.invalidLength) =>
        const LanSyncChannelException(
          LanSyncChannelError.protocolError,
          'invalid frame length',
        ),
      LanSyncFrameException() => LanSyncChannelException(
        LanSyncChannelError.connectionLost,
        '$error',
      ),
      FormatException(:final message) => LanSyncChannelException(
        LanSyncChannelError.protocolError,
        message,
      ),
      _ => LanSyncChannelException(
        LanSyncChannelError.connectionLost,
        '$error',
      ),
    };
  }
}
