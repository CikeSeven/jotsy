import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
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
    String? zipPassword,
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
      final bytes = await _encodeDirectoryToZipBytes(
        tempRoot,
        password: _normalizeOptionalPassword(zipPassword),
      );
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
    String? zipPassword,
  }) async {
    final sourceZip = File(zipPath);
    if (!await sourceZip.exists()) {
      throw const FileSystemException('备份文件不存在');
    }

    final extractRoot = await _prepareWorkingDirectory(prefix: 'backup_import');
    try {
      await _extractZipToDirectory(
        sourceZip,
        extractRoot,
        password: _normalizeOptionalPassword(zipPassword),
      );
      final payloadFile = File(
        p.join(extractRoot.path, _backupPayloadFileName),
      );
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

  /// 判断 zip 是否为加密包。
  ///
  /// 规则：
  /// - 任意文件头存在加密位（generalPurposeBitFlag bit0）则认为需要密码；
  /// - 或压缩方法标记为 AES 加密（99）也视为加密包。
  static Future<bool> isZipPasswordProtected({required String zipPath}) async {
    final sourceZip = File(zipPath);
    if (!await sourceZip.exists()) {
      throw const FileSystemException('备份文件不存在');
    }
    return Isolate.run<bool>(() => _isZipPasswordProtectedSync(sourceZip.path));
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
        'diaryTags': diaryTags
            .map((row) => row.toJson())
            .toList(growable: false),
      },
      'settings': <String, Object?>{
        'themeMode': settingsService.themeModeNotifier.value.name,
        'themeSeedColorValue': settingsService.themeSeedColorValue,
        'homeTabSwitchCurveType': settingsService.homeTabSwitchCurveTypeValue,
        'editorBodyFontSizePreset':
            settingsService.editorBodyFontSizePresetStorageValue,
        'editorBodyLineHeightPreset':
            settingsService.editorBodyLineHeightPresetStorageValue,
        'fontScale': settingsService.fontScaleValue,
        'appLocaleCode': settingsService.appLocaleCode,
        'appLockEnabled': settingsService.isAppLockEnabled,
        'diarySortModeRaw': settingsService.diarySortModeRaw,
        'diaryLayoutModeRaw': settingsService.diaryLayoutModeRaw,
        'diaryCardTagLimit': settingsService.diaryCardTagLimit,
        'diaryToolbarOrderRaw': settingsService.diaryToolbarOrderRaw,
        'diaryToolbarHiddenItemsRaw':
            settingsService.diaryToolbarHiddenItemsRaw,
        'diaryToolbarCurrentTimeFormatRaw':
            settingsService.diaryToolbarCurrentTimeFormatRaw,
        'tagOrderRaw': settingsService.tagOrderRaw,
        'tagFilterMemoryEnabled': settingsService.isTagFilterMemoryEnabled,
        'rememberedTagFilterIdsRaw': settingsService.rememberedTagFilterIdsRaw,
        'createDiaryDraftRaw': settingsService.createDiaryDraftRaw,
        'releaseMirrorStartIndex': settingsService.releaseMirrorStartIndexRaw,
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

    final diaries = diariesJson
        .map((row) => Diary.fromJson(row))
        .toList(growable: false);
    final tags = tagsJson
        .map((row) => Tag.fromJson(row))
        .toList(growable: false);
    final diaryTags = diaryTagsJson
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
            tags
                .map((row) {
                  return TagsCompanion(
                    id: Value<int>(row.id),
                    name: Value<String>(row.name),
                    color: Value<int>(row.color),
                  );
                })
                .toList(growable: false),
          );
        });
      }

      if (diaries.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(
            database.diaries,
            diaries
                .map((row) {
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
                    isPinned: Value<bool>(row.isPinned),
                    isDeleted: Value<bool>(row.isDeleted),
                    deletedAt: Value<DateTime?>(row.deletedAt),
                    capsuleUnlockAt: Value<DateTime?>(row.capsuleUnlockAt),
                    capsuleLockedAt: Value<DateTime?>(row.capsuleLockedAt),
                  );
                })
                .toList(growable: false),
          );
        });
      }

      if (diaryTags.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(
            database.diaryTags,
            diaryTags
                .map((row) {
                  return DiaryTagsCompanion(
                    diaryId: Value<int>(row.diaryId),
                    tagId: Value<int>(row.tagId),
                  );
                })
                .toList(growable: false),
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

    final themeSeedColorRaw = settingsNode['themeSeedColorValue'];
    final themeSeedColorValue = switch (themeSeedColorRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (themeSeedColorValue != null) {
      await settingsService.setThemeSeedColor(Color(themeSeedColorValue));
    }

    final tabSwitchCurveTypeRaw = settingsNode['homeTabSwitchCurveType'];
    if (tabSwitchCurveTypeRaw is String && tabSwitchCurveTypeRaw.isNotEmpty) {
      await settingsService.setHomeTabSwitchCurveType(
        switch (tabSwitchCurveTypeRaw) {
          'easeOutCubic' => HomeTabSwitchCurveType.easeOutCubic,
          'linear' => HomeTabSwitchCurveType.linear,
          'easeOutCirc' => HomeTabSwitchCurveType.easeOutCirc,
          _ => SettingsService.defaultHomeTabSwitchCurveType,
        },
      );
    }

    final editorBodyFontSizeRaw =
        settingsNode['editorBodyFontSizePreset']?.toString();
    if (editorBodyFontSizeRaw != null && editorBodyFontSizeRaw.isNotEmpty) {
      await settingsService.setEditorBodyFontSizePreset(
        switch (editorBodyFontSizeRaw) {
          'small' => EditorBodyFontSizePreset.small,
          'large' => EditorBodyFontSizePreset.large,
          'medium' => EditorBodyFontSizePreset.medium,
          _ => SettingsService.defaultEditorBodyFontSizePreset,
        },
      );
    }

    final editorBodyLineHeightRaw =
        settingsNode['editorBodyLineHeightPreset']?.toString();
    if (editorBodyLineHeightRaw != null && editorBodyLineHeightRaw.isNotEmpty) {
      await settingsService.setEditorBodyLineHeightPreset(
        switch (editorBodyLineHeightRaw) {
          'compact' => EditorBodyLineHeightPreset.compact,
          'relaxed' => EditorBodyLineHeightPreset.relaxed,
          'normal' => EditorBodyLineHeightPreset.normal,
          _ => SettingsService.defaultEditorBodyLineHeightPreset,
        },
      );
    }

    final fontScaleRaw = settingsNode['fontScale'];
    final fontScale = switch (fontScaleRaw) {
      double value => value,
      int value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    if (fontScale != null) {
      await settingsService.setFontScale(fontScale);
    }

    final localeRaw = settingsNode['appLocaleCode']?.toString();
    if (localeRaw != null && localeRaw.trim().isNotEmpty) {
      await settingsService.setAppLocaleCode(localeRaw);
    }

    final appLockRaw = settingsNode['appLockEnabled'];
    if (appLockRaw is bool) {
      await settingsService.setAppLockEnabled(appLockRaw);
    }

    final sortRaw = settingsNode['diarySortModeRaw']?.toString();
    if (sortRaw != null && sortRaw.isNotEmpty) {
      await settingsService.setDiarySortModeRaw(sortRaw);
    }

    final layoutRaw = settingsNode['diaryLayoutModeRaw']?.toString();
    if (layoutRaw != null && layoutRaw.isNotEmpty) {
      await settingsService.setDiaryLayoutModeRaw(layoutRaw);
    }

    final diaryCardTagLimitRaw = settingsNode['diaryCardTagLimit'];
    final diaryCardTagLimit = switch (diaryCardTagLimitRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (diaryCardTagLimit != null) {
      await settingsService.setDiaryCardTagLimit(diaryCardTagLimit);
    }

    final toolbarRaw = settingsNode['diaryToolbarOrderRaw']?.toString();
    if (toolbarRaw != null && toolbarRaw.isNotEmpty) {
      await settingsService.setDiaryToolbarOrderRaw(toolbarRaw);
    }

    if (settingsNode.containsKey('diaryToolbarHiddenItemsRaw')) {
      final toolbarHiddenRaw =
          settingsNode['diaryToolbarHiddenItemsRaw']?.toString() ?? '';
      await settingsService.setDiaryToolbarHiddenItemsRaw(toolbarHiddenRaw);
    }

    if (settingsNode.containsKey('diaryToolbarCurrentTimeFormatRaw')) {
      final toolbarCurrentTimeFormatRaw =
          settingsNode['diaryToolbarCurrentTimeFormatRaw']?.toString() ?? '';
      await settingsService.setDiaryToolbarCurrentTimeFormatRaw(
        toolbarCurrentTimeFormatRaw,
      );
    }

    final tagOrderRaw = settingsNode['tagOrderRaw']?.toString();
    if (tagOrderRaw != null && tagOrderRaw.isNotEmpty) {
      await settingsService.setTagOrderRaw(tagOrderRaw);
    }

    final tagFilterMemoryEnabledRaw = settingsNode['tagFilterMemoryEnabled'];
    final tagFilterMemoryEnabled = switch (tagFilterMemoryEnabledRaw) {
      bool value => value,
      String value => value.toLowerCase() == 'true',
      _ => null,
    };
    if (tagFilterMemoryEnabled != null) {
      await settingsService.setTagFilterMemoryEnabled(tagFilterMemoryEnabled);
    }
    if (settingsNode.containsKey('rememberedTagFilterIdsRaw')) {
      final rememberedTagFilterIdsRaw =
          settingsNode['rememberedTagFilterIdsRaw']?.toString() ?? '';
      if (settingsService.isTagFilterMemoryEnabled &&
          rememberedTagFilterIdsRaw.isNotEmpty) {
        await settingsService.setRememberedTagFilterIdsRaw(
          rememberedTagFilterIdsRaw,
        );
      } else {
        await settingsService.clearRememberedTagFilterIds();
      }
    }

    final draftRaw = settingsNode['createDiaryDraftRaw']?.toString();
    if (draftRaw != null && draftRaw.isNotEmpty) {
      await settingsService.setCreateDiaryDraftRaw(draftRaw);
    } else {
      await settingsService.clearCreateDiaryDraft();
    }

    final releaseMirrorStartIndexRaw = settingsNode['releaseMirrorStartIndex'];
    final releaseMirrorStartIndex = switch (releaseMirrorStartIndexRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (releaseMirrorStartIndex != null) {
      await settingsService.setReleaseMirrorStartIndex(releaseMirrorStartIndex);
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

    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
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

  static Future<Uint8List> _encodeDirectoryToZipBytes(
    Directory root, {
    String? password,
  }) async {
    // ZIP 编码是纯 CPU + 大量字节处理，放到后台 isolate 避免阻塞主线程动画。
    return Isolate.run<Uint8List>(
      () => _encodeDirectoryToZipBytesSync(root.path, password: password),
    );
  }

  static Uint8List _encodeDirectoryToZipBytesSync(
    String rootPath, {
    String? password,
  }) {
    final archive = Archive();
    final normalizedRootPath = p.normalize(rootPath);
    final rootDirectory = Directory(rootPath);
    final entities = rootDirectory.listSync(
      recursive: true,
      followLinks: false,
    );
    for (final entity in entities) {
      if (entity is! File) {
        continue;
      }
      final normalizedEntityPath = p.normalize(entity.path);
      final relativePath = p
          .relative(normalizedEntityPath, from: normalizedRootPath)
          .replaceAll('\\', '/');
      final bytes = entity.readAsBytesSync();
      final entry = ArchiveFile(relativePath, bytes.length, bytes);
      archive.addFile(entry);
    }

    final encoded = ZipEncoder(password: password).encode(archive);
    if (encoded == null) {
      throw const FileSystemException('创建 zip 失败');
    }
    return Uint8List.fromList(encoded);
  }

  static Future<void> _extractZipToDirectory(
    File zipFile,
    Directory targetDirectory, {
    String? password,
  }) async {
    // 解压与写盘也属于重操作，迁移到后台 isolate 保持 UI 可交互。
    await Isolate.run<void>(
      () => _extractZipToDirectorySync(
        zipFile.path,
        targetDirectory.path,
        password: password,
      ),
    );
  }

  static void _extractZipToDirectorySync(
    String zipPath,
    String targetDirectoryPath, {
    String? password,
  }) {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(
        input,
        verify: true,
        password: password,
      );
      try {
        final targetRoot = p.normalize(targetDirectoryPath);
        for (final entry in archive.files) {
          if (!entry.isFile) {
            continue;
          }

          final normalizedEntryName = p
              .normalize(entry.name)
              .replaceAll('\\', '/');
          if (normalizedEntryName.isEmpty ||
              normalizedEntryName.contains('..')) {
            continue;
          }

          final outputPath = p.join(targetRoot, normalizedEntryName);
          final normalizedOutputPath = p.normalize(outputPath);
          if (!p.isWithin(targetRoot, normalizedOutputPath) &&
              normalizedOutputPath != targetRoot) {
            continue;
          }

          final outputFile = File(normalizedOutputPath);
          outputFile.parent.createSync(recursive: true);
          final output = OutputFileStream(outputFile.path);
          try {
            entry.writeContent(output);
          } finally {
            output.closeSync();
          }
        }
      } finally {
        archive.clearSync();
      }
    } finally {
      input.closeSync();
    }
  }

  static bool _isZipPasswordProtectedSync(String zipPath) {
    final input = InputFileStream(zipPath);
    final decoder = ZipDecoder();
    try {
      decoder.decodeBuffer(input, verify: false);
      for (final header in decoder.directory.fileHeaders) {
        final encryptedByFlag = (header.generalPurposeBitFlag & 0x1) != 0;
        final encryptedByMethod =
            header.compressionMethod == ZipFile.zipCompressionAexEncryption;
        if (encryptedByFlag || encryptedByMethod) {
          return true;
        }
      }
      return false;
    } finally {
      input.closeSync();
    }
  }

  static String? _normalizeOptionalPassword(String? rawPassword) {
    final normalized = rawPassword?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
