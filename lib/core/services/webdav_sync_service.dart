import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'data_archive_service.dart';
import 'settings_service.dart';
import 'webdav_client.dart';
import 'webdav_models.dart';
import 'webdav_settings_service.dart';

/// WebDAV 备份式同步编排服务。
///
/// 职责边界：
/// - 复用 DataArchiveService 生成/恢复完整 ZIP，不直接操作数据库表细节；
/// - 串联 WebDAV 建目录、上传/下载、manifest 合并与远程删除；
/// - 不持有 BuildContext，不展示 SnackBar，不决定 UI 文案。
class WebDavSyncService {
  WebDavSyncService({
    required AppDatabase database,
    required SettingsService settingsService,
    required WebDavSettingsService webDavSettingsService,
    WebDavClient Function(WebDavConfig config)? clientFactory,
  }) : _database = database,
       _settingsService = settingsService,
       _webDavSettingsService = webDavSettingsService,
       _clientFactory =
           clientFactory ?? ((config) => WebDavClient(config: config));

  final AppDatabase _database;
  final SettingsService _settingsService;
  final WebDavSettingsService _webDavSettingsService;
  final WebDavClient Function(WebDavConfig config) _clientFactory;

  Future<void> testConnection({WebDavConfig? config}) async {
    final targetConfig = (config ?? _webDavSettingsService.config).validate();
    final client = _clientFactory(targetConfig);
    await client.ensureDirectory(targetConfig.normalizedRemoteDirectory);
    await client.listFiles(targetConfig.normalizedRemoteDirectory);
  }

  Future<WebDavBackupEntry> uploadCurrentBackup({
    String? zipPassword,
    DateTime? now,
  }) async {
    final config = _webDavSettingsService.config.validate();
    final client = _clientFactory(config);
    await client.ensureDirectory(config.normalizedRemoteDirectory);

    final zipFile = await DataArchiveService.exportToZip(
      database: _database,
      settingsService: _settingsService,
      zipPassword: zipPassword,
    );
    final fileName = buildWebDavBackupFileName(now ?? DateTime.now());
    final remotePath = joinWebDavRemotePath(
      config.normalizedRemoteDirectory,
      fileName,
    );

    try {
      await client.putFile(remotePath: remotePath, file: zipFile);
      final entry = WebDavBackupEntry(
        fileName: fileName,
        remotePath: remotePath,
        size: await zipFile.length(),
        createdAt: now ?? DateTime.now(),
      );
      final manifest = await _readManifest(client, config);
      await _writeManifest(client, config, manifest.upsertBackup(entry));
      return entry;
    } finally {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }

  Future<List<WebDavBackupEntry>> listRemoteBackups() async {
    final config = _webDavSettingsService.config.validate();
    final client = _clientFactory(config);
    await client.ensureDirectory(config.normalizedRemoteDirectory);
    final files = await client.listFiles(config.normalizedRemoteDirectory);
    final manifest = await _readManifest(client, config);
    final manifestByName = <String, WebDavBackupEntry>{
      for (final entry in manifest.backups) entry.fileName: entry,
    };
    final backups = <WebDavBackupEntry>[];
    for (final file in files) {
      if (!file.fileName.toLowerCase().endsWith('.zip')) {
        continue;
      }
      final remoteEntry = WebDavBackupEntry.fromRemoteFile(file);
      backups.add(
        manifestByName.containsKey(remoteEntry.fileName)
            ? remoteEntry.mergeManifest(manifestByName[remoteEntry.fileName]!)
            : remoteEntry,
      );
    }
    return WebDavManifest.sortedBackups(backups);
  }

  Future<File> downloadBackup(WebDavBackupEntry entry) async {
    final config = _webDavSettingsService.config.validate();
    final client = _clientFactory(config);
    final temp = await getTemporaryDirectory();
    final targetFile = File(
      p.join(
        temp.path,
        'jotsy_webdav_${DateTime.now().microsecondsSinceEpoch}_${entry.fileName}',
      ),
    );
    await client.downloadFile(
      remotePath: entry.remotePath,
      targetFile: targetFile,
    );
    return targetFile;
  }

  Future<void> restoreBackup({
    required WebDavBackupEntry entry,
    String? zipPassword,
  }) async {
    final zipFile = await downloadBackup(entry);
    try {
      await DataArchiveService.importFromZip(
        database: _database,
        settingsService: _settingsService,
        zipPath: zipFile.path,
        zipPassword: zipPassword,
      );
    } finally {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }

  Future<bool> isRemoteBackupPasswordProtected(WebDavBackupEntry entry) async {
    final zipFile = await downloadBackup(entry);
    try {
      return DataArchiveService.isZipPasswordProtected(zipPath: zipFile.path);
    } finally {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }

  Future<void> deleteRemoteBackup(WebDavBackupEntry entry) async {
    final config = _webDavSettingsService.config.validate();
    final client = _clientFactory(config);
    await client.deleteFile(entry.remotePath);
    final manifest = await _readManifest(client, config);
    await _writeManifest(client, config, manifest.removeBackup(entry.fileName));
  }

  Future<WebDavManifest> _readManifest(
    WebDavClient client,
    WebDavConfig config,
  ) async {
    final manifestPath = joinWebDavRemotePath(
      config.normalizedRemoteDirectory,
      webDavManifestFileName(),
    );
    final raw = await client.getTextOrNull(manifestPath);
    if (raw == null || raw.trim().isEmpty) {
      return WebDavManifest.empty();
    }
    try {
      return WebDavManifest.decode(raw);
    } catch (_) {
      // manifest 不是权威数据源；NAS 上被用户手动改坏时，仍允许通过 PROPFIND 展示 ZIP。
      return WebDavManifest.empty();
    }
  }

  Future<void> _writeManifest(
    WebDavClient client,
    WebDavConfig config,
    WebDavManifest manifest,
  ) async {
    final manifestPath = joinWebDavRemotePath(
      config.normalizedRemoteDirectory,
      webDavManifestFileName(),
    );
    await client.putText(remotePath: manifestPath, text: manifest.encode());
  }
}
