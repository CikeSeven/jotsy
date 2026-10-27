import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show countAll;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'backup_archive_io.dart';
import 'backup_constants.dart';
import 'backup_import_models.dart';
import 'backup_media_paths.dart';
import 'backup_media_transaction.dart';
import 'backup_merge.dart';
import 'backup_payload.dart';
import 'backup_settings.dart';
import 'diary_media_references.dart';
import 'journal_import_models.dart';
import 'settings_service.dart';
import 'app_data_directory.dart';

/// 数据归档编排：导出完整 ZIP 或单篇日记包；导入前只读预检，再按所选方式
/// 合并（[BackupMerge]）或先校验再覆盖恢复媒体、数据库与设置。
/// 本地与远程备份共用同一串行队列；IO、路径映射和载荷校验由独立服务负责。
class DataArchiveService {
  DataArchiveService._();

  static Future<void> _pending = Future<void>.value();

  static Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    // 一次失败不能阻塞后续恢复；调用方仍从 result 收到原异常。
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  /// 其他导入来源（如其他日记应用的导出）写入本机数据时，与备份导入导出
  /// 共用同一串行队列，避免与恢复事务交错。
  static Future<T> runSerialized<T>(Future<T> Function() action) =>
      _run(action);

  static Future<File> exportToZip({
    required AppDatabase database,
    required SettingsService settingsService,
    String? zipPassword,
  }) => _run(() => _export(database, settingsService, zipPassword));

  static Future<File> _export(
    AppDatabase database,
    SettingsService settingsService,
    String? password,
  ) async {
    final temporary = await getTemporaryDirectory();
    final working = await temporary.createTemp('backup_export_');
    try {
      final payload = await BackupPayload.capture(
        database: database,
        settingsService: settingsService,
      );
      await File(p.join(working.path, backupPayloadFileName)).writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      final documents = await appDataRootDirectory();
      // 完整备份带上全部托管目录：日记媒体与设置引用的背景图。
      for (final name in [
        ...backupMediaDirectories,
        ...backupSettingsMediaDirectories,
      ]) {
        final source = Directory(p.join(documents.path, name));
        if (await source.exists()) {
          await BackupArchiveIO.copyDirectory(
            source,
            Directory(p.join(working.path, name)),
          );
        }
      }
      final output = p.join(
        temporary.path,
        'node_note_backup_${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      await BackupArchiveIO.encodeDirectory(
        working,
        outputZipPath: output,
        password: _password(password),
      );
      return File(output);
    } finally {
      await _cleanWorkingDirectory(working);
    }
  }

  /// 导出日记包：指定日记、它们的标签与引用到的媒体，不含应用设置。
  ///
  /// 只能合并导入（见 [BackupArchiveKind.diaryPackage]），可在另一台设备或
  /// 本机重新导入。返回临时目录中的 ZIP，调用方负责保存后删除。
  static Future<File> exportDiariesToZip({
    required AppDatabase database,
    required Iterable<String> diaryIds,
    String? zipPassword,
  }) => _run(() => _exportDiaries(database, diaryIds, zipPassword));

  static Future<File> _exportDiaries(
    AppDatabase database,
    Iterable<String> diaryIds,
    String? password,
  ) async {
    final temporary = await getTemporaryDirectory();
    final working = await temporary.createTemp('diary_export_');
    try {
      final captured = await BackupPayload.captureDiaries(
        database: database,
        diaryIds: diaryIds,
      );
      await File(
        p.join(working.path, diaryPackagePayloadFileName),
      ).writeAsString(
        const JsonEncoder.withIndent('  ').convert(captured.json),
        flush: true,
      );
      // 与媒体回收共用同一套引用识别：正文、封面与 metadata 里提到的托管文件
      // 都会带上，包里日记本的封面（在载荷 JSON 里）同样带上，导入端再按与
      // 完整备份相同的规则重绑。
      final references = DiaryMediaReferences([
        for (final diary in captured.diaries) ...[
          diary.content,
          diary.cover,
          diary.metadata,
        ],
        for (final notebook in captured.notebooks) notebook.payload,
      ]);
      await BackupArchiveIO.copyMediaFiles(
        await appDataRootDirectory(),
        working,
        references.keys,
      );
      final output = p.join(
        temporary.path,
        'jotsy_diary_${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      await BackupArchiveIO.encodeDirectory(
        working,
        outputZipPath: output,
        password: _password(password),
      );
      return File(output);
    } finally {
      await _cleanWorkingDirectory(working);
    }
  }

