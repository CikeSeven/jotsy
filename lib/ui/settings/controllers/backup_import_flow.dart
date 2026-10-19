import 'package:flutter/widgets.dart';

import '../../../core/services/backup_import_models.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/backup_import_folder_section.dart';
import '../widgets/backup_import_options_sheet.dart';
import '../widgets/backup_overwrite_warning_dialog.dart';

/// 本地导入与 WebDAV 恢复共用的导入决策：先选导入方式，会改写本机数据的
/// 方式再经严重警告确认。返回最终方式；任何一步取消都返回 null，调用方据此
/// 不做任何写入。
///
/// 所有导入入口都必须经过这里，覆盖本机数据前一定有严重警告。
///
/// 其他应用的导出带有来源日记本 / 文件夹时传入 [folderChoice]：面板里多出
/// 落地方式一节，确认后所选方式留在 [folderChoice.selected]，覆盖警告也按
/// 该方式的预检结果说明。
Future<BackupImportMode?> chooseBackupImportMode(
  BuildContext context,
  BackupArchivePreview preview, {
  BackupImportFolderChoice? folderChoice,
}) async {
  final mode = await showBackupImportOptionsSheet(
    context,
    preview: preview,
    folderChoice: folderChoice,
  );
  if (mode == null || !context.mounted) return null;
  if (mode.overwritesLocalData &&
      !await showBackupOverwriteWarningDialog(
        context,
        mode: mode,
        preview: folderChoice?.preview ?? preview,
      )) {
    return null;
  }
  return mode;
}

/// 导入结果提示：合并说明新增/跳过的篇数，文件带纪念日时另起一行写纪念日
/// 的统计，新增了日记模板、日记本时各再起一行；覆盖全部沿用各入口原有的成功文案
/// [replaceAllMessage]（本地导入与 WebDAV 恢复不同）。
String describeBackupImportResult(
  AppLocalizations l10n,
  BackupImportResult result, {
  required String replaceAllMessage,
}) {
  final diaries = _describeDiaries(l10n, result, replaceAllMessage);
  if (result.mode == BackupImportMode.replaceAll) return diaries;
  return <String>[
    diaries,
    if (result.touchedAnniversaries) _describeAnniversaries(l10n, result),
    if (result.addedTemplates > 0)
      l10n.backupImportTemplateMergeResult(result.addedTemplates),
    if (result.addedNotebooks > 0)
      l10n.backupImportNotebookMergeResult(result.addedNotebooks),
  ].join('\n');
}

String _describeAnniversaries(
  AppLocalizations l10n,
  BackupImportResult result,
) {
  return switch (result.mode) {
    BackupImportMode.mergeOverwrite =>
      l10n.backupImportAnniversaryOverwriteResult(
        result.addedAnniversaries,
        result.replacedAnniversaries,
      ),
    _ when result.skippedAnniversaries > 0 =>
      l10n.backupImportAnniversaryMergeSkippedResult(
        result.addedAnniversaries,
        result.skippedAnniversaries,
      ),
    _ => l10n.backupImportAnniversaryMergeResult(result.addedAnniversaries),
  };
}

String _describeDiaries(
  AppLocalizations l10n,
  BackupImportResult result,
  String replaceAllMessage,
) {
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
