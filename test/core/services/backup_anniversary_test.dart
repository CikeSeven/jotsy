import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';

import '../../support/backup_test_fixture.dart';

/// 纪念日随完整备份导出、覆盖恢复与合并；日记包与旧备份不动它们以外的
/// 预期。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  Future<List<Anniversary>> anniversaries() =>
      fixture.database.select(fixture.database.anniversaries).get();

  Future<BackupImportResult> importWith(
    Map<String, Object?> payload,
    BackupImportMode mode,
  ) async {
    final zip = await fixture.writeZip(payload);
    return DataArchiveService.importFromZip(
      database: fixture.database,
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: mode,
    );
  }

  Future<BackupArchivePreview> preview(Map<String, Object?> payload) async {
    final zip = await fixture.writeZip(payload);
    return DataArchiveService.inspectZip(
      database: fixture.database,
      zipPath: zip.path,
    );
  }

  test('a full backup restores every anniversary field as it was', () async {
    final original = await anniversaries();
    final payload = await fixture.capturePayload();
    expect((payload['database'] as Map)['anniversaries'], hasLength(1));

    await fixture.database.deleteAnniversary(original.single.anniversaryId);
    await fixture.database.createAnniversary(
      title: 'later',
      baseDate: DateTime(2026),
      recurrence: AnniversaryRecurrence.once,
    );
    final result = await importWith(payload, BackupImportMode.replaceAll);

    expect(await anniversaries(), original);
    expect(result.addedAnniversaries, 1);
  });

  test('restoring an old backup without the table clears anniversaries, '
      'and the preview says how many', () async {
    final legacy = fixture.emptyPayload();
    final check = await preview(legacy);
    expect(check.localAnniversaryCount, 1);
    expect(check.anniversaryCount, 0);

    await importWith(legacy, BackupImportMode.replaceAll);
    expect(await anniversaries(), isEmpty);
  });

  group('anniversaries toggle (off by default)', () {
    bool anniversariesOn() =>
        AppFeatures.decode(fixture.settings.appFeaturesRaw).anniversaries;

    test('an old backup with anniversaries keeps them visible', () async {
      // 纪念日默认关闭之前的备份：没保存过功能开关时导出的是 null。
      final payload = await fixture.capturePayload();
      (payload['settings'] as Map)['appFeaturesRaw'] = null;

      await importWith(payload, BackupImportMode.replaceAll);

      expect(anniversariesOn(), isTrue);
    });

    test('a toggle saved in the backup is restored as it was', () async {
      final payload = await fixture.capturePayload();
      (payload['settings'] as Map)['appFeaturesRaw'] = AppFeatures.defaults
          .encode();

      await importWith(payload, BackupImportMode.replaceAll);

      expect(anniversariesOn(), isFalse);
    });

    test('merging anniversaries in keeps them visible when never saved, '
        'but not over a saved choice', () async {
      final payload = await fixture.capturePayload();
      await fixture.settings.setAppFeaturesRaw(null);
      await importWith(payload, BackupImportMode.merge);
      expect(anniversariesOn(), isTrue);

      await fixture.settings.setAppFeaturesRaw(AppFeatures.defaults.encode());
      await importWith(payload, BackupImportMode.merge);
      expect(anniversariesOn(), isFalse);
    });
  });

  group('merging', () {
    late Map<String, Object?> payload;
    setUp(() async {
      payload = await fixture.capturePayload();
      final tables = payload['database'] as Map;
      final existing = Map<String, Object?>.from(
        (tables['anniversaries'] as List).single as Map,
      );
      tables['diaries'] = <Object?>[];
      tables['diaryTags'] = <Object?>[];
      tables['anniversaries'] = <Object?>[
        {...existing, 'title': 'from the file'},
        {
          ...existing,
          'id': 99,
          'anniversaryId': 'other-device',
          'title': 'new one',
          'linkedDiaryId': 'missing-diary',
        },
      ];
    });

    test('offers overwrite when only anniversaries overlap', () async {
      final check = await preview(payload);
      expect(check.existingDiaryCount, 0);
      expect(check.anniversaryCount, 2);
      expect(check.existingAnniversaryCount, 1);
      expect(check.availableModes, contains(BackupImportMode.mergeOverwrite));
    });

    test('merge keeps the local version and adds the new one', () async {
      final result = await importWith(payload, BackupImportMode.merge);
      final rows = await anniversaries();
      expect(rows.map((row) => row.title), <String>[
        'current anniversary',
        'new one',
      ]);
      expect(rows.last.id, isNot(99), reason: '文件里的本地 id 不沿用');
      expect(rows.last.linkedDiaryId, 'missing-diary');
      expect((result.addedAnniversaries, result.skippedAnniversaries), (1, 1));
      expect(
        (await fixture.database.select(fixture.database.diaries).get()).map(
          (row) => row.title,
        ),
        <String>['current diary'],
      );
    });

    test('merge-overwrite replaces the existing one in place', () async {
      final before = (await anniversaries()).single;
      final result = await importWith(payload, BackupImportMode.mergeOverwrite);
      final rows = await anniversaries();
      expect(rows.first.id, before.id);
      expect(rows.first.title, 'from the file');
      expect((result.addedAnniversaries, result.replacedAnniversaries), (1, 1));
    });
  });

  test(
    'a diary package carries no anniversaries and leaves them alone',
    () async {
      final diary = await fixture.database
          .select(fixture.database.diaries)
          .getSingle();
      final zip = await DataArchiveService.exportDiariesToZip(
        database: fixture.database,
        diaryIds: <String>[diary.diaryId],
      );
      final check = await DataArchiveService.inspectZip(
        database: fixture.database,
        zipPath: zip.path,
      );
      expect(check.anniversaryCount, 0);

      final result = await DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: zip.path,
        mode: BackupImportMode.mergeOverwrite,
      );
      expect(result.touchedAnniversaries, isFalse);
      expect((await anniversaries()).single.title, 'current anniversary');
    },
  );
}
