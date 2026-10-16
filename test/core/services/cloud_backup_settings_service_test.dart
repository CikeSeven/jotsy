import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_settings_service.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const legacy = <String, Object>{
    'app.webdav.server_url': 'https://nas.example.com:5006/webdav/',
    'app.webdav.username': 'alice',
    'app.webdav.password': 'secret',
    'app.webdav.remote_directory': '/jotsy/',
  };

  test('migrates the legacy single WebDAV config into one target', () async {
    SharedPreferences.setMockInitialValues(legacy);
    final service = await CloudBackupSettingsService.create();
    addTearDown(service.dispose);

    final target = service.targets.single;
    expect(target.kind, CloudBackupKind.webDav);
    expect(target.config, {
      'serverUrl': 'https://nas.example.com:5006/webdav/',
      'username': 'alice',
      'password': 'secret',
      'remoteDirectory': '/jotsy/',
    });
    final prefs = await SharedPreferences.getInstance();
    for (final key in legacy.keys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }

    // 再次启动不会重复迁移。
    final again = await CloudBackupSettingsService.create();
    addTearDown(again.dispose);
    expect(again.targets.single.id, target.id);
  });

  test(
    'does not duplicate a target when old keys survived a migration',
    () async {
      final existing = CloudBackupTarget.create(
        kind: CloudBackupKind.webDav,
        config: {
          'serverUrl': 'https://nas.example.com:5006/webdav/',
          'username': 'alice',
        },
      );
      SharedPreferences.setMockInitialValues({
        ...legacy,
        'app.cloud_backup.targets': CloudBackupTarget.encodeList([existing]),
      });
      final service = await CloudBackupSettingsService.create();
      addTearDown(service.dispose);

      expect(service.targets.single.id, existing.id);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('app.webdav.password'), isFalse);
    },
  );

  test('skips malformed entries and tolerates a corrupt list', () async {
    expect(CloudBackupTarget.decodeList('{not json'), isEmpty);
    expect(CloudBackupTarget.decodeList('{"a":1}'), isEmpty);
    final decoded = CloudBackupTarget.decodeList(
      '[{"id":"x","kind":"martian"},"junk",'
      '{"id":"s3_1","kind":"s3","preset":"cloudflareR2",'
      '"createdAt":"2026-10-16T00:00:00.000Z","config":{"bucket":"b"}}]',
    );
    expect(decoded, hasLength(1));
    expect(decoded.single.kind, CloudBackupKind.s3);
    expect(decoded.single.presetId, 'cloudflareR2');
    expect(decoded.single.config['bucket'], 'b');
    expect(decoded.single.createdAt, DateTime.utc(2026, 10, 16));
  });

  test('saves, updates and removes targets in order', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await CloudBackupSettingsService.create();
    addTearDown(service.dispose);
    final first = CloudBackupTarget.create(
      kind: CloudBackupKind.s3,
      config: {'bucket': 'one'},
    );
    final second = CloudBackupTarget.create(
      kind: CloudBackupKind.dropbox,
      config: {'account': 'me'},
    );
    expect(first.id, isNot(second.id));

    await service.saveTarget(first);
    await service.saveTarget(second);
    await service.saveTarget(first.copyWith(config: {'bucket': 'renamed'}));
    expect(service.targets.map((t) => t.id), [first.id, second.id]);
    expect(service.targetById(first.id)!.config['bucket'], 'renamed');

    // 并发写入串行执行，后者基于前者的结果。
    await Future.wait([
      service.updateConfig(second.id, (c) => {...c, 'token': 't1'}),
      service.updateConfig(second.id, (c) => {...c, 'account': 'other'}),
    ]);
    expect(service.targetById(second.id)!.config, {
      'account': 'other',
      'token': 't1',
    });

    await service.removeTarget(first.id);
    // 位置删除后才返回的令牌刷新不会让它复活。
    await service.updateConfig(first.id, (c) => {...c, 'token': 'late'});
    expect(service.targets.map((t) => t.id), [second.id]);

    final reloaded = await CloudBackupSettingsService.create();
    addTearDown(reloaded.dispose);
    expect(reloaded.targets.single.config['token'], 't1');
  });
}
