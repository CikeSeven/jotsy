import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_checker.dart';
import 'app_update_downloader.dart';
import 'app_update_http.dart';
import 'app_update_installer.dart';
import 'app_update_models.dart';
import 'app_update_sources.dart';

export 'app_update_checker.dart' show AppUpdateCheckOutcome;
export 'app_update_download_progress.dart' show AppUpdateDownloadProgress;
export 'app_update_http.dart'
    show AppUpdateCancelToken, AppUpdateException, AppUpdateFailureKind;
export 'app_update_models.dart';
export 'app_update_preferences.dart';
export 'app_update_release_parsers.dart';
export 'app_update_sources.dart';

/// 本机已安装的应用。
class InstalledApp {
  const InstalledApp({required this.version, required this.packageName});

  final AppVersion version;
  final String packageName;
}

/// 应用更新服务：组合版本读取、检查（[AppUpdateChecker]）、下载与校验
/// （[AppUpdateDownloader]）和原生安装（[AppUpdateInstaller]）。
///
/// 只做单步操作、不持有流程状态；检查 → 下载 → 安装的编排、偏好读写与
/// 界面状态由 `AppUpdateController` 负责。测试以假实现替换整个服务。
class AppUpdateService {
  AppUpdateService({
    AppUpdateChecker? checker,
    AppUpdateDownloader? downloader,
    AppUpdateInstaller? installer,
    Future<InstalledApp> Function()? readInstalledApp,
  }) : _checker = checker ?? AppUpdateChecker(),
       _downloader = downloader ?? AppUpdateDownloader(),
       _installer = installer ?? const AppUpdateInstaller(),
       _readInstalledApp = readInstalledApp ?? _readFromPlatform;

  final AppUpdateChecker _checker;
  final AppUpdateDownloader _downloader;
  final AppUpdateInstaller _installer;
  final Future<InstalledApp> Function() _readInstalledApp;

  static Future<InstalledApp> _readFromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber.trim());
    final parsed = AppVersion.tryParse(info.version);
    return InstalledApp(
      version: parsed == null
          ? AppVersion(0, 0, 0, build: build)
          : AppVersion(
              parsed.major,
              parsed.minor,
              parsed.patch,
              preRelease: parsed.preRelease,
              build: build,
            ),
      packageName: info.packageName,
    );
  }

  Future<InstalledApp> installedApp() => _readInstalledApp();

  /// 是否支持应用内下载安装（Android）；其他平台只提供打开 Release 页面。
  bool get supportsInAppInstall => _installer.isSupported;

  Future<AppUpdateCheckOutcome> fetchLatest({
    required List<AppUpdateSource> sources,
    required String languageCode,
    AppUpdateCancelToken? cancelToken,
  }) {
    return _checker.fetchLatest(
      sources: sources,
      languageCode: languageCode,
      cancelToken: cancelToken,
    );
  }

  Future<List<String>> supportedAbis() => _installer.supportedAbis();

  Future<File?> findDownloaded(
    AppUpdateRelease release,
    AppUpdateAsset asset,
  ) => _downloader.findDownloaded(release, asset);

  Future<File> download({
    required AppUpdateRelease release,
    required AppUpdateAsset asset,
    required List<AppUpdateSource> sources,
    required void Function(AppUpdateDownloadProgress progress) onProgress,
    required bool probe,
    AppUpdateCancelToken? cancelToken,
    void Function(AppUpdateSource source)? onSourceSucceeded,
  }) {
    return _downloader.download(
      release: release,
      asset: asset,
      sources: sources,
      onProgress: onProgress,
      probe: probe,
      cancelToken: cancelToken,
      onSourceSucceeded: onSourceSucceeded,
    );
  }

  Future<void> cleanUp({
    required AppVersion installed,
    AppUpdateRelease? keep,
  }) => _downloader.cleanUp(installed: installed, keep: keep);

  /// 安装前确认能覆盖安装：包名一致、签名相同、版本更高。签名或包名
  /// 不符（例如别人重新打包）时删除安装包并报错，而不是让系统安装器只给
  /// 一句“应用未安装”。原生读不到信息时不拦截，交给系统安装器判断。
  Future<void> verifyInstallable(File apk, InstalledApp installed) async {
    final info = await _installer.inspectApk(apk.path);
    if (info == null) {
      return;
    }
    AppUpdateFailureKind? failure;
    if (info.packageName != installed.packageName || info.sameSigner == false) {
      failure = AppUpdateFailureKind.signatureMismatch;
    } else if (info.versionCode <= info.installedVersionCode) {
      failure = AppUpdateFailureKind.notNewer;
    }
    if (failure != null) {
      try {
        await apk.delete();
      } on FileSystemException {
        // 删除失败只多占缓存，下次启动清理。
      }
      throw AppUpdateException(failure);
    }
  }

  Future<bool> canRequestPackageInstalls() =>
      _installer.canRequestPackageInstalls();

  Future<bool> openInstallPermissionSettings() =>
      _installer.openInstallPermissionSettings();

  Future<bool> install(String path) => _installer.install(path);
}
