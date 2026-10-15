import 'package:flutter/widgets.dart';

import '../../../core/services/backup_import_models.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/backup_import_options_sheet.dart';
import '../widgets/backup_overwrite_warning_dialog.dart';

/// 本地导入与 WebDAV 恢复共用的导入决策：先选导入方式，会改写本机数据的
/// 方式再经严重警告确认。返回最终方式；任何一步取消都返回 null，调用方据此
/// 不做任何写入。
///
/// 所有导入入口都必须经过这里，覆盖本机数据前一定有严重警告。
Future<BackupImportMode?> chooseBackupImportMode(
  BuildContext context,
  BackupArchivePreview preview,
) async {
  final mode = await showBackupImportOptionsSheet(context, preview: preview);
  if (mode == null || !context.mounted) return null;
  if (mode.overwritesLocalData &&
      !await showBackupOverwriteWarningDialog(
        context,
        mode: mode,
        preview: preview,
      )) {
    return null;
  }
  return mode;
}

/// 导入结果提示：合并说明新增/跳过的篇数；覆盖全部沿用各入口原有的成功文案
/// [replaceAllMessage]（本地导入与 WebDAV 恢复不同）。
String describeBackupImportResult(
  AppLocalizations l10n,
  BackupImportResult result, {
  required String replaceAllMessage,
}) {
  return switch (result.mode) {
    BackupImportMode.replaceAll => replaceAllMessage,
    BackupImportMode.mergeOverwrite => l10n.backupImportOverwriteResult(
      result.addedDiaries,
      result.replacedDiaries,
    ),
    BackupImportMode.merge when result.skippedDiaries > 0 =>
      l10n.backupImportMergeSkippedResult(
        result.addedDiaries,
        result.skippedDiaries,
      ),
    BackupImportMode.merge => l10n.backupImportMergeResult(result.addedDiaries),
  };
}