  /// 导入前的只读预检：只解出载荷，识别文件类型并统计与本机重复的日记。
  ///
  /// 密码错误、文件损坏或不是备份时在这里就报错，用户不必先选导入方式。
  /// 不修改数据库、设置或媒体；正式导入时会重新校验并按当时的数据计算。
  static Future<BackupArchivePreview> inspectZip({
    required AppDatabase database,
    required String zipPath,
    String? zipPassword,
  }) => _run(() => _inspect(database, zipPath, zipPassword));

  static Future<BackupArchivePreview> _inspect(
    AppDatabase database,
    String zipPath,
    String? password,
  ) async {
    if (!await File(zipPath).exists()) {
      throw const FileSystemException('备份文件不存在');
    }
    final working = await (await getTemporaryDirectory()).createTemp(
      'backup_inspect_',
    );
    try {
      await BackupArchiveIO.extract(
        zipPath,
        working,
        password: _password(password),
        only: const {backupPayloadFileName, diaryPackagePayloadFileName},
      );
      final (kind, payload) = await _readPayload(working);
      return await previewPayload(
        database: database,
        kind: kind,
        payload: payload,
      );
    } finally {
      await _cleanWorkingDirectory(working);
    }
  }

  /// 统计载荷与本机数据的关系（重复篇数、本机总数），生成导入预检结果。
  /// 只读查询，不修改本机数据。
  static Future<BackupArchivePreview> previewPayload({
    required AppDatabase database,
    required BackupArchiveKind kind,
    required BackupPayload payload,
    JournalImportSource? journalSource,
    int missingMediaCount = 0,
    Map<JournalSkipReason, int> skippedNotes = const {},
    int summaryOnlyCount = 0,
    int partialContentCount = 0,
  }) async {
    final diaries = database.diaries;
    final localIds = {
      for (final row in await (database.selectOnly(
        diaries,
      )..addColumns([diaries.diaryId])).get())
        row.read(diaries.diaryId)!,
    };
    final localTags = countAll();
    final anniversaries = database.anniversaries;
    final localAnniversaryIds = {
      for (final row in await (database.selectOnly(
        anniversaries,
      )..addColumns([anniversaries.anniversaryId])).get())
        row.read(anniversaries.anniversaryId)!,
    };
    final dayMoods = database.dayMoods;
    final localMoodDays = {
      for (final row in await (database.selectOnly(
        dayMoods,
      )..addColumns([dayMoods.day])).get())
        row.read(dayMoods.day)!,
    };
    final notebooks = database.notebooks;
    final localNotebookIds = {
      for (final row in await (database.selectOnly(
        notebooks,
      )..addColumns([notebooks.notebookId])).get())
        row.read(notebooks.notebookId)!,
    };
    return BackupArchivePreview(
      kind: kind,
      diaryCount: payload.diaries.length,
      tagCount: payload.tags.length,
      existingDiaryCount: payload.diaries
          .where((diary) => localIds.contains(diary.diaryId))
          .length,
      localDiaryCount: localIds.length,
      localTagCount: (await (database.selectOnly(
        database.tags,
      )..addColumns([localTags])).getSingle()).read(localTags)!,
      soleDiaryTitle: payload.diaries.length == 1
          ? payload.diaries.single.title
          : null,
      journalSource: journalSource,
      missingMediaCount: missingMediaCount,
      skippedNotes: skippedNotes,
      summaryOnlyCount: summaryOnlyCount,
      partialContentCount: partialContentCount,
      anniversaryCount: payload.anniversaries.length,
      existingAnniversaryCount: payload.anniversaries
          .where((row) => localAnniversaryIds.contains(row.anniversaryId))
          .length,
      localAnniversaryCount: localAnniversaryIds.length,
      localTemplateCount: await database.countDiaryTemplates(),
      localNotebookCount: localNotebookIds.length,
      existingNotebookCount: payload.notebooks
          .where((row) => localNotebookIds.contains(row.notebookId))
          .length,
      existingDayMoodCount: payload.dayMoods
          .where((row) => localMoodDays.contains(row.day))
          .length,
      localDayMoodCount: localMoodDays.length,
    );
  }

  /// 按 [mode] 导入完整备份或日记包。
  ///
  /// 所有数据先解压并校验到隔离目录：
  /// - [BackupImportMode.replaceAll]（默认，兼容原有恢复入口）：换入失败时
  ///   数据库事务、文件和设置一同回滚；日记包没有设置与完整数据，拒绝此方式；
  /// - 合并方式：见 [BackupMerge]，不删除本机任何数据。
  static Future<BackupImportResult> importFromZip({
    required AppDatabase database,
    required SettingsService settingsService,
    required String zipPath,
    String? zipPassword,
    BackupImportMode mode = BackupImportMode.replaceAll,
  }) => _run(
    () => _import(database, settingsService, zipPath, zipPassword, mode),
  );

