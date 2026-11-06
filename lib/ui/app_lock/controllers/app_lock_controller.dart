// 应用锁的运行逻辑（docs/rules/app_lock.md）：什么时候盖上锁屏、什么时候弹
// 验证、验证通过后揭开。应用根部（`NodeDiaryApp`）只负责创建它、把状态画成
// 遮罩，并把指针操作转给 [AppLockController.noteActivity]。
//
// - 输入：设置服务（应用锁开关）、[AppLockOptions]、统一验证入口
//   [IdentityVerifier]、原生能力 [AppLockPlatform]、应用前后台变化
//   （[AppLifecycleListener]）、实体键盘事件；
// - 输出：[AppLockController.locked] / [AppLockController.unlocking]；
// - 副作用：弹系统验证；验证方式不可用时关闭应用锁；按选项开关熄屏监听与
//   防截屏；解锁后调用 `onUnlocked`（顺带解开上锁日记本的重锁遮罩）。
//
// 上锁时机（应用锁开着时）：
// 1. 冷启动（[AppLockController.start]）与打开应用锁开关：立即上锁；
// 2. 离开应用（hidden：切到其他应用、回到桌面、窗口最小化）：记下时刻。
//    “立即”当场盖上；其余档位回到前台时按离开时长判断。应用自己打开的界面
//    （选图片、拍照、选文件、系统分享面板）不算离开：原生判断那个界面盖在
//    本应用的任务上（异步回答，“立即”先盖上、确认是自己的界面再撤回）；
//    系统验证（手机锁屏密码页）进行中同样不算（[IdentityVerifier.systemPromptActive]）；
// 3. 熄屏（Android，“锁屏时上锁”）：收到熄屏事件就盖上，应用在后台也一样；
// 4. 闲置（桌面，“闲置时上锁”）：窗口在前台但一段时间没有指针与键盘操作。
//
// 在后台盖上的锁不在后台弹验证（系统界面弹不出来、指纹会被取消），回到前台
// 才按“自动弹出验证”弹（[_promptOnReturn]）。应用密码方式下遮罩里的解锁视图
// 自己负责输入与自动弹指纹，这里只决定盖不盖。
//
// 时间一律按墙上时钟：Dart 的单调时钟在手机深度睡眠、电脑休眠时不走，离开
// 一小时可能只算几分钟。离开期间时钟被往回调（回来时早于离开时刻）按超时
// 处理，宁可多锁一次；闲置计时遇到时钟回拨则从现在重新算，不在用户操作中
// 途突然上锁。闲置定时器最长 30 秒检查一次，电脑休眠醒来后很快就会补上锁。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/app_lock_platform.dart';
import '../../../core/services/app_passcode/app_passcode_config.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/settings_service.dart';
import '../models/app_lock_options.dart';
import 'identity_verifier.dart';

/// 一次离开应用的记录。
class _AwaySpan {
  _AwaySpan(this.since);

  final DateTime since;

  /// 原生的回答：这次是不是应用自己打开的界面；null 为还没回答。
  bool? ownActivity;

  /// 这次离开时是否已经当场盖上（“立即”）。
  bool lockedOnLeave = false;

  /// 离开期间是否熄过屏（熄屏上的锁不因为“是自己的界面”而撤回）。
  bool screenOff = false;
}

class AppLockController extends ChangeNotifier {
  AppLockController({
    required this._verifier,
    required this._settings,
    required this._platform,
    required this._options,
    required this._authReason,
    this._clock = DateTime.now,
    this.onUnlocked,
  }) {
    final state = WidgetsBinding.instance.lifecycleState;
    _visible =
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _lastActivity = _clock();
    _settings.appLockEnabledNotifier.addListener(_handleEnabledChanged);
    _lifecycle = AppLifecycleListener(onHide: _handleHide, onShow: _handleShow);
    _screenOffSubscription = _platform.screenOffEvents.listen(
      (_) => _handleScreenOff(),
    );
    if (AppPlatform.supportsIdleLock) {
      _keyHandlerInstalled = true;
      HardwareKeyboard.instance.addHandler(_handleKey);
    }
    _applyPlatformOptions();
  }

  /// 闲置定时器单次最长等待：见文件头（电脑休眠醒来后尽快补上锁）。
  static const Duration idleCheckInterval = Duration(seconds: 30);

  final IdentityVerifier _verifier;
  final SettingsService _settings;
  final AppLockPlatform _platform;
  final String Function() _authReason;
  final DateTime Function() _clock;

  /// 揭开遮罩之后调用。
  final VoidCallback? onUnlocked;

  AppLockOptions _options;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _screenOffSubscription;
  bool _keyHandlerInstalled = false;

