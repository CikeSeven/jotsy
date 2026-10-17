import '../../../core/services/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/app_update_state.dart';

/// 应用更新界面的展示文案：线路名称、失败说明。镜像以域名显示（专有名词
/// 不翻译）。

String appUpdateSourceName(AppLocalizations l10n, AppUpdateSource source) {
  if (source.isDirect) {
    return l10n.appUpdateSourceDirect;
  }
  return source.host;
}

/// 设置项副标题：当前选择的线路。
String appUpdatePreferredSourceLabel(
  AppLocalizations l10n,
  AppUpdatePreferences preferences,
) {
  switch (preferences.sourceId) {
    case AppUpdatePreferences.autoSource:
      return l10n.appUpdateSourceAuto;
    case AppUpdateSource.customId:
      final custom = AppUpdateSource.custom(preferences.customMirror);
      return custom == null
          ? l10n.appUpdateSourceAuto
          : '${l10n.appUpdateSourceCustom} · ${custom.host}';
  }
  for (final source in AppUpdateSource.builtInSources) {
    if (source.id == preferences.sourceId) {
      return appUpdateSourceName(l10n, source);
    }
  }
  return l10n.appUpdateSourceAuto;
}

String appUpdateFailureTitle(AppLocalizations l10n, AppUpdateFailure failure) {
  return switch (failure.stage) {
    AppUpdateStage.check => l10n.appUpdateFailedCheckTitle,
    AppUpdateStage.download => l10n.appUpdateFailedDownloadTitle,
    AppUpdateStage.install => l10n.appUpdateFailedInstallTitle,
  };
}

String appUpdateFailureMessage(
  AppLocalizations l10n,
  AppUpdateFailureKind kind,
) {
  return switch (kind) {
    AppUpdateFailureKind.network ||
    AppUpdateFailureKind.cancelled => l10n.appUpdateFailureNetwork,
    AppUpdateFailureKind.notFound => l10n.appUpdateFailureNotFound,
    AppUpdateFailureKind.noCompatibleApk => l10n.appUpdateNoCompatibleApk,
    AppUpdateFailureKind.integrity => l10n.appUpdateFailureIntegrity,
    AppUpdateFailureKind.signatureMismatch => l10n.appUpdateFailureSignature,
    AppUpdateFailureKind.notNewer => l10n.appUpdateFailureNotNewer,
    AppUpdateFailureKind.storage => l10n.appUpdateFailureStorage,
    AppUpdateFailureKind.installUnavailable =>
      l10n.appUpdateFailureInstallUnavailable,
  };
}

/// 重试有意义的失败；签名不符、并非新版本时重下也是同一个文件。
bool appUpdateFailureRetryable(AppUpdateFailureKind kind) {
  return switch (kind) {
    AppUpdateFailureKind.signatureMismatch ||
    AppUpdateFailureKind.notNewer ||
    AppUpdateFailureKind.noCompatibleApk => false,
    _ => true,
  };
}

/// 版本号展示：`0.6.0 (17)`；没有构建号时只显示版本名。
String appVersionLabel(AppVersion version) =>
    version.build == null ? version.name : '${version.name} (${version.build})';
