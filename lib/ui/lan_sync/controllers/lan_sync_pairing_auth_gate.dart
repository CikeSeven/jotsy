// 确认配对前的身份验证（docs/lan_sync.md §8）。
//
// - 输入：设备身份验证服务、读取“应用锁是否开启”与书架列表的两个回调、
//   平台是否支持身份验证（默认取 `AppPlatform.supportsDeviceAuth`）；
// - 输出：[LanSyncPairingAuthOutcome]；
// - 副作用：需要时弹出系统身份验证。
//
// 判断时机放在用户点“一致，配对”的那一刻（而不是面板打开时）：应用锁与
// 上锁日记本随时可能被改动，读到的是确认那一刻的状态；不需要验证的绝大
// 多数用户也不会因为面板打开就多读一次数据库。读取失败（设置或书架加载
// 出错）按“需要验证”处理——宁可多验证一次，也不在拿不准时放行。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/device_auth_service.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../models/lan_sync_pairing_auth.dart';

/// 见文件头注释。
class LanSyncPairingAuthGate {
  const LanSyncPairingAuthGate({
    required this.auth,
    required this.loadAppLockEnabled,
    required this.loadNotebooks,
    this.platformSupportsAuth = _platformSupportsAuth,
  });

  final DeviceAuthService auth;
  final Future<bool> Function() loadAppLockEnabled;
  final Future<List<NotebookView>> Function() loadNotebooks;
  final bool Function() platformSupportsAuth;

  static bool _platformSupportsAuth() => AppPlatform.supportsDeviceAuth;

  /// 需要时验证身份；[reason] 为系统验证面板上的说明。
  ///
  /// 验证中途切到后台视为取消（与进入上锁日记本同一口径），回来后由用户
  /// 重新点“一致，配对”。
  Future<LanSyncPairingAuthOutcome> authorize({required String reason}) async {
    if (!platformSupportsAuth()) return LanSyncPairingAuthOutcome.allowed;
    bool required;
    try {
      required = lanSyncPairingRequiresAuth(
        platformSupportsAuth: true,
        appLockEnabled: await loadAppLockEnabled(),
        notebooks: await loadNotebooks(),
      );
    } catch (_) {
      required = true;
    }
    if (!required) return LanSyncPairingAuthOutcome.allowed;
    if (!await auth.isSupported()) return LanSyncPairingAuthOutcome.unsupported;
    final passed = await auth.authenticate(
      reason: reason,
      persistAcrossBackgrounding: false,
    );
    return passed
        ? LanSyncPairingAuthOutcome.allowed
        : LanSyncPairingAuthOutcome.failed;
  }
}

/// 配对前的身份验证门；测试覆盖为带假验证服务的实例。
///
/// 书架取 `notebooksProvider` 的当前一份（它在应用里常驻订阅，通常已经
/// 加载好）；日记本功能关闭时上锁的本子仍然存在、仍会随同步交出去，所以
/// 照样计入。
final lanSyncPairingAuthGateProvider = Provider<LanSyncPairingAuthGate>((
  Ref ref,
) {
  return LanSyncPairingAuthGate(
    auth: ref.read(deviceAuthServiceProvider),
    loadAppLockEnabled: () async =>
        (await ref.read(settingsServiceProvider.future)).isAppLockEnabled,
    loadNotebooks: () => ref.read(notebooksProvider.future),
  );
});
