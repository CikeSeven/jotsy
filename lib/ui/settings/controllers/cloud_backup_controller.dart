import 'package:flutter/widgets.dart';

import '../../../core/services/cloud_backup_drive.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_oauth.dart';
import '../../../core/services/cloud_backup_service.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/backup_password_dialog.dart';
import '../widgets/cloud_backup_authorization_dialogs.dart';
import '../widgets/cloud_backup_dialogs.dart';
import '../widgets/cloud_backup_labels.dart';
import 'backup_import_flow.dart';
import 'cloud_backup_busy.dart';
import 'cloud_backup_failure.dart';

export 'cloud_backup_busy.dart' show CloudBackupHost;

/// 网盘备份的业务流程编排（不构建 UI）；增量备份的流程见
/// `CloudIncrementalController`。
///
/// - 上传完整 ZIP：可选密码 → 导出完整备份 ZIP → 上传（遮罩显示百分比）；
/// - 恢复：只下载一次到临时文件 → 判断加密并按需输入密码 → 只读预检 →
///   [chooseBackupImportMode] 选择合并或覆盖（覆盖须经严重警告）→ 按所选
///   方式恢复；任何一步取消都不写入数据，临时文件总会删除；
/// - 授权：按网盘的授权方式弹出设备码或授权码对话框，拿到令牌后校验备份
///   目录并保存备份位置。
/// 忙碌遮罩只盖在耗时步骤上，弹窗出现前先撤下。
class CloudBackupController with CloudBackupBusyRunner {
  CloudBackupController(this.host);

  @override
  final CloudBackupHost host;

  /// 保存（新增或更新）备份位置；不发网络请求。
  Future<bool> saveTarget(CloudBackupTarget target, {bool notify = true}) {
    final l10n = host.context.l10n;
    return runBusy(l10n.cloudBackupBusySave, () async {
      final service = await this.service();
      await service.targets.saveTarget(target);
      if (notify) host.showSnack(l10n.cloudBackupConfigSaved);
    });
  }

  Future<bool> testConnection(CloudBackupTarget target) {
    final l10n = host.context.l10n;
    return runBusy(l10n.cloudBackupBusyTest, () async {
      final service = await this.service();
      await service.testConnection(target);
      host.showSnack(l10n.cloudBackupConnectionOk);
    });
  }

  /// 读取远程备份列表（完整 ZIP 与增量备份）；失败时提示并返回 null。
  Future<CloudBackupListing?> listBackups(
    CloudBackupTarget target, {
    bool showBusy = true,
  }) async {
    final l10n = host.context.l10n;
    CloudBackupListing? listing;
    Future<void> action() async {
      listing = await (await service()).listBackups(target);
    }

    if (showBusy) {
      await runBusy(l10n.cloudBackupBusyRefresh, action);
    } else {
      await action();
    }
    return listing;
  }

  Future<bool> upload(CloudBackupTarget target) async {
    if (host.busy) return false;
    final context = host.context;
    final l10n = context.l10n;
    final password = await showBackupPasswordDialog(
      context,
      purpose: BackupPasswordPurpose.export,
      confirmLabel: l10n.cloudBackupUploadBackup,
    );
    if (!context.mounted || password == null) return false;
    return runBusy(l10n.cloudBackupBusyUpload, () async {
      final service = await this.service();
      await service.uploadCurrentBackup(
        target,
        zipPassword: password,
        onProgress: progressLabel(l10n.cloudBackupBusyUploadProgress),
      );
      host.showSnack(l10n.cloudBackupUploadSuccess);
    });
  }

