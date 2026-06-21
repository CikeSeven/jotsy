import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/webdav_models.dart';
import 'package:node_diary/core/services/webdav_settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

/// WebDAV 备份式同步页。
///
/// 职责边界：
/// - 负责配置表单、连接测试、上传备份、远程列表、恢复与删除交互；
/// - 业务流程委托 WebDavSyncService，凭据持久化委托 WebDavSettingsService；
/// - 通过明确确认弹窗强调“恢复会覆盖本地数据”，避免误认为是逐条合并同步。
class WebDavSyncPage extends ConsumerStatefulWidget {
  const WebDavSyncPage({super.key});

  @override
  ConsumerState<WebDavSyncPage> createState() => _WebDavSyncPageState();
}

class _WebDavSyncPageState extends ConsumerState<WebDavSyncPage> {
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _remoteDirectoryController = TextEditingController(text: '/jotsy/');

  bool _obscurePassword = true;
  bool _busy = false;
  String _busyText = '';
  List<WebDavBackupEntry> _backups = const <WebDavBackupEntry>[];
  String? _loadedConfigSignature;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remoteDirectoryController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig({bool showSuccess = true}) async {
    final l10n = context.l10n;
    await _runBusy(l10n.webDavBusySave, () async {
      await _persistConfig(showSuccess: showSuccess);
    });
  }

  Future<void> _persistConfig({required bool showSuccess}) async {
    final settings = await ref.read(webDavSettingsServiceProvider.future);
    await settings.saveConfig(_configFromForm());
    ref.invalidate(webDavSyncServiceProvider);
    if (showSuccess && mounted) {
      _showSnack(context.l10n.webDavConfigSaved);
    }
  }

  Future<void> _testConnection() async {
    final l10n = context.l10n;
    await _runBusy(l10n.webDavBusyTest, () async {
      await _persistConfig(showSuccess: false);
      final service = await ref.read(webDavSyncServiceProvider.future);
      await service.testConnection(config: _configFromForm());
      _showSnack(l10n.webDavConnectionOk);
    });
  }

  Future<void> _uploadBackup() async {
    final l10n = context.l10n;
    final password = await _showBackupPasswordDialog(requiredPassword: false);
    if (!mounted || password == null) {
      return;
    }
    await _runBusy(l10n.webDavBusyUpload, () async {
      await _persistConfig(showSuccess: false);
      final service = await ref.read(webDavSyncServiceProvider.future);
      await service.uploadCurrentBackup(zipPassword: password);
      _showSnack(l10n.webDavUploadSuccess);
      await _refreshBackups(showBusy: false);
    });
  }

  Future<void> _refreshBackups({bool showBusy = true}) async {
    final l10n = context.l10n;
    Future<void> action() async {
      await _persistConfig(showSuccess: false);
      final service = await ref.read(webDavSyncServiceProvider.future);
      final backups = await service.listRemoteBackups();
      if (!mounted) {
        return;
      }
      setState(() => _backups = backups);
    }

    if (showBusy) {
      await _runBusy(l10n.webDavBusyRefresh, action);
    } else {
      await action();
    }
  }

  Future<void> _restoreBackup(WebDavBackupEntry entry) async {
    final l10n = context.l10n;
    final confirmed = await _confirmRestore();
    if (!mounted || !confirmed) {
      return;
    }

    String? password;
    await _runBusy(l10n.webDavBusyRestore, () async {
      final service = await ref.read(webDavSyncServiceProvider.future);
      // 仅下载一次：先取到本地，再判断是否加密、按需输入密码并恢复，
      // 避免「判断加密」与「恢复」对同一备份重复下载整包。
      final zipFile = await service.downloadBackup(entry);
      try {
        final passwordProtected = await service.isLocalBackupPasswordProtected(
          zipFile,
        );
        if (!mounted) {
          return;
        }
        if (passwordProtected) {
          _setBusy(false, '');
          password = await _showBackupPasswordDialog(requiredPassword: true);
          if (!mounted || password == null) {
            return;
          }
          _setBusy(true, l10n.webDavBusyRestore);
        }
        await service.restoreFromLocalBackup(
          zipFile: zipFile,
          zipPassword: password,
        );
        _showSnack(l10n.webDavRestoreSuccess);
      } finally {
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
      }
    });
  }

  Future<void> _deleteBackup(WebDavBackupEntry entry) async {
    final l10n = context.l10n;
    final confirmed = await _confirmDelete(entry);
    if (!mounted || !confirmed) {
      return;
    }
    await _runBusy(l10n.webDavBusyDelete, () async {
      final service = await ref.read(webDavSyncServiceProvider.future);
      await service.deleteRemoteBackup(entry);
      _showSnack(l10n.webDavDeleteSuccess);
      await _refreshBackups(showBusy: false);
    });
  }

