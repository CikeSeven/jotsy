// 应用密码解锁的输入状态机（`PasscodeUnlockView` 用）。
//
// - 输入：密码存储（核对与限流）、时钟；形式与位数先取调用方给的初值，
//   [start] 读出存储后以存储为准；
// - 输出：经 ChangeNotifier 通知的界面状态；
// - 副作用：核对时写入输错记录；等待期间每秒一次的倒数计时器；输错后
//   [rejectHold] 的“保留红色输入”计时器。
//
// 状态：
// - 输入中：数字逐位输入，输满 [pinLength] 位立即核对（不用再按“确定”）；
//   图案抬手即核对，少于 4 个点直接提示、不算输错；
// - 核对中（[checking]）：摘要在后台 isolate 计算，期间键盘与图案停用，
//   圆点保持填满；
// - 被拒（[rejected]）：输错后圆点全部变红 / 图案连线变红并抖动
//   （[shakeCount] 加一），保留 [rejectHold] 后清空；期间再按数字或开始画
//   图案会立即清空并开始新的一次；
// - 等待（[lockedUntil] 非空）：输错太多次，键盘与图案停用，倒数到点后自动
//   回到输入中；打开时就在等待中（上次输错太多后重开应用）也从存储读出来
//   接着倒数；
// - 已解锁（[unlocked]）：徽章换成开锁，调用方随后揭开遮罩或关闭页面。
//
// 计时器的生命周期：倒数计时器只在等待期间存在，到点、解锁或 dispose 时
// 取消；被拒计时器在重新输入、解锁或 dispose 时取消。回调里先检查
// [_disposed]，不会在页面关闭后通知。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_passcode/app_passcode_store.dart';

/// 输入区下方提示行的内容。
enum PasscodeEntryError { none, wrong, tooShort, lockedOut, unavailable }

class PasscodeEntryController extends ChangeNotifier {
  PasscodeEntryController({
    required this._loadStore,
    required this._clock,
    AppPasscodeKind initialKind = AppPasscodeKind.pin,
    int initialPinLength = 6,
  }) : _kind = initialKind,
       _pinLength = initialPinLength;

  /// 输错后红色输入保留多久再清空（显示计时，不是动画时长）。
  static const Duration rejectHold = Duration(milliseconds: 900);

  final Future<AppPasscodeStore?> Function() _loadStore;
  final DateTime Function() _clock;

  AppPasscodeStore? _store;
  AppPasscodeKind _kind;
  int _pinLength;
  bool _ready = false;
  String _digits = '';
  bool _checking = false;
  bool _unlocked = false;
  bool _rejected = false;
  bool _disposed = false;
  PasscodeEntryError _error = PasscodeEntryError.none;
  int _attemptsLeft = 0;
  int _shakeCount = 0;
  int _patternClears = 0;
  DateTime? _lockedUntil;
  Timer? _ticker;
  Timer? _rejectTimer;

  AppPasscodeKind get kind => _kind;
  int get pinLength => _pinLength;

  /// 已输入的位数。
  int get filled => _digits.length;

  bool get checking => _checking;
  bool get unlocked => _unlocked;
  bool get rejected => _rejected;
  PasscodeEntryError get error => _error;

  /// 再输错几次就要等待（提示“再错 N 次需要等待”）。
  int get attemptsLeft => _attemptsLeft;

  /// 每输错一次加一，界面据此播放一次抖动与触觉反馈。
  int get shakeCount => _shakeCount;

  /// 变化时图案板清空连线（被拒保留结束、重新开始）。
  int get patternClears => _patternClears;

  DateTime? get lockedUntil => _lockedUntil;
  bool get lockedOut => _lockedUntil != null;

