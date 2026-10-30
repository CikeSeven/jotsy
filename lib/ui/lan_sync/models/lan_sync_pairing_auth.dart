// 确认配对前要不要先验证身份（docs/lan_sync.md §8）。纯函数，无副作用。
//
// 配对之后两台设备会双向合并全部日记，包括上锁日记本里的内容；本机既然
// 用应用锁或上锁日记本挡着别人，确认把这些内容交给另一台设备之前就应当
// 和打开上锁日记本一样先验证身份。平台不支持系统身份验证（Linux）时不验证、
// 也不额外提示（安全说明块已写明会合并私密日记本）。

import '../../../core/database/app_database.dart';
import '../../notebooks/viewmodels/notebook_view.dart';

/// 一次验证的结果；配对面板据此决定确认配对，或停在核对码上并提示。
enum LanSyncPairingAuthOutcome {
  /// 不需要验证，或验证通过：可以确认配对。
  allowed,

  /// 用户取消或验证没有通过。
  failed,

  /// 需要验证，但设备没有设置锁屏密码，系统弹不出验证（与上锁日记本同一
  /// 口径：不放行）。
  unsupported,
}

/// 是否需要验证：平台支持身份验证，且开启了应用锁或存在上锁的日记本。
///
/// 上锁看生效可见性：上级上了锁的子本同样算（它的上级本身也会被数到，
/// 这里看生效值只是与 `notebookRequiresAuth` 同一口径）。
bool lanSyncPairingRequiresAuth({
  required bool platformSupportsAuth,
  required bool appLockEnabled,
  required Iterable<NotebookView> notebooks,
}) {
  if (!platformSupportsAuth) return false;
  if (appLockEnabled) return true;
  return notebooks.any(
    (NotebookView notebook) =>
        notebook.effectiveVisibility == NotebookVisibility.locked,
  );
}