  Future<void> restore(CloudBackupTarget target, CloudBackupEntry entry) async {
    if (host.busy) return;
    final context = host.context;
    final l10n = context.l10n;
    final service = await this.service();
    if (!context.mounted) return;
    String? password;
    final zipFile = await runBusyResult(
      l10n.cloudBackupBusyDownload,
      () => service.downloadBackup(
        target,
        entry,
        onProgress: progressLabel(l10n.cloudBackupBusyDownloadProgress),
      ),
    );
    if (zipFile == null) return;
    try {
      host.setBusy(true, l10n.backupBusyInspect);
      if (await service.isLocalBackupPasswordProtected(zipFile)) {
        host.setBusy(false);
        if (!context.mounted) return;
        password = await showBackupPasswordDialog(
          context,
          purpose: BackupPasswordPurpose.import,
        );
        if (!context.mounted || password == null) return;
        host.setBusy(true, l10n.backupBusyInspect);
      }
      final preview = await service.inspectLocalBackup(
        zipFile: zipFile,
        zipPassword: password,
      );
      host.setBusy(false);
      if (!context.mounted) return;
      final mode = await chooseBackupImportMode(context, preview);
      if (!context.mounted || mode == null) return;
      host.setBusy(true, l10n.cloudBackupBusyRestore);
      final result = await service.restoreFromLocalBackup(
        zipFile: zipFile,
        zipPassword: password,
        mode: mode,
      );
      if (context.mounted) {
        host.showSnack(
          describeBackupImportResult(
            l10n,
            result,
            replaceAllMessage: l10n.cloudBackupRestoreSuccess,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        host.showSnack(describeCloudBackupError(l10n, error));
      }
    } finally {
      host.setBusy(false);
      if (await zipFile.exists()) await zipFile.delete();
    }
  }

  Future<bool> delete(CloudBackupTarget target, CloudBackupEntry entry) async {
    if (host.busy) return false;
    final context = host.context;
    final l10n = context.l10n;
    if (!await confirmCloudBackupDelete(context, entry.fileName) ||
        !context.mounted) {
      return false;
    }
    return runBusy(l10n.cloudBackupBusyDelete, () async {
      final service = await this.service();
      await service.deleteBackup(target, entry);
      host.showSnack(l10n.cloudBackupDeleteSuccess);
    });
  }

  /// 只移除本机保存的连接与授权，不删除网盘里的备份文件。
  Future<bool> removeTarget(CloudBackupTarget target) async {
    if (host.busy) return false;
    final context = host.context;
    final l10n = context.l10n;
    if (!await confirmCloudBackupRemoveTarget(context) || !context.mounted) {
      return false;
    }
    return runBusy(l10n.cloudBackupBusySave, () async {
      await (await service()).removeTarget(target.id);
      host.showSnack(l10n.cloudBackupRemoved);
    });
  }

  /// 授权一个网盘；[existing] 不为空时是重新授权。成功返回保存后的位置。
  Future<CloudBackupTarget?> authorize(
    CloudBackupKind kind, {
    CloudBackupTarget? existing,
  }) async {
    if (host.busy) return null;
    final context = host.context;
    final l10n = context.l10n;
    final name = cloudBackupKindName(l10n, kind);
    final service = await this.service();
    if (!context.mounted) return null;
    final CloudDriveAuthorizationSession session;
    try {
      session = service.beginAuthorization(kind);
    } catch (error) {
      host.showSnack(describeCloudBackupError(l10n, error));
      return null;
    }
    try {
      final token = await _obtainToken(context, session.method, name);
      if (token == null || !context.mounted) return null;
      final granted = token;
      return await runBusyResult(l10n.cloudBackupBusyAuthorize, () async {
        final target = await service.completeAuthorization(
          kind: kind,
          token: granted,
          existing: existing,
        );
        host.showSnack(l10n.cloudBackupAuthorized(name));
        return target;
      });
    } on CloudAuthorizationFailed catch (failed) {
      if (context.mounted) {
        host.showSnack(describeCloudBackupError(l10n, failed.error));
      }
      return null;
    } finally {
      session.close();
    }
  }

  /// 按授权方式取得令牌，用户取消返回 null。
  ///
  /// 系统授权（Play 服务账号选择器）不可用时改走 [CloudNativeAuthorization.fallback]
  /// （设备码）；没有备用方式时以 [CloudBackupFailure.platformUnavailable]
  /// 提示。系统授权自带界面，不盖忙碌遮罩。
  Future<CloudOAuthToken?> _obtainToken(
    BuildContext context,
    CloudDriveAuthorization method,
    String name,
  ) async {
    switch (method) {
      case final CloudDeviceCodeAuthorization method:
        return showCloudDeviceAuthorizationDialog(
          context,
          method: method,
          providerName: name,
        );
      case final CloudCodePasteAuthorization method:
        return showCloudCodePasteDialog(
          context,
          method: method,
          providerName: name,
        );
      case final CloudNativeAuthorization method:
        try {
          return await method.authorize();
        } on CloudNativeAuthUnavailable catch (error) {
          final fallback = method.fallback;
          if (fallback == null) {
            throw CloudAuthorizationFailed(
              CloudBackupException(
                CloudBackupFailure.platformUnavailable,
                error.detail,
              ),
            );
          }
          if (!context.mounted) return null;
          return _obtainToken(context, fallback, name);
        }
    }
  }
}
