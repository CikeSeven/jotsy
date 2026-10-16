import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
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
import 'cloud_backup_failure.dart';

/// 网盘备份页面提供给流程的上下文、忙碌态与提示出口。
///
/// 流程开始时取一次 [context]，之后以 `context.mounted` 判断页面是否仍在。
abstract interface class CloudBackupHost {
  BuildContext get context;
  WidgetRef get ref;

  /// 是否已有操作在进行；进行中忽略新的点击。
  bool get busy;

  /// 切换忙碌遮罩；进行中可多次调用以更新文案（传输进度）。
  void setBusy(bool busy, [String text]);
  void showSnack(String message);
}

/// 网盘备份的业务流程编排（不构建 UI）。
///
/// - 上传：可选密码 → 导出完整备份 ZIP → 上传（遮罩显示百分比）；
/// - 恢复：只下载一次到临时文件 → 判断加密并按需输入密码 → 只读预检 →
///   [chooseBackupImportMode] 选择合并或覆盖（覆盖须经严重警告）→ 按所选
///   方式恢复；任何一步取消都不写入数据，临时文件总会删除；
/// - 授权：按网盘的授权方式弹出设备码或授权码对话框，拿到令牌后校验备份
///   目录并保存备份位置。
/// 忙碌遮罩只盖在耗时步骤上，弹窗出现前先撤下。
class CloudBackupController {
  CloudBackupController(this._host);

  final CloudBackupHost _host;

  Future<CloudBackupService> _service() =>
      _host.ref.read(cloudBackupServiceProvider.future);

  /// 保存（新增或更新）备份位置；不发网络请求。
  Future<bool> saveTarget(CloudBackupTarget target, {bool notify = true}) {
    final l10n = _host.context.l10n;
    return _run(l10n.cloudBackupBusySave, () async {
      final service = await _service();
      await service.targets.saveTarget(target);
      if (notify) _host.showSnack(l10n.cloudBackupConfigSaved);
    });
  }

  Future<bool> testConnection(CloudBackupTarget target) {
    final l10n = _host.context.l10n;
    return _run(l10n.cloudBackupBusyTest, () async {
      final service = await _service();
      await service.testConnection(target);
      _host.showSnack(l10n.cloudBackupConnectionOk);
    });
  }

  /// 读取远程备份列表；失败时提示并返回 null。
  Future<List<CloudBackupEntry>?> listBackups(
    CloudBackupTarget target, {
    bool showBusy = true,
  }) async {
    final l10n = _host.context.l10n;
    List<CloudBackupEntry>? backups;
    Future<void> action() async {
      final service = await _service();
      backups = await service.listBackups(target);
    }

    if (showBusy) {
      await _run(l10n.cloudBackupBusyRefresh, action);
    } else {
      await action();
    }
    return backups;
  }

  Future<bool> upload(CloudBackupTarget target) async {
    if (_host.busy) return false;
    final context = _host.context;
    final l10n = context.l10n;
    final password = await showBackupPasswordDialog(
      context,
      purpose: BackupPasswordPurpose.export,
      confirmLabel: l10n.cloudBackupUploadBackup,
    );
    if (!context.mounted || password == null) return false;
    return _run(l10n.cloudBackupBusyUpload, () async {
      final service = await _service();
      await service.uploadCurrentBackup(
        target,
        zipPassword: password,
        onProgress: _progress(l10n.cloudBackupBusyUploadProgress),
      );
      _host.showSnack(l10n.cloudBackupUploadSuccess);
    });
  }

