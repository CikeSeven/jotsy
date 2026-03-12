import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'settings_service.dart';

/// 数据归档服务（ZIP 导入/导出）。
///
/// 职责边界：
/// - 导出：打包数据库表数据、设置项与本地媒体资源到 zip；
/// - 导入：从 zip 恢复数据库表数据、设置项与本地媒体资源；
/// - 不参与 UI 提示与交互，页面层负责 loading 与反馈文案。
class DataArchiveService {
  DataArchiveService._();

  static const String _backupPayloadFileName = 'backup_data.json';
  static const String _backupCoversDirectoryName = 'diary_covers';
  static const String _backupImagesDirectoryName = 'diary_images';
  static const int _backupFormatVersion = 1;

  /// 导出当前数据到 zip，返回生成的 zip 文件对象（位于临时目录）。
  static Future<File> exportToZip({
    required AppDatabase database,
    required SettingsService settingsService,
  }) async {
    final tempRoot = await _prepareWorkingDirectory(prefix: 'backup_export');
    try {
      final payload = await _buildBackupPayload(
        database: database,
        settingsService: settingsService,
      );
      final payloadFile = File(p.join(tempRoot.path, _backupPayloadFileName));
      await payloadFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );

      await _copyManagedDirectoryToWorkingDir(
        sourceDirectoryName: _backupCoversDirectoryName,
        targetRoot: tempRoot,
      );
      await _copyManagedDirectoryToWorkingDir(
        sourceDirectoryName: _backupImagesDirectoryName,
        targetRoot: tempRoot,
      );

      final outputZipPath = p.join(
        (await getTemporaryDirectory()).path,
        'node_note_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      final bytes = await _encodeDirectoryToZipBytes(tempRoot);
      final zipFile = File(outputZipPath);
      await zipFile.writeAsBytes(bytes, flush: true);
      return zipFile;
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  /// 从 zip 覆盖导入数据。
  ///
  /// 导入策略：
  /// 1) 恢复数据库表数据（清空后重建）；
  /// 2) 恢复本地媒体目录（封面/正文图片）；
  /// 3) 恢复设置项（主题、排序、布局、工具栏顺序、标签顺序、草稿）。
  static Future<void> importFromZip({
    required AppDatabase database,
    required SettingsService settingsService,
    required String zipPath,
  }) async {
    final sourceZip = File(zipPath);
    if (!await sourceZip.exists()) {
      throw const FileSystemException('备份文件不存在');
    }

    final extractRoot = await _prepareWorkingDirectory(prefix: 'backup_import');
    try {
      await _extractZipToDirectory(sourceZip, extractRoot);
      final payloadFile = File(p.join(extractRoot.path, _backupPayloadFileName));
      if (!await payloadFile.exists()) {
        throw const FormatException('备份文件缺少 backup_data.json');
      }

      final payloadRaw = await payloadFile.readAsString();
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('备份数据格式错误');
      }

      await _restoreDatabaseFromPayload(database, decoded);
      await _restoreManagedDirectoryFromBackup(
        backupRoot: extractRoot,
        directoryName: _backupCoversDirectoryName,
      );
      await _restoreManagedDirectoryFromBackup(
        backupRoot: extractRoot,
        directoryName: _backupImagesDirectoryName,
      );
      await _restoreSettingsFromPayload(settingsService, decoded);
    } finally {
      if (await extractRoot.exists()) {
        await extractRoot.delete(recursive: true);
      }
    }
  }

  static Future<Map<String, Object?>> _buildBackupPayload({
    required AppDatabase database,
    required SettingsService settingsService,
  }) async {
    final diaries = await database.select(database.diaries).get();
    final tags = await database.select(database.tags).get();
    final diaryTags = await database.select(database.diaryTags).get();

    return <String, Object?>{
      'formatVersion': _backupFormatVersion,
      'generatedAt': DateTime.now().toIso8601String(),
      'database': <String, Object?>{
        'diaries': diaries.map((row) => row.toJson()).toList(growable: false),
        'tags': tags.map((row) => row.toJson()).toList(growable: false),
        'diaryTags': diaryTags.map((row) => row.toJson()).toList(growable: false),
      },
      'settings': <String, Object?>{
        'themeMode': settingsService.themeModeNotifier.value.name,
        'diarySortModeRaw': settingsService.diarySortModeRaw,
        'diaryLayoutModeRaw': settingsService.diaryLayoutModeRaw,
        'diaryToolbarOrderRaw': settingsService.diaryToolbarOrderRaw,
        'tagOrderRaw': settingsService.tagOrderRaw,
        'createDiaryDraftRaw': settingsService.createDiaryDraftRaw,
      },
    };
  }

  static Future<void> _restoreDatabaseFromPayload(
    AppDatabase database,
    Map<String, dynamic> payload,
  ) async {
    final databaseNode = payload['database'];
    if (databaseNode is! Map<String, dynamic>) {
      throw const FormatException('备份数据缺少 database 节点');
    }

    final diariesJson = _asMapList(databaseNode['diaries']);
    final tagsJson = _asMapList(databaseNode['tags']);
    final diaryTagsJson = _asMapList(databaseNode['diaryTags']);

    final diaries =
        diariesJson
            .map((row) => Diary.fromJson(row))
            .toList(growable: false);
    final tags =
        tagsJson.map((row) => Tag.fromJson(row)).toList(growable: false);
    final diaryTags =
        diaryTagsJson
            .map((row) => DiaryTag.fromJson(row))
            .toList(growable: false);

    await database.transaction(() async {
      await database.delete(database.diaryTags).go();
      await database.delete(database.diaries).go();
      await database.delete(database.tags).go();

      if (tags.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(
            database.tags,
            tags.map((row) {
              return TagsCompanion(
                id: Value<int>(row.id),
                name: Value<String>(row.name),
                color: Value<int>(row.color),
              );
            }).toList(growable: false),
          );
        });
      }

      if (diaries.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(
            database.diaries,
            diaries.map((row) {
              return DiariesCompanion(
                id: Value<int>(row.id),
                diaryId: Value<String>(row.diaryId),
                title: Value<String>(row.title),
                content: Value<String>(row.content),
                contentText: Value<String>(row.contentText),
                cover: Value<String?>(row.cover),
                metadata: Value<String>(row.metadata),
                createdAt: Value<DateTime>(row.createdAt),
                updatedAt: Value<DateTime>(row.updatedAt),
                isArchived: Value<bool>(row.isArchived),
                archivedAt: Value<DateTime?>(row.archivedAt),
                isDeleted: Value<bool>(row.isDeleted),
                deletedAt: Value<DateTime?>(row.deletedAt),
              );
            }).toList(growable: false),
          );
        });
      }