  Future<void> _runBusy(String busyText, Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    _setBusy(true, busyText);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showSnack(_messageForError(error));
      }
    } finally {
      _setBusy(false, '');
    }
  }

  Future<bool> _confirmRestore() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.webDavRestoreConfirmTitle),
          content: Text(l10n.webDavRestoreConfirmContent),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.webDavRestoreAction),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<bool> _confirmDelete(WebDavBackupEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.webDavDeleteConfirmTitle),
          content: Text(l10n.webDavDeleteConfirmContent(entry.fileName)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.webDavDeleteAction),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<String?> _showBackupPasswordDialog({required bool requiredPassword}) {
    var passwordValue = '';
    var obscureText = true;
    return showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            final l10n = context.l10n;
            return AlertDialog(
              title: Text(l10n.webDavPasswordDialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      obscureText: obscureText,
                      onChanged: (value) => passwordValue = value,
                      decoration: InputDecoration(
                        hintText: l10n.webDavPasswordDialogHint,
                        prefixIcon: const SizedBox(
                          width: 44,
                          child: Center(
                            child: FaIcon(FontAwesomeIcons.lock, size: 16),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() => obscureText = !obscureText);
                          },
                          icon: FaIcon(
                            obscureText
                                ? FontAwesomeIcons.eyeSlash
                                : FontAwesomeIcons.eye,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.webDavPasswordWarning,
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
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: () {
                    if (requiredPassword && passwordValue.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(passwordValue);
                  },
                  child: Text(l10n.webDavContinueWithoutPassword),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _loadConfigIfNeeded(WebDavSettingsService settings) {
    final config = settings.config;
    final signature = config.toJson().toString();
    if (_loadedConfigSignature == signature) {
      return;
    }
    _loadedConfigSignature = signature;
    _serverUrlController.text = config.serverUrl;
    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _remoteDirectoryController.text = config.remoteDirectory;
  }

  WebDavConfig _configFromForm() {
    return WebDavConfig(
      serverUrl: _serverUrlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      remoteDirectory: _remoteDirectoryController.text,
    );
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

  String _messageForError(Object error) {
    final l10n = context.l10n;
    final detail = switch (error) {
      WebDavConfigException() => l10n.webDavErrorConfig,
      WebDavException(isUnauthorized: true) => l10n.webDavErrorAuth,
      WebDavException(isNotFound: true) => l10n.webDavErrorNotFound,
      WebDavException(isInsufficientStorage: true) =>
        l10n.webDavErrorStorageFull,
      WebDavException() => l10n.webDavErrorNetwork,
      _ => l10n.webDavErrorUnknown,
    };
    return l10n.webDavOperationFailed(detail);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(webDavSettingsServiceProvider);
    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.webDavTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: Stack(
        children: <Widget>[
          settingsAsync.when(
            data: (settings) {
              _loadConfigIfNeeded(settings);
              return _buildContent(context, colorScheme);
            },
            loading: () => const SizedBox.shrink(),
            error:
                (error, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: <Widget>[Text(_messageForError(error))],
                ),
          ),
          if (_busy) _buildBusyOverlay(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Text(
          l10n.webDavConfigSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildConfigField(
          controller: _serverUrlController,
          icon: FontAwesomeIcons.link,
          labelText: l10n.webDavServerUrl,
          hintText: l10n.webDavServerUrlHint,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        _buildConfigField(
          controller: _usernameController,
          icon: FontAwesomeIcons.user,
          labelText: l10n.webDavUsername,
        ),
        const SizedBox(height: 12),
        _buildConfigField(
          controller: _passwordController,
          icon: FontAwesomeIcons.lock,
          labelText: l10n.webDavPassword,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            tooltip: l10n.webDavPassword,
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: FaIcon(
              _obscurePassword
                  ? FontAwesomeIcons.eyeSlash
                  : FontAwesomeIcons.eye,
              size: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildConfigField(
          controller: _remoteDirectoryController,
          icon: FontAwesomeIcons.folder,
          labelText: l10n.webDavRemoteDirectory,
          hintText: l10n.webDavRemoteDirectoryHint,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.webDavHint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy ? null : _saveConfig,
              icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
              label: Text(l10n.webDavSaveConfig),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _testConnection,
              icon: const FaIcon(FontAwesomeIcons.plugCircleCheck, size: 14),
              label: Text(l10n.webDavTestConnection),
            ),
          ],
        ),
        const Divider(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy ? null : _uploadBackup,
              icon: const FaIcon(FontAwesomeIcons.cloudArrowUp, size: 14),
              label: Text(l10n.webDavUploadBackup),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _refreshBackups,
              icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
              label: Text(l10n.webDavRefreshBackups),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.webDavBackupList,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_backups.isEmpty)
          Text(
            l10n.webDavNoBackups,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          ..._backups.map(_buildBackupTile),
      ],
    );
  }

  /// 构建一个配置编辑框。
  ///
  /// 统一约束 prefixIcon：用固定宽度的居中盒子承载图标，
  /// 让不同 FontAwesome 字形（宽度天然不一）在多字段列布局中保持左对齐与垂直居中，
  /// 同时令各输入文本起始位置一致，避免出现“图标参差不齐”的观感。
  Widget _buildConfigField({
    required TextEditingController controller,
    required IconData icon,
    required String labelText,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: SizedBox(
          width: 44,
          child: Center(child: FaIcon(icon, size: 16)),
        ),
        // 与上面的固定宽度盒子配套，关闭默认的 48 最小交互尺寸自适应，
        // 保证四个字段的图标盒子完全等宽。
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildBackupTile(WebDavBackupEntry entry) {
    final l10n = context.l10n;
    final subtitleParts = <String>[
      if (entry.createdAt != null)
        l10n.webDavBackupTime(_formatDateTime(entry.createdAt!)),
      if (entry.size != null) l10n.webDavBackupSize(_formatBytes(entry.size!)),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const FaIcon(FontAwesomeIcons.fileZipper, size: 16),
      title: Text(entry.fileName),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: Wrap(
        spacing: 2,
        children: <Widget>[
          IconButton(
            tooltip: l10n.webDavRestoreAction,
            onPressed: _busy ? null : () => _restoreBackup(entry),
            icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14),
          ),
          IconButton(
            tooltip: l10n.webDavDeleteAction,
            onPressed: _busy ? null : () => _deleteBackup(entry),
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBusyOverlay(BuildContext context, ColorScheme colorScheme) {
    return Positioned.fill(
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
                  semanticLabel: context.l10n.webDavBusyLabel,
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
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
