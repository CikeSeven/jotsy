import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../../../core/services/journal_import_cloud.dart';
import '../../../core/services/journal_import_cloud_http.dart';
import '../../../core/services/journal_import_cloud_platforms.dart';
import '../../../core/services/journal_import_models.dart';
import '../../../core/services/journal_import_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/color_palette_families.dart';
import '../pages/cloud_notes_login_page.dart';
import '../widgets/journal_import_source_labels.dart';
import '../widgets/journal_import_source_sheet.dart';
import 'backup_import_flow.dart';
import 'data_management_controller.dart';
import 'journal_import_cloud_failure.dart';

/// 导入其他日记应用的流程编排：
///
/// 选择来源应用 → 取得数据 → 预检（不写本机数据）→ 经
/// [chooseBackupImportMode] 选择合并或覆盖已导入过的日记（覆盖须经严重
/// 警告）→ 合并导入 → 提示新增/跳过/覆盖的篇数。取得数据有两种方式：
/// - 导出文件：选择文件，[JournalImportService.prepare] 解析；
/// - 手机厂商与 WPS 的云端笔记：打开 [CloudNotesLoginPage] 在官方网页中
///   登录，[JournalImportService.prepareCloud] 读取笔记与附件。
///
/// 每一步取消都不写入数据；不论成功、失败或取消，最后都删除导入暂存区、
/// 文件选择器留在缓存里的副本，以及云端登录状态（Cookie）。格式不符、
/// 没有日记、加密备份、登录失效等给出具体提示。
class JournalImportController {
  JournalImportController(this._host);

  final DataManagementHost _host;

  Future<void> importFromApp() async {
    if (_host.busy) return;
    final context = _host.context;
    final source = await showJournalImportSourceSheet(context);
    if (source == null || !context.mounted) return;
    final platform = cloudNotePlatforms[source];
    if (platform != null) {
      await _importFromCloud(context, source, platform);
    } else {
      await _importFromFile(context, source);
    }
  }

  Future<void> _importFromFile(
    BuildContext context,
    JournalImportSource source,
  ) async {
    final l10n = context.l10n;
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
    try {
      await _run(
        context,
        name,
        busyText: l10n.backupBusyInspect,
        prepare: (settings) => JournalImportService.prepare(
          database: _host.ref.read(appDatabaseProvider),
          source: source,
          filePath: path,
          moodOptions: settings.moodOptions,
          tagColors: journalImportTagColors,
        ),
      );
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(path);
    }
  }

  Future<void> _importFromCloud(
    BuildContext context,
    JournalImportSource source,
    CloudNotePlatform platform,
  ) async {
    final l10n = context.l10n;
    final name = journalImportSourceName(l10n, source);
    final login = await Navigator.of(context).push<CloudLoginResult>(
      MaterialPageRoute<CloudLoginResult>(
        builder: (BuildContext context) =>
            CloudNotesLoginPage(platform: platform, platformName: name),
      ),
    );
    if (!context.mounted) {
      await login?.close();
      return;
    }
    if (login == null) {
      _host.showSnack(l10n.dataMgmtImportCanceled);
      return;
    }
    try {
      await _run(
        context,
        name,
        busyText: l10n.cloudBusyReading(0),
        prepare: (settings) => JournalImportService.prepareCloud(
          database: _host.ref.read(appDatabaseProvider),
          source: source,
          provider: login.provider,
          onProgress: (done, total) => _host.setBusy(
            true,
            total == null
                ? l10n.cloudBusyReading(done)
                : l10n.cloudBusyProgress(done, total),
          ),
          moodOptions: settings.moodOptions,
          tagColors: journalImportTagColors,
        ),
      );
    } finally {
      await login.close();
    }
  }

  /// 预检 → 选择导入方式 → 合并导入；会话无论结果如何都会被释放。
  Future<void> _run(
    BuildContext context,
    String sourceName, {
    required String busyText,
    required Future<JournalImportSession> Function(SettingsService settings)
    prepare,
  }) async {
    final l10n = context.l10n;
    final database = _host.ref.read(appDatabaseProvider);
    JournalImportSession? session;
    try {
      _host.setBusy(true, busyText);
      try {
        final settings = await _host.ref.read(settingsServiceProvider.future);
        session = await prepare(settings);
      } catch (error) {
        if (context.mounted) {
          _host.showSnack(_describeError(l10n, sourceName, error));
        }
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
    }
  }

  static String _describeError(
    AppLocalizations l10n,
    String sourceName,
    Object error,
  ) {
    if (error is JournalImportFormatException) {
      if (error.encrypted) return l10n.journalImportEncrypted(sourceName);
      return error.noEntries
          ? l10n.journalImportNoEntries
          : l10n.journalImportUnrecognized(sourceName);
    }
    if (error is CloudNoteException) {
      return describeCloudNoteFailure(l10n, error, sourceName);
    }
    return l10n.dataMgmtImportFailed('$error');
  }
}

/// 导入新建标签的颜色：各色系的中间色依次轮换，与标签色板一致。
final List<int> journalImportTagColors = [
  for (final family in kColorPaletteFamilies)
    family.colors[family.colors.length ~/ 2].toARGB32(),
];
