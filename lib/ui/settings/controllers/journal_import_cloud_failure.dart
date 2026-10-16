import '../../../core/services/journal_import_cloud_http.dart';
import '../../../l10n/app_localizations.dart';

/// 云端读取失败的提示文案；[platformName] 是来源应用的展示名称。
String describeCloudNoteFailure(
  AppLocalizations l10n,
  CloudNoteException error,
  String platformName,
) {
  return switch (error.failure) {
    CloudNoteFailure.sessionExpired => l10n.cloudErrorSession,
    CloudNoteFailure.forbidden => l10n.cloudErrorForbidden,
    CloudNoteFailure.rateLimited => l10n.cloudErrorRateLimited,
    CloudNoteFailure.serverError => l10n.cloudErrorServer,
    CloudNoteFailure.rejected => l10n.cloudErrorRejected,
    CloudNoteFailure.network => l10n.cloudErrorNetwork,
    CloudNoteFailure.protocolChanged => l10n.cloudErrorProtocol(platformName),
    CloudNoteFailure.unsupportedAccount => l10n.cloudErrorUnsupportedAccount(
      platformName,
    ),
  };
}
