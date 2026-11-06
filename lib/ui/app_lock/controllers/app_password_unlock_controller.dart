// 应用密码输入的状态机（`AppPasswordView` 用）。
//
// - 输入：密码存储（核对与限流）、指纹快捷解锁（经 `IdentityVerifier`）、时钟；
// - 输出：经 ChangeNotifier 通知的界面状态；
// - 副作用：核对时写入输错记录；指纹通过时清零记录；等待期间每秒一次的
//   倒数计时器。
//
// 状态：
// - 空闲：可以输入、可以按“解锁”（输入为空时按钮停用）；
// - 核对中（[checking]）：摘要在后台 isolate 计算，期间输入与按钮停用，
//   连按不会重复提交；
// - 输错（[error] 为 wrong）：清空输入、[shakeCount] 加一（界面据此抖动），
//   提示还能再试几次；
// - 等待（[lockedUntil] 非空）：输入与按钮停用，倒数到点后自动回到空闲；
//   打开时就在等待中（上次输错太多后重开应用）也从存储读出来接着倒数；
// - 已解锁（[unlocked]）：徽章换成开锁，调用方随后揭开遮罩或关闭页面。
//
// 计时器只在等待期间存在：到点、解锁或 dispose 时取消；回调里先检查
// [_disposed]，不会在页面关闭后通知。

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/services/app_password/app_password_store.dart';

/// 输入框下方提示行的内容。
enum AppPasswordUnlockError { none, wrong, lockedOut, unavailable }

class AppPasswordUnlockController extends ChangeNotifier {
  AppPasswordUnlockController({
    required this._loadStore,
    required this._clock,
  }) {
    text.addListener(_handleTextChanged);
  }

  final Future<AppPasswordStore?> Function() _loadStore;
  final DateTime Function() _clock;

  final TextEditingController text = TextEditingController();

  bool _checking = false;
  bool _unlocked = false;
  bool _disposed = false;
  bool _hasText = false;
  AppPasswordUnlockError _error = AppPasswordUnlockError.none;
  int _attemptsLeft = 0;
  int _shakeCount = 0;
  DateTime? _lockedUntil;
  Timer? _ticker;

  bool get checking => _checking;
  bool get unlocked => _unlocked;
  AppPasswordUnlockError get error => _error;

  /// 再输错几次就要等待（提示“还可以试 N 次”）。
  int get attemptsLeft => _attemptsLeft;

  /// 每输错一次加一，界面据此播放一次抖动。
  int get shakeCount => _shakeCount;

  DateTime? get lockedUntil => _lockedUntil;

  bool get lockedOut => _lockedUntil != null;

  /// 还要等多少秒（向上取整，至少 1）。
  int get lockoutSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final ms = until.difference(_clock()).inMilliseconds;
    return ms <= 0 ? 1 : (ms / 1000).ceil();
  }

  /// 输入框与“解锁”按钮是否可用。
  bool get inputEnabled => !_checking && !_unlocked && !lockedOut;

  bool get canSubmit => inputEnabled && _hasText;

  /// 打开时读出是否仍在等待（上次输错太多次）。
  Future<void> restoreLockout() async {
    final store = await _loadStore();
    final until = await store?.currentLockout();
    if (_disposed || until == null) return;
    _startLockout(until);
  }

  /// 核对输入的密码；通过返回 true。
  Future<bool> submit() async {
    if (!canSubmit) return false;
    _checking = true;
    _notify();
    final store = await _loadStore();
    final check = store == null
        ? const AppPasswordCheck(AppPasswordCheckStatus.noPassword)
        : await store.verify(text.text);
    if (_disposed) return check.status == AppPasswordCheckStatus.accepted;
    _checking = false;
    switch (check.status) {
      case AppPasswordCheckStatus.accepted:
        _error = AppPasswordUnlockError.none;
        _unlocked = true;
      case AppPasswordCheckStatus.wrong:
        _error = AppPasswordUnlockError.wrong;
        _attemptsLeft = check.attemptsLeft;
        _shakeCount++;
        text.clear();
      case AppPasswordCheckStatus.lockedOut:
        _shakeCount++;
        text.clear();
        _startLockout(check.lockedUntil!);
      case AppPasswordCheckStatus.noPassword:
        _error = AppPasswordUnlockError.unavailable;
    }
    _notify();
    return _unlocked;
  }

  /// 指纹 / 面容通过：直接进入已解锁。
  void markUnlocked() {
    if (_unlocked) return;
    _ticker?.cancel();
    _ticker = null;
    _lockedUntil = null;
    _error = AppPasswordUnlockError.none;
    _unlocked = true;
    _notify();
  }

  void _startLockout(DateTime until) {
    _lockedUntil = until;
    _error = AppPasswordUnlockError.lockedOut;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_disposed) return;
    final until = _lockedUntil;
    if (until == null || !_clock().isBefore(until)) {
      _ticker?.cancel();
      _ticker = null;
      _lockedUntil = null;
      _error = AppPasswordUnlockError.none;
    }
    _notify();
  }

  void _handleTextChanged() {
    final hasText = text.text.isNotEmpty;
    if (hasText == _hasText) return;
    _hasText = hasText;
    // 重新输入时收起上一次的“密码不对”。
    if (hasText && _error == AppPasswordUnlockError.wrong) {
      _error = AppPasswordUnlockError.none;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    text.removeListener(_handleTextChanged);
    text.dispose();
    super.dispose();
  }
}
