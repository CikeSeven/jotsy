// 前台自动同步的触发、去抖、节流与双向重试（docs/lan_sync.md §9）。
//
// 职责边界：纯调度逻辑——时钟与计时器注入，不碰网络与数据库。
// - 输入：触发事件（已配对设备上线、应用回到前台、本机数据变化、编辑结束）
//   与服务提供的判断（能否与某台自动同步、是否正忙、是否在编辑、在线的设备）；
// - 输出：调用 [LanSyncAutoScheduler.start] 发起一次自动同步；
// - 副作用：只有计时器。
//
// 规则：
// - 谁发起：deviceId 较小的一方立即发起；较大的一方等 [LanSyncAutoTimings
//   .mutualRetry]，期间没有任何与对方的会话到达才自己发起——两边同时触发时
//   通常只有一次会话，而某个方向被防火墙拦住时另一个方向仍能同步；
// - 节流：同一台设备两次自动同步至少相隔 [LanSyncAutoTimings.rateLimit]
//   （两个方向合计），没到时间就排到时间到了再试；较大的一方到点后仍先等
//   对方发起（两边的节流常同时到期，同时发起会互相以 busy 拒绝）；
// - 数据变化：每次变化重新计时 [LanSyncAutoTimings.dataDebounce]；到点时
//   还在编辑就等编辑结束（[editingChanged]）再重新计时；
// - 正忙（与别的设备同步中）：隔 [LanSyncAutoTimings.busyRetry] 再试一次；
// - 每台设备同时最多一个待定的计时器，新的取代旧的；[pause]（切到后台）
//   取消全部计时器。
// 计时器回调里一律先重新判断 [canSync]：期间设备可能下线、开关被关掉。
import 'dart:async';

import 'lan_sync_service_config.dart';

class LanSyncAutoScheduler {
  LanSyncAutoScheduler({
    required this.localDeviceId,
    required this.canSync,
    required this.isBusy,
    required this.isEditing,
    required this.onlinePeers,
    required this.start,
    this.timings = const LanSyncAutoTimings(),
    DateTime Function()? clock,
    LanSyncTimerFactory? timer,
  }) : _clock = clock ?? DateTime.now,
       _timer = timer ?? Timer.new;

  final String localDeviceId;

  /// 现在能否与这台设备自动同步（开关、在线、前台、不需要确认、不在编辑）。
  final bool Function(String peerId) canSync;

  /// 是否正有一次会话在进行（任何设备）。
  final bool Function() isBusy;
  final bool Function() isEditing;

  /// 在线的已配对设备（数据变化与回到前台时逐台触发）。
  final Iterable<String> Function() onlinePeers;

  /// 发起一次自动同步。
  final void Function(String peerId) start;

  final LanSyncAutoTimings timings;
  final DateTime Function() _clock;
  final LanSyncTimerFactory _timer;

  final Map<String, DateTime> _lastAutoSession = <String, DateTime>{};
  final Map<String, DateTime> _lastArrival = <String, DateTime>{};
  final Map<String, Timer> _peerTimers = <String, Timer>{};
  Timer? _dataTimer;
  bool _dataPending = false;

  /// 一台已配对设备上线。
  void peerOnline(String peerId) => _trigger(peerId);

  /// 应用回到前台。
  void resumed() {
    for (final peer in onlinePeers()) {
      _trigger(peer);
    }
  }

  /// 本机同步范围内的数据变了（不含同步自己写入的）。
  void localDataChanged() {
    _dataPending = true;
    _restartDataTimer();
  }

  /// 阻塞者个数变了：编辑刚结束且有待同步的变化时重新开始去抖计时。
  void editingChanged() {
    if (_dataPending && !isEditing()) _restartDataTimer();
  }

  /// 与 [peerId] 的一次会话开始（任一方向，含被拒绝的）：较大一方的等待据此
  /// 判断对方已经发起过。
  void sessionArrived(String peerId) => _lastArrival[peerId] = _clock();

  /// 对方发起的一次自动同步跑过了：计入节流。
  void autoSessionRan(String peerId, DateTime at) {
    final last = _lastAutoSession[peerId];
    if (last == null || at.isAfter(last)) _lastAutoSession[peerId] = at;
  }

  /// 切到后台或关闭自动同步：取消全部计时器与待同步的变化。
  void pause() {
    _dataTimer?.cancel();
    _dataTimer = null;
    _dataPending = false;
    for (final timer in _peerTimers.values) {
      timer.cancel();
    }
    _peerTimers.clear();
  }

  void _restartDataTimer() {
    _dataTimer?.cancel();
    _dataTimer = _timer(timings.dataDebounce, () {
      _dataTimer = null;
      // 还在编辑：等 editingChanged 在编辑结束时重新计时。
      if (isEditing()) return;
      _dataPending = false;
      for (final peer in onlinePeers()) {
        _trigger(peer);
      }
    });
  }

  /// 本机是不是这对设备里先发起的一方（deviceId 较小）。
  bool _leads(String peerId) => localDeviceId.compareTo(peerId) < 0;

  void _trigger(String peerId) {
    if (!canSync(peerId)) return;
    if (_leads(peerId)) {
      _attempt(peerId);
      return;
    }
    final since = _clock();
    _schedule(peerId, timings.mutualRetry, () {
      final arrived = _lastArrival[peerId];
      if (arrived != null && !arrived.isBefore(since)) return;
      _attempt(peerId);
    });
  }

  void _attempt(String peerId, {bool retried = false}) {
    if (!canSync(peerId)) return;
    final now = _clock();
    final last = _lastAutoSession[peerId];
    if (last != null) {
      final wait = last.add(timings.rateLimit).difference(now);
      if (wait > Duration.zero) {
        // 较大的一方到点后重新走“先等对方发起”：两边的节流常常同时到期，
        // 同时发起会互相以 busy 拒绝。
        _schedule(
          peerId,
          wait,
          () => _leads(peerId) ? _attempt(peerId) : _trigger(peerId),
        );
        return;
      }
    }
    if (isBusy()) {
      if (!retried) {
        _schedule(
          peerId,
          timings.busyRetry,
          () => _attempt(peerId, retried: true),
        );
      }
      return;
    }
    _lastAutoSession[peerId] = now;
    start(peerId);
  }

  void _schedule(String peerId, Duration delay, void Function() action) {
    _peerTimers.remove(peerId)?.cancel();
    _peerTimers[peerId] = _timer(delay, () {
      _peerTimers.remove(peerId);
      action();
    });
  }
}
