import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/settings/pages/webdav_sync_page.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/backup_file_save_service.dart';
import '../../../core/services/data_archive_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_icon_swap.dart';

/// 数据管理页面：提供 zip 导出与导入入口。
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _busy = false;
  String _busyText = '';

  Future<void> _exportData() async {
    if (_busy) {
      return;
    }
    final l10n = context.l10n;
    final exportPassword = await _showExportPasswordDialog();
    if (!mounted || exportPassword == null) {
      return;
    }

    _setBusy(true, l10n.dataMgmtBusyExport);
    try {
      final database = ref.read(appDatabaseProvider);
      final settings = await ref.read(settingsServiceProvider.future);
      final zipFile = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settings,
        zipPassword: exportPassword,
      );
      final fileName =
          'node_note_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      final savePath = await BackupFileSaveService.saveBackupFile(
        zipFile: zipFile,
        fileName: fileName,
        dialogTitle: l10n.dataMgmtSaveDialogTitle,
      );

      if (!mounted) {
        return;
      }
      if (savePath == null || savePath.trim().isEmpty) {
        _showSnack(l10n.dataMgmtExportCanceled);
        return;
      }
      _showSnack(l10n.dataMgmtExportSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(l10n.dataMgmtExportFailed('$error'));
    } finally {
      _setBusy(false, '');
    }
  }

  /// 导出密码设置弹窗（可选）。
  ///
  /// 返回值：
  /// - `null`：用户取消导出；
  /// - `''` 或具体密码：继续导出（空串表示不加密）。
  Future<String?> _showExportPasswordDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    var passwordValue = '';
    var obscureText = true;

    final result = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.dataMgmtExportPasswordTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      initialValue: passwordValue,
                      obscureText: obscureText,
                      onChanged: (value) => passwordValue = value,
                      decoration: InputDecoration(
                        hintText: context.l10n.dataMgmtExportPasswordHint,
                        suffixIcon: IconButton(
                          tooltip: obscureText
                              ? context.l10n.passwordShow
                              : context.l10n.passwordHide,
                          onPressed: () {
                            setDialogState(() => obscureText = !obscureText);
                          },
                          icon: ExpressiveIconSwap(
                            switchKey: obscureText,
                            child: FaIcon(
                              obscureText
                                  ? FontAwesomeIcons.eyeSlash
                                  : FontAwesomeIcons.eye,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.dataMgmtExportPasswordWarning,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(passwordValue);
                  },
                  child: Text(context.l10n.dataMgmtExport),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _importData() async {
    if (_busy) {
      return;
    }
    final l10n = context.l10n;
    final shouldImport = await _confirmImport();
    if (!mounted || !shouldImport) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.dataMgmtPickDialogTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (!mounted) {
      return;
    }
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.first.path == null) {
      _showSnack(l10n.dataMgmtImportCanceled);
      return;
    }

    final zipPath = picked.files.first.path!;
    String? importPassword;

    _setBusy(true, l10n.dataMgmtBusyImport);
    try {
      final passwordProtected = await DataArchiveService.isZipPasswordProtected(
        zipPath: zipPath,
      );
      if (!mounted) {
        return;
      }
      _setBusy(false, '');

      if (passwordProtected) {
        importPassword = await _showImportPasswordDialog();
        if (!mounted || importPassword == null) {
          _showSnack(l10n.dataMgmtImportCanceled);
          return;
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setBusy(false, '');
      _showSnack(l10n.dataMgmtImportFailed('$error'));
      return;
    }

    _setBusy(true, l10n.dataMgmtBusyImport);
    try {
      final database = ref.read(appDatabaseProvider);
      final settings = await ref.read(settingsServiceProvider.future);
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zipPath,
        zipPassword: importPassword,
      );

      if (!mounted) {
        return;
      }
      _showSnack(l10n.dataMgmtImportSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(l10n.dataMgmtImportFailed('$error'));
    } finally {
      _setBusy(false, '');
    }
  }

  /// 导入密码输入弹窗（可选）。
  Future<String?> _showImportPasswordDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    var passwordValue = '';
    var obscureText = true;

    final result = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.dataMgmtImportPasswordTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      initialValue: passwordValue,
                      obscureText: obscureText,
                      onChanged: (value) => passwordValue = value,
                      decoration: InputDecoration(
                        hintText: context.l10n.dataMgmtImportPasswordHint,
                        suffixIcon: IconButton(
                          tooltip: obscureText
                              ? context.l10n.passwordShow
                              : context.l10n.passwordHide,
                          onPressed: () {
                            setDialogState(() => obscureText = !obscureText);
                          },
                          icon: ExpressiveIconSwap(
                            switchKey: obscureText,
                            child: FaIcon(
                              obscureText
                                  ? FontAwesomeIcons.eyeSlash
                                  : FontAwesomeIcons.eye,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(passwordValue);
                  },
                  child: Text(context.l10n.dataMgmtImportAction),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<bool> _confirmImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(context.l10n.dataMgmtImportConfirmTitle),
          content: Text(context.l10n.dataMgmtImportConfirmContent),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.dataMgmtImportAction),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  /// 切换忙碌态。结束时保留上一条步骤文案，让它随遮罩一起淡出，而不是先
  /// 变空再消失。
  void _setBusy(bool busy, String text) {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = busy;
      if (busy) {
        _busyText = text;
      }
    });
  }

  void _showSnack(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 导入/恢复会覆盖本地数据，进行中禁止返回，避免页面销毁后流程仍在后台
    // 改写数据库而用户无从得知结果。
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppTopBar(
          title: Text(context.l10n.dataMgmtTitle),
          leading: IconButton(
            tooltip: context.l10n.commonBack,
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
        ),
        body: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              children: <Widget>[
                SettingsCardGroup(
                  children: <Widget>[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.fileExport,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtExport),
                      subtitle: Text(context.l10n.dataMgmtExportSubtitle),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: _exportData,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.fileImport,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtImport),
                      subtitle: Text(context.l10n.dataMgmtImportSubtitle),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: _importData,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.cloudArrowUp,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtWebDav),
                      subtitle: Text(context.l10n.dataMgmtWebDavSubtitle),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: () {
                        if (_busy) {
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const WebDavSyncPage();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    context.l10n.dataMgmtHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            // 忙碌期间立即拦截点击，画面在超过 300ms 后才淡入；条目不再随
            // 忙碌态整体变灰闪一下。
            Positioned.fill(
              child: ActionLoadingOverlay(
                visible: _busy,
                label: _busyText,
                semanticLabel: context.l10n.dataMgmtBusyLabel,
                revealDelay: DelayedLoadingGate.defaultDelay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
