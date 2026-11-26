import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'app_data_location.dart';
import 'app_data_media_rebind.dart';
import 'settings_service.dart';

/// 迁移进度阶段。
enum AppDataMigrationPhase {
  preparing,
  copying,
  rebinding,
  finalizing,
  cleaningUp,
}

/// 迁移进度快照。
@immutable
class AppDataMigrationProgress {
  const AppDataMigrationProgress({
    required this.phase,
    this.copiedFiles = 0,
    this.totalFiles = 0,
    this.copiedBytes = 0,
    this.totalBytes = 0,
  });

  final AppDataMigrationPhase phase;
  final int copiedFiles;
  final int totalFiles;
  final int copiedBytes;
  final int totalBytes;

  double? get fraction {
    if (phase == AppDataMigrationPhase.preparing) return null;
    if (phase != AppDataMigrationPhase.copying) return 1.0;
    if (totalBytes > 0) return (copiedBytes / totalBytes).clamp(0.0, 1.0);
    if (totalFiles > 0) return (copiedFiles / totalFiles).clamp(0.0, 1.0);
    return 1.0;
  }
}

/// 迁移或切换数据位置的结果。
@immutable
class AppDataMigrationResult {
  const AppDataMigrationResult({
    required this.targetRoot,
    required this.reboundRows,
    required this.cleanupIncomplete,
  });

  final Directory targetRoot;
  final int reboundRows;
  final bool cleanupIncomplete;
}

class _PlannedFile {
  const _PlannedFile({
    required this.source,
    required this.relativePath,
    required this.bytes,
    required this.modifiedAt,
  });

  final File source;
  final String relativePath;
  final int bytes;
  final DateTime modifiedAt;
}

/// 执行桌面端数据根目录的安全迁移、切换到已有数据以及外部路径变动自愈。
///
/// 所有操作先复制并校验、重绑目标库、再切配置指针，最后才清理原目录中的
/// 托管数据文件（从不碰默认支持目录下的 `shared_preferences.json` 与
/// `data_location.json`）；提交之前任一步失败都会回滚目标位置新建的内容。
class AppDataLocationMigrator {
  AppDataLocationMigrator({AppDataLocationStore? store})
    : _store = store ?? AppDataLocationStore.instance;

  final AppDataLocationStore _store;

