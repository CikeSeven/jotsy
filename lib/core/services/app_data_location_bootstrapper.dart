import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_data_location.dart';
import 'app_data_location_migrator.dart';
import 'app_platform.dart';
import 'settings_service.dart';

/// 冷启动数据位置引导的结果。
@immutable
class AppDataStartupBootstrapResult {
  const AppDataStartupBootstrapResult({
    this.migratedToPath,
    this.pendingMigrationFailed = false,
    this.errorMessage,
  });

  final String? migratedToPath;
  final bool pendingMigrationFailed;
  final String? errorMessage;
}

/// 冷启动数据位置引导：
/// 1. 处理 Windows 安装程序升级换路径时写下的 `pendingTargetPath` 自动迁移；
/// 2. 在已有数据库且根目录发生变化（例如便携盘盘符变化）时自动重绑媒体路径。
class AppDataLocationBootstrapper {
  AppDataLocationBootstrapper({
    AppDataLocationStore? store,
    AppDataLocationMigrator? migrator,
    Future<SettingsService> Function()? settingsFactory,
  }) : _store = store ?? AppDataLocationStore.instance,
       _migrator = migrator ?? AppDataLocationMigrator(store: store),
       _settingsFactory = settingsFactory ?? SettingsService.create;

  final AppDataLocationStore _store;
  final AppDataLocationMigrator _migrator;
  final Future<SettingsService> Function() _settingsFactory;

  Future<bool> hasPendingStartupWork() async {
    if (!AppPlatform.supportsCustomDataDirectory) return false;
    final resolution = await _store.resolve();
    return resolution.pendingTargetPath != null;
  }

  Future<AppDataStartupBootstrapResult> prepareOnStartup({
    void Function(AppDataMigrationProgress progress)? onProgress,
  }) async {
    if (!AppPlatform.supportsCustomDataDirectory) {
      return const AppDataStartupBootstrapResult();
    }
    final resolution = await _store.resolve();
    final pendingTarget = resolution.pendingTargetPath;
    if (pendingTarget != null) {
      final sourceNorm = p.normalize(resolution.activeRoot.path);
      final targetNorm = p.normalize(pendingTarget);
      if (p.equals(sourceNorm, targetNorm)) {
        await _store.saveUserConfig(
          supportDir: resolution.defaultRoot,
          targetPath:
              p.equals(targetNorm, p.normalize(resolution.defaultRoot.path))
              ? null
              : targetNorm,
        );
        return const AppDataStartupBootstrapResult();
      }
      try {
        final settings = await _settingsFactory();
        final check = await _store.inspectTarget(
          targetNorm,
          currentRoot: sourceNorm,
          defaultRoot: p.normalize(resolution.defaultRoot.path),
        );
        if (check.status ==
            AppDataLocationTargetStatus.validExistingJotsyData) {
          await _migrator.switchToExistingData(
            sourceRoot: resolution.activeRoot,
            targetRoot: Directory(targetNorm),
            supportDir: resolution.defaultRoot,
            settings: settings,
            onProgress: onProgress,
          );
        } else {
          await _migrator.migrateData(
            sourceRoot: resolution.activeRoot,
            targetRoot: Directory(targetNorm),
            supportDir: resolution.defaultRoot,
            settings: settings,
            onProgress: onProgress,
          );
        }
        return AppDataStartupBootstrapResult(migratedToPath: targetNorm);
      } catch (error, stackTrace) {
        debugPrint('Startup data migration failed: $error\n$stackTrace');
        return AppDataStartupBootstrapResult(
          pendingMigrationFailed: true,
          errorMessage: error.toString(),
        );
      }
    }

    try {
      await _migrator.ensureBoundRootCurrent(activeRoot: resolution.activeRoot);
    } catch (error, stackTrace) {
      debugPrint('Startup bound root check skipped: $error\n$stackTrace');
    }
    return const AppDataStartupBootstrapResult();
  }

  /// 放弃待执行的安装迁移并保留原路径继续启动。
  Future<void> clearPendingMigration() async {
    final resolution = await _store.resolve();
    await _store.saveUserConfig(
      supportDir: resolution.defaultRoot,
      targetPath: resolution.isCustomLocation
          ? resolution.activeRoot.path
          : null,
    );
  }
}
