// 信道交付数据给消费者的出口：消费者没有监听或已暂停时，生产者在 [push] 处
// 等待，而不是把收到的帧堆在内存里（docs/lan_sync.md §5.2 的接收侧背压）。
//
// 状态：未监听 / 暂停 → push 等待；监听中 → 立即交付；消费者取消 → 之后的值
// 直接丢弃（push 返回 false，生产者照常前进）；finish 或信道终止 → 唤醒等待者，
// 之后的值同样丢弃。
import 'dart:async';

class LanSyncOutlet<T> {
  /// [isTerminated] 是所属信道的终止状态：终止后等待中的 push 立即放弃。
  LanSyncOutlet(this._isTerminated) {
    _controller = StreamController<T>(
      onListen: _wake,
      onResume: _wake,
      onCancel: () {
        _cancelled = true;
        _wake();
      },
    );
  }

  final bool Function() _isTerminated;
  late final StreamController<T> _controller;
  bool _cancelled = false;
  bool _finished = false;
  Completer<void>? _signal;

  /// 只能监听一次。
  Stream<T> get stream => _controller.stream;

  bool get _gone => _cancelled || _finished || _isTerminated();

  /// 交给消费者；等到消费者在听且没有暂停。值被丢弃时返回 false。
  Future<bool> push(T value) async {
    while (!_gone && (!_controller.hasListener || _controller.isPaused)) {
      final signal = _signal = Completer<void>();
      await signal.future;
    }
    if (_gone) return false;
    _controller.add(value);
    return true;
  }

  /// 结束这个出口：[error] 非空时先报错再结束。重复调用无效。
  void finish([Object? error]) {
    if (_finished) return;
    _finished = true;
    if (error != null && !_cancelled) _controller.addError(error);
    unawaited(_controller.close());
    _wake();
  }

  void _wake() {
    final signal = _signal;
    _signal = null;
    signal?.complete();
  }
}
