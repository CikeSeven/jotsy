// 确认配对前的身份验证（docs/lan_sync.md §8）。
//
// - 输入：能否验证 / 验证一次的两个回调（默认经 `IdentityVerifier`，按全局
//   验证方式走系统验证或应用密码）、读取“应用锁是否开启”与书架列表的两个
//   回调、这台设备能不能上锁（平台有系统验证，或设了应用密码）；
// - 输出：[LanSyncPairingAuthOutcome]；
// - 副作用：需要时弹出系统身份验证或应用密码页。
//
// 判断时机放在用户点“一致，配对”的那一刻（而不是面板打开时）：应用锁与
// 上锁日记本随时可能被改动，读到的是确认那一刻的状态；不需要验证的绝大
// 多数用户也不会因为面板打开就多读一次数据库。读取失败（设置或书架加载
// 出错）按“需要验证”处理——宁可多验证一次，也不在拿不准时放行。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_password/app_password_store.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../app_lock/controllers/identity_verifier.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../models/lan_sync_pairing_auth.dart';

/// 见文件头注释。
class LanSyncPairingAuthGate {
  const LanSyncPairingAuthGate({
    required this.isAvailable,
    required this.verify,
    required this.loadAppLockEnabled,
    required this.loadNotebooks,
    this.canLockOnThisDevice = _platformSupportsAuth,
  });

  /// 现在能不能验证身份（系统验证方式下设备没有锁屏密码时为 false）。
  final Future<bool> Function() isAvailable;

  /// 验证一次；[BuildContext] 用来打开应用密码页。
  final Future<bool> Function(BuildContext context, String reason) verify;
  final Future<bool> Function() loadAppLockEnabled;
  final Future<List<NotebookView>> Function() loadNotebooks;

  /// 这台设备能不能上锁：不能时（Linux 且没设应用密码）应用锁与上锁日记本
  /// 都用不了，配对不验证。
  final Future<bool> Function() canLockOnThisDevice;

  static Future<bool> _platformSupportsAuth() async =>
      AppPlatform.supportsDeviceAuth;

  /// 需要时验证身份；[reason] 为系统验证面板或密码页上的说明。
  ///
  /// 验证中途切到后台视为取消（与进入上锁日记本同一口径），回来后由用户
  /// 重新点“一致，配对”。
  Future<LanSyncPairingAuthOutcome> authorize(
    BuildContext context, {
    required String reason,
  }) async {
    if (!await canLockOnThisDevice()) return LanSyncPairingAuthOutcome.allowed;
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
    if (!await isAvailable()) return LanSyncPairingAuthOutcome.unsupported;
    if (!context.mounted) return LanSyncPairingAuthOutcome.failed;
    final passed = await verify(context, reason);
    return passed
        ? LanSyncPairingAuthOutcome.allowed
        : LanSyncPairingAuthOutcome.failed;
  }
}

/// 配对前的身份验证门；测试覆盖为带假验证的实例。
///
/// 书架取 `notebooksProvider` 的当前一份（它在应用里常驻订阅，通常已经
/// 加载好）；日记本功能关闭时上锁的本子仍然存在、仍会随同步交出去，所以
/// 照样计入。
final lanSyncPairingAuthGateProvider = Provider<LanSyncPairingAuthGate>((
  Ref ref,
) {
  final verifier = ref.read(identityVerifierProvider);
  return LanSyncPairingAuthGate(
    isAvailable: verifier.isAvailable,
    verify: (BuildContext context, String reason) =>
        verifier.verify(context, reason: reason),
    loadAppLockEnabled: () async =>
        (await ref.read(settingsServiceProvider.future)).isAppLockEnabled,
    loadNotebooks: () => ref.read(notebooksProvider.future),
    canLockOnThisDevice: () async => identityVerificationPossible(
      (await verifier.store())?.config ?? AppPasswordConfig.initial,
    ),
  );
});
