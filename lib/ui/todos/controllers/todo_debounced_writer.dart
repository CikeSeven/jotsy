import 'dart:async';

/// 输入防抖（非动画计时）：详情页的标题 / 备注写库与搜索页的查询共用。
///
/// [schedule] 记下最新的值并重新计时，[delay] 内没有新输入才交给 [onFire]；
/// [flush] 立即交出还没交出的值（离开页面时用），[cancel] 丢掉它（删除这条
/// 待办时，不再写回）。[pending] 为 true 表示有值还没交出——页面据此判断能否
/// 用外部的新值覆盖输入框。
class TodoDebouncedWriter<T> {
  TodoDebouncedWriter({required this.onFire, this.delay = defaultDelay});

  /// 写库的防抖时长。
  static const Duration defaultDelay = Duration(milliseconds: 400);

  /// 搜索的防抖时长：逐字查询没必要，但要跟手。
  static const Duration searchDelay = Duration(milliseconds: 200);

  final void Function(T value) onFire;
  final Duration delay;
  Timer? _timer;
  T? _value;

  bool get pending => _timer != null;

  void schedule(T value) {
    _value = value;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  void flush() {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    onFire(_value as T);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