  /// 还要等多少秒（向上取整，至少 1）。
  int get lockoutSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final ms = until.difference(_clock()).inMilliseconds;
    return ms <= 0 ? 1 : (ms / 1000).ceil();
  }

  /// 键盘与图案板是否接受输入。
  bool get inputEnabled => _ready && !_checking && !_unlocked && !lockedOut;

  /// 读出存储：形式、位数，以及是否仍在等待（上次输错太多次）。
  Future<void> start() async {
    final store = await _loadStore();
    if (_disposed) return;
    _store = store;
    if (store == null || !store.config.hasPasscode) {
      _error = PasscodeEntryError.unavailable;
      _notify();
      return;
    }
    _kind = store.config.kind;
    _pinLength = store.config.pinLength;
    final until = await store.currentLockout();
    if (_disposed) return;
    _ready = true;
    if (until != null) {
      _startLockout(until);
    }
    _notify();
  }

  /// 数字键盘：输入一位；输满即核对。
  void addDigit(int digit) {
    if (!inputEnabled || _kind != AppPasscodeKind.pin) return;
    _beginNewAttempt();
    if (_digits.length >= _pinLength) return;
    _digits += '$digit';
    _notify();
    if (_digits.length == _pinLength) {
      unawaited(_submit(_digits));
    }
  }

  void backspace() {
    if (!inputEnabled || _digits.isEmpty) return;
    if (_rejected) {
      _beginNewAttempt();
      _notify();
      return;
    }
    _digits = _digits.substring(0, _digits.length - 1);
    _notify();
  }

  /// 长按删除键：清空已输入的数字。
  void clearDigits() {
    if (!inputEnabled || _digits.isEmpty) return;
    _beginNewAttempt();
    _digits = '';
    _notify();
  }

  /// 开始画图案：收起上一次的红色连线与提示。
  void startPattern() {
    if (!inputEnabled) return;
    _beginNewAttempt();
    _notify();
  }

  /// 画完图案（抬手）。少于 4 个点只提示，不算输错。
  Future<void> submitPattern(List<int> nodes) async {
    if (!inputEnabled || _kind != AppPasscodeKind.pattern) return;
    if (nodes.length < AppPasscodeRules.patternMinNodes) {
      _error = PasscodeEntryError.tooShort;
      _reject();
      _notify();
      return;
    }
    await _submit(AppPasscodeRules.encodePattern(nodes));
  }

  /// 指纹 / 面容通过：直接进入已解锁。
  void markUnlocked() {
    if (_unlocked) return;
    _ticker?.cancel();
    _ticker = null;
    _rejectTimer?.cancel();
    _rejectTimer = null;
    _rejected = false;
    _lockedUntil = null;
    _error = PasscodeEntryError.none;
    _unlocked = true;
    _notify();
  }

  Future<void> _submit(String value) async {
    final store = _store;
    if (store == null) {
      _error = PasscodeEntryError.unavailable;
      _notify();
      return;
    }
    _checking = true;
    _notify();
    final check = await store.verify(value);
    if (_disposed) return;
    _checking = false;
    switch (check.status) {
      case AppPasscodeCheckStatus.accepted:
        _error = PasscodeEntryError.none;
        _unlocked = true;
      case AppPasscodeCheckStatus.wrong:
        _error = PasscodeEntryError.wrong;
        _attemptsLeft = check.attemptsLeft;
        _reject();
      case AppPasscodeCheckStatus.lockedOut:
        _reject();
        _startLockout(check.lockedUntil!);
      case AppPasscodeCheckStatus.noPasscode:
        _error = PasscodeEntryError.unavailable;
    }
    _notify();
  }

  /// 输错：抖动一次，保留红色输入 [rejectHold] 后清空。
  void _reject() {
    _shakeCount++;
    _rejected = true;
    _rejectTimer?.cancel();
    _rejectTimer = Timer(rejectHold, () {
      if (_disposed) return;
      _clearRejected();
      _notify();
    });
  }

  /// 重新输入：清掉被拒的输入，收起“密码不对 / 至少连 4 个点”（等待中的
  /// 倒数不收）。
  void _beginNewAttempt() {
    _clearRejected();
    if (_error == PasscodeEntryError.wrong ||
        _error == PasscodeEntryError.tooShort) {
      _error = PasscodeEntryError.none;
    }
  }

  void _clearRejected() {
    if (!_rejected) return;
    _rejectTimer?.cancel();
    _rejectTimer = null;
    _rejected = false;
    _digits = '';
    _patternClears++;
  }

  void _startLockout(DateTime until) {
    _lockedUntil = until;
    _error = PasscodeEntryError.lockedOut;
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
      _error = PasscodeEntryError.none;
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
    _rejectTimer?.cancel();
    super.dispose();
  }
}
