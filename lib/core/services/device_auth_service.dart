import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// 设备身份验证（指纹、面容或锁屏密码）。
///
/// 界面不直接调用：一律经 `IdentityVerifier`（按“验证方式”走系统验证或应用
/// 密码，见 docs/rules/app_lock.md）。
///
/// 应用锁与上锁的日记本共用：两处的口径必须一致——设备“支持”指系统能弹出
/// 验证（生物识别或设备凭据任一可用），验证允许回落到锁屏密码
/// （`biometricOnly: false`）。任何插件异常都按“不支持 / 未通过”处理，
/// 调用方不必再包 try/catch。
class DeviceAuthService {
  DeviceAuthService([LocalAuthentication? localAuthentication])
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  /// 这台设备能否验证身份：设置了锁屏密码，或至少能检查生物识别。
  Future<bool> isSupported() async {
    try {
      if (await _localAuthentication.isDeviceSupported()) {
        return true;
      }
      return await _localAuthentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// 弹出系统验证，[reason] 为系统面板上的说明。通过返回 true；取消、失败
  /// 或插件异常返回 false。
  ///
  /// [persistAcrossBackgrounding] 为 true 时，验证中途切到后台再回来系统会
  /// 继续这次验证（应用锁需要），否则视为取消。
  Future<bool> authenticate({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );
    } catch (_) {
      return false;
    }
  }

  /// 这台设备是否登记了指纹 / 面容等生物识别（应用密码的快捷解锁用）。
  Future<bool> canUseBiometrics() async {
    try {
      if (!await _localAuthentication.canCheckBiometrics) {
        return false;
      }
      final available = await _localAuthentication.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 只用生物识别验证（`biometricOnly: true`，不回落到锁屏密码）：应用密码
  /// 方式下的快捷解锁。平台须为 `AppPlatform.supportsBiometricOnly`。
  Future<bool> authenticateBiometric({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );
    } catch (_) {
      return false;
    }
  }
}

/// 设备身份验证服务；测试覆盖为假的实现。
final deviceAuthServiceProvider = Provider<DeviceAuthService>(
  (Ref ref) => DeviceAuthService(),
);
