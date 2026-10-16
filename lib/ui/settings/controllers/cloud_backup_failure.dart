import 'dart:io';

import '../../../core/services/cloud_backup_models.dart';
import '../../../l10n/app_localizations.dart';

/// 网盘备份操作失败的提示文案。
///
/// 只按失败分类给出可操作的说明，不把服务端原文或异常字符串展示给用户
/// （可能含地址、令牌片段，也看不懂）。备份文件本身的问题（密码错误、
/// 文件损坏）来自恢复前的预检，单独说明。
String describeCloudBackupError(AppLocalizations l10n, Object error) {
  final detail = switch (error) {
    CloudBackupException(:final failure) => switch (failure) {
      CloudBackupFailure.config => l10n.cloudBackupErrorConfig,
      CloudBackupFailure.appKeyMissing => l10n.cloudBackupErrorAppKeyMissing,
      CloudBackupFailure.unauthorized => l10n.cloudBackupErrorAuth,
      CloudBackupFailure.sessionExpired => l10n.cloudBackupErrorSessionExpired,
      CloudBackupFailure.authorizationDenied =>
        l10n.cloudBackupErrorAuthorizationDenied,
      CloudBackupFailure.authorizationExpired =>
        l10n.cloudBackupErrorAuthorizationExpired,
      CloudBackupFailure.notFound => l10n.cloudBackupErrorNotFound,
      CloudBackupFailure.storageFull => l10n.cloudBackupErrorStorageFull,
      CloudBackupFailure.fileTooLarge => l10n.cloudBackupErrorFileTooLarge,
      CloudBackupFailure.rateLimited => l10n.cloudBackupErrorRateLimited,
      CloudBackupFailure.network => l10n.cloudBackupErrorNetwork,
      CloudBackupFailure.protocol => l10n.cloudBackupErrorProtocol,
    },
    FormatException(:final message)
        when message.toLowerCase().contains('password') =>
      l10n.cloudBackupErrorPassword,
    FormatException() => l10n.cloudBackupErrorArchive,
    FileSystemException() => l10n.cloudBackupErrorLocalFile,
    _ => l10n.cloudBackupErrorUnknown,
  };
  return l10n.cloudBackupOperationFailed(detail);
}

/// 需要重新授权才能继续的失败（界面据此突出“重新授权”）。
bool cloudBackupNeedsReauthorization(Object error) =>
    error is CloudBackupException &&
    error.failure == CloudBackupFailure.sessionExpired;
