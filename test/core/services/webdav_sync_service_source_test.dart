import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WebDAV credentials are not exported by DataArchiveService', () async {
    final source =
        await File(
          'lib/core/services/data_archive_service.dart',
        ).readAsString();

    expect(source, isNot(contains('webdav')));
    expect(source, isNot(contains('WebDav')));
    expect(source, isNot(contains('serverUrl')));
    expect(source, isNot(contains('remoteDirectory')));
  });

  test(
    'WebDAV client and sync service keep backup ZIP transfer stream-safe',
    () async {
      final clientSource =
          await File('lib/core/services/webdav_client.dart').readAsString();
      final syncSource =
          await File(
            'lib/core/services/webdav_sync_service.dart',
          ).readAsString();

      expect(clientSource, contains('file.openRead()'));
      expect(clientSource, contains('targetFile.openWrite()'));
      expect(clientSource, isNot(contains('file.readAsBytes()')));
      expect(syncSource, isNot(contains('zipFile.readAsBytes()')));
    },
  );

  test(
    'WebDAV sync uses Jotsy backup filename policy and manifest file',
    () async {
      final modelsSource =
          await File('lib/core/services/webdav_models.dart').readAsString();
      final syncSource =
          await File(
            'lib/core/services/webdav_sync_service.dart',
          ).readAsString();

      expect(modelsSource, contains('jotsy_backup_'));
      expect(modelsSource, contains('manifest.json'));
      expect(syncSource, contains('buildWebDavBackupFileName'));
      expect(syncSource, contains('webDavManifestFileName'));
    },
  );

  test('app service registers WebDAV providers', () async {
    final source =
        await File('lib/core/services/app_service.dart').readAsString();

    expect(source, contains('webDavSettingsServiceProvider'));
    expect(source, contains('webDavSyncServiceProvider'));
  });
}
