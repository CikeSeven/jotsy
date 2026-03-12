import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/data_archive_service.dart';

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
    _setBusy(true, '正在导出数据...');
    try {
      final database = ref.read(appDatabaseProvider);
      final settings = await ref.read(settingsServiceProvider.future);
      final zipFile = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settings,
      );
      final fileName =
          'node_note_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      String? savePath;

      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端必须传 bytes，且系统会处理写入，不再执行二次写盘。
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存数据备份',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const <String>['zip'],
          bytes: await zipFile.readAsBytes(),
        );
      } else {
        // 桌面端返回目标路径后由应用写入文件。
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存数据备份',
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
        _showSnack('已取消导出');
        return;
      }
      _showSnack('数据导出成功');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('导出失败: $error');
    } finally {
      _setBusy(false, '');
    }
  }

  Future<void> _importData() async {
    final shouldImport = await _confirmImport();
    if (!mounted || !shouldImport) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (!mounted) {
      return;
    }
    if (picked == null || picked.files.isEmpty || picked.files.first.path == null) {
      _showSnack('已取消导入');
      return;
    }

    _setBusy(true, '正在导入数据...');
    try {
      final zipPath = picked.files.first.path!;
      final database = ref.read(appDatabaseProvider);
      final settings = await ref.read(settingsServiceProvider.future);
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zipPath,
      );

      if (!mounted) {
        return;
      }
      _showSnack('数据导入完成');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('导入失败: $error');
    } finally {
      _setBusy(false, '');
    }
  }

  Future<bool> _confirmImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('导入数据'),
          content: const Text('导入会覆盖当前数据，确认继续吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('导入'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
        leading: IconButton(
          tooltip: '返回',
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
                title: const Text('导出数据'),
                subtitle: const Text('导出为 zip，包含日记、标签、设置与本地图片资源'),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: _busy ? null : _exportData,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(FontAwesomeIcons.fileImport, size: 16),
                title: const Text('导入数据'),
                subtitle: const Text('从 zip 恢复数据，会覆盖当前内容'),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: _busy ? null : _importData,
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '建议先执行一次导出备份，再进行导入操作。',
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
                        const LoadingIndicatorM3E(
                          variant: LoadingIndicatorM3EVariant.contained,
                          constraints: BoxConstraints.tightFor(
                            width: 72,
                            height: 72,
                          ),
                          semanticLabel: '数据处理中',
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
