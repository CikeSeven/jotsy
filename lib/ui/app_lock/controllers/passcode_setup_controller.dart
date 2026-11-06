// 设置 / 修改应用密码的两步状态机（`PasscodeSetupPage` 用）。
//
// - 输入：初始形式（修改时为原来的形式）、保存回调（写入 `AppPasscodeStore`）；
// - 输出：经 ChangeNotifier 通知的界面状态；
// - 副作用：两次一致时调用保存回调；输错后 [rejectHold] 的“保留红色输入”
//   计时器。
//
// 步骤：
// 1. 新建（[PasscodeSetupStep.create]）：可以切换形式（6 位数字 / 4 位数字 /
//    图案，切换会清空输入）。数字输满、图案抬手（至少 4 个点）即记下第一次
//    的输入并进入第二步；图案不足 4 个点在提示行说明并抖动，停在这一步；
// 2. 确认（[PasscodeSetupStep.confirm]）：再输一次。一致 → 保存，[done]；
//    不一致 → 提示“两次不一致”、抖动，退回第一步重新设置；第二步按返回也
//    回到第一步（[back]）。
//
// 被拒计时器在重新输入、换步、dispose 时取消，回调里检查 [_disposed]。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_passcode/app_passcode_config.dart';
import '../models/passcode_form.dart';

enum PasscodeSetupStep { create, confirm }

enum PasscodeSetupError { none, tooShort, mismatch, saveFailed }

class PasscodeSetupController extends ChangeNotifier {
  PasscodeSetupController({
    required PasscodeForm initialForm,
    required this._save,
  }) : _form = initialForm;

  /// 输错后红色输入保留多久再清空（显示计时，不是动画时长）。
  static const Duration rejectHold = Duration(milliseconds: 900);

  final Future<void> Function(PasscodeForm form, String value) _save;

  PasscodeForm _form;
  PasscodeSetupStep _step = PasscodeSetupStep.create;
  String? _first;
  String _digits = '';
  bool _rejected = false;
  bool _saving = false;
  bool _done = false;
  bool _disposed = false;
  PasscodeSetupError _error = PasscodeSetupError.none;
  int _shakeCount = 0;
  int _patternClears = 0;
  Timer? _rejectTimer;

  PasscodeForm get form => _form;
  PasscodeSetupStep get step => _step;
  bool get confirming => _step == PasscodeSetupStep.confirm;
  int get filled => _digits.length;
  bool get rejected => _rejected;
  bool get saving => _saving;
  bool get done => _done;
  PasscodeSetupError get error => _error;
  int get shakeCount => _shakeCount;
  int get patternClears => _patternClears;

  bool get inputEnabled => !_saving && !_done;

  /// 第一步可以切换形式；切换会清空输入。
  void selectForm(PasscodeForm form) {
    if (!inputEnabled || confirming || form == _form) return;
    _clearRejected();
    _form = form;
    _digits = '';
    _error = PasscodeSetupError.none;
    _patternClears++;
    _notify();
  }

  void addDigit(int digit) {
    if (!inputEnabled || _form.kind != AppPasscodeKind.pin) return;
    _beginNewAttempt();
    if (_digits.length >= _form.pinLength) return;
    _digits += '$digit';
    _notify();
    if (_digits.length == _form.pinLength) {
      unawaited(_complete(_digits));
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

  void clearDigits() {
    if (!inputEnabled || _digits.isEmpty) return;
    _beginNewAttempt();
    _digits = '';
    _notify();
  }

  void startPattern() {
    if (!inputEnabled) return;
    _beginNewAttempt();
    _notify();
  }

  Future<void> submitPattern(List<int> nodes) async {
    if (!inputEnabled || _form.kind != AppPasscodeKind.pattern) return;
    if (!AppPasscodeRules.validPattern(nodes)) {
      _error = PasscodeSetupError.tooShort;
      _reject();
      _notify();
      return;
    }
    await _complete(AppPasscodeRules.encodePattern(nodes));
  }

  /// 第二步按返回：回到第一步。返回 true 表示已处理（页面不要关闭）。
  bool back() {
    if (!confirming || _saving) return false;
    _clearRejected();
    _step = PasscodeSetupStep.create;
    _first = null;
    _digits = '';
    _error = PasscodeSetupError.none;
    _patternClears++;
    _notify();
    return true;
  }

  Future<void> _complete(String value) async {
    if (!confirming) {
      _first = value;
      _step = PasscodeSetupStep.confirm;
      _digits = '';
      _error = PasscodeSetupError.none;
      _patternClears++;
      _notify();
      return;
    }
    if (value != _first) {
      _error = PasscodeSetupError.mismatch;
      _step = PasscodeSetupStep.create;
      _first = null;
      _reject();
      _notify();
      return;
    }
    _saving = true;
    _notify();
    try {
      await _save(_form, value);
      if (_disposed) return;
      _saving = false;
      _done = true;
    } catch (_) {
      if (_disposed) return;
      _saving = false;
      _error = PasscodeSetupError.saveFailed;
      _step = PasscodeSetupStep.create;
      _first = null;
      _reject();
    }
    _notify();
  }

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

  /// 重新输入：清掉被拒的输入。“两次不一致”留着，直到第一次输完——它说明
  /// 为什么回到了第一步。
  void _beginNewAttempt() {
    _clearRejected();
    if (_error == PasscodeSetupError.tooShort ||
        _error == PasscodeSetupError.saveFailed) {
      _error = PasscodeSetupError.none;
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _rejectTimer?.cancel();
    super.dispose();
  }
}
