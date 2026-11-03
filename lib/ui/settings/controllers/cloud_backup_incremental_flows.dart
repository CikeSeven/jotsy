import 'package:flutter/widgets.dart';

import '../../../core/services/cloud_backup_incremental.dart';
import '../../../core/services/cloud_backup_incremental_io.dart';
import '../../../core/services/cloud_backup_incremental_prune.dart';
import '../../../core/services/cloud_backup_incremental_restore.dart';
import '../../../core/services/cloud_backup_options.dart';
import '../../../core/services/cloud_backup_service.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/backup_password_dialog.dart';
import '../widgets/cloud_backup_dialogs.dart';
import '../widgets/cloud_backup_labels.dart';
import 'backup_import_flow.dart';
import 'cloud_backup_busy.dart';
import 'cloud_backup_failure.dart';

/// 网盘增量备份的界面流程（不构建 UI）。
///
/// - 备份：遮罩依次显示“检查变化 → 读取网盘 → 上传 x% → 清理”。本机还没有
///   增量链时：网盘上已有加密的链 → 输入密码接上（打不开可重新输入或开始
///   新的一串）；已有不加密的链 → 接着备份或开始新的一串；没有 → 设一个
///   密码（可留空）开始新链。弹窗出现前先撤下遮罩，选完再盖回去；
/// - 记住的密码打不开网盘上的链（另一台设备换过密码）时，确认后忘掉它并
///   重新走一遍上面的选择，只重试一次；
/// - 恢复：先用记住的密码（只对本机那条链）下载并解开快照，打不开再询问；
///   预检后经 [chooseBackupImportMode] 选择合并或覆盖（覆盖须经严重警告），
///   任何一步取消都不写入数据；临时文件总会删除。
class CloudIncrementalController with CloudBackupBusyRunner {
  CloudIncrementalController(this.host);

  @override
  final CloudBackupHost host;

  Future<bool> backup(CloudBackupTarget target) async {
    if (host.busy) return false;
    final context = host.context;
    final l10n = context.l10n;
    final service = await this.service();
    if (!context.mounted) return false;
    var resetOnce = false;
    while (true) {
      try {
        host.setBusy(true, l10n.cloudIncrementalBusyScan);
        final result = await service.backupIncremental(
          target,
          resolveChain: (chain) => _resolveChain(context, chain),
          onPhase: (phase) => host.setBusy(true, _phaseLabel(l10n, phase)),
          onProgress: progressLabel(l10n.cloudBackupBusyUploadProgress),
        );
        host.setBusy(false);
        if (!context.mounted) return true;
        switch (result.outcome) {
          case CloudIncrementalBackupOutcome.uploaded:
            host.showSnack(
              l10n.cloudIncrementalUploaded(
                formatCloudBackupBytes(result.bytes),
              ),
            );
          case CloudIncrementalBackupOutcome.unchanged:
            host.showSnack(l10n.cloudIncrementalUnchanged);
          case CloudIncrementalBackupOutcome.cancelled:
          case CloudIncrementalBackupOutcome.needsManual:
            return false;
        }
        return true;
      } on CloudIncrementalPasswordException {
        host.setBusy(false);
        if (!context.mounted) return false;
        if (resetOnce) {
          host.showSnack(
            describeCloudBackupError(
              l10n,
              const CloudIncrementalPasswordException(''),
            ),
          );
          return false;
        }
        final reset = await confirmCloudIncrementalForget(
          context,
          content: l10n.cloudIncrementalRememberedMismatchContent,
        );
        if (!reset || !context.mounted) return false;
        await service.forgetIncrementalChain(target.id);
        resetOnce = true;
      } catch (error) {
        host.setBusy(false);
        if (context.mounted) {
          host.showSnack(describeCloudBackupError(l10n, error));
        }
        return false;
      }
    }
  }

  Future<CloudIncrementalChainChoice?> _resolveChain(
    BuildContext context,
    CloudIncrementalChainContext chain,
  ) async {
    final l10n = context.l10n;
    final existing = chain.existingChain;
    if (existing != null) {
      host.setBusy(true, l10n.cloudIncrementalBusyCheck);
      final encrypted = await chain.isExistingEncrypted();
      host.setBusy(false);
      if (!context.mounted) return null;
      if (!encrypted) {
        final answer = await askCloudIncrementalExistingPlain(context);
        if (answer == null || !context.mounted) return null;
        if (answer == CloudIncrementalChainAnswer.continueExisting) {
          host.setBusy(true, l10n.cloudIncrementalBusyCheck);
          return CloudIncrementalChainChoice(chain: existing, password: '');
        }
      } else {
        final answer = await _askExistingPassword(context, chain);
        if (answer == null) return null;
        if (answer.password case final password?) {
          host.setBusy(true, l10n.cloudIncrementalBusyCheck);
          return CloudIncrementalChainChoice(
            chain: existing,
            password: password,
          );
        }
        // password 为 null：用户改选了“开始新的一串”。
      }
    }
    if (!context.mounted) return null;
    final password = await showBackupPasswordDialog(
      context,
      purpose: BackupPasswordPurpose.export,
      confirmLabel: l10n.cloudBackupBackupNow,
      message: l10n.cloudIncrementalNewPasswordMessage,
    );
    if (password == null || !context.mounted) return null;
    host.setBusy(true, l10n.cloudIncrementalBusyCheck);
    return CloudIncrementalChainChoice(
      chain: chain.newChainId(),
      password: password,
    );
  }

