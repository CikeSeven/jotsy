import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 网盘备份的源码约束：凭据不进备份、传输不整包读内存、命名与登记一致。
void main() {
  Future<List<File>> cloudBackupSources() async => [
    await for (final entity in Directory('lib/core/services').list())
      if (entity is File &&
          (entity.path.contains('cloud_backup_') ||
              entity.path.contains('webdav_')))
        entity,
  ];

  test('backup credentials are not exported by DataArchiveService', () async {
    final source = await File(
      'lib/core/services/data_archive_service.dart',
    ).readAsString();

    for (final secret in [
      'webdav',
      'WebDav',
      'cloud_backup',
      'CloudBackup',
      'serverUrl',
      'remoteDirectory',
      'secretAccessKey',
      'accessToken',
      'refreshToken',
    ]) {
      expect(source, isNot(contains(secret)), reason: secret);
    }
  });

  test('backup transfers stream files instead of reading them whole', () async {
    final sources = await cloudBackupSources();
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = await file.readAsString();
      expect(source, isNot(contains('readAsBytes')), reason: file.path);
    }
    final http = await File(
      'lib/core/services/cloud_backup_http.dart',
    ).readAsString();
    final webDav = await File(
      'lib/core/services/webdav_client.dart',
    ).readAsString();
    expect(http, contains('openWrite()'));
    expect(http, contains('openRead(start, end)'));
    expect(webDav, contains('.openRead()'));
    expect(webDav, contains('targetFile.openWrite()'));
  });

  test(
    'backups share one file name policy and WebDAV keeps its manifest',
    () async {
      final models = await File(
        'lib/core/services/cloud_backup_models.dart',
      ).readAsString();
      final service = await File(
        'lib/core/services/cloud_backup_service.dart',
      ).readAsString();
      final webDav = await File(
        'lib/core/services/cloud_backup_webdav.dart',
      ).readAsString();
      final webDavModels = await File(
        'lib/core/services/webdav_models.dart',
      ).readAsString();

      expect(models, contains('jotsy_backup_'));
      expect(service, contains('buildCloudBackupFileName'));
      expect(webDav, contains('webDavManifestFileName'));
      expect(webDavModels, contains('manifest.json'));
    },
  );

  test(
    'every authorized drive is registered and keyed from dart-define',
    () async {
      final registry = await File(
        'lib/core/services/cloud_backup_drives.dart',
      ).readAsString();
      final keys = await File(
        'lib/core/services/cloud_backup_app_keys.dart',
      ).readAsString();
      for (final provider in [
        'GoogleDriveProvider',
        'OneDriveProvider',
        'DropboxProvider',
        'BaiduPanProvider',
        'AliyunDriveProvider',
      ]) {
        expect(registry, contains('$provider()'), reason: provider);
      }
      // 应用密钥只能来自构建参数，不能写进仓库。
      expect(keys, contains('String.fromEnvironment'));
      expect(
        RegExp(r"defaultValue: '[A-Za-z0-9]{20,}'").hasMatch(keys),
        isFalse,
      );
    },
  );

  test('app service registers cloud backup providers', () async {
    final source = await File(
      'lib/core/services/app_service.dart',
    ).readAsString();

    expect(source, contains('cloudBackupSettingsServiceProvider'));
    expect(source, contains('cloudBackupServiceProvider'));
    expect(source, isNot(contains('webDavSyncServiceProvider')));
  });
}