      if (diaryTags.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(
            database.diaryTags,
            diaryTags.map((row) {
              return DiaryTagsCompanion(
                diaryId: Value<int>(row.diaryId),
                tagId: Value<int>(row.tagId),
              );
            }).toList(growable: false),
          );
        });
      }
    });
  }

  static Future<void> _restoreSettingsFromPayload(
    SettingsService settingsService,
    Map<String, dynamic> payload,
  ) async {
    final settingsNode = payload['settings'];
    if (settingsNode is! Map<String, dynamic>) {
      return;
    }

    final themeRaw = settingsNode['themeMode']?.toString();
    if (themeRaw != null) {
      await settingsService.setThemeMode(_parseThemeMode(themeRaw));
    }

    final sortRaw = settingsNode['diarySortModeRaw']?.toString();
    if (sortRaw != null && sortRaw.isNotEmpty) {
      await settingsService.setDiarySortModeRaw(sortRaw);
    }

    final layoutRaw = settingsNode['diaryLayoutModeRaw']?.toString();
    if (layoutRaw != null && layoutRaw.isNotEmpty) {
      await settingsService.setDiaryLayoutModeRaw(layoutRaw);
    }

    final toolbarRaw = settingsNode['diaryToolbarOrderRaw']?.toString();
    if (toolbarRaw != null && toolbarRaw.isNotEmpty) {
      await settingsService.setDiaryToolbarOrderRaw(toolbarRaw);
    }

    final tagOrderRaw = settingsNode['tagOrderRaw']?.toString();
    if (tagOrderRaw != null && tagOrderRaw.isNotEmpty) {
      await settingsService.setTagOrderRaw(tagOrderRaw);
    }

    final draftRaw = settingsNode['createDiaryDraftRaw']?.toString();
    if (draftRaw != null && draftRaw.isNotEmpty) {
      await settingsService.setCreateDiaryDraftRaw(draftRaw);
    } else {
      await settingsService.clearCreateDiaryDraft();
    }
  }

  static ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }

  static Future<Directory> _prepareWorkingDirectory({
    required String prefix,
  }) async {
    final temp = await getTemporaryDirectory();
    final target = Directory(
      p.join(temp.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}'),
    );
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);
    return target;
  }

  static Future<void> _copyManagedDirectoryToWorkingDir({
    required String sourceDirectoryName,
    required Directory targetRoot,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final sourceDir = Directory(p.join(docs.path, sourceDirectoryName));
    if (!await sourceDir.exists()) {
      return;
    }
    final targetDir = Directory(p.join(targetRoot.path, sourceDirectoryName));
    await _copyDirectoryRecursively(sourceDir, targetDir);
  }

  static Future<void> _restoreManagedDirectoryFromBackup({
    required Directory backupRoot,
    required String directoryName,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docs.path, directoryName));
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }

    final sourceDir = Directory(p.join(backupRoot.path, directoryName));
    if (!await sourceDir.exists()) {
      await targetDir.create(recursive: true);
      return;
    }
    await _copyDirectoryRecursively(sourceDir, targetDir);
  }

  static Future<void> _copyDirectoryRecursively(
    Directory source,
    Directory target,
  ) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectoryRecursively(entity, Directory(targetPath));
        continue;
      }
      if (entity is File) {
        await File(entity.path).copy(targetPath);
      }
    }
  }

  static Future<Uint8List> _encodeDirectoryToZipBytes(Directory root) async {
    final archive = Archive();
    final rootPath = p.normalize(root.path);
    await for (final entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final normalizedEntityPath = p.normalize(entity.path);
      final relativePath = p
          .relative(normalizedEntityPath, from: rootPath)
          .replaceAll('\\', '/');
      final bytes = await entity.readAsBytes();
      final entry = ArchiveFile(relativePath, bytes.length, bytes);
      archive.addFile(entry);
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const FileSystemException('创建 zip 失败');
    }
    return Uint8List.fromList(encoded);
  }

  static Future<void> _extractZipToDirectory(
    File zipFile,
    Directory targetDirectory,
  ) async {
    final rawBytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(rawBytes, verify: true);
    final targetRoot = p.normalize(targetDirectory.path);

    for (final entry in archive.files) {
      if (!entry.isFile) {
        continue;
      }

      final normalizedEntryName = p
          .normalize(entry.name)
          .replaceAll('\\', '/');
      if (normalizedEntryName.isEmpty || normalizedEntryName.contains('..')) {
        continue;
      }

      final outputPath = p.join(targetRoot, normalizedEntryName);
      final normalizedOutputPath = p.normalize(outputPath);
      if (!p.isWithin(targetRoot, normalizedOutputPath) &&
          normalizedOutputPath != targetRoot) {
        continue;
      }

      final outputFile = File(normalizedOutputPath);
      await outputFile.parent.create(recursive: true);
      final data = entry.content;
      if (data is List<int>) {
        await outputFile.writeAsBytes(data, flush: true);
      }
    }
  }
}
