// 局域网同步的长度前缀帧：`[u32 大端长度][载荷]`（握手的明文帧与之后的密文帧
// 共用同一格式，docs/lan_sync.md §5.2）。
//
// 职责边界：
// - 输入：套接字的字节流（单订阅）；
// - 输出：按需拉取的一帧帧载荷；
// - 副作用：持有并在需要时暂停 / 恢复对字节流的订阅（背压），cancel 时取消订阅。
//
// 为什么是“拉取”：握手阶段逐条等待对方消息（各自有超时），握手结束后信道的
// 分发循环沿用同一个读取器继续读，缓冲里已到达的字节不会丢失；读取方不来取
// 时缓冲到上限即暂停订阅，TCP 窗口随之收紧，发送方的 flush 自然变慢。
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

/// 握手明文帧的上限：hello 等消息都是几百字节的 JSON。
const int kLanSyncHandshakeFrameMax = 8 * 1024;

/// 信道一帧的明文上限（64 KiB）。
const int kLanSyncFramePlaintextMax = 64 * 1024;

/// 读取帧时的错误。
enum LanSyncFrameError {
  /// 帧长度为 0 或超过允许的上限（不分配缓冲就拒绝）。
  invalidLength,

  /// 对方在一帧中间断开。
  truncated,

  /// 字节流本身报错（连接被重置等）。
  connectionError,
}

class LanSyncFrameException implements Exception {
  const LanSyncFrameException(this.error, [this.cause]);

  final LanSyncFrameError error;
  final Object? cause;

  @override
  String toString() => 'LanSyncFrameException(${error.name}, $cause)';
}

/// 一帧的明文长度前缀（握手帧用；密文帧由 [LanSyncFrameCipher.seal] 产出整帧）。
Uint8List lanSyncPlainFrame(List<int> payload) {
  final frame = Uint8List(4 + payload.length);
  ByteData.sublistView(frame, 0, 4).setUint32(0, payload.length);
  frame.setRange(4, frame.length, payload);
  return frame;
}

/// 从字节流里按需拉取长度前缀帧。
///
/// 正常情况下同一时刻只有一个 [next] 在等待（握手与信道都是单读取者）；关闭
/// 收尾时 [drain] 可能与一个仍在等待的 [next] 并存，因此等待者是一个列表，
/// 每次有新字节、出错、结束或取消时全部唤醒，各自重新检查条件。
class LanSyncFrameReader {
  LanSyncFrameReader(Stream<Uint8List> source) {
    _subscription = source.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  /// 缓冲超过这个字节数就暂停订阅，约为几帧的量。
  static const int _highWater = 256 * 1024;

  late final StreamSubscription<Uint8List> _subscription;
  final Queue<Uint8List> _chunks = Queue<Uint8List>();
  int _buffered = 0;
  bool _done = false;
  bool _cancelled = false;
  Object? _error;
  final List<Completer<void>> _waiters = [];

  void _onData(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _chunks.add(chunk);
    _buffered += chunk.length;
    if (_buffered >= _highWater && !_subscription.isPaused) {
      _subscription.pause();
    }
    _wake();
  }

  void _onError(Object error) {
    _error = error;
    _done = true;
    _wake();
  }

  void _onDone() {
    _done = true;
    _wake();
  }

  void _wake() {
    if (_waiters.isEmpty) return;
    final waiters = List.of(_waiters);
    _waiters.clear();
    for (final waiter in waiters) {
      waiter.complete();
    }
  }

  Future<void> _wait() {
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  /// 读下一帧的载荷。对方在帧边界正常关闭时返回 null；载荷长度为 0 或超过
  /// [maxLength]、帧被截断、字节流报错时抛 [LanSyncFrameException]。
  Future<Uint8List?> next({required int maxLength}) async {
    if (!await _fill(4)) {
      if (_buffered == 0 && _error == null) return null;
      throw _endError();
    }
    final length = ByteData.sublistView(_peek(4)).getUint32(0);
    if (length == 0 || length > maxLength) {
      throw LanSyncFrameException(LanSyncFrameError.invalidLength, length);
    }
    if (!await _fill(4 + length)) throw _endError();
    _take(4);
    return _take(length);
  }

  LanSyncFrameException _endError() {
    final error = _error;
    return error == null
        ? const LanSyncFrameException(LanSyncFrameError.truncated)
        : LanSyncFrameException(LanSyncFrameError.connectionError, error);
  }

  /// 等到缓冲至少有 [count] 字节；字节流结束仍不够时返回 false。
  Future<bool> _fill(int count) async {
    while (_buffered < count) {
      if (_done || _cancelled) return false;
      if (_subscription.isPaused) _subscription.resume();
      await _wait();
    }
    return true;
  }

  Uint8List _peek(int count) {
    final first = _chunks.first;
    if (first.length >= count) return Uint8List.sublistView(first, 0, count);
    final out = Uint8List(count);
    var offset = 0;
    for (final chunk in _chunks) {
      final n = min(count - offset, chunk.length);
      out.setRange(offset, offset + n, chunk);
      offset += n;
      if (offset == count) break;
    }
    return out;
  }

  Uint8List _take(int count) {
    final first = _chunks.first;
    late final Uint8List out;
    if (first.length == count) {
      out = _chunks.removeFirst();
    } else if (first.length > count) {
      out = Uint8List.sublistView(first, 0, count);
      _chunks
        ..removeFirst()
        ..addFirst(Uint8List.sublistView(first, count));
    } else {
      out = Uint8List(count);
      var offset = 0;
      while (offset < count) {
        final chunk = _chunks.removeFirst();
        final n = count - offset;
        if (chunk.length <= n) {
          out.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        } else {
          out.setRange(offset, count, chunk);
          _chunks.addFirst(Uint8List.sublistView(chunk, n));
          offset = count;
        }
      }
    }
    _buffered -= count;
    if (_buffered < _highWater && _subscription.isPaused && !_done) {
      _subscription.resume();
    }
    return out;
  }

  /// 丢弃缓冲直到对方关闭或超时（发送拒绝 / 关闭帧之后用）：读完对方已发来的
  /// 字节再关闭，避免本机带着未读数据关闭套接字触发 RST、让对方丢掉我们的
  /// 最后一条消息。
  Future<void> drain(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (!_done && !_cancelled) {
      _chunks.clear();
      _buffered = 0;
      if (_subscription.isPaused) _subscription.resume();
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) return;
      try {
        await _wait().timeout(left);
      } on TimeoutException {
        return;
      }
    }
  }

  /// 取消订阅；之后的 [next] 视为字节流结束。
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _wake();
    await _subscription.cancel();
  }
}
