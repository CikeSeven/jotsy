import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/data_archive_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';

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
    final exportPassword = await _showExportPasswordDialog();
    if (!mounted || exportPassword == null) {
      return;
    }

    _setBusy(true, context.l10n.dataMgmtBusyExport);
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
      String? savePath;

      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端必须传 bytes，且系统会处理写入，不再执行二次写盘。
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: context.l10n.dataMgmtSaveDialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const <String>['zip'],
          bytes: await zipFile.readAsBytes(),
        );
      } else {
        // 桌面端返回目标路径后由应用写入文件。
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: context.l10n.dataMgmtSaveDialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const <String>['zip'],
        );
        if (savePath != null && savePath.trim().isNotEmpty) {
          final outputFile = File(savePath);
          await outputFile.parent.create(recursive: true);
          await zipFile.copy(outputFile.path);
        }
      }

      if (!mounted) {
        return;
      }
      if (savePath == null || savePath.trim().isEmpty) {
        _showSnack(context.l10n.dataMgmtExportCanceled);
        return;
      }
      _showSnack(context.l10n.dataMgmtExportSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context.l10n.dataMgmtExportFailed('$error'));
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
              title: const Text('设置导出密码（可选）'),
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
                        hintText: '不填写则不加密',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() => obscureText = !obscureText);
                          },
                          icon: FaIcon(
                            obscureText
                                ? FontAwesomeIcons.eyeSlash
                                : FontAwesomeIcons.eye,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '请妥善保管此密码。本应用采用本地端到端加密，我们无法为您找回密码。一旦遗忘，导出的数据将永久无法恢复。',
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
    final shouldImport = await _confirmImport();
    if (!mounted || !shouldImport) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: context.l10n.dataMgmtPickDialogTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (!mounted) {
      return;
    }
    if (picked == null || picked.files.isEmpty || picked.files.first.path == null) {
      _showSnack(context.l10n.dataMgmtImportCanceled);
      return;
    }

    final zipPath = picked.files.first.path!;
    String? importPassword;

    _setBusy(true, context.l10n.dataMgmtBusyImport);
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
          _showSnack(context.l10n.dataMgmtImportCanceled);
          return;
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setBusy(false, '');
      _showSnack(context.l10n.dataMgmtImportFailed('$error'));
      return;
    }

    _setBusy(true, context.l10n.dataMgmtBusyImport);
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
      _showSnack(context.l10n.dataMgmtImportSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context.l10n.dataMgmtImportFailed('$error'));
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
              title: const Text('导入密码'),
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
                        hintText: '请输入导入密码',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() => obscureText = !obscureText);
                          },
                          icon: FaIcon(
                            obscureText
                                ? FontAwesomeIcons.eyeSlash
                                : FontAwesomeIcons.eye,
                            size: 14,
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
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.dataMgmtImportAction),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  void _setBusy(bool busy, String text) {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = busy;
      _busyText = text;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dataMgmtTitle),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(FontAwesomeIcons.fileExport, size: 16),
                title: Text(context.l10n.dataMgmtExport),
                subtitle: Text(context.l10n.dataMgmtExportSubtitle),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: _busy ? null : _exportData,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(FontAwesomeIcons.fileImport, size: 16),
                title: Text(context.l10n.dataMgmtImport),
                subtitle: Text(context.l10n.dataMgmtImportSubtitle),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: _busy ? null : _importData,
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                context.l10n.dataMgmtHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.82),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        LoadingIndicatorM3E(
                          variant: LoadingIndicatorM3EVariant.contained,
                          constraints: const BoxConstraints.tightFor(
                            width: 72,
                            height: 72,
                          ),
                          semanticLabel: context.l10n.dataMgmtBusyLabel,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _busyText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
