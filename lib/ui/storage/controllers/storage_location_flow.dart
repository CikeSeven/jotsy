import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/app_root_shell.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_data_location.dart';
import '../../../core/services/app_data_location_migrator.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/data_archive_service.dart';
import '../../../core/services/diary_media_cleanup_service.dart';
import '../../../core/services/editing_session_registry.dart';
import '../../../core/services/managed_media_write_gate.dart';
import '../../../core/services/storage/storage_media_service.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../lan_sync/controllers/engine_lan_sync_ui_controller.dart';
import '../../lan_sync/providers/lan_sync_providers.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../providers/storage_providers.dart';
import 'storage_busy_messages.dart';
import 'storage_flows.dart';

/// 桌面端“更改数据存储位置”的交互编排：选目录、校验、确认、停稳写入与
/// 数据库句柄后交给 [AppDataRelocationHost] 执行迁移并重启应用容器。
class StorageLocationFlow {
  const StorageLocationFlow(this._ref, this._host);

  final WidgetRef _ref;
  final StorageFlowHost _host;

  Future<void> openFolder(BuildContext context, String path) async {
    final l10n = context.l10n;
    try {
      final opened = await _ref.read(storageFolderOpenerProvider)(path);
      if (!opened && context.mounted) {
        _host.showSnack(l10n.storageLocationOpenFailed);
      }
    } catch (_) {
      if (context.mounted) _host.showSnack(l10n.storageLocationOpenFailed);
    }
  }

  Future<void> changeLocation(BuildContext context) async {
    final l10n = context.l10n;
    if (!await _guardReady(context)) return;
    if (!context.mounted) return;

    final store = _ref.read(storageLocationStoreProvider);
    final resolution = await store.resolve();
    if (!context.mounted) return;

    final picked = await _ref.read(storageDirectoryPickerProvider)(
      dialogTitle: l10n.storageLocationPickTitle,
    );
    if (picked == null || picked.trim().isEmpty || !context.mounted) return;

    await _handleTargetPath(
      context,
      resolution: resolution,
      rawTargetPath: picked,
      isReset: false,
    );
  }

  Future<void> resetToDefault(BuildContext context) async {
    if (!await _guardReady(context)) return;
    if (!context.mounted) return;

    final store = _ref.read(storageLocationStoreProvider);
    final resolution = await store.resolve();
    if (!resolution.isCustomLocation || !context.mounted) return;

    await _handleTargetPath(
      context,
      resolution: resolution,
      rawTargetPath: resolution.defaultRoot.path,
      isReset: true,
    );
  }

  Future<void> _handleTargetPath(
    BuildContext context, {
    required AppDataLocationResolution resolution,
    required String rawTargetPath,
    required bool isReset,
  }) async {
    final store = _ref.read(storageLocationStoreProvider);
    final check = await store.inspectTarget(
      rawTargetPath,
      currentRoot: resolution.activeRoot.path,
      defaultRoot: resolution.defaultRoot.path,
    );
    if (!context.mounted) return;

    if (!check.isValid) {
      await _showInvalidTargetFeedback(context, check.status);
      return;
    }

    final targetPath = check.normalizedPath!;
    final switchExisting =
        check.status == AppDataLocationTargetStatus.validExistingJotsyData;

    final confirmed = await _confirmRelocation(
      context,
      sourcePath: resolution.activeRoot.path,
      targetPath: targetPath,
      switchExisting: switchExisting,
      isReset: isReset,
    );
    if (!confirmed || !context.mounted) return;

    await _executeRelocation(
      context,
      resolution: resolution,
      targetPath: targetPath,
      switchExisting: switchExisting,
    );
  }

  Future<bool> _guardReady(BuildContext context) async {
    final l10n = context.l10n;
    final registry = EditingSessionRegistry.instance;
    if (registry.isEditing) {
      _host.showSnack(storageBusyMessage(l10n, StorageBusyReason.editing));
      return false;
    }
    if (ManagedMediaWriteGate.hasWriters) {
      _host.showSnack(storageBusyMessage(l10n, StorageBusyReason.mediaWrites));
      return false;
    }
    return true;
  }

