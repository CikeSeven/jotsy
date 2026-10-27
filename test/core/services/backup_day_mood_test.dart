import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';

import '../../support/backup_test_fixture.dart';

/// 这天的心情随完整备份导出、覆盖恢复与按日期合并；日记包与旧备份不带它。
/// 夹具里本机记了 2026-10-01 的心情“不错”。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  Future<Map<String, String>> moods() async => {
    for (final row
        in await fixture.database.select(fixture.database.dayMoods).get())
      row.day: row.mood,
  };

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

  test('a full backup restores every day mood as it was', () async {
    // 更新版本写入的心情名也原样往返，不在备份里丢掉。
    await fixture.database
        .into(fixture.database.dayMoods)
        .insert(
          DayMoodsCompanion.insert(
            day: '2026-10-02',
            mood: 'ecstatic',
            updatedAt: DateTime(2026, 10, 2),
          ),
        );
    final original = await fixture.database
        .select(fixture.database.dayMoods)
        .get();
    final payload = await fixture.capturePayload();
    expect((payload['database'] as Map)['dayMoods'], hasLength(2));

    await fixture.database.clearDayMood(DateTime(2026, 10, 1));
    await fixture.database.setDayMood(DateTime(2026, 10, 3), DayMood.awful);
    final result = await importWith(payload, BackupImportMode.replaceAll);

    expect(
      await fixture.database.select(fixture.database.dayMoods).get(),
      original,
    );
    expect(result.addedDayMoods, 2);
  });

  test('restoring an old backup without the table clears the moods, '
      'and the warning counts them', () async {
    final legacy = fixture.emptyPayload();
    final check = await preview(legacy);
    expect(check.localDayMoodCount, 1);

    await importWith(legacy, BackupImportMode.replaceAll);
    expect(await moods(), isEmpty);
  });

  test(
    'a backup with an impossible date is rejected and changes nothing',
    () async {
      final payload = await fixture.capturePayload();
      (payload['database'] as Map)['dayMoods'] = <Object?>[
        {'day': '2026-02-30', 'mood': 'good', 'updatedAt': 0},
      ];
      await expectLater(
        importWith(payload, BackupImportMode.replaceAll),
        throwsA(isA<FormatException>()),
      );
      await fixture.expectCurrentDataIntact();
    },
  );

  group('merging', () {
    late Map<String, Object?> payload;
    setUp(() async {
      payload = await fixture.capturePayload();
      final tables = payload['database'] as Map;
      tables['diaries'] = <Object?>[];
      tables['diaryTags'] = <Object?>[];
      tables['anniversaries'] = <Object?>[];
      tables['dayMoods'] = <Object?>[
        {'day': '2026-10-01', 'mood': 'awful', 'updatedAt': 0},
        {'day': '2026-10-05', 'mood': 'great', 'updatedAt': 0},
      ];
    });

    test('offers overwrite when only day moods overlap', () async {
      final check = await preview(payload);
      expect(check.existingDiaryCount, 0);
      expect(check.existingAnniversaryCount, 0);
      expect(check.existingDayMoodCount, 1);
      expect(check.availableModes, contains(BackupImportMode.mergeOverwrite));
    });

    test('merge keeps the local mood and adds the new day', () async {
      final result = await importWith(payload, BackupImportMode.merge);
      expect(await moods(), <String, String>{
        '2026-10-01': 'good',
        '2026-10-05': 'great',
      });
      expect((result.addedDayMoods, result.replacedDayMoods), (1, 0));
    });

    test('merge-overwrite takes the mood from the file', () async {
      final result = await importWith(payload, BackupImportMode.mergeOverwrite);
      expect(await moods(), <String, String>{
        '2026-10-01': 'awful',
        '2026-10-05': 'great',
      });
      expect((result.addedDayMoods, result.replacedDayMoods), (1, 1));
    });
  });

  test('a diary package carries no day moods and leaves them alone', () async {
    final diary = await fixture.database
        .select(fixture.database.diaries)
        .getSingle();
    final zip = await DataArchiveService.exportDiariesToZip(
      database: fixture.database,
      diaryIds: <String>[diary.diaryId],
    );
    final result = await DataArchiveService.importFromZip(
      database: fixture.database,
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: BackupImportMode.mergeOverwrite,
    );
    expect((result.addedDayMoods, result.replacedDayMoods), (0, 0));
    expect(await moods(), <String, String>{'2026-10-01': 'good'});
  });
}
