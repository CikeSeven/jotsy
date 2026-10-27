import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_background_storage_service.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  /// 在当前托管目录导入一张背景图并写进设置，返回文件名。
  Future<String> seedBackground(List<int> bytes) async {
    final source = File(p.join(fixture.root.path, 'source.png'));
    await source.writeAsBytes(bytes);
    final name = await AppBackgroundStorageService.importImage(source.path);
    final settings = AppSurfaceSettings.defaults.withGlobal(
      AppBackground(kind: AppBackgroundKind.image, image: name),
    );
    await fixture.settings.setAppSurfaceRaw(settings.encode());
    return name;
  }

  File backgroundFile(String name) => File(
    p.join(
      fixture.documents.path,
      AppBackgroundStorageService.directoryName,
      name,
    ),
  );

  Future<List<String>> zipEntries(File zip) async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    try {
      return [for (final file in archive.files) file.name];
    } finally {
      archive.clearSync();
    }
  }

  test(
    'full backups carry background images and a replace restore makes the settings point at them again',
    () async {
      final name = await seedBackground([1, 2, 3]);
      final backup = await DataArchiveService.exportToZip(
        database: fixture.database,
        settingsService: fixture.settings,
      );
      expect(
        await zipEntries(backup),
        contains('${AppBackgroundStorageService.directoryName}/$name'),
      );

      // 换到一个全新的安装目录、清掉设置，模拟在另一台设备上恢复。
      fixture.documents = await Directory(
        p.join(fixture.root.path, 'other_install'),
      ).create();
      await fixture.settings.setAppSurfaceRaw(null);
      await fixture.import(backup);

      final restored = AppSurfaceSettings.decode(
        fixture.settings.appSurfaceRaw,
      );
      expect(restored.global.image, name);
      final file = await AppBackgroundStorageService.resolve(name);
      expect(file, isNotNull);
      expect(await file!.readAsBytes(), [1, 2, 3]);
    },
  );

  test('diary packages never carry background images', () async {
    await seedBackground([4, 5, 6]);
    final diaryId = await fixture.database.createDiary(
      title: 'packaged',
      contentDocJson: '[{"insert":"\\n"}]',
      contentText: '',
      metadataJson: '{}',
    );
    final package = await DataArchiveService.exportDiariesToZip(
      database: fixture.database,
      diaryIds: [diaryId],
    );
    expect(
      (await zipEntries(package)).where(
        (entry) =>
            entry.startsWith('${AppBackgroundStorageService.directoryName}/'),
      ),
      isEmpty,
    );
  });

  test(
    'a failed replace restore puts the local background images back',
    () async {
      await fixture.seedCurrentData();
      final local = await seedBackground([7, 7, 7]);
      final localRaw = fixture.settings.appSurfaceRaw;
      final incoming = await fixture.capturePayload();
      (incoming['settings'] as Map)['appSurfaceRaw'] =
          '{"v":1,"global":{"kind":"image","image":"bg_incoming.png"}}';
      final zip = await fixture.writeZip(
        incoming,
        files: {
          '${AppBackgroundStorageService.directoryName}/bg_incoming.png': [9],
        },
      );
      await fixture.database.customStatement('''
CREATE TRIGGER reject_backup_restore BEFORE INSERT ON diaries
BEGIN SELECT RAISE(ABORT, 'forced restore failure'); END;
''');
      await expectLater(fixture.import(zip), throwsA(anything));

      expect(await backgroundFile(local).readAsBytes(), [7, 7, 7]);
      expect(await backgroundFile('bg_incoming.png').exists(), isFalse);
      expect(fixture.settings.appSurfaceRaw, localRaw);
      await fixture.expectCurrentDataIntact();
    },
  );

  test(
    'backups without background settings keep the local images on replace restore',
    () async {
      final local = await seedBackground([8]);
      final localRaw = fixture.settings.appSurfaceRaw;
      // 旧版备份：设置里没有 appSurfaceRaw，本机设置原样保留，图片也必须
      // 原样保留；包里即便带了这个目录也不换入。
      final zip = await fixture.writeZip(
        fixture.emptyPayload(),
        files: {
          '${AppBackgroundStorageService.directoryName}/bg_stray.png': [1],
        },
      );
      await fixture.import(zip);

      expect(fixture.settings.appSurfaceRaw, localRaw);
      expect(await backgroundFile(local).readAsBytes(), [8]);
      expect(await backgroundFile('bg_stray.png').exists(), isFalse);
    },
  );

  test('merge imports leave background settings and images alone', () async {
    final local = await seedBackground([5]);
    final localRaw = fixture.settings.appSurfaceRaw;
    final payload = fixture.emptyPayload();
    (payload['settings'] as Map)['appSurfaceRaw'] =
        '{"v":1,"global":{"kind":"image","image":"bg_incoming.png"}}';
    final zip = await fixture.writeZip(
      payload,
      files: {
        '${AppBackgroundStorageService.directoryName}/bg_incoming.png': [9],
      },
    );
    for (final mode in [
      BackupImportMode.merge,
      BackupImportMode.mergeOverwrite,
    ]) {
      await DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: zip.path,
        mode: mode,
      );
      expect(fixture.settings.appSurfaceRaw, localRaw);
      expect(await backgroundFile(local).readAsBytes(), [5]);
      expect(await backgroundFile('bg_incoming.png').exists(), isFalse);
    }
  });

  test(
    'backups that reset the background settings replace the local images',
    () async {
      final local = await seedBackground([3]);
      final payload = fixture.emptyPayload();
      (payload['settings'] as Map)['appSurfaceRaw'] = null;
      await fixture.import(await fixture.writeZip(payload));

      expect(fixture.settings.appSurfaceRaw, isNull);
      expect(await backgroundFile(local).exists(), isFalse);
    },
  );
}
