import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/app_update_state.dart';

/// 当前时间；测试覆盖它来验证自动检查间隔。
final appUpdateClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

/// 应用更新流程，全局单例：离开更新页后下载继续，关于页与设置页的入口
/// 随时显示进度与“有新版本”标记。
final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
      AppUpdateController.new,
    );

/// 应用更新的业务编排（不构建 UI）。
///
/// 输入：[AppUpdateService] 的单步操作与 [SettingsService] 里的本机偏好；
/// 输出：[AppUpdateState]；副作用：读写偏好、缓存目录里的安装包、拉起系统
/// 安装器与设置页。
///
/// 流程（阶段见 [AppUpdatePhase]）：
/// - 检查：按偏好排好线路后查询最新版本，记下检查时间与可用线路；有新版本
///   时挑选本机 ABI 的安装包，若之前已下载并校验过则直接进入待安装；随后
///   清理已安装版本留下的旧安装包；
/// - 下载：自动线路先测速择优，指定线路则不测速；进度节流后写入状态；取消
///   回到“有新版本”并保留进度（`.part` 留着，下次续传）；下载完成后校验
///   SHA-256 与签名，通过即拉起系统安装器；
/// - 安装：Android 8+ 未允许“安装未知应用”时停在待授权，用户从系统设置
///   返回（[handleAppResumed]）后自动继续，不需要再点一次。
/// 所有异步回调写状态前检查 `ref.mounted`。同一时间只允许一个检查或下载，
/// 忙碌时的重复调用直接忽略。
class AppUpdateController extends Notifier<AppUpdateState> {
  AppUpdateCancelToken? _checkToken;
  AppUpdateCancelToken? _downloadToken;
  bool _preferencesLoaded = false;

  /// 本次进程内已弹过提示的版本：自动检查每 2 小时可能跑一次，“以后再说”
  /// 之后不再反复弹出，下次冷启动再提示。
  final Set<String> _promptedVersions = <String>{};

  @override
  AppUpdateState build() {
    // 重建时状态回到默认偏好，须重新从设置读取。
    _preferencesLoaded = false;
    ref.onDispose(() {
      _checkToken?.cancel();
      _downloadToken?.cancel();
    });
    return AppUpdateState(
      supportsInAppInstall: ref
          .read(appUpdateServiceProvider)
          .supportsInAppInstall,
    );
  }

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  DateTime _now() => ref.read(appUpdateClockProvider)();