  /// 输入已有加密链的密码，直到核对通过。返回 null 为取消；`password` 为
  /// null 表示用户改选了“开始新的一串”。
  Future<({String? password})?> _askExistingPassword(
    BuildContext context,
    CloudIncrementalChainContext chain,
  ) async {
    final l10n = context.l10n;
    while (true) {
      if (!context.mounted) return null;
      final password = await showBackupPasswordDialog(
        context,
        purpose: BackupPasswordPurpose.import,
        confirmLabel: l10n.cloudIncrementalContinue,
        message: l10n.cloudIncrementalExistingEncryptedMessage,
      );
      if (password == null || !context.mounted) return null;
      host.setBusy(true, l10n.cloudIncrementalBusyCheck);
      final ok = password.isNotEmpty && await chain.verify(password);
      host.setBusy(false);
      if (ok) return (password: password);
      if (!context.mounted) return null;
      final answer = await askCloudIncrementalWrongPassword(context);
      if (answer == null) return null;
      if (answer == CloudIncrementalChainAnswer.startNew) {
        return (password: null);
      }
    }
  }

  Future<void> restore(
    CloudBackupTarget target,
    IncrementalSnapshotRef snapshot,
  ) async {
    if (host.busy) return;
    final context = host.context;
    final l10n = context.l10n;
    final service = await this.service();
    if (!context.mounted) return;
    final current = service.targets.targetById(target.id) ?? target;
    final options = current.options;
    var password = options.hasChain && options.chain == snapshot.chain
        ? options.zipPassword
        : null;
    var asked = false;
    IncrementalSnapshotOpened? opened;
    try {
      while (opened == null) {
        try {
          host.setBusy(true, l10n.cloudBackupBusyDownload);
          opened = await service.openIncrementalSnapshot(
            current,
            snapshot,
            password: password,
            onProgress: progressLabel(l10n.cloudBackupBusyDownloadProgress),
          );
        } on CloudIncrementalPasswordException {
          host.setBusy(false);
          if (!context.mounted) return;
          if (asked) host.showSnack(l10n.cloudIncrementalErrorPassword);
          final input = await showBackupPasswordDialog(
            context,
            purpose: BackupPasswordPurpose.import,
            message: l10n.cloudIncrementalRestorePasswordMessage,
          );
          if (input == null || !context.mounted) return;
          password = input.isEmpty ? null : input;
          asked = true;
        }
      }
      host.setBusy(true, l10n.backupBusyInspect);
      final preview = await service.previewIncrementalSnapshot(opened);
      host.setBusy(false);
      if (!context.mounted) return;
      final mode = await chooseBackupImportMode(context, preview);
      if (!context.mounted || mode == null) return;
      host.setBusy(true, l10n.cloudBackupBusyRestore);
      final download = progressLabel(l10n.cloudBackupBusyDownloadProgress);
      final result = await service.restoreIncremental(
        current,
        opened,
        mode: mode,
        onDownloadProgress: (transferred, total) {
          // 下载完就是导入：遮罩换回“正在恢复”，不停在“下载 100%”。
          if (total != null && transferred >= total) {
            host.setBusy(true, l10n.cloudBackupBusyRestore);
          } else {
            download(transferred, total);
          }
        },
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
      await opened?.dispose();
    }
  }

  Future<bool> delete(
    CloudBackupTarget target,
    IncrementalSnapshotRef snapshot,
  ) async {
    if (host.busy) return false;
    final context = host.context;
    final l10n = context.l10n;
    if (!await confirmCloudIncrementalDelete(
          context,
          formatCloudBackupTime(snapshot.time),
        ) ||
        !context.mounted) {
      return false;
    }
    return runBusy(l10n.cloudBackupBusyDelete, () async {
      await (await service()).deleteIncrementalSnapshot(target, snapshot);
      host.showSnack(l10n.cloudBackupDeleteSuccess);
    });
  }

  /// 忘记本机记住的增量链与密码（自动备份随之暂停）。
  Future<bool> forgetChain(CloudBackupTarget target) async {
    if (host.busy) return false;
    final context = host.context;
    final l10n = context.l10n;
    if (!await confirmCloudIncrementalForget(context) || !context.mounted) {
      return false;
    }
    return runBusy(l10n.cloudBackupBusySave, () async {
      await (await service()).forgetIncrementalChain(target.id);
      host.showSnack(l10n.cloudIncrementalForgotten);
    });
  }

  /// 改保留份数 / 自动备份开关与频率：只写本机偏好，不联网。
  Future<void> updateOptions(
    CloudBackupTarget target,
    CloudBackupOptions Function(CloudBackupOptions options) update,
  ) async {
    final context = host.context;
    try {
      await (await service()).targets.updateOptions(target.id, update);
    } catch (error) {
      if (context.mounted) {
        host.showSnack(describeCloudBackupError(context.l10n, error));
      }
    }
  }

  static String _phaseLabel(
    AppLocalizations l10n,
    CloudIncrementalPhase phase,
  ) => switch (phase) {
    CloudIncrementalPhase.scanning => l10n.cloudIncrementalBusyScan,
    CloudIncrementalPhase.checking => l10n.cloudIncrementalBusyCheck,
    CloudIncrementalPhase.uploading => l10n.cloudBackupBusyUploadProgress(0),
    CloudIncrementalPhase.pruning => l10n.cloudIncrementalBusyPrune,
  };
}