  static Future<BackupImportResult> _import(
    AppDatabase database,
    SettingsService settingsService,
    String zipPath,
    String? password,
    BackupImportMode mode,
  ) async {
    if (!await File(zipPath).exists()) {
      throw const FileSystemException('备份文件不存在');
    }
    final documents = await appDataRootDirectory();
    await documents.create(recursive: true);
    // 位于相同文件系统，换入/回滚大媒体仅需 rename，避免额外复制或空间不足。
    final working = await documents.createTemp('.backup_import_');
    var cleanup = true;
    try {
      await BackupArchiveIO.extract(
        zipPath,
        working,
        password: _password(password),
      );
      final (kind, payload) = await _readPayload(working);
      if (mode != BackupImportMode.replaceAll) {
        return await BackupMerge(
          documents: documents,
          staging: working,
        ).apply(database: database, payload: payload, mode: mode);
      }
      if (kind != BackupArchiveKind.fullBackup) {
        throw const FormatException('日记文件只能合并导入，不能覆盖全部数据');
      }
      final restored = await payload.rebindMedia(
        BackupMediaPaths(
          documentsDirectory: documents,
          stagingDirectory: working,
        ),
      );
      final media = BackupMediaTransaction(
        documents: documents,
        staging: working,
        directories: _replaceDirectories(restored.settings),
      );
      final settingsSnapshot = settingsService.captureBackupSnapshot();
      try {
        await database.transaction(() async {
          await media.install();
          await restored.writeDatabase(database);
          await BackupSettings.restore(settingsService, restored.settings);
        });
      } catch (error, stack) {
        final rollbackErrors = <Object>[];
        try {
          await media.rollback();
        } catch (failure) {
          rollbackErrors.add(failure);
        }
        try {
          await settingsSnapshot.restore();
        } catch (failure) {
          rollbackErrors.add(failure);
        }
        if (rollbackErrors.isNotEmpty) {
          // 恢复原目录失败时必须保留暂存区的原文件，不能在 finally 中将其删除。
          cleanup = false;
          throw FileSystemException(
            '备份恢复失败，暂存数据已保留：$error；回滚失败：$rollbackErrors',
            working.path,
          );
        }
        Error.throwWithStackTrace(error, stack);
      }
      return BackupImportResult(
        mode: mode,
        addedDiaries: restored.diaries.length,
        replacedDiaries: 0,
        skippedDiaries: 0,
        addedAnniversaries: restored.anniversaries.length,
        addedTemplates: restored.diaryTemplates.length,
        addedNotebooks: restored.notebooks.length,
        addedDayMoods: restored.dayMoods.length,
      );
    } finally {
      if (cleanup) await _cleanWorkingDirectory(working);
    }
  }

  /// 覆盖恢复整目录换入的托管目录：日记媒体一律换入；设置引用的目录
  /// （背景图）只在备份设置里有对应键、即这项设置也会被恢复时才换入。
  /// 旧版备份没有该键时本机设置原样保留，本机的图片也必须原样保留，否则
  /// 设置会指向已被换走的文件。
  static List<String> _replaceDirectories(Map<String, dynamic>? settings) => [
    ...backupMediaDirectories,
    for (final name in backupSettingsMediaDirectories)
      if (settings != null && settings.containsKey(backupSettingsKeyOf(name)))
        name,
  ];

  /// 按载荷文件名区分完整备份与日记包；两者都有或都没有都不是有效文件。
  static Future<(BackupArchiveKind, BackupPayload)> _readPayload(
    Directory working,
  ) async {
    final full = File(p.join(working.path, backupPayloadFileName));
    final package = File(p.join(working.path, diaryPackagePayloadFileName));
    final isFull = await full.exists();
    final isPackage = await package.exists();
    if (isFull && isPackage) {
      throw const FormatException('备份文件同时包含完整备份与日记包载荷');
    }
    if (!isFull && !isPackage) {
      throw const FormatException('备份文件缺少 backup_data.json');
    }
    final kind = isFull
        ? BackupArchiveKind.fullBackup
        : BackupArchiveKind.diaryPackage;
    return (
      kind,
      BackupPayload.decode(await (isFull ? full : package).readAsString()),
    );
  }

  static Future<bool> isZipPasswordProtected({required String zipPath}) async {
    if (!await File(zipPath).exists()) {
      throw const FileSystemException('备份文件不存在');
    }
    return BackupArchiveIO.isPasswordProtected(zipPath);
  }

  static Future<void> _cleanWorkingDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // 提交或回滚已经结束，临时目录清理失败不能改变其结果或掩盖原异常。
    }
  }

  static String? _password(String? raw) {
    final value = raw?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
