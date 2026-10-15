import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/backup_import_models.dart';
import '../../../core/services/backup_file_save_service.dart';
import '../../../core/services/data_archive_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/backup_password_dialog.dart';
import 'backup_import_flow.dart';

/// 数据管理页提供给流程的上下文、忙碌态与提示出口。
///
/// 流程在开始时取一次 [context]，之后以 `context.mounted` 判断页面是否仍在：
/// 页面销毁后不能再读 State.context。
abstract interface class DataManagementHost {
  BuildContext get context;
  WidgetRef get ref;

  /// 是否已有导出/导入在进行；进行中忽略新的点击。
  bool get busy;

  /// 切换忙碌遮罩；结束时调用方不必传文案（遮罩淡出期间保留上一条）。
  void setBusy(bool busy, [String text]);
  void showSnack(String message);
}

/// 数据管理页的导出/导入流程编排。
///
/// - 导出：可选密码 → 生成完整备份 ZIP → 交给系统保存；
/// - 导入：选择文件 → 判断加密并按需输入密码 → 只读预检（识别完整备份或
///   日记文件、统计本机已存在的日记）→ 选择合并或覆盖，覆盖须经严重警告 →
///   按所选方式导入 → 提示新增/跳过/覆盖的篇数。
///
/// 每一步取消都不写入任何数据；密码错误、文件损坏在预检阶段就报错。忙碌
/// 遮罩只盖在耗时步骤上，弹窗与选择面板出现前先撤下。不构建页面 UI。
class DataManagementController {
  DataManagementController(this._host);

  final DataManagementHost _host;

  Future<void> exportAll() async {
    if (_host.busy) {
      return;
    }
    final context = _host.context;
    final l10n = context.l10n;
    final password = await showBackupPasswordDialog(
      context,
      purpose: BackupPasswordPurpose.export,
    );
    if (!context.mounted || password == null) {
      return;
    }

    _host.setBusy(true, l10n.dataMgmtBusyExport);
    try {
      final database = _host.ref.read(appDatabaseProvider);
      final settings = await _host.ref.read(settingsServiceProvider.future);
      final zipFile = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settings,
        zipPassword: password,
      );
      final fileName =
          'node_note_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final savePath = await BackupFileSaveService.saveBackupFile(
        zipFile: zipFile,
        fileName: fileName,
        dialogTitle: l10n.dataMgmtSaveDialogTitle,
      );
      if (!context.mounted) {
        return;
      }
      if (savePath == null || savePath.trim().isEmpty) {
        _host.showSnack(l10n.dataMgmtExportCanceled);
        return;
      }
      _host.showSnack(l10n.dataMgmtExportSuccess);
    } catch (error) {
      if (context.mounted) {
        _host.showSnack(l10n.dataMgmtExportFailed('$error'));
      }
    } finally {
      _host.setBusy(false);
    }
  }

  Future<void> importData() async {
    if (_host.busy) {
      return;
    }
    final context = _host.context;
    final l10n = context.l10n;
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.dataMgmtPickDialogTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (!context.mounted) {
      return;
    }
    final zipPath = picked?.files.firstOrNull?.path;
    if (zipPath == null) {
      _host.showSnack(l10n.dataMgmtImportCanceled);
      return;
    }

    final database = _host.ref.read(appDatabaseProvider);
    String? password;
    BackupArchivePreview preview;
    _host.setBusy(true, l10n.backupBusyInspect);
    try {
      if (await DataArchiveService.isZipPasswordProtected(zipPath: zipPath)) {
        if (!context.mounted) {
          return;
        }
        _host.setBusy(false);
        password = await showBackupPasswordDialog(
          context,
          purpose: BackupPasswordPurpose.import,
        );
        if (!context.mounted) {
          return;
        }
        if (password == null) {
          _host.showSnack(l10n.dataMgmtImportCanceled);
          return;
        }
        _host.setBusy(true, l10n.backupBusyInspect);
      }
      preview = await DataArchiveService.inspectZip(
        database: database,
        zipPath: zipPath,
        zipPassword: password,
      );
    } catch (error) {
      if (context.mounted) {
        _host.showSnack(l10n.dataMgmtImportFailed('$error'));
      }
      return;
    } finally {
      _host.setBusy(false);
    }
    if (!context.mounted) {
      return;
    }

    final mode = await chooseBackupImportMode(context, preview);
    if (!context.mounted) {
      return;
    }
    if (mode == null) {
      _host.showSnack(l10n.dataMgmtImportCanceled);
      return;
    }

    _host.setBusy(true, l10n.dataMgmtBusyImport);
    try {
      final settings = await _host.ref.read(settingsServiceProvider.future);
      final result = await DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zipPath,
        zipPassword: password,
        mode: mode,
      );
      if (context.mounted) {
        _host.showSnack(
          describeBackupImportResult(
            l10n,
            result,
            replaceAllMessage: l10n.dataMgmtImportSuccess,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _host.showSnack(l10n.dataMgmtImportFailed('$error'));
      }
    } finally {
      _host.setBusy(false);
    }
  }
}
