import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/webdav_models.dart';

void main() {
  group('WebDavConfig', () {
    test('normalizes base url and remote directory for NAS style paths', () {
      final config = WebDavConfig(
        serverUrl: ' https://nas.example.com:5006/webdav/// ',
        username: ' alice ',
        password: ' secret ',
        remoteDirectory: ' //Jotsy Backups//手机// ',
      );

      expect(config.baseUri, Uri.parse('https://nas.example.com:5006/webdav/'));
      expect(config.normalizedRemoteDirectory, '/Jotsy Backups/手机/');
      expect(
        config.remoteDirectoryUri.toString(),
        'https://nas.example.com:5006/webdav/Jotsy%20Backups/%E6%89%8B%E6%9C%BA/',
      );
      expect(config.isConfigured, isTrue);
    });

    test('rejects unsupported server urls and missing host', () {
      expect(
        () =>
            WebDavConfig(
              serverUrl: 'ftp://nas.example.com/dav',
              username: 'u',
              password: 'p',
              remoteDirectory: '/jotsy',
            ).validate(),
        throwsA(isA<WebDavConfigException>()),
      );

      expect(
        () =>
            WebDavConfig(
              serverUrl: 'https:///dav',
              username: 'u',
              password: 'p',
              remoteDirectory: '/jotsy',
            ).validate(),
        throwsA(isA<WebDavConfigException>()),
      );
    });
  });

  group('WebDavManifest', () {
    test('round-trips backup entries and ignores malformed items', () {
      final manifest = WebDavManifest.fromJson(<String, Object?>{
        'formatVersion': 1,
        'updatedAt': '2026-06-15T10:00:00.000Z',
        'backups': <Object?>[
          <String, Object?>{
            'fileName': 'jotsy_backup_20260615_100000.zip',
            'path': '/jotsy/jotsy_backup_20260615_100000.zip',
            'size': 12,
            'createdAt': '2026-06-15T10:00:00.000Z',
          },
          <String, Object?>{'fileName': ''},
          'invalid',
        ],
      });

      expect(manifest.backups, hasLength(1));
      expect(
        manifest.backups.single.fileName,
        'jotsy_backup_20260615_100000.zip',
      );
      expect(manifest.toJson()['formatVersion'], 1);
      expect((manifest.toJson()['backups'] as List<Object?>), hasLength(1));
    });

    test('sorts newest backups first by created time and name fallback', () {
      final older = WebDavBackupEntry(
        fileName: 'jotsy_backup_20260614_090000.zip',
        remotePath: '/jotsy/jotsy_backup_20260614_090000.zip',
        size: 10,
        createdAt: DateTime.utc(2026, 6, 14, 9),
      );
      final newer = WebDavBackupEntry(
        fileName: 'jotsy_backup_20260615_090000.zip',
        remotePath: '/jotsy/jotsy_backup_20260615_090000.zip',
        size: 20,
        createdAt: DateTime.utc(2026, 6, 15, 9),
      );
      final unknown = WebDavBackupEntry(
        fileName: 'jotsy_backup_unknown.zip',
        remotePath: '/jotsy/jotsy_backup_unknown.zip',
        size: null,
        createdAt: null,
      );

      final sorted = WebDavManifest.sortedBackups(<WebDavBackupEntry>[
        older,
        unknown,
        newer,
      ]);

      expect(sorted.map((entry) => entry.fileName), <String>[
        'jotsy_backup_20260615_090000.zip',
        'jotsy_backup_20260614_090000.zip',
        'jotsy_backup_unknown.zip',
      ]);
    });
  });
}
