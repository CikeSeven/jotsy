// 同步引擎的生产装配：解析真实目录与应用版本，接上本地化的冲突副本后缀。
//
// - 输入：数据库、设置服务（同步设置与界面语言）；
// - 输出：一份尚未启动的 [LanSyncService]（由 `EngineLanSyncUiController`
//   启动与关闭）；
// - 副作用：解析 / 创建托管数据根目录与不随备份的状态目录（docs/lan_sync.md
//   §1：引擎各类只经构造参数拿目录，只有这里调用 `appDataRootDirectory()` 与
//   `lanSyncStateDirectory()`）。
//
// 网络、套接字、发现、设备名与编辑会话一律用引擎的生产默认值
// （`LanSyncServiceHooks()`、`EditingSessionRegistry.instance`）。

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_data_directory.dart';
import '../../../core/services/lan_sync/lan_sync_service.dart';
import '../../../core/services/lan_sync/lan_sync_state_directory.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';

/// 冲突副本标题后缀（如“（冲突副本 · ThinkPad）”）：[deviceName] 是副本所
/// 保存版本那一台的设备名，由引擎按败方给出；这里只负责按 [locale] 拼文字。
/// 不支持的语言按英文。
String lanSyncConflictTitleSuffix(Locale locale, String deviceName) {
  final supported = AppLocalizations.delegate.isSupported(locale)
      ? locale
      : const Locale('en');
  return lookupAppLocalizations(
    supported,
  ).lanSyncConflictCopySuffix(deviceName);
}

/// 建一份生产用的同步引擎（不启动）。
///
/// 冲突副本后缀在每次规划时现取 [SettingsService.localeNotifier] 的当前值：
/// 用户在应用运行中切换语言后，之后生成的副本按新语言命名，不冻结在启动
/// 那一刻。应用版本只用于 `sync.hello` 里告诉对方，读不到时为空串。
Future<LanSyncService> createAppLanSyncService({
  required AppDatabase database,
  required SettingsService settings,
}) async {
  final dataRoot = await appDataRootDirectory();
  final stateDir = await lanSyncStateDirectory();
  return LanSyncService(
    database: database,
    dataRoot: dataRoot,
    stateDir: stateDir,
    settings: settings,
    appVersion: await _appVersion(),
    conflictTitleSuffix: (String deviceName) =>
        lanSyncConflictTitleSuffix(settings.localeNotifier.value, deviceName),
  );
}

/// “版本号+构建号”，与关于页同一写法；读取失败为空串。
Future<String> _appVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  } on Object catch (error) {
    debugPrint('LAN sync: app version unavailable: $error');
    return '';
  }
}
