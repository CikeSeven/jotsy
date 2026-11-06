// “应用锁与密码”设置页的操作编排（docs/rules/app_lock.md）。
//
// - 输入：设置服务（应用锁开关）、统一验证入口 `IdentityVerifier`；
// - 输出：无（结果经提示条告诉用户）；
// - 副作用：验证身份、打开设置密码页、写入应用锁开关与密码存储。
//
// 每个会削弱保护的改动都先按当前方式验证一次，且应用密码方式下只认密码
// （`IdentityPurpose.sensitive`）：
// - 关闭应用锁：验证后关闭；
// - 系统验证 → 应用密码：先做一次系统验证（设备有锁屏密码时），防止进到已
//   解锁应用的人自己设个密码去打开上锁的日记本；设备没有系统验证时（Linux、
//   没设锁屏密码的手机）原本就什么也锁不住，直接设置；
// - 应用密码 → 系统验证：先输入应用密码，且设备必须能弹出系统验证（否则切过去
//   应用锁与上锁日记本都打不开），通过后清除密码；
// - 修改密码（可以换形式）：先输入当前密码；
// - 打开指纹快捷解锁：先验一次指纹，确认能用；关闭不用验证（更严格了）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/settings_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../pages/passcode_setup_page.dart';
import 'identity_verifier.dart';

class AppLockSettingsFlow {
  const AppLockSettingsFlow(this._ref);

  final WidgetRef _ref;

  IdentityVerifier get _verifier => _ref.read(identityVerifierProvider);

  /// 开关应用锁：开启前确认现在能验证身份，关闭前先验证一次。
  Future<void> setAppLockEnabled(
    BuildContext context,
    SettingsService settings,
    bool enabled,
  ) async {
    if (enabled) {
      final available = await _verifier.isAvailable();
      if (!context.mounted) return;
      if (!available) {
        _hint(context, context.l10n.appLockNotSupported);
        return;
      }
      await settings.setAppLockEnabled(true);
      return;
    }
    final verified = await _verifier.verify(
      context,
      reason: context.l10n.appLockDisableAuthReason,
      purpose: IdentityPurpose.sensitive,
    );
    if (!context.mounted) return;
    if (!verified) {
      _hint(context, context.l10n.appLockDisableVerifyFailed);
      return;
    }
    await settings.setAppLockEnabled(false);
  }

  /// 系统验证 → 应用密码。
  Future<void> switchToPasscode(BuildContext context) async {
    final l10n = context.l10n;
    if (await _verifier.systemSupported()) {
      final verified = await _verifier.verifySystem(
        reason: l10n.appLockSwitchToPasscodeReason,
      );
      if (!context.mounted) return;
      if (!verified) {
        _hint(context, l10n.appLockSwitchVerifyFailed);
        return;
      }
    }
    if (!context.mounted) return;
    final done = await PasscodeSetupPage.open(context);
    if (!context.mounted || !done) return;
    _hint(context, l10n.passcodeSetDone);
  }

  /// 应用密码 → 系统验证。
  Future<void> switchToSystem(BuildContext context) async {
    final l10n = context.l10n;
    if (!await _verifier.systemSupported()) {
      if (!context.mounted) return;
      _hint(context, l10n.appLockSystemUnsupported);
      return;
    }
    if (!context.mounted) return;
    final verified = await _verifier.verify(
      context,
      reason: l10n.appLockSwitchToSystemReason,
      purpose: IdentityPurpose.sensitive,
    );
    if (!context.mounted) return;
    if (!verified) {
      _hint(context, l10n.appLockSwitchVerifyFailed);
      return;
    }
    await (await _verifier.store())?.clear();
    if (!context.mounted) return;
    _hint(context, l10n.appLockSwitchedToSystem);
  }

  /// 修改应用密码：先输入当前密码。
  Future<void> changePasscode(BuildContext context) async {
    final l10n = context.l10n;
    final verified = await _verifier.verify(
      context,
      reason: l10n.passcodeChangeReason,
      purpose: IdentityPurpose.sensitive,
    );
    if (!context.mounted || !verified) return;
    final done = await PasscodeSetupPage.open(context, change: true);
    if (!context.mounted || !done) return;
    _hint(context, l10n.passcodeChangedDone);
  }

  /// 指纹 / 面容快捷解锁的开关。
  Future<void> setBiometric(BuildContext context, bool enabled) async {
    final store = await _verifier.store();
    if (store == null || !context.mounted) return;
    if (!enabled) {
      await store.setBiometric(false);
      return;
    }
    final passed = await _verifier.authenticateBiometric(
      reason: context.l10n.passcodeBiometricEnableReason,
    );
    if (!context.mounted) return;
    if (!passed) {
      _hint(context, context.l10n.passcodeBiometricFailed);
      return;
    }
    await store.setBiometric(true);
  }

  /// 弹出提示，不等它关闭：`showTrackedSnackBar` 要到提示条消失才完成，
  /// 等它会让设置页的“一次一个操作”锁多挂几秒、连着的下一下点按被吞掉。
  void _hint(BuildContext context, String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }
}
