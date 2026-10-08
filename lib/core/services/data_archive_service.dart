import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'backup_archive_io.dart';
import 'backup_constants.dart';
import 'backup_media_paths.dart';
import 'backup_media_transaction.dart';
import 'backup_payload.dart';
import 'backup_settings.dart';
import 'settings_service.dart';

/// 数据归档编排：导出完整 ZIP，或先校验再覆盖恢复媒体、数据库与设置。
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
      final documents = await getApplicationDocumentsDirectory();
      for (final name in backupMediaDirectories) {
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

  /// 所有数据先解压并校验到隔离目录；换入失败时数据库事务、文件和设置一同回滚。
  static Future<void> importFromZip({
    required AppDatabase database,
    required SettingsService settingsService,
    required String zipPath,
    String? zipPassword,
  }) => _run(() => _import(database, settingsService, zipPath, zipPassword));

  static Future<void> _import(
    AppDatabase database,
    SettingsService settingsService,
    String zipPath,
    String? password,
  ) async {
    if (!await File(zipPath).exists()) {
      throw const FileSystemException('备份文件不存在');
    }
    final documents = await getApplicationDocumentsDirectory();
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
      final payloadFile = File(p.join(working.path, backupPayloadFileName));
      if (!await payloadFile.exists()) {
        throw const FormatException('备份文件缺少 backup_data.json');
      }
      final payload = BackupPayload.decode(await payloadFile.readAsString());
      final restored = await payload.rebindMedia(
        BackupMediaPaths(
          documentsDirectory: documents,
          stagingDirectory: working,
        ),
      );
      final media = BackupMediaTransaction(
        documents: documents,
        staging: working,
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
    } finally {
      if (cleanup) await _cleanWorkingDirectory(working);
    }
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