  Future<void> restore(CloudBackupTarget target, CloudBackupEntry entry) async {
    if (_host.busy) return;
    final context = _host.context;
    final l10n = context.l10n;
    final service = await _service();
    if (!context.mounted) return;
    String? password;
    final zipFile = await _runResult(
      l10n.cloudBackupBusyDownload,
      () => service.downloadBackup(
        target,
        entry,
        onProgress: _progress(l10n.cloudBackupBusyDownloadProgress),
      ),
    );
    if (zipFile == null) return;
    try {
      _host.setBusy(true, l10n.backupBusyInspect);
      if (await service.isLocalBackupPasswordProtected(zipFile)) {
        _host.setBusy(false);
        if (!context.mounted) return;
        password = await showBackupPasswordDialog(
          context,
          purpose: BackupPasswordPurpose.import,
        );
        if (!context.mounted || password == null) return;
        _host.setBusy(true, l10n.backupBusyInspect);
      }
      final preview = await service.inspectLocalBackup(
        zipFile: zipFile,
        zipPassword: password,
      );
      _host.setBusy(false);
      if (!context.mounted) return;
      final mode = await chooseBackupImportMode(context, preview);
      if (!context.mounted || mode == null) return;
      _host.setBusy(true, l10n.cloudBackupBusyRestore);
      final result = await service.restoreFromLocalBackup(
        zipFile: zipFile,
        zipPassword: password,
        mode: mode,
      );
      if (context.mounted) {
        _host.showSnack(
          describeBackupImportResult(
            l10n,
            result,
            replaceAllMessage: l10n.cloudBackupRestoreSuccess,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _host.showSnack(describeCloudBackupError(l10n, error));
      }
    } finally {
      _host.setBusy(false);
      if (await zipFile.exists()) await zipFile.delete();
    }
  }

  Future<bool> delete(CloudBackupTarget target, CloudBackupEntry entry) async {
    if (_host.busy) return false;
    final context = _host.context;
    final l10n = context.l10n;
    if (!await confirmCloudBackupDelete(context, entry.fileName) ||
        !context.mounted) {
      return false;
    }
    return _run(l10n.cloudBackupBusyDelete, () async {
      final service = await _service();
      await service.deleteBackup(target, entry);
      _host.showSnack(l10n.cloudBackupDeleteSuccess);
    });
  }

  /// 只移除本机保存的连接与授权，不删除网盘里的备份文件。
  Future<bool> removeTarget(CloudBackupTarget target) async {
    if (_host.busy) return false;
    final context = _host.context;
    final l10n = context.l10n;
    if (!await confirmCloudBackupRemoveTarget(context) || !context.mounted) {
      return false;
    }
    return _run(l10n.cloudBackupBusySave, () async {
      final service = await _service();
      await service.targets.removeTarget(target.id);
      _host.showSnack(l10n.cloudBackupRemoved);
    });
  }

  /// 授权一个网盘；[existing] 不为空时是重新授权。成功返回保存后的位置。
  Future<CloudBackupTarget?> authorize(
    CloudBackupKind kind, {
    CloudBackupTarget? existing,
  }) async {
    if (_host.busy) return null;
    final context = _host.context;
    final l10n = context.l10n;
    final name = cloudBackupKindName(l10n, kind);
    final service = await _service();
    if (!context.mounted) return null;
    final CloudDriveAuthorizationSession session;
    try {
      session = service.beginAuthorization(kind);
    } catch (error) {
      _host.showSnack(describeCloudBackupError(l10n, error));
      return null;
    }
    try {
      final token = await _obtainToken(context, session.method, name);
      if (token == null || !context.mounted) return null;
      final granted = token;
      return await _runResult(l10n.cloudBackupBusyAuthorize, () async {
        final target = await service.completeAuthorization(
          kind: kind,
          token: granted,
          existing: existing,
        );
        _host.showSnack(l10n.cloudBackupAuthorized(name));
        return target;
      });
    } on CloudAuthorizationFailed catch (failed) {
      if (context.mounted) {
        _host.showSnack(describeCloudBackupError(l10n, failed.error));
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

  /// 进度只在百分比变化时刷新遮罩文案，避免每个数据块都重建页面。
  CloudBackupProgress _progress(String Function(int percent) label) {
    var last = -1;
    return (transferred, total) {
      if (total == null || total <= 0) return;
      final percent = (transferred * 100 ~/ total).clamp(0, 100);
      if (percent == last) return;
      last = percent;
      _host.setBusy(true, label(percent));
    };
  }

  Future<bool> _run(String busyText, Future<void> Function() action) async {
    var ok = false;
    await _runResult(busyText, () async {
      await action();
      ok = true;
      return true;
    });
    return ok;
  }

  /// 在忙碌遮罩下执行；失败时提示并返回 null。
  Future<T?> _runResult<T>(String busyText, Future<T> Function() action) async {
    if (_host.busy) return null;
    final context = _host.context;
    _host.setBusy(true, busyText);
    try {
      return await action();
    } catch (error) {
      if (context.mounted) {
        _host.showSnack(describeCloudBackupError(context.l10n, error));
      }
      return null;
    } finally {
      _host.setBusy(false);
    }
  }
}
