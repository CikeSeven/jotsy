// 握手之后的加密信道：在一条 TCP 连接上承载 JSON 控制消息与二进制数据块
// （docs/lan_sync.md §5.2）。
//
// 职责边界：
// - 输入：握手交给的套接字、帧读取器与两个方向的 [LanSyncFrameCipher]；
// - 输出：[messages]（控制消息）、[blobs]（数据块，每块自带字节流）、[done]；
// - 副作用：读写并最终销毁套接字。
//
// 帧明文的第一个字节是种类：
//   0x01 消息（最后一段） / 0x02 消息分段（后面还有）——大消息自动分段，单条上限
//        [kLanSyncMaxMessageBytes]；
//   0x10 数据块开始 [u32 id][u64 总长度] / 0x11 数据 [u32 id][字节…] /
//   0x12 结束 [u32 id] / 0x13 发送方放弃 [u32 id][UTF-8 原因]；
//   0x7f 关闭（经过认证的“正常结束”，与被截断的连接区分开）。
//
// 背压（为什么不会把整个文件读进内存）：
// - 发送：所有帧经一把写锁串行写出，每帧写完等 `flush`（操作系统收下数据）再写
//   下一帧；数据块按帧加锁，控制消息可以插在两帧数据之间；
// - 接收：分发循环一次只处理一帧。消息、数据块公告与每块的数据都经 [_Outlet]
//   交给消费者，消费者没监听或暂停时循环就停在那里，读取器缓冲满后暂停读套接字，
//   TCP 窗口收紧，对方的 flush 随之变慢。因此使用方必须一直监听 [messages] 与
//   [blobs]，并对每个收到的数据块要么读完 `data`、要么取消订阅（之后这块的剩余
//   数据被丢弃），否则整条信道会停住。
//
// 错误：认证失败（篡改、重放、乱序）、帧格式不对、对方没发关闭帧就断开，都会让
// 信道立即终止——两个流以 [LanSyncChannelException] 报错并结束，进行中的数据块
// 以同一错误结束，[done] 以它完成，套接字被销毁。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'lan_sync_channel_outlet.dart';
import 'lan_sync_crypto.dart';
import 'lan_sync_frames.dart';
import 'lan_sync_channel_types.dart';
import 'lan_sync_messages.dart';

export 'lan_sync_channel_types.dart';

part 'lan_sync_channel_inbound.dart';

abstract final class _Kind {
  static const int message = 0x01;
  static const int messagePart = 0x02;
  static const int blobBegin = 0x10;
  static const int blobData = 0x11;
  static const int blobEnd = 0x12;
  static const int blobAbort = 0x13;
  static const int close = 0x7f;
}

/// 一帧数据块的数据部分上限：明文上限减去种类与 id。
const int _blobChunkMax = kLanSyncFramePlaintextMax - 5;

class LanSyncChannel {
  /// 只由握手（lan_sync_handshake.dart）在派生出方向密钥后创建，测试也可直接
  /// 用固定密钥创建。握手阶段经 [receiveHandshakeMessage] 逐条读取，结束时调用
  /// [start] 开始分发。
  LanSyncChannel.establish({
    required Socket socket,
    required this._reader,
    required this._sendCipher,
    required this._receiveCipher,
    this.lingerTimeout = const Duration(seconds: 2),
  }) : _socket = socket {
    _messages = LanSyncOutlet<LanSyncMessage>(() => _terminated);
    _blobs = LanSyncOutlet<LanSyncBlob>(() => _terminated);
    // done 允许没人等待；错误仍会交给之后的等待者。
    _done.future.ignore();
    socket.done.ignore();
  }

  /// 关闭时等待对方收尾的最长时间（之后直接销毁套接字）。
  final Duration lingerTimeout;

  final Socket _socket;
  final LanSyncFrameReader _reader;
  final LanSyncFrameCipher _sendCipher;
  final LanSyncFrameCipher _receiveCipher;

  late final LanSyncOutlet<LanSyncMessage> _messages;
  late final LanSyncOutlet<LanSyncBlob> _blobs;
  final Map<int, _IncomingBlob> _incoming = {};
  final Set<int> _outgoing = {};
  final BytesBuilder _messageParts = BytesBuilder(copy: true);

  final Completer<void> _done = Completer<void>();
  final Completer<void> _terminatedSignal = Completer<void>();
  Future<void> _writeTail = Future<void>.value();
  Future<void>? _loop;

  /// close() 已被调用：之后的 send / sendBlob 立即失败。
  bool _closeRequested = false;

  /// 关闭帧已进入写锁：写锁里排在它之后的帧一律拒绝（排在它之前的照常写出）。
  bool _closing = false;
  bool _terminated = false;

  /// 对方发来的控制消息。正常关闭时结束，异常时先报 [LanSyncChannelException]。
  Stream<LanSyncMessage> get messages => _messages.stream;

