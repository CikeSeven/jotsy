import 'dart:io';

import 'cloud_backup_models.dart';
import 'webdav_client.dart';
import 'webdav_models.dart';

/// WebDAV 备份位置（坚果云、Nextcloud、群晖、Alist 等都走这里）。
///
/// 职责边界：
/// - 协议细节在 [WebDavClient]；这里只负责备份目录、manifest 与错误归类；
/// - 目录里的 `manifest.json` 记录每份备份的创建时间，只是辅助信息：列表以
///   PROPFIND 实际看到的 ZIP 为准，manifest 损坏或缺失时仍能展示与恢复；
/// - manifest 写入失败不影响已成功的上传或删除（文件本身才是备份）。
class WebDavBackupRemote implements CloudBackupRemote {
  WebDavBackupRemote({
    required this._config,
    WebDavClient Function(WebDavConfig config)? clientFactory,
  }) : _clientFactory =
           clientFactory ?? ((config) => WebDavClient(config: config));

  final WebDavConfig _config;
  final WebDavClient Function(WebDavConfig config) _clientFactory;
  WebDavClient? _client;

  WebDavClient get _webDav => _client ??= _clientFactory(_config.validate());

  String get _directory => _config.normalizedRemoteDirectory;

  @override
  Future<void> prepare() => _guard(() async {
    await _webDav.ensureDirectory(_directory);
    await _webDav.listFiles(_directory);
  });

  @override
  Future<List<CloudBackupEntry>> list() => _guard(() async {
    await _webDav.ensureDirectory(_directory);
    final files = await _webDav.listFiles(_directory);
    final manifest = await _readManifest();
    final manifestByName = <String, WebDavBackupEntry>{
      for (final entry in manifest.backups) entry.fileName: entry,
    };
    final backups = <CloudBackupEntry>[];
    for (final file in files) {
      if (!isCloudBackupFileName(file.fileName)) continue;
      var entry = WebDavBackupEntry.fromRemoteFile(file);
      final recorded = manifestByName[entry.fileName];
      if (recorded != null) entry = entry.mergeManifest(recorded);
      backups.add(_toCloudEntry(entry));
    }
    return sortCloudBackups(backups);
  });

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) => _guard(() async {
    await _webDav.ensureDirectory(_directory);
    final remotePath = joinWebDavRemotePath(_directory, fileName);
    await _webDav.putFile(
      remotePath: remotePath,
      file: file,
      onProgress: onProgress,
    );
    final entry = WebDavBackupEntry(
      fileName: fileName,
      remotePath: remotePath,
      size: await file.length(),
      createdAt: cloudBackupCreatedAtFromFileName(fileName) ?? DateTime.now(),
    );
    await _updateManifest((manifest) => manifest.upsertBackup(entry));
    return _toCloudEntry(entry);
  });

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) => _guard(() async {
    await _webDav.downloadFile(
      remotePath: entry.remoteId,
      targetFile: target,
      onProgress: onProgress,
    );
  });

  @override
  Future<void> delete(CloudBackupEntry entry) => _guard(() async {
    await _webDav.deleteFile(entry.remoteId);
    await _updateManifest((manifest) => manifest.removeBackup(entry.fileName));
  });

  @override
  void close() {}

  String get _manifestPath =>
      joinWebDavRemotePath(_directory, webDavManifestFileName());

  Future<WebDavManifest> _readManifest() async {
    final raw = await _webDav.getTextOrNull(_manifestPath);
    if (raw == null || raw.trim().isEmpty) return WebDavManifest.empty();
    try {
      return WebDavManifest.decode(raw);
    } catch (_) {
      // manifest 不是权威数据源；被用户手动改坏时仍按 PROPFIND 展示 ZIP。
      return WebDavManifest.empty();
    }
  }

  Future<void> _updateManifest(
    WebDavManifest Function(WebDavManifest manifest) change,
  ) async {
    try {
      final manifest = await _readManifest();
      await _webDav.putText(
        remotePath: _manifestPath,
        text: change(manifest).encode(),
      );
    } on WebDavException {
      // 只影响列表里的创建时间（会回落到文件名推断），不能让已完成的上传
      // 或删除报告失败。
    }
  }

  static CloudBackupEntry _toCloudEntry(WebDavBackupEntry entry) {
    return CloudBackupEntry(
      fileName: entry.fileName,
      remoteId: entry.remotePath,
      size: entry.size,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// WebDAV 的配置/协议错误统一转为 [CloudBackupException]。
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on WebDavConfigException catch (error) {
      throw CloudBackupException(CloudBackupFailure.config, error.message);
    } on WebDavException catch (error) {
      final status = error.statusCode;
      if (status == null) {
        throw CloudBackupException(CloudBackupFailure.network, error.message);
      }
      throw CloudBackupException.forStatus(status, error.message);
    } on FormatException catch (error) {
      throw CloudBackupException(CloudBackupFailure.protocol, error.message);
    }
  }
}