  Future<void> _showInvalidTargetFeedback(
    BuildContext context,
    AppDataLocationTargetStatus status,
  ) async {
    final l10n = context.l10n;
    if (status == AppDataLocationTargetStatus.invalidSameAsCurrent) {
      _host.showSnack(l10n.storageLocationErrorSamePath);
      return;
    }
    final message = switch (status) {
      AppDataLocationTargetStatus.invalidEmpty ||
      AppDataLocationTargetStatus.invalidRelative =>
        l10n.storageLocationErrorInvalidPath,
      AppDataLocationTargetStatus.invalidDriveRoot =>
        l10n.storageLocationErrorDriveRoot,
      AppDataLocationTargetStatus.invalidNestedWithCurrent =>
        l10n.storageLocationErrorNested,
      AppDataLocationTargetStatus.invalidInsideAppBundle =>
        l10n.storageLocationErrorInsideApp,
      AppDataLocationTargetStatus.invalidNotWritable =>
        l10n.storageLocationErrorNotWritable,
      AppDataLocationTargetStatus.invalidNonEmptyOther =>
        l10n.storageLocationErrorNotEmpty,
      AppDataLocationTargetStatus.validEmpty ||
      AppDataLocationTargetStatus.validExistingJotsyData ||
      AppDataLocationTargetStatus.invalidSameAsCurrent => '',
    };
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: FaIcon(
            FontAwesomeIcons.circleExclamation,
            size: 24,
            color: colors.error,
          ),
          title: Text(l10n.storageLocationInvalidTitle),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmRelocation(
    BuildContext context, {
    required String sourcePath,
    required String targetPath,
    required bool switchExisting,
    required bool isReset,
  }) async {
    final result = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        final title = switchExisting
            ? l10n.storageLocationConfirmSwitchTitle
            : isReset
            ? l10n.storageLocationConfirmResetTitle
            : l10n.storageLocationConfirmMigrateTitle;
        final body = switchExisting
            ? l10n.storageLocationConfirmSwitchBody
            : l10n.storageLocationConfirmMigrateBody;
        final actionLabel = switchExisting
            ? l10n.storageLocationConfirmSwitchAction
            : l10n.storageLocationConfirmMigrateAction;
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                _PathSummaryBox(
                  label: l10n.storageLocationCurrentLabel,
                  path: sourcePath,
                ),
                const SizedBox(height: AppSpacing.s),
                _PathSummaryBox(
                  label: l10n.storageLocationTargetLabel,
                  path: targetPath,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _executeRelocation(
    BuildContext context, {
    required AppDataLocationResolution resolution,
    required String targetPath,
    required bool switchExisting,
  }) async {
    final l10n = context.l10n;
    final host = _ref.read(appDataRelocationHostProvider);
    final migrator = _ref.read(storageLocationMigratorProvider);
    final settings = await _ref.read(settingsServiceProvider.future);
    final themeMode = settings.themeModeNotifier.value;
    final locale = settings.localeNotifier.value;
    final seedColor = settings.themeSeedColorNotifier.value;

    _host.setBusy(true, l10n.storageLocationPreparing);
    try {
      final registry = EditingSessionRegistry.instance;
      await registry.flushAll();
      final undoClosed = await registry.waitForUndoWindows(
        timeout: StorageMediaService.undoWindowTimeout,
      );
      if (!undoClosed) {
        if (context.mounted) {
          _host.showSnack(
            storageBusyMessage(l10n, StorageBusyReason.undoWindow),
          );
        }
        return;
      }
      if (registry.isEditing) {
        if (context.mounted) {
          _host.showSnack(storageBusyMessage(l10n, StorageBusyReason.editing));
        }
        return;
      }

      // 停稳局域网同步、媒体回收、网盘备份与串行归档队列，再关 SQLite 句柄。
      final lanSync = _ref.read(lanSyncControllerProvider);
      if (lanSync is EngineLanSyncUiController) {
        await lanSync.dispose();
      }
      _ref.read(diaryMediaCleanupServiceProvider).dispose();
      await DiaryMediaCleanupService.whenSweepsIdle();
      final cloudBackup = _ref.read(cloudBackupServiceProvider).asData?.value;
      if (cloudBackup != null) {
        await cloudBackup.waitForIdle();
      }

      final acquired = await ManagedMediaWriteGate.exclusive(
        () => DataArchiveService.runSerialized(() async {
          final db = _ref.read(appDatabaseProvider);
          try {
            await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
          } catch (_) {
            // WAL 未启用或库尚未打开时忽略。
          }
          await db.close();
          return true;
        }),
        timeout: const Duration(seconds: 8),
      ).catchError((Object _) => false);

      if (!acquired) {
        _ref
          ..invalidate(lanSyncControllerProvider)
          ..invalidate(diaryMediaCleanupServiceProvider);
        if (context.mounted) {
          _host.showSnack(
            storageBusyMessage(l10n, StorageBusyReason.mediaWrites),
          );
        }
        return;
      }

      Future<AppDataMigrationResult> runTask(
        void Function(AppDataMigrationProgress) onProgress,
      ) {
        if (switchExisting) {
          return migrator.switchToExistingData(
            sourceRoot: resolution.activeRoot,
            targetRoot: Directory(targetPath),
            supportDir: resolution.defaultRoot,
            settings: settings,
            onProgress: onProgress,
          );
        }
        return migrator.migrateData(
          sourceRoot: resolution.activeRoot,
          targetRoot: Directory(targetPath),
          supportDir: resolution.defaultRoot,
          settings: settings,
          onProgress: onProgress,
        );
      }

      if (host != null) {
        await host.relocate(
          themeMode: themeMode,
          locale: locale,
          seedColor: seedColor,
          task: runTask,
          successNotice: (l10n, result) {
            if (result.cleanupIncomplete) {
              return l10n.storageLocationMigratedCleanupPartial(
                result.targetRoot.path,
              );
            }
            return switchExisting
                ? l10n.storageLocationSwitchedNotice(result.targetRoot.path)
                : l10n.storageLocationMigratedNotice(result.targetRoot.path);
          },
          failureNotice: (l10n, error) =>
              l10n.storageLocationMigrationFailed(error.toString()),
        );
      } else {
        await runTask((_) {});
        if (context.mounted) {
          refreshStorageViews(_ref);
          _host.showSnack(
            switchExisting
                ? l10n.storageLocationSwitchedNotice(targetPath)
                : l10n.storageLocationMigratedNotice(targetPath),
          );
        }
      }
    } finally {
      _host.setBusy(false);
    }
  }
}

class _PathSummaryBox extends StatelessWidget {
  const _PathSummaryBox({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            AppGlassField.of(context)?.fill ??
            colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              path,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