  /// 将 [sourceRoot] 的托管数据库、媒体、字体与本机状态安全迁移到 [targetRoot]。
  /// 调用前须先关闭已打开的 [AppDatabase] 与写入后台服务。
  Future<AppDataMigrationResult> migrateData({
    required Directory sourceRoot,
    required Directory targetRoot,
    required Directory supportDir,
    SettingsService? settings,
    void Function(AppDataMigrationProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const AppDataMigrationProgress(phase: AppDataMigrationPhase.preparing),
    );
    final sourceNorm = p.normalize(sourceRoot.path);
    final targetNorm = p.normalize(targetRoot.path);
    final supportNorm = p.normalize(supportDir.path);
    final check = await _store.inspectTarget(
      targetNorm,
      currentRoot: sourceNorm,
      defaultRoot: supportNorm,
    );
    if (check.status != AppDataLocationTargetStatus.validEmpty) {
      throw StateError('Invalid migration target state: ${check.status.name}');
    }

    final plan = await _collectPlan(Directory(sourceNorm));
    final totalBytes = plan.files.fold<int>(0, (sum, file) => sum + file.bytes);
    final targetDir = Directory(targetNorm);
    final targetExisted = await targetDir.exists();
    final createdFiles = <File>[];
    final createdDirs = <Directory>[];

    try {
      if (!targetExisted) {
        await targetDir.create(recursive: true);
        createdDirs.add(targetDir);
      }

      var copiedFiles = 0;
      var copiedBytes = 0;
      onProgress?.call(
        AppDataMigrationProgress(
          phase: AppDataMigrationPhase.copying,
          copiedFiles: 0,
          totalFiles: plan.files.length,
          copiedBytes: 0,
          totalBytes: totalBytes,
        ),
      );

      for (final dirRelative in plan.emptyDirectories) {
        final dir = Directory(p.join(targetNorm, dirRelative));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          createdDirs.add(dir);
        }
      }

      for (final entry in plan.files) {
        final destFile = File(p.join(targetNorm, entry.relativePath));
        await _ensureParentTracked(destFile.parent, createdDirs);
        await _copyFileStreamed(
          entry.source,
          destFile,
          expectedBytes: entry.bytes,
          modifiedAt: entry.modifiedAt,
          onChunk: (int chunkBytes) {
            copiedBytes += chunkBytes;
            onProgress?.call(
              AppDataMigrationProgress(
                phase: AppDataMigrationPhase.copying,
                copiedFiles: copiedFiles,
                totalFiles: plan.files.length,
                copiedBytes: copiedBytes,
                totalBytes: totalBytes,
              ),
            );
          },
        );
        createdFiles.add(destFile);
        copiedFiles++;
        onProgress?.call(
          AppDataMigrationProgress(
            phase: AppDataMigrationPhase.copying,
            copiedFiles: copiedFiles,
            totalFiles: plan.files.length,
            copiedBytes: copiedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      onProgress?.call(
        AppDataMigrationProgress(
          phase: AppDataMigrationPhase.rebinding,
          copiedFiles: copiedFiles,
          totalFiles: plan.files.length,
          copiedBytes: copiedBytes,
          totalBytes: totalBytes,
        ),
      );
      final targetDb = File(p.join(targetNorm, appDatabaseFileName));
      var reboundRows = 0;
      if (await targetDb.exists()) {
        reboundRows = await _rebindDatabaseFile(
          targetDb,
          newRoot: targetNorm,
          oldRoot: sourceNorm,
          settings: settings,
        );
      }

      onProgress?.call(
        AppDataMigrationProgress(
          phase: AppDataMigrationPhase.finalizing,
          copiedFiles: copiedFiles,
          totalFiles: plan.files.length,
          copiedBytes: copiedBytes,
          totalBytes: totalBytes,
        ),
      );
      await _store.writeBoundRootMarker(targetDir);
      createdFiles.add(File(p.join(targetNorm, boundRootMarkerFileName)));
      await _store.saveUserConfig(
        supportDir: Directory(supportNorm),
        targetPath: p.equals(targetNorm, supportNorm) ? null : targetNorm,
      );

      onProgress?.call(
        AppDataMigrationProgress(
          phase: AppDataMigrationPhase.cleaningUp,
          copiedFiles: copiedFiles,
          totalFiles: plan.files.length,
          copiedBytes: copiedBytes,
          totalBytes: totalBytes,
        ),
      );
      final cleanupOk = await _cleanupSourceItems(Directory(sourceNorm));
      return AppDataMigrationResult(
        targetRoot: targetDir,
        reboundRows: reboundRows,
        cleanupIncomplete: !cleanupOk,
      );
    } catch (_) {
      await _rollbackCreated(
        files: createdFiles,
        dirs: createdDirs,
        targetExisted: targetExisted,
        targetDir: targetDir,
      );
      rethrow;
    }
  }

  /// 切换到已经存在 `node_diary.sqlite` 的目标目录，不删除原目录数据。
  Future<AppDataMigrationResult> switchToExistingData({
    required Directory sourceRoot,
    required Directory targetRoot,
    required Directory supportDir,
    SettingsService? settings,
    void Function(AppDataMigrationProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const AppDataMigrationProgress(phase: AppDataMigrationPhase.rebinding),
    );
    final targetNorm = p.normalize(targetRoot.path);
    final supportNorm = p.normalize(supportDir.path);
    final check = await _store.inspectTarget(
      targetNorm,
      currentRoot: p.normalize(sourceRoot.path),
      defaultRoot: supportNorm,
    );
    if (check.status != AppDataLocationTargetStatus.validExistingJotsyData) {
      throw StateError('Target does not contain existing Jotsy data');
    }
    final reboundRows = await ensureBoundRootCurrent(
      activeRoot: Directory(targetNorm),
      settings: settings,
    );
    onProgress?.call(
      const AppDataMigrationProgress(phase: AppDataMigrationPhase.finalizing),
    );
    await _store.saveUserConfig(
      supportDir: Directory(supportNorm),
      targetPath: p.equals(targetNorm, supportNorm) ? null : targetNorm,
    );
    return AppDataMigrationResult(
      targetRoot: Directory(targetNorm),
      reboundRows: reboundRows,
      cleanupIncomplete: false,
    );
  }

  /// 若 [activeRoot] 中已有数据库且实际路径与上次绑定标记不一致（如移动了
  /// 便携盘盘符），自动重绑媒体路径并更新标记。
  Future<int> ensureBoundRootCurrent({
    required Directory activeRoot,
    SettingsService? settings,
  }) async {
    final activeNorm = p.normalize(activeRoot.path);
    final dbFile = File(p.join(activeNorm, appDatabaseFileName));
    if (!await dbFile.exists()) return 0;

    final recordedRoot = await _store.readBoundRootMarker(activeRoot);
    if (recordedRoot != null && p.equals(recordedRoot, activeNorm)) {
      return 0;
    }
    final updated = await _rebindDatabaseFile(
      dbFile,
      newRoot: activeNorm,
      oldRoot: recordedRoot,
      settings: settings,
    );
    await _store.writeBoundRootMarker(activeRoot);
    return updated;
  }

  Future<int> _rebindDatabaseFile(
    File dbFile, {
    required String newRoot,
    String? oldRoot,
    SettingsService? settings,
  }) async {
    final db = AppDatabase.openFile(dbFile);
    try {
      final rows = await rebindDatabaseManagedMediaRoot(
        database: db,
        newRoot: newRoot,
        oldRoot: oldRoot,
        settings: settings,
      );
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      return rows;
    } finally {
      await db.close();
    }
  }

  Future<({List<_PlannedFile> files, List<String> emptyDirectories})>
  _collectPlan(Directory sourceRoot) async {
    final files = <_PlannedFile>[];
    final emptyDirectories = <String>[];
    final rootNorm = p.normalize(sourceRoot.path);
    if (!await sourceRoot.exists()) {
      return (files: files, emptyDirectories: emptyDirectories);
    }

    for (final fileName in managedDatabaseFileNames) {
      final file = File(p.join(rootNorm, fileName));
      if (!await file.exists()) continue;
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      files.add(
        _PlannedFile(
          source: file,
          relativePath: fileName,
          bytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    for (final dirName in managedDataDirectoryNames) {
      final dir = Directory(p.join(rootNorm, dirName));
      if (!await dir.exists()) continue;
      var hasFile = false;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Directory) {
          final rel = p.relative(entity.path, from: rootNorm);
          emptyDirectories.add(rel);
          continue;
        }
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        hasFile = true;
        files.add(
          _PlannedFile(
            source: entity,
            relativePath: p.relative(entity.path, from: rootNorm),
            bytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      }
      if (!hasFile) emptyDirectories.add(dirName);
    }

    return (files: files, emptyDirectories: emptyDirectories);
  }

  Future<void> _ensureParentTracked(
    Directory dir,
    List<Directory> createdDirs,
  ) async {
    if (await dir.exists()) return;
    await _ensureParentTracked(dir.parent, createdDirs);
    await dir.create();
    createdDirs.add(dir);
  }

  Future<void> _copyFileStreamed(
    File source,
    File dest, {
    required int expectedBytes,
    required DateTime modifiedAt,
    required void Function(int bytes) onChunk,
  }) async {
    final sink = dest.openWrite();
    var written = 0;
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        written += chunk.length;
        onChunk(chunk.length);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (written != expectedBytes || await dest.length() != expectedBytes) {
      throw FileSystemException('Copied file size mismatch', dest.path);
    }
    try {
      await dest.setLastModified(modifiedAt);
    } on FileSystemException {
      // 部分文件系统不允许改时间时只影响去重缓存重建，不阻断迁移。
    }
  }

  Future<bool> _cleanupSourceItems(Directory sourceRoot) async {
    var allClean = true;
    final rootNorm = p.normalize(sourceRoot.path);
    for (final name in <String>[
      ...managedDatabaseFileNames,
      boundRootMarkerFileName,
    ]) {
      final file = File(p.join(rootNorm, name));
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (error) {
        debugPrint(
          'Migration source file cleanup skipped ${file.path}: $error',
        );
        allClean = false;
      }
    }
    for (final dirName in managedDataDirectoryNames) {
      final dir = Directory(p.join(rootNorm, dirName));
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('Migration source dir cleanup skipped ${dir.path}: $error');
        allClean = false;
      }
    }
    return allClean;
  }

  Future<void> _rollbackCreated({
    required List<File> files,
    required List<Directory> dirs,
    required bool targetExisted,
    required Directory targetDir,
  }) async {
    for (final file in files.reversed) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // 回滚清理尽力而为。
      }
    }
    for (final dir in dirs.reversed) {
      try {
        if (await dir.exists() && await dir.list().isEmpty) {
          await dir.delete();
        }
      } on FileSystemException {
        // 同上。
      }
    }
    if (!targetExisted) {
      try {
        if (await targetDir.exists() && await targetDir.list().isEmpty) {
          await targetDir.delete();
        }
      } on FileSystemException {
        // 同上。
      }
    }
  }
}