  /// 对方发来的数据块。
  Stream<LanSyncBlob> get blobs => _blobs.stream;

  /// 信道终止时完成：正常关闭为值，异常为 [LanSyncChannelException]。
  Future<void> get done => _done.future;

  /// 是否已不能再发送（关闭中或已终止）。
  bool get isClosed => _closeRequested || _terminated;

  // ---------------------------------------------------------------------------
  // 发送
  // ---------------------------------------------------------------------------

  /// 发送一条控制消息（超过一帧时分段，分段之间不会插入其他消息）。
  Future<void> send(LanSyncMessage message) async {
    _ensureOpen();
    final bytes = message.encode();
    if (bytes.length > kLanSyncMaxMessageBytes) {
      throw ArgumentError.value(bytes.length, 'message', 'too large');
    }
    await _locked(() async {
      const max = kLanSyncFramePlaintextMax - 1;
      var offset = 0;
      do {
        final end = offset + max < bytes.length ? offset + max : bytes.length;
        final last = end == bytes.length;
        final plain = Uint8List(1 + end - offset)
          ..[0] = last ? _Kind.message : _Kind.messagePart
          ..setRange(1, 1 + end - offset, bytes, offset);
        await _writeFrame(plain);
        offset = end;
      } while (offset < bytes.length);
    });
  }

  /// 发送一个数据块：从 [data] 流式读取，正好 [length] 字节。
  ///
  /// 每写出一帧都等对方收下再从 [data] 取下一段（`await for` 会暂停源订阅），
  /// 不会把整个文件读进内存。源报错或长度不符时先告知对方放弃这一块再抛出，
  /// 信道本身照常可用。同一时刻不能有两个相同 [blobId] 的块在发送。
  Future<void> sendBlob(int blobId, Stream<List<int>> data, int length) async {
    if (blobId < 0 || blobId > 0xffffffff) {
      throw ArgumentError.value(blobId, 'blobId');
    }
    if (length < 0) throw ArgumentError.value(length, 'length');
    _ensureOpen();
    if (!_outgoing.add(blobId)) {
      throw StateError('blob $blobId is already being sent');
    }
    try {
      final begin = ByteData(13)
        ..setUint8(0, _Kind.blobBegin)
        ..setUint32(1, blobId)
        ..setUint32(5, length >> 32)
        ..setUint32(9, length & 0xffffffff);
      await _locked(() => _writeFrame(begin.buffer.asUint8List()));

      final chunk = Uint8List(5 + _blobChunkMax);
      ByteData.sublistView(chunk)
        ..setUint8(0, _Kind.blobData)
        ..setUint32(1, blobId);
      var filled = 0;
      var sent = 0;
      try {
        await for (final piece in data) {
          if (sent + filled + piece.length > length) {
            throw ArgumentError('blob $blobId is longer than $length bytes');
          }
          var offset = 0;
          while (offset < piece.length) {
            final n = _min(piece.length - offset, _blobChunkMax - filled);
            chunk.setRange(5 + filled, 5 + filled + n, piece, offset);
            filled += n;
            offset += n;
            if (filled == _blobChunkMax) {
              // seal 同步复制出密文，缓冲可以立即复用。
              await _locked(() => _writeFrame(chunk));
              sent += filled;
              filled = 0;
            }
          }
        }
        if (filled > 0) {
          await _locked(
            () => _writeFrame(Uint8List.sublistView(chunk, 0, 5 + filled)),
          );
          sent += filled;
        }
        if (sent != length) {
          throw ArgumentError('blob $blobId has $sent of $length bytes');
        }
      } catch (error) {
        if (error is! LanSyncChannelException && !isClosed) {
          await _abortBlob(blobId, error.toString());
        }
        rethrow;
      }
      final end = ByteData(5)
        ..setUint8(0, _Kind.blobEnd)
        ..setUint32(1, blobId);
      await _locked(() => _writeFrame(end.buffer.asUint8List()));
    } finally {
      _outgoing.remove(blobId);
    }
  }

  Future<void> _abortBlob(int blobId, String reason) async {
    final text = utf8.encode(reason);
    final cut = text.length > 1024 ? text.sublist(0, 1024) : text;
    final plain = Uint8List(5 + cut.length);
    ByteData.sublistView(plain)
      ..setUint8(0, _Kind.blobAbort)
      ..setUint32(1, blobId);
    plain.setRange(5, plain.length, cut);
    try {
      await _locked(() => _writeFrame(plain));
    } on LanSyncChannelException {
      // 信道已终止：对方的这一块会随信道一起报错，无需再告知。
    }
  }

