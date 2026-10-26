import 'dart:async';
import 'dart:io';

import 'package:node_diary/core/services/app_update_service.dart';

/// 可编排的假更新服务：检查结果、下载过程与安装权限都由测试设定，并记录
/// 调用，供控制器与页面测试使用。
class FakeAppUpdateService implements AppUpdateService {
  FakeAppUpdateService({
    this.installed = const InstalledApp(
      version: AppVersion(0, 6, 0, build: 17),
      packageName: 'com.jotsy.diary',
    ),
    this.supportsInAppInstall = true,
    this.abis = const <String>['arm64-v8a', 'armeabi-v7a'],
  });

  InstalledApp installed;
  List<String> abis;

  @override
  bool supportsInAppInstall;

  /// 下一次检查的结果；为 null 时抛出 [checkFailure]。
  AppUpdateCheckOutcome? outcome;
  AppUpdateFailureKind checkFailure = AppUpdateFailureKind.network;

  /// 设置后检查会一直等到它完成，用来观察检查进行中的状态。
  Completer<void>? fetchGate;
  int fetchCount = 0;
  List<AppUpdateSource>? lastSources;

  /// 下载：完成 [downloadCompleter] 时结束；为 null 时立即返回 [downloadedFile]。
  Completer<File>? downloadCompleter;
  File? downloadedFile;
  File? alreadyDownloaded;
  bool? lastProbe;
  void Function(AppUpdateDownloadProgress progress)? onProgress;
  AppUpdateCancelToken? lastDownloadToken;
  AppUpdateFailureKind? verifyFailure;

  bool canInstall = true;
  bool installOpens = true;
  int installCount = 0;
  int openSettingsCount = 0;
  final List<AppVersion> cleanedUpFor = <AppVersion>[];

  @override
  Future<InstalledApp> installedApp() async => installed;

  @override
  Future<AppUpdateCheckOutcome> fetchLatest({
    required List<AppUpdateSource> sources,
    required String languageCode,
    AppUpdateCancelToken? cancelToken,
  }) async {
    fetchCount++;
    lastSources = sources;
    await fetchGate?.future;
    final result = outcome;
    if (result == null) {
      throw AppUpdateException(checkFailure);
    }
    return result;
  }

  @override
  Future<List<String>> supportedAbis() async => abis;

  @override
  Future<File?> findDownloaded(
    AppUpdateRelease release,
    AppUpdateAsset asset,
  ) async => alreadyDownloaded;

  @override
  Future<File> download({
    required AppUpdateRelease release,
    required AppUpdateAsset asset,
    required List<AppUpdateSource> sources,
    required void Function(AppUpdateDownloadProgress progress) onProgress,
    required bool probe,
    AppUpdateCancelToken? cancelToken,
    void Function(AppUpdateSource source)? onSourceSucceeded,
  }) async {
    lastProbe = probe;
    lastDownloadToken = cancelToken;
    this.onProgress = onProgress;
    final completer = downloadCompleter;
    if (completer == null) {
      onSourceSucceeded?.call(sources.first);
      return downloadedFile ?? File('/cache/app_update/0.6.1+18-arm64-v8a.apk');
    }
    unawaited(
      cancelToken?.whenCancelled.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(
            const AppUpdateException(AppUpdateFailureKind.cancelled),
          );
        }
      }),
    );
    final file = await completer.future;
    onSourceSucceeded?.call(sources.first);
    return file;
  }

  @override
  Future<void> cleanUp({
    required AppVersion installed,
    AppUpdateRelease? keep,
  }) async {
    cleanedUpFor.add(installed);
  }

  @override
  Future<void> verifyInstallable(File apk, InstalledApp installed) async {
    final failure = verifyFailure;
    if (failure != null) {
      throw AppUpdateException(failure);
    }
  }

  @override
  Future<bool> canRequestPackageInstalls() async => canInstall;

  @override
  Future<bool> openInstallPermissionSettings() async {
    openSettingsCount++;
    return true;
  }

  @override
  Future<bool> install(String path) async {
    installCount++;
    return installOpens;
  }
}

/// 测试用的新版本（v0.6.1+18，三个分 ABI 安装包，带中英文说明）。
/// [desktop] 为 true 时另带 Windows 安装程序 / 便携版与 Linux 压缩包。
AppUpdateRelease fakeRelease({
  String version = '0.6.1+18',
  bool desktop = false,
}) {
  final parsed = AppVersion.tryParse(version)!;
  final tag = 'v${parsed.name}';
  return AppUpdateRelease(
    version: parsed,
    tag: tag,
    publishedAt: DateTime.utc(2026, 10, 20),
    notes: const <String, String>{
      'zh': '## 新增\n- 应用内更新与下载线路\n- **镜像**测速\n\n## 修复\n1. 修复检查更新失败',
      'en':
          '## New\n- In-app updates and download routes\n- **Mirror** speed tests\n\n'
          '## Fixed\n1. Update checks failing',
    },
    assets: <AppUpdateAsset>[
      for (final abi in const <String>['arm64-v8a', 'armeabi-v7a', 'x86_64'])
        AppUpdateAsset(
          name: 'jotsy-$tag-$abi.apk',
          url: AppUpdateEndpoints.assetUrl(tag, 'jotsy-$tag-$abi.apk'),
          size: 51428875,
          sha256: 'a' * 64,
        ),
    ],
    desktopAssets: <AppUpdateAsset>[
      if (desktop)
        for (final name in <String>[
          'jotsy-$tag-linux-x64.tar.gz',
          'jotsy-$tag-windows-x64-setup.exe',
          'jotsy-$tag-windows-x64.zip',
        ])
          AppUpdateAsset(
            name: name,
            url: AppUpdateEndpoints.assetUrl(tag, name),
            size: 31457280,
            sha256: 'b' * 64,
          ),
    ],
  );
}
