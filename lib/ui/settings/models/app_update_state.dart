import 'package:flutter/foundation.dart';

import '../../../core/services/app_update_service.dart';

/// 更新流程所处的阶段（界面据此切换状态卡片与底部操作）。
///
/// ```text
/// idle ─check→ checking ─┬→ upToDate
///                        ├→ available ─download→ downloading → verifying
///                        │      ↑ 取消（保留进度）            ↓
///                        │      └──────────────────── readyToInstall
///                        └→ failed（检查失败）
/// 下载 / 校验 / 安装失败 → failed（保留 release 与 asset，可重试）
/// ```
enum AppUpdatePhase {
  /// 本次启动还没检查过。
  idle,
  checking,
  upToDate,
  available,
  downloading,

  /// 下载完成，正在计算 SHA-256 与核对签名。
  verifying,

  /// 安装包已就绪，等待（或已打开）系统安装器。
  readyToInstall,
  failed,
}

/// 失败发生在哪一步：决定“重试”是重新检查还是重新下载 / 安装。
enum AppUpdateStage { check, download, install }

@immutable
class AppUpdateFailure {
  const AppUpdateFailure(this.kind, this.stage);

  final AppUpdateFailureKind kind;
  final AppUpdateStage stage;
}

@immutable
class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.preferences = const AppUpdatePreferences(),
    this.installed,
    this.release,
    this.asset,
    this.progress,
    this.apkPath,
    this.failure,
    this.checkedAt,
    this.awaitingInstallPermission = false,
    this.supportsInAppInstall = true,
    this.desktopTarget,
    this.desktopAsset,
  });

  final AppUpdatePhase phase;
  final AppUpdatePreferences preferences;
  final InstalledApp? installed;

  /// 最近一次检查到的最新版本（已是最新时也保留，用于显示版本号）。
  final AppUpdateRelease? release;

  /// 适合本机 ABI 的安装包；为 null 时只能去 Release 页面手动下载。
  final AppUpdateAsset? asset;

  /// 下载进度；取消后仍保留，界面显示“继续下载”与已下载比例。
  final AppUpdateDownloadProgress? progress;

  /// 校验通过的安装包路径。
  final String? apkPath;
  final AppUpdateFailure? failure;

  /// 本次启动内最近一次成功检查的时间。
  final DateTime? checkedAt;

  /// 正在等用户在系统设置里允许“安装未知应用”；从设置返回后自动继续安装。
  final bool awaitingInstallPermission;

  /// 当前平台能否应用内安装（Android）；否则只提供打开 Release 页面。
  final bool supportsInAppInstall;

  /// 桌面平台（Windows / Linux）：新版本改为在浏览器里下载安装包，不显示
  /// 应用内下载、安装与 ABI；其他平台为 null。
  final AppUpdateDesktopTarget? desktopTarget;

  /// 桌面平台要在浏览器里下载的安装包；新版本里没有本平台的安装包（桌面版
  /// 之前的版本）时为 null，界面改为打开发布页面。
  final AppUpdateAsset? desktopAsset;

  /// 有比本机新的版本（含下载中、待安装与下载失败）。
  bool get hasUpdate {
    final release = this.release;
    final installed = this.installed;
    return release != null &&
        installed != null &&
        release.version.isNewerThan(installed.version);
  }

  bool get busy =>
      phase == AppUpdatePhase.checking ||
      phase == AppUpdatePhase.downloading ||
      phase == AppUpdatePhase.verifying;

  /// 当前版本被用户跳过（自动检查不再提示）。
  bool get isSkipped =>
      release != null &&
      preferences.skippedVersion == release!.version.toString();

  AppUpdateState copyWith({
    AppUpdatePhase? phase,
    AppUpdatePreferences? preferences,
    InstalledApp? installed,
    AppUpdateRelease? Function()? release,
    AppUpdateAsset? Function()? asset,
    AppUpdateDownloadProgress? Function()? progress,
    String? Function()? apkPath,
    AppUpdateFailure? Function()? failure,
    DateTime? checkedAt,
    bool? awaitingInstallPermission,
    bool? supportsInAppInstall,
    AppUpdateAsset? Function()? desktopAsset,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      preferences: preferences ?? this.preferences,
      installed: installed ?? this.installed,
      release: release == null ? this.release : release(),
      asset: asset == null ? this.asset : asset(),
      progress: progress == null ? this.progress : progress(),
      apkPath: apkPath == null ? this.apkPath : apkPath(),
      failure: failure == null ? this.failure : failure(),
      checkedAt: checkedAt ?? this.checkedAt,
      awaitingInstallPermission:
          awaitingInstallPermission ?? this.awaitingInstallPermission,
      supportsInAppInstall: supportsInAppInstall ?? this.supportsInAppInstall,
      desktopTarget: desktopTarget,
      desktopAsset: desktopAsset == null ? this.desktopAsset : desktopAsset(),
    );
  }
}
