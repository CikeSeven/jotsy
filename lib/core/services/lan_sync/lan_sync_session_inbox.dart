// 会话收件箱：一直监听信道的消息流与数据块流，按到达顺序排队供会话取用。
part of 'lan_sync_session.dart';

/// 为什么要一直监听：信道的接收侧背压规定消费者从不停听——没人听消息流，
/// 分发循环就停住，后面的数据块也到不了（docs §5.2）。所以会话一开始就订阅
/// 两个流，消息先进队列，会话按自己的节奏 [next]。
///
/// - `sync.ping` 只重置静默计时，不入队；
/// - `sync.abort` 记为对方中止 [peerStop]，之后的等待立即以它失败；
/// - 信道报错或结束（对方没发 done / abort 就断开）记为连接断开；已排队的
///   消息仍按顺序交出（对方发完 `sync.done` 就关闭信道是正常结束）；
/// - 对方中止或本机取消则立即生效：排队的与之后到达的消息一律不再交出——
///   中止之后还照着排队的 `sync.apply` 写库就违背了中止的本意；
/// - 数据块按 id 暂存、不监听它的字节流：信道会停在这一块上，直到会话取用
///   它。宣告它的消息先于它到达，会话总能先读到那条消息再来取块，不会互相
///   等待；收件箱停止或释放时，没取用的块一律取消（剩余数据被丢弃）。
///
/// 静默计时：只在有等待者时计时，任何消息、ping 或数据块到达都把计时器重新
/// 拨满；到点即以 TimeoutException 唤醒等待者。
class _SessionInbox {
  _SessionInbox(LanSyncChannel channel) {
    _messages = channel.messages.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );
    _blobs = channel.blobs.listen(_onBlob, onError: _onError, onDone: _onDone);
  }

  late final StreamSubscription<LanSyncMessage> _messages;
  late final StreamSubscription<LanSyncBlob> _blobs;
  final Queue<LanSyncMessage> _queue = Queue<LanSyncMessage>();
  final Map<int, LanSyncBlob> _pendingBlobs = <int, LanSyncBlob>{};
  final Completer<void> _stoppedSignal = Completer<void>();
  Object? _stopped;
  Completer<void>? _waiter;
  Timer? _silenceTimer;
  Duration _silence = Duration.zero;
  bool _disposed = false;

  /// 对方发来的中止（原因已换算成本机的失败原因）。
  _SessionStop? peerStop;

  /// 收件箱停止（对方中止、断开、本机取消）时完成。
  Future<void> get whenStopped => _stoppedSignal.future;

  /// 下一条消息（已排队的先交出）。
  Future<LanSyncMessage> next(Duration silence) async {
    while (true) {
      if (_stopped is _SessionStop) throwIfStopped();
      if (_queue.isNotEmpty) return _queue.removeFirst();
      throwIfStopped();
      await _wait(silence);
    }
  }

  /// 取出 id 为 [id] 的数据块（还没到时等它）。
  Future<LanSyncBlob> blob(int id, Duration silence) async {
    while (true) {
      final blob = _pendingBlobs.remove(id);
      if (blob != null) return blob;
      throwIfStopped();
      await _wait(silence);
    }
  }

  /// 以 [stop] 停止：唤醒等待者，之后的等待立即失败。只记第一次的原因。
  void fail(Object stop) {
    _stopped ??= stop;
    if (_stopped is _SessionStop) _queue.clear();
    if (!_stoppedSignal.isCompleted) _stoppedSignal.complete();
    _cancelPendingBlobs();
    _wake();
  }

  void throwIfStopped() {
    final stopped = _stopped;
    if (stopped != null) throw stopped;
  }

  /// 会话结束（信道已关闭）后释放。
  void dispose() {
    _disposed = true;
    _silenceTimer?.cancel();
    _cancelPendingBlobs();
    unawaited(_messages.cancel());
    unawaited(_blobs.cancel());
  }

  void _onMessage(LanSyncMessage message) {
    _touch();
    if (message.type == LanSyncSessionMessages.ping) return;
    if (message.type == LanSyncSessionMessages.abort) {
      final stop = _SessionStop(
        lanSyncFailureFromPeerAbort(message.fields['reason']),
      );
      peerStop ??= stop;
      fail(stop);
      return;
    }
    if (_stopped is _SessionStop) return;
    _queue.add(message);
    _wake();
  }

  void _onBlob(LanSyncBlob blob) {
    _touch();
    if (_disposed || _stopped != null) {
      _discard(blob);
      return;
    }
    _pendingBlobs[blob.id] = blob;
    _wake();
  }

  void _onError(Object error) {
    fail(
      error is LanSyncChannelException
          ? error
          : LanSyncChannelException(
              LanSyncChannelError.connectionLost,
              '$error',
            ),
    );
  }

  void _onDone() => fail(
    const LanSyncChannelException(LanSyncChannelError.closed, 'peer closed'),
  );

  Future<void> _wait(Duration silence) {
    final waiter = _waiter = Completer<void>();
    _silence = silence;
    _arm();
    return waiter.future.whenComplete(() {
      _silenceTimer?.cancel();
      if (identical(_waiter, waiter)) _waiter = null;
    });
  }

  void _touch() {
    if (_waiter != null) _arm();
  }

  void _arm() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silence, () {
      final waiter = _waiter;
      if (waiter != null && !waiter.isCompleted) {
        waiter.completeError(TimeoutException('peer silent', _silence));
      }
    });
  }

  void _wake() {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _cancelPendingBlobs() {
    for (final blob in _pendingBlobs.values) {
      _discard(blob);
    }
    _pendingBlobs.clear();
  }
}

/// 取消一个数据块的字节流（之后这块的剩余数据被信道丢弃）。已经被监听过的
/// 流再监听会抛 StateError：那说明已有人在读，忽略即可。
void _discard(LanSyncBlob blob) {
  try {
    unawaited(blob.data.listen(null, onError: (Object _) {}).cancel());
  } on StateError {
    // 已经在读。
  }
}
