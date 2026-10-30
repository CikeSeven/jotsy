import 'dart:async';
import 'dart:typed_data';

import 'package:node_diary/core/services/lan_sync/lan_sync_channel.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_messages.dart';

/// 内存里的一对“已建立的信道”，供会话状态机测试使用（真实信道的端到端
/// 行为由服务的回环测试覆盖）。
///
/// 语义与 [LanSyncChannel] 对齐到会话用得到的程度：消息经 JSON 往返一次再
/// 交给对方；数据块以字节流交付；[close] 让对方的两个流正常结束，[destroy]
/// 与注入的断线让双方的流以 `connectionLost` 报错。
///
/// 注入点：
/// - [onSend]：每条消息发出之前回调（可在这里取消会话）；
/// - [killBefore]：返回 true 时不发这条消息，直接断线；
/// - [killAfter]：这条消息照常送达后立即断线；
/// - [killAfterBlobBytes]：发送数据块累计到这么多字节时断线。
class FakeLanSyncChannel implements LanSyncChannel {
  FakeLanSyncChannel._(this.label);

  /// (发起方一端, 响应方一端)。
  static (FakeLanSyncChannel, FakeLanSyncChannel) pair() {
    final a = FakeLanSyncChannel._('initiator');
    final b = FakeLanSyncChannel._('responder');
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  final String label;
  late FakeLanSyncChannel _peer;
  final StreamController<LanSyncMessage> _messages =
      StreamController<LanSyncMessage>();
  final StreamController<LanSyncBlob> _blobs = StreamController<LanSyncBlob>();
  final Completer<void> _done = Completer<void>();
  final List<StreamController<Uint8List>> _openBlobs = [];
  bool _closed = false;
  bool _terminated = false;

  void Function(LanSyncMessage message)? onSend;
  bool Function(LanSyncMessage message)? killBefore;
  bool Function(LanSyncMessage message)? killAfter;
  int? killAfterBlobBytes;

  /// 发出的消息类型（按顺序）与数据块个数。
  final List<String> sentTypes = <String>[];
  int blobsSent = 0;
  int _blobBytes = 0;

  bool get terminated => _terminated;

  @override
  Duration get lingerTimeout => Duration.zero;

  @override
  Stream<LanSyncMessage> get messages => _messages.stream;

  @override
  Stream<LanSyncBlob> get blobs => _blobs.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => _closed || _terminated;

  @override
  Future<void> send(LanSyncMessage message) async {
    _ensureOpen();
    onSend?.call(message);
    _ensureOpen();
    if (killBefore?.call(message) ?? false) {
      _kill();
      throw const LanSyncChannelException(LanSyncChannelError.connectionLost);
    }
    sentTypes.add(message.type);
    final copy = LanSyncMessage.decode(message.encode());
    await Future<void>.delayed(Duration.zero);
    if (_terminated) {
      throw const LanSyncChannelException(LanSyncChannelError.connectionLost);
    }
    if (!_peer._terminated && !_peer._messages.isClosed) {
      _peer._messages.add(copy);
    }
    if (killAfter?.call(message) ?? false) _kill();
  }

  @override
  Future<void> sendBlob(int blobId, Stream<List<int>> data, int length) async {
    _ensureOpen();
    blobsSent++;
    final controller = StreamController<Uint8List>();
    _peer._openBlobs.add(controller);
    if (!_peer._terminated) {
      _peer._blobs.add(LanSyncBlob(blobId, length, controller.stream));
    }
    await for (final chunk in data) {
      final limit = killAfterBlobBytes;
      if (limit != null && _blobBytes + chunk.length > limit) {
        _kill();
        throw const LanSyncChannelException(LanSyncChannelError.connectionLost);
      }
      if (_terminated) {
        throw const LanSyncChannelException(LanSyncChannelError.closed);
      }
      _blobBytes += chunk.length;
      controller.add(Uint8List.fromList(chunk));
      await Future<void>.delayed(Duration.zero);
    }
    _peer._openBlobs.remove(controller);
    await controller.close();
  }

  @override
  Future<void> close() async {
    if (_closed || _terminated) return;
    _closed = true;
    await Future<void>.delayed(Duration.zero);
    _finish(this, null);
    _finish(_peer, null);
  }

  @override
  void destroy() => _kill();

  @override
  Future<LanSyncMessage> receiveHandshakeMessage(Duration timeout) =>
      throw UnimplementedError();

  @override
  void start() {}

  void _ensureOpen() {
    if (isClosed) {
      throw const LanSyncChannelException(LanSyncChannelError.closed);
    }
  }

  void _kill() {
    const error = LanSyncChannelException(LanSyncChannelError.connectionLost);
    _finish(this, error);
    _finish(_peer, error);
  }

  static void _finish(FakeLanSyncChannel side, Object? error) {
    if (side._terminated) return;
    side._terminated = true;
    final blobError =
        error ?? const LanSyncChannelException(LanSyncChannelError.closed);
    for (final blob in side._openBlobs) {
      if (!blob.isClosed) {
        blob.addError(blobError);
        unawaited(blob.close());
      }
    }
    side._openBlobs.clear();
    if (error != null) {
      side._messages.addError(error);
      side._blobs.addError(error);
    }
    unawaited(side._messages.close());
    unawaited(side._blobs.close());
    if (error == null) {
      side._done.complete();
    } else {
      side._done.completeError(error);
      side._done.future.ignore();
    }
  }
}
