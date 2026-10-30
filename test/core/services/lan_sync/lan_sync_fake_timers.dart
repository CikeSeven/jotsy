import 'dart:async';

/// 可手动推进的时钟与计时器：[advance] 按到期时间顺序触发计时器，期间
/// [now] 跟着前进。不涉及真实等待。
class FakeTimers {
  FakeTimers([DateTime? start]) : _now = start ?? DateTime.utc(2026, 10, 1);

  DateTime _now;
  final List<_FakeTimer> _pending = [];

  DateTime now() => _now;

  Timer create(Duration duration, void Function() callback) {
    final timer = _FakeTimer(this, _now.add(duration), callback);
    _pending.add(timer);
    return timer;
  }

  /// 前进 [duration]，按顺序触发其间到期的计时器（回调里新建的也算）。
  void advance(Duration duration) {
    final target = _now.add(duration);
    while (true) {
      _pending.sort((a, b) => a.due.compareTo(b.due));
      final next = _pending.isEmpty ? null : _pending.first;
      if (next == null || next.due.isAfter(target)) break;
      _pending.remove(next);
      _now = next.due;
      next.callback();
    }
    _now = target;
  }

  int get pendingCount => _pending.length;
}

class _FakeTimer implements Timer {
  _FakeTimer(this._owner, this.due, this.callback);

  final FakeTimers _owner;
  final DateTime due;
  final void Function() callback;

  @override
  void cancel() => _owner._pending.remove(this);

  @override
  bool get isActive => _owner._pending.contains(this);

  @override
  int get tick => 0;
}
