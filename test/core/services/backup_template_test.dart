import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/backup_payload.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/settings/controllers/backup_import_flow.dart';

import '../../support/backup_test_fixture.dart';

/// 日记模板随完整备份导出与覆盖恢复；两种合并只新增本机没有的模板，从不
/// 替换本机已有的；日记包不带模板。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  Future<List<DiaryTemplateRow>> templates() =>
      fixture.database.getDiaryTemplates();

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

  test(
    'a full backup restores templates and their prefs as they were',
    () async {
      await fixture.settings.setDiaryTemplatePrefsRaw('{"v":1,"strip":false}');
      final original = await templates();
      final payload = await fixture.capturePayload();
      expect((payload['database'] as Map)['diaryTemplates'], hasLength(1));

      await fixture.database.deleteDiaryTemplates(['current-template']);
      await fixture.database.saveDiaryTemplate(name: 'later', payload: '{}');
      await fixture.settings.setDiaryTemplatePrefsRaw(null);
      final result = await importWith(payload, BackupImportMode.replaceAll);

      expect(await templates(), original);
      expect(result.addedTemplates, 1);
      expect(fixture.settings.diaryTemplatePrefsRaw, '{"v":1,"strip":false}');
    },
  );

  test('restoring an old backup without the table clears templates, '
      'and the preview says how many', () async {
    final legacy = fixture.emptyPayload();
    final check = await preview(legacy);
    expect(check.localTemplateCount, 1);

    await importWith(legacy, BackupImportMode.replaceAll);
    expect(await templates(), isEmpty);
  });

  test('built-in ids in a hand-edited backup are dropped', () async {
    final payload = await fixture.capturePayload();
    final rows = (payload['database'] as Map)['diaryTemplates'] as List;
    rows.add({
      ...(rows.single as Map),
      'id': 50,
      'templateId': 'builtin.daily',
    });
    final decoded = BackupPayload.decode(jsonEncode(payload));
    expect(decoded.diaryTemplates.map((row) => row.templateId), [
      'current-template',
    ]);
  });

  test('duplicate template ids reject the backup', () async {
    final payload = await fixture.capturePayload();
    final rows = (payload['database'] as Map)['diaryTemplates'] as List;
    rows.add({...(rows.single as Map), 'id': 50});
    expect(
      () => BackupPayload.decode(jsonEncode(payload)),
      throwsFormatException,
    );
  });

  test('payload rebuilds keep templates', () async {
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    // 悬空的标签关联触发 _withRestorableTagRelations 重建载荷。
    (tables['diaryTags'] as List).add({'diaryId': 999, 'tagId': 999});
    final decoded = BackupPayload.decode(jsonEncode(payload));
    expect(decoded.diaryTemplates, hasLength(1));
  });

  group('merging', () {
    late Map<String, Object?> payload;
    setUp(() async {
      payload = await fixture.capturePayload();
      final tables = payload['database'] as Map;
      final existing = Map<String, Object?>.from(
        (tables['diaryTemplates'] as List).single as Map,
      );
      tables['diaries'] = <Object?>[];
      tables['diaryTags'] = <Object?>[];
      tables['anniversaries'] = <Object?>[];
      tables['diaryTemplates'] = <Object?>[
        {...existing, 'name': 'from the file', 'payload': '{"x":1}'},
        {
          ...existing,
          'id': 99,
          'templateId': 'other-b',
          'name': 'second',
          'sortOrder': 7,
        },
        {
          ...existing,
          'id': 98,
          'templateId': 'other-a',
          'name': 'first',
          'sortOrder': 3,
        },
      ];
    });

    for (final mode in [
      BackupImportMode.merge,
      BackupImportMode.mergeOverwrite,
    ]) {
      test(
        '${mode.name} only adds templates, in file order, at the end',
        () async {
          await fixture.database.saveDiaryTemplate(
            name: 'local two',
            payload: '{}',
          );
          final result = await importWith(payload, mode);

          final rows = await templates();
          expect(rows.map((row) => row.name), [
            'current template',
            'local two',
            'first',
            'second',
          ]);
          expect(rows.first.payload, '{"name":"current template"}');
          expect(rows.map((row) => row.sortOrder), [0, 1, 2, 3]);
          expect(result.addedTemplates, 2);
        },
      );
    }

    test('the result message mentions added templates', () async {
      final result = await importWith(payload, BackupImportMode.merge);
      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(
        describeBackupImportResult(l10n, result, replaceAllMessage: ''),
        contains('日记模板：新增 2 个'),
      );
    });
  });

  test('a diary package carries no templates and leaves them alone', () async {
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
    expect(result.addedTemplates, 0);
    expect((await templates()).single.name, 'current template');
  });
}