  /// 正常关闭：发出关闭帧，结束两个流，等对方收尾（最多 [lingerTimeout]）后
  /// 销毁套接字。重复调用返回同一个 [done]。
  Future<void> close() async {
    if (_closeRequested || _terminated) return done.catchError((_) {});
    _closeRequested = true;
    try {
      // 排在写锁里、早于 close 调用的发送先写完，再写关闭帧。
      await _locked(() {
        _closing = true;
        return _writeFrame(const [_Kind.close], allowClosing: true);
      });
    } on LanSyncChannelException {
      return done.catchError((_) {});
    }
    _terminate(null, destroySocket: false);
    // 读完对方已发来的字节再销毁，避免带着未读数据关闭触发 RST。
    final loop = _loop;
    if (loop != null) {
      await loop.timeout(lingerTimeout, onTimeout: () {});
    } else {
      await _reader.drain(lingerTimeout);
    }
    _destroySocket();
  }

  /// 立即断开，不发关闭帧（握手失败、会话层超时等）。对方会看到连接断开。
  void destroy() {
    _terminate(
      const LanSyncChannelException(LanSyncChannelError.closed, 'destroyed'),
    );
  }

  void _ensureOpen() {
    if (isClosed) {
      throw const LanSyncChannelException(LanSyncChannelError.closed);
    }
  }

  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _writeTail.then((_) => body());
    _writeTail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _writeFrame(List<int> plaintext, {bool allowClosing = false}) {
    if (_terminated || (_closing && !allowClosing)) {
      throw const LanSyncChannelException(LanSyncChannelError.closed);
    }
    _socket.add(_sendCipher.seal(plaintext));
    return _flush();
  }

  Future<void> _flush() async {
    final flush = _socket.flush();
    flush.ignore();
    try {
      await Future.any<Object?>([flush, _terminatedSignal.future]);
    } on Object catch (error) {
      const failure = LanSyncChannelException(
        LanSyncChannelError.connectionLost,
      );
      _terminate(failure);
      if (error is SocketException || error is StateError) throw failure;
      rethrow;
    }
    if (_terminated && !_closing) {
      throw const LanSyncChannelException(LanSyncChannelError.closed);
    }
  }

  // ---------------------------------------------------------------------------
  // 接收
  // ---------------------------------------------------------------------------

  /// 握手阶段读取一条单帧消息（只供握手在 [start] 之前使用）。超时抛
  /// [TimeoutException]，其余失败抛 [LanSyncChannelException]，失败时信道已终止。
  Future<LanSyncMessage> receiveHandshakeMessage(Duration timeout) async {
    try {
      final plain = await _readPlain().timeout(timeout);
      if (plain.isNotEmpty && plain[0] == _Kind.close) {
        throw const LanSyncChannelException(
          LanSyncChannelError.closed,
          'peer closed during the handshake',
        );
      }
      if (plain.isEmpty || plain[0] != _Kind.message) {
        throw const FormatException('expected a single-frame message');
      }
      return LanSyncMessage.decode(Uint8List.sublistView(plain, 1));
    } on TimeoutException {
      rethrow;
    } catch (error) {
      final failure = _mapReceiveError(error);
      _terminate(failure);
      throw failure;
    }
  }

  /// 开始分发（握手成功后由握手调用一次）。
  void start() {
    _loop ??= _run();
  }

  Future<Uint8List> _readPlain() async {
    final body = await _reader.next(
      maxLength: kLanSyncFramePlaintextMax + kLanSyncTagBytes,
    );
    if (body == null) {
      throw const LanSyncChannelException(
        LanSyncChannelError.connectionLost,
        'connection ended without a close frame',
      );
    }
    return _receiveCipher.open(body);
  }

  Future<void> _run() async {
    try {
      while (!_terminated) {
        final plain = await _readPlain();
        if (_terminated) break;
        if (plain.isEmpty) throw const FormatException('empty frame');
        if (plain[0] == _Kind.close) {
          _terminate(null);
          return;
        }
        await _dispatch(plain);
      }
    } catch (error) {
      // 本机已关闭后（close 的收尾阶段）读到的任何结果都不再重要。
      if (!_terminated) _terminate(_mapReceiveError(error));
    }
  }

  // ---------------------------------------------------------------------------
  // 终止
  // ---------------------------------------------------------------------------

  /// 结束信道：[error] 为 null 是正常关闭。流与进行中的数据块随之结束，等待中
  /// 的分发与发送被唤醒（它们看到 `_terminated` 后放弃）。
  void _terminate(LanSyncChannelException? error, {bool destroySocket = true}) {
    if (_terminated) return;
    _terminated = true;
    _terminatedSignal.complete();
    final blobError =
        error ?? const LanSyncChannelException(LanSyncChannelError.closed);
    for (final blob in _incoming.values) {
      blob.outlet.finish(blobError);
    }
    _incoming.clear();
    _messages.finish(error);
    _blobs.finish(error);
    if (error == null) {
      _done.complete();
    } else {
      _done.completeError(error);
    }
    if (destroySocket) _destroySocket();
  }

  void _destroySocket() {
    _socket.destroy();
    unawaited(_reader.cancel());
  }
}

int _min(int a, int b) => a < b ? a : b;
