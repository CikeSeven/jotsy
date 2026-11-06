// 统一的身份验证入口（docs/rules/app_lock.md）。
//
// - 输入：验证方式（有没有设应用密码，见 `AppPasscodeStore`）、设备验证
//   服务 `DeviceAuthService`；
// - 输出：验证是否通过；
// - 副作用：弹系统验证，或打开应用密码页（`PasscodeVerifyPage`）。
//
// 应用锁、上锁的日记本与局域网配对确认都经这里验证，验证方式是全局的一个
// 设置：设了应用密码就用应用密码，否则用系统验证。界面禁止绕过这里直接调用
// `DeviceAuthService`（`app_lock_source_test.dart` 兜底），否则切到应用密码后
// 仍会冒出系统验证，或在 Linux 上直接打不开。
//
// 应用密码方式下：
// - [IdentityPurpose.unlock]（解锁、进入日记本、配对）允许指纹 / 面容快捷
//   解锁；
// - [IdentityPurpose.sensitive]（关闭应用锁、切换验证方式、修改密码）只认
//   应用密码：拿到已解锁手机的人不能靠主人的指纹改掉密码。
//
// 存储加载失败时按系统验证处理：仍然要验证，不会因此放行。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_passcode/app_passcode_store.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/device_auth_service.dart';
import '../pages/passcode_verify_page.dart';

/// 验证用途：决定应用密码方式下能否用指纹 / 面容代替密码。
enum IdentityPurpose { unlock, sensitive }

/// 见文件头注释。
class IdentityVerifier {
  IdentityVerifier(this._ref);

  final Ref _ref;

  DeviceAuthService get _deviceAuth => _ref.read(deviceAuthServiceProvider);

  /// 当前的密码存储；加载失败为 null（按系统验证）。
  Future<AppPasscodeStore?> store() async {
    try {
      return await _ref.read(appPasscodeStoreProvider.future);
    } catch (_) {
      return null;
    }
  }

  Future<AppVerificationMethod> method() async =>
      (await store())?.config.method ?? AppVerificationMethod.system;

  /// 现在能不能验证身份：设了应用密码，或系统能弹出验证（设置了锁屏密码）。
  /// 不能时应用锁自动解除、上锁的日记本打不开。
  Future<bool> isAvailable() async {
    if ((await store())?.config.hasPasscode ?? false) {
      return true;
    }
    return _deviceAuth.isSupported();
  }

  /// 按当前验证方式验证一次。[reason] 为系统验证面板或密码页上的说明。
  ///
  /// 系统验证中途切到后台视为取消（与进入上锁日记本同一口径），由用户重新
  /// 发起；应用密码页是普通路由，切到后台再回来仍停在页面上。
  Future<bool> verify(
    BuildContext context, {
    required String reason,
    IdentityPurpose purpose = IdentityPurpose.unlock,
  }) async {
    final passcodeStore = await store();
    if (passcodeStore == null || !passcodeStore.config.hasPasscode) {
      return _deviceAuth.authenticate(
        reason: reason,
        persistAcrossBackgrounding: false,
      );
    }
    if (!context.mounted) {
      return false;
    }
    return PasscodeVerifyPage.open(
      context,
      reason: reason,
      allowBiometric: purpose == IdentityPurpose.unlock,
    );
  }

  /// 应用密码方式下能否用指纹 / 面容快捷解锁：开着开关、平台支持只认生物
  /// 识别的验证、设备登记了生物识别。
  Future<bool> biometricShortcutAvailable() async {
    final config = (await store())?.config;
    if (config == null || !config.hasPasscode || !config.biometric) {
      return false;
    }
    if (!AppPlatform.supportsBiometricOnly) {
      return false;
    }
    return _deviceAuth.canUseBiometrics();
  }

  /// 用指纹 / 面容验证；通过时清零输错记录（主人已证明身份）。
  Future<bool> authenticateBiometric({
    required String reason,
    bool persistAcrossBackgrounding = false,
  }) async {
    final passed = await _deviceAuth.authenticateBiometric(
      reason: reason,
      persistAcrossBackgrounding: persistAcrossBackgrounding,
    );
    if (passed) {
      await (await store())?.resetFailures();
    }
    return passed;
  }

  /// 只走系统验证：系统验证方式的锁屏遮罩（遮罩在 Navigator 之上，不能经
  /// [verify] 打开页面），以及切到应用密码前确认是机主本人。
  Future<bool> verifySystem({
    required String reason,
    bool persistAcrossBackgrounding = false,
  }) => _deviceAuth.authenticate(
    reason: reason,
    persistAcrossBackgrounding: persistAcrossBackgrounding,
  );

  /// 系统能否弹出验证（设备设置了锁屏密码）。
  Future<bool> systemSupported() => _deviceAuth.isSupported();

  /// 设备是否登记了指纹 / 面容（设置页决定要不要显示快捷解锁开关）。
  Future<bool> deviceHasBiometrics() async =>
      AppPlatform.supportsBiometricOnly && await _deviceAuth.canUseBiometrics();
}

/// 统一验证入口；测试一般覆盖下层的 `deviceAuthServiceProvider` 与密码存储。
final identityVerifierProvider = Provider<IdentityVerifier>(
  IdentityVerifier.new,
);

/// 这台设备上能不能上锁（同步，给界面门控用）：设了应用密码，或平台有系统
/// 验证。平台有、但设备没设锁屏密码的情况要到验证时才知道（见
/// [IdentityVerifier.isAvailable]）。
bool identityVerificationPossible(AppPasscodeConfig config) =>
    config.hasPasscode || AppPlatform.supportsDeviceAuth;

/// [identityVerificationPossible] 的 provider，随密码设置变化。
final identityVerificationPossibleProvider = Provider<bool>(
  (Ref ref) =>
      identityVerificationPossible(ref.watch(appPasscodeConfigProvider)),
);