  bool _locked = false;
  bool _unlocking = false;
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;
  bool _promptOnReturn = false;
  late bool _visible;
  _AwaySpan? _away;
  Timer? _idleTimer;
  late DateTime _lastActivity;
  bool _watchingScreenOff = false;
  bool _secureScreen = false;

  /// 遮罩盖着（含正在判断验证方式、正在系统验证）。
  bool get locked => _locked;

  /// 正在判断验证方式或正在进行系统验证：系统验证方式的遮罩显示加载指示。
  bool get unlocking => _unlocking;

  AppLockOptions get options => _options;

  set options(AppLockOptions next) {
    if (next == _options) return;
    _options = next;
    _applyPlatformOptions();
    _restartIdle();
  }

  bool get _enabled => _settings.isAppLockEnabled;

  /// 冷启动的检查（首帧之后调用一次）：应用锁开着就上锁。
  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (_enabled) {
      unawaited(_lockAndAuthenticate(prompt: _options.autoPrompt));
    } else {
      _restartIdle();
    }
  }

  /// 系统验证方式的遮罩上点“立即解锁”。
  Future<void> manualUnlock() => _lockAndAuthenticate(prompt: true);

  /// 遮罩里的应用密码（或指纹）验证通过。
  void passcodeUnlocked() {
    if (_disposed || !_locked) return;
    _unlock();
  }

  /// 用户操作了一下（指针事件，桌面）：闲置计时从现在重新算。只记时刻，
  /// 指针移动也会调用，不能做更多事。
  void noteActivity() {
    _lastActivity = _clock();
  }

  bool _handleKey(KeyEvent event) {
    _lastActivity = _clock();
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _handleEnabledChanged() {
    if (_disposed) return;
    _applyPlatformOptions();
    if (!_enabled) {
      _cancelIdle();
      _away = null;
      _promptOnReturn = false;
      if (_locked || _unlocking) {
        _locked = false;
        _unlocking = false;
        _notify();
      }
      return;
    }
    // 打开应用锁（含从备份恢复）：立即上锁并验证一次，确认能解开。
    unawaited(_lockAndAuthenticate(prompt: _options.autoPrompt));
  }

  /// 上锁并按需验证。[prompt] 为 false 时只盖上（系统验证方式停在“立即解锁”
  /// 上，应用密码方式由解锁视图按“自动弹出验证”决定弹不弹指纹）。
  Future<void> _lockAndAuthenticate({required bool prompt}) async {
    if (_busy || _disposed || !_enabled) return;
    _busy = true;
    try {
      _cancelIdle();
      final wasLocked = _locked;
      _locked = true;
      // 还没盖住时先进入“判断中”：读出验证方式之前显示加载指示。已经盖着时
      // 保持原样，应用密码的输入不会闪成加载指示再换回来。
      if (!wasLocked) _unlocking = true;
      _notify();

      final available = await _verifier.isAvailable();
      if (_disposed || !_locked) return;
      if (!available) {
        // 设备取消了锁屏密码等：应用锁自动解除（开关监听随即揭开遮罩）。
        await _settings.setAppLockEnabled(false);
        return;
      }
      final passcode =
          await _verifier.method() == AppVerificationMethod.passcode;
      if (_disposed || !_locked) return;
      if (prompt && !_visible) {
        // 在后台弹不出系统验证：回到前台再弹。
        _promptOnReturn = true;
        prompt = false;
      }
      if (passcode || !prompt) {
        if (_unlocking) {
          _unlocking = false;
          _notify();
        }
        return;
      }
      if (!_unlocking) {
        _unlocking = true;
        _notify();
      }
      final passed = await _verifier.verifySystem(
        reason: _authReason(),
        persistAcrossBackgrounding: true,
      );
      if (_disposed) return;
      _unlocking = false;
      if (passed) {
        _unlock();
      } else {
        _notify();
      }
    } finally {
      _busy = false;
    }
  }

  void _unlock() {
    _locked = false;
    _unlocking = false;
    _promptOnReturn = false;
    _notify();
    _restartIdle();
    onUnlocked?.call();
  }

  /// 在后台（或熄屏的那一刻）盖上，回到前台再验证。
  void _lockWhileAway() {
    if (_disposed || !_enabled || _locked) return;
    _locked = true;
    _unlocking = false;
    _promptOnReturn = true;
    _cancelIdle();
    _notify();
  }

  void _handleHide() {
    if (!_visible) return;
    _visible = false;
    _cancelIdle();
    _away = null;
    if (_disposed || !_enabled || _locked) return;
    // “从不”：离开多久都不上锁，不必记录（熄屏另有事件）。
    if (_options.afterLeaving.after == null) return;
    // 系统验证（手机锁屏密码页）把应用挤到后台：不算离开。
    if (_verifier.systemPromptActive) return;
    final away = _AwaySpan(_clock());
    _away = away;
    if (_options.afterLeaving == AppLockAfterLeaving.immediately) {
      away.lockedOnLeave = true;
      _lockWhileAway();
    }
    unawaited(
      _platform.leftForOwnActivity().then((bool own) {
        away.ownActivity = own;
        // 应用自己打开的界面：撤回刚才当场盖上的锁。回答来得比用户回来还晚、
        // 或这段时间熄过屏时保持锁着。
        if (own &&
            !_disposed &&
            identical(_away, away) &&
            !_visible &&
            away.lockedOnLeave &&
            !away.screenOff &&
            _locked &&
            !_busy) {
          _locked = false;
          _promptOnReturn = false;
          _notify();
        }
      }),
    );
  }

  void _handleShow() {
    if (_visible) return;
    _visible = true;
    final away = _away;
    _away = null;
    if (_disposed || !_enabled) return;
    if (_promptOnReturn) {
      _promptOnReturn = false;
      if (_locked) {
        unawaited(_lockAndAuthenticate(prompt: _options.autoPrompt));
      }
      return;
    }
    // 冷启动或打开开关时的验证还没结束（系统验证中途切到后台会接着验证）。
    if (_locked) return;
    if (away != null && away.ownActivity != true && _awayTooLong(away.since)) {
      unawaited(_lockAndAuthenticate(prompt: _options.autoPrompt));
      return;
    }
    _restartIdle();
  }

  bool _awayTooLong(DateTime since) {
    final after = _options.afterLeaving.after;
    if (after == null) return false;
    final now = _clock();
    if (now.isBefore(since)) return true;
    return now.difference(since) >= after;
  }

  void _handleScreenOff() {
    if (_disposed ||
        !_enabled ||
        !_options.onScreenOff ||
        !AppPlatform.supportsScreenOffLock) {
      return;
    }
    _away?.screenOff = true;
    _lockWhileAway();
  }

  Duration? get _idleAfter =>
      AppPlatform.supportsIdleLock ? _options.whenIdle.after : null;

  void _cancelIdle() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// 从现在开始重新计算闲置。
  void _restartIdle() {
    _cancelIdle();
    final idle = _idleAfter;
    if (_disposed || idle == null || !_enabled || !_visible || _locked) {
      return;
    }
    _lastActivity = _clock();
    _scheduleIdleCheck(idle);
  }

  void _scheduleIdleCheck(Duration wait) {
    _idleTimer = Timer(
      wait < idleCheckInterval ? wait : idleCheckInterval,
      _checkIdle,
    );
  }

  void _checkIdle() {
    _idleTimer = null;
    final idle = _idleAfter;
    if (_disposed || idle == null || !_enabled || !_visible || _locked) {
      return;
    }
    final quiet = _clock().difference(_lastActivity);
    if (quiet.isNegative) {
      // 时钟往回调了：从现在重新算。
      _restartIdle();
      return;
    }
    if (quiet < idle) {
      _scheduleIdleCheck(idle - quiet);
      return;
    }
    // 正在弹系统验证（如进入上锁的日记本）：等它结束后再算。
    if (_verifier.systemPromptActive) {
      _restartIdle();
      return;
    }
    unawaited(_lockAndAuthenticate(prompt: _options.autoPrompt));
  }

  /// 按当前开关与选项打开 / 关闭原生的熄屏监听与防截屏（只在变化时下发）。
  void _applyPlatformOptions() {
    final watch =
        _enabled && _options.onScreenOff && AppPlatform.supportsScreenOffLock;
    if (watch != _watchingScreenOff) {
      _watchingScreenOff = watch;
      unawaited(_platform.setWatchScreenOff(watch));
    }
    // 防截屏与应用锁开关无关：没开应用锁也可以单独防截屏。
    final secure = _options.secureScreen && AppPlatform.supportsSecureScreen;
    if (secure != _secureScreen) {
      _secureScreen = secure;
      unawaited(_platform.setSecureScreen(secure));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.appLockEnabledNotifier.removeListener(_handleEnabledChanged);
    _lifecycle.dispose();
    unawaited(_screenOffSubscription.cancel());
    if (_keyHandlerInstalled) {
      HardwareKeyboard.instance.removeHandler(_handleKey);
    }
    _cancelIdle();
    if (_watchingScreenOff) unawaited(_platform.setWatchScreenOff(false));
    if (_secureScreen) unawaited(_platform.setSecureScreen(false));
    super.dispose();
  }
}