  Future<AppUpdatePreferences> loadPreferences() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final preferences = AppUpdatePreferences.decode(
      settings.appUpdatePreferencesRaw,
    );
    _preferencesLoaded = true;
    if (ref.mounted && preferences != state.preferences) {
      state = state.copyWith(preferences: preferences);
    }
    return preferences;
  }

  Future<AppUpdatePreferences> _ensurePreferences() async =>
      _preferencesLoaded ? state.preferences : loadPreferences();

  /// 以状态里的最新偏好为基础修改并保存，避免并发的修改（下载中记录可用
  /// 线路、用户同时切换开关）互相覆盖。保存失败只影响下次启动，不打断流程。
  Future<void> _updatePreferences(
    AppUpdatePreferences Function(AppUpdatePreferences current) change,
  ) async {
    final next = change(await _ensurePreferences());
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(preferences: next);
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setAppUpdatePreferencesRaw(next.encode());
    } catch (_) {
      // 偏好写入失败（存储异常）时保留内存中的值，下次修改再写。
    }
  }

  /// 检查更新。[silent] 用于自动检查：过程不切到“检查中”（更新页开着时
  /// 不闪烁、操作按钮不消失），失败时保持原状态，不在入口上显示“检查失败”
  /// 打扰用户；只有拿到结果才更新状态。同一时间只跑一个检查。
  Future<void> check({
    required String languageCode,
    bool silent = false,
  }) async {
    if (state.busy || _checkToken != null) {
      return;
    }
    final previous = state;
    final token = _checkToken = AppUpdateCancelToken();
    if (!silent) {
      state = state.copyWith(
        phase: AppUpdatePhase.checking,
        failure: () => null,
      );
    }
    try {
      final service = _service;
      final installed = await service.installedApp();
      final preferences = await _ensurePreferences();
      final outcome = await service.fetchLatest(
        sources: AppUpdateSource.ordered(preferences),
        languageCode: languageCode,
        cancelToken: token,
      );
      final checkedAt = _now();
      await _updatePreferences(
        (current) => current.copyWith(
          lastCheckedAt: checkedAt,
          lastGoodSourceId: outcome.source.id,
        ),
      );
      final release = outcome.release;
      // 静默检查期间用户已经开始了别的操作（如点了下载）：不覆盖其状态。
      bool superseded() => silent && state.phase != previous.phase;
      if (!release.version.isNewerThan(installed.version)) {
        if (!ref.mounted || superseded()) return;
        state = state.copyWith(
          phase: AppUpdatePhase.upToDate,
          installed: installed,
          release: () => release,
          asset: () => null,
          progress: () => null,
          apkPath: () => null,
          checkedAt: checkedAt,
        );
        unawaited(service.cleanUp(installed: installed.version));
        return;
      }
      final asset = release.assetFor(await service.supportedAbis());
      final downloaded = asset == null
          ? null
          : await service.findDownloaded(release, asset);
      if (!ref.mounted || superseded()) return;
      final sameDownload =
          previous.release?.version == release.version &&
          previous.asset?.name == asset?.name;
      state = state.copyWith(
        phase: downloaded == null
            ? AppUpdatePhase.available
            : AppUpdatePhase.readyToInstall,
        installed: installed,
        release: () => release,
        asset: () => asset,
        progress: () => sameDownload ? previous.progress : null,
        apkPath: () => downloaded?.path,
        checkedAt: checkedAt,
      );
      unawaited(service.cleanUp(installed: installed.version, keep: release));
    } catch (error) {
      // 静默检查没有改动过状态，失败时保持原样。
      if (!ref.mounted || silent) return;
      final kind = error is AppUpdateException
          ? error.kind
          : AppUpdateFailureKind.network;
      if (kind == AppUpdateFailureKind.cancelled) {
        state = previous.copyWith(preferences: state.preferences);
        return;
      }
      state = state.copyWith(
        phase: AppUpdatePhase.failed,
        failure: () => AppUpdateFailure(kind, AppUpdateStage.check),
      );
    } finally {
      if (identical(_checkToken, token)) {
        _checkToken = null;
      }
    }
  }

  /// 自动检查（冷启动与回到前台时）：未开启或距上次检查不足
  /// [AppUpdatePreferences.autoCheckInterval] 时不请求（只清理已安装版本的
  /// 安装包）；正在下载、校验或已有待安装的安装包时也不打扰。有未被跳过、
  /// 本次进程内还没提示过的新版本时返回它，由首页决定是否提示。
  ///
  /// 只在支持应用内安装的平台（Android）进行：Release 只发布 APK，其他平台
  /// 提示了也无从更新。
  Future<AppUpdateRelease?> autoCheck({required String languageCode}) async {
    if (!_service.supportsInAppInstall) {
      return null;
    }
    final preferences = await _ensurePreferences();
    if (state.busy ||
        _checkToken != null ||
        state.phase == AppUpdatePhase.readyToInstall ||
        !preferences.shouldAutoCheck(_now())) {
      try {
        final service = _service;
        final installed = await service.installedApp();
        await service.cleanUp(installed: installed.version);
      } catch (_) {
        // 清理只是回收缓存，读不到本机版本时下次再清。
      }
      return null;
    }
    await check(languageCode: languageCode, silent: true);
    final current = state;
    if (!ref.mounted ||
        !current.hasUpdate ||
        current.isSkipped ||
        _promptedVersions.contains(current.release!.version.toString()) ||
        (current.phase != AppUpdatePhase.available &&
            current.phase != AppUpdatePhase.readyToInstall)) {
      return null;
    }
    return current.release;
  }

  /// 记下已为 [release] 弹出过提示（本次进程内不再自动提示）。
  void markPrompted(AppUpdateRelease release) =>
      _promptedVersions.add(release.version.toString());

  Future<void> download() async {
    final release = state.release;
    final asset = state.asset;
    final installed = state.installed;
    if (release == null || asset == null || installed == null || state.busy) {
      return;
    }
    final preferences = await _ensurePreferences();
    final token = _downloadToken = AppUpdateCancelToken();
    state = state.copyWith(
      phase: AppUpdatePhase.downloading,
      failure: () => null,
      awaitingInstallPermission: false,
    );
    try {
      final service = _service;
      final file = await service.download(
        release: release,
        asset: asset,
        sources: AppUpdateSource.ordered(preferences),
        // 用户指定了线路就照用，不再测速改顺序。
        probe: preferences.sourceId == AppUpdatePreferences.autoSource,
        cancelToken: token,
        onProgress: (progress) {
          if (ref.mounted && state.phase == AppUpdatePhase.downloading) {
            state = state.copyWith(progress: () => progress);
          }
        },
        onSourceSucceeded: (source) => unawaited(
          _updatePreferences(
            (current) => current.copyWith(lastGoodSourceId: source.id),
          ),
        ),
      );
      if (!ref.mounted) return;
      state = state.copyWith(phase: AppUpdatePhase.verifying);
      await service.verifyInstallable(file, installed);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: AppUpdatePhase.readyToInstall,
        apkPath: () => file.path,
      );
      await install();
    } catch (error) {
      if (!ref.mounted) return;
      final kind = error is AppUpdateException
          ? error.kind
          : AppUpdateFailureKind.network;
      if (kind == AppUpdateFailureKind.cancelled) {
        state = state.copyWith(phase: AppUpdatePhase.available);
        return;
      }
      // 校验或签名不符时已删除文件，进度不再有意义。
      final discarded =
          kind == AppUpdateFailureKind.integrity ||
          kind == AppUpdateFailureKind.signatureMismatch ||
          kind == AppUpdateFailureKind.notNewer;
      state = state.copyWith(
        phase: AppUpdatePhase.failed,
        failure: () => AppUpdateFailure(kind, AppUpdateStage.download),
        progress: discarded ? () => null : null,
      );
    } finally {
      if (identical(_downloadToken, token)) {
        _downloadToken = null;
      }
    }
  }

  void cancelDownload() => _downloadToken?.cancel();

  /// 打开系统安装器；未授权“安装未知应用”时停在待授权。
  Future<void> install() async {
    final path = state.apkPath;
    if (path == null || state.phase != AppUpdatePhase.readyToInstall) {
      return;
    }
    final service = _service;
    if (!await service.canRequestPackageInstalls()) {
      if (ref.mounted) {
        state = state.copyWith(awaitingInstallPermission: true);
      }
      return;
    }
    try {
      final opened = await service.install(path);
      if (!ref.mounted) return;
      state = opened
          ? state.copyWith(awaitingInstallPermission: false)
          : _installFailed();
    } on PlatformException catch (error) {
      if (!ref.mounted) return;
      state = error.code == 'permission_required'
          ? state.copyWith(awaitingInstallPermission: true)
          : _installFailed();
    }
  }

  AppUpdateState _installFailed() => state.copyWith(
    phase: AppUpdatePhase.failed,
    failure: () => const AppUpdateFailure(
      AppUpdateFailureKind.installUnavailable,
      AppUpdateStage.install,
    ),
  );

  /// 打开“安装未知应用”设置；打不开时返回 false（界面提示手动前往）。
  Future<bool> openInstallPermissionSettings() =>
      _service.openInstallPermissionSettings();

  /// 应用回到前台：若正等待安装授权且用户已允许，自动继续安装。
  Future<void> handleAppResumed() async {
    if (!state.awaitingInstallPermission ||
        state.phase != AppUpdatePhase.readyToInstall) {
      return;
    }
    if (await _service.canRequestPackageInstalls() && ref.mounted) {
      state = state.copyWith(awaitingInstallPermission: false);
      await install();
    }
  }

  /// 按失败所在的步骤重试。
  Future<void> retry({required String languageCode}) async {
    switch (state.failure?.stage) {
      case AppUpdateStage.download:
        await download();
      case AppUpdateStage.install:
        state = state.copyWith(
          phase: AppUpdatePhase.readyToInstall,
          failure: () => null,
        );
        await install();
      case AppUpdateStage.check || null:
        await check(languageCode: languageCode);
    }
  }

  Future<void> skipCurrentVersion() async {
    final release = state.release;
    if (release == null) {
      return;
    }
    await _updatePreferences(
      (current) =>
          current.copyWith(skippedVersion: () => release.version.toString()),
    );
  }

  Future<void> setAutoCheck(bool enabled) =>
      _updatePreferences((current) => current.copyWith(autoCheck: enabled));

  /// 设置下载线路；[customMirror] 为新填写的自定义镜像前缀（已校验），为
  /// null 时保留原值，切到其他线路后还能切回来。
  Future<void> setSource(String sourceId, {String? customMirror}) =>
      _updatePreferences(
        (current) => current.copyWith(
          sourceId: sourceId,
          customMirror: () => customMirror ?? current.customMirror,
        ),
      );
}
