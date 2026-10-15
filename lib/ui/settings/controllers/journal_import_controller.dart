import 'package:file_picker/file_picker.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../../../core/services/journal_import_models.dart';
import '../../../core/services/journal_import_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/color_palette_families.dart';
import '../widgets/journal_import_source_sheet.dart';
import 'backup_import_flow.dart';
import 'data_management_controller.dart';

/// 导入其他日记应用导出的流程编排：
///
/// 选择来源应用 → 选择导出文件 → 解析并预检（[JournalImportService.prepare]，
/// 不写本机数据）→ 经 [chooseBackupImportMode] 选择合并或覆盖已导入过的
/// 日记（覆盖须经严重警告）→ 合并导入 → 提示新增/跳过/覆盖的篇数。
///
/// 每一步取消都不写入数据；不论成功、失败或取消，最后都删除导入暂存区与
/// 文件选择器留在缓存里的副本。格式不符、文件里没有日记时给出具体提示。
class JournalImportController {
  JournalImportController(this._host);

  final DataManagementHost _host;

  Future<void> importFromApp() async {
    if (_host.busy) return;
    final context = _host.context;
    final l10n = context.l10n;
    final source = await showJournalImportSourceSheet(context);
    if (source == null || !context.mounted) return;

    final name = journalImportSourceName(l10n, source);
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.journalImportPickDialogTitle(name),
      // .daylio/.diary 等扩展名在部分平台没有对应 MIME，按扩展名过滤会让
      // 文件无法选中；不限制类型，由解析器识别格式并给出提示。
      type: FileType.any,
    );
    if (!context.mounted) return;
    final path = picked?.files.firstOrNull?.path;
    if (path == null) {
      _host.showSnack(l10n.dataMgmtImportCanceled);
      return;
    }

    final database = _host.ref.read(appDatabaseProvider);
    JournalImportSession? session;
    try {
      _host.setBusy(true, l10n.backupBusyInspect);
      try {
        final settings = await _host.ref.read(settingsServiceProvider.future);
        session = await JournalImportService.prepare(
          database: database,
          source: source,
          filePath: path,
          moodOptions: settings.moodOptions,
          tagColors: journalImportTagColors,
        );
      } catch (error) {
        if (context.mounted) _host.showSnack(_describeError(l10n, name, error));
        return;
      } finally {
        _host.setBusy(false);
      }
      if (!context.mounted) return;

      final mode = await chooseBackupImportMode(context, session.preview);
      if (!context.mounted) return;
      if (mode == null) {
        _host.showSnack(l10n.dataMgmtImportCanceled);
        return;
      }

      _host.setBusy(true, l10n.dataMgmtBusyImport);
      try {
        final result = await session.apply(database: database, mode: mode);
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
    } finally {
      await session?.dispose();
      await DiaryMediaStorageService.discardPickerCopy(path);
    }
  }

  static String _describeError(
    AppLocalizations l10n,
    String sourceName,
    Object error,
  ) {
    if (error is JournalImportFormatException) {
      return error.noEntries
          ? l10n.journalImportNoEntries
          : l10n.journalImportUnrecognized(sourceName);
    }
    return l10n.dataMgmtImportFailed('$error');
  }
}

/// 导入新建标签的颜色：各色系的中间色依次轮换，与标签色板一致。
final List<int> journalImportTagColors = [
  for (final family in kColorPaletteFamilies)
    family.colors[family.colors.length ~/ 2].toARGB32(),
];
