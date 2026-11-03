import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/cloud_backup_service.dart';

/// 网盘自动备份的时机（每个位置是否该备份、间隔与失败退避见
/// `isCloudAutoBackupDue`；这里只决定“什么时候去看一眼”）。
///
/// - 冷启动后 [launchDelay]：上次切到后台时的备份可能被系统杀掉，开机补上；
/// - 进入后台（paused / hidden）后 [backgroundDelay]：刚写完日记离开应用正是
///   该备份的时候；稍等片刻，让编辑页在同一时刻触发的自动保存先写进数据库。
///   等待期间回到前台就取消；已经开始的备份让它跑完（续传日志兜住被挂起或
///   被杀的情况）；
/// - 前台每 [foregroundInterval] 看一次：桌面窗口可能连开好几天。
///
/// 自动备份全程静默：不弹窗、不弹提示条，结果记进本机状态，由网盘备份页
/// 显示。同一时间只跑一轮；手动操作与自动备份经服务的锁按位置排队。
class CloudBackupAutoScheduler with WidgetsBindingObserver {
  CloudBackupAutoScheduler(this._run);

  static const Duration launchDelay = Duration(seconds: 10);
  static const Duration backgroundDelay = Duration(seconds: 3);
  static const Duration foregroundInterval = Duration(hours: 1);

  final Future<void> Function() _run;
  Timer? _timer;
  Timer? _periodic;
  bool _started = false;
  bool _running = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(launchDelay);
    _startPeriodic();
  }

  void dispose() {
    _timer?.cancel();
    _periodic?.cancel();
    _timer = null;
    _periodic = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _periodic?.cancel();
        _periodic = null;
        _schedule(backgroundDelay);
      case AppLifecycleState.resumed:
        // 切到后台又马上回来：还没开始的那次不必跑，回到前台的检查交给
        // 定时器。
        _timer?.cancel();
        _timer = null;
        _startPeriodic();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _startPeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(foregroundInterval, (_) => _trigger());
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      _trigger();
    });
  }

  void _trigger() {
    if (_running) return;
    _running = true;
    unawaited(_run().whenComplete(() => _running = false));
  }
}

/// 一轮自动备份：逐个位置调用 `runAutoBackup`（不该备份的直接跳过，不联网）。
/// 任何错误都只吞掉——自动备份不能影响应用的其他部分。
Future<void> runCloudAutoBackups(WidgetRef ref) async {
  try {
    final service = await ref.read(cloudBackupServiceProvider.future);
    for (final target in service.targets.targets) {
      if (!target.options.autoBackup) continue;
      await service.runAutoBackup(target.id);
    }
  } on Object catch (error) {
    debugPrint('cloud auto backup round failed: $error');
  }
}
