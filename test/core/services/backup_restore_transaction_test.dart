import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  test(
    'database write failure restores original media and allows a later retry',
    () async {
      final incoming = await fixture.capturePayload();
      final row =
          ((incoming['database'] as Map)['diaries'] as List).single as Map;
      row['title'] = 'incoming diary';
      final files = {
        for (final path in fixture.originalMedia.keys)
          path.substring(fixture.documents.path.length + 1): <int>[99, 98, 97],
      };
      final zip = await fixture.writeZip(incoming, files: files);
      await fixture.database.customStatement('''
CREATE TRIGGER reject_backup_restore BEFORE INSERT ON diaries
BEGIN SELECT RAISE(ABORT, 'forced restore failure'); END;
''');
      await expectLater(
        fixture.import(zip),
        throwsA(
          predicate(
            (error) => error.toString().contains('forced restore failure'),
          ),
        ),
      );
      await fixture.expectCurrentDataIntact();
      await fixture.database.customStatement(
        'DROP TRIGGER reject_backup_restore',
      );
      await fixture.import(zip);
      expect(
        (await fixture.database.select(fixture.database.diaries).getSingle())
            .title,
        'incoming diary',
      );
      for (final path in fixture.originalMedia.keys) {
        expect(await File(path).readAsBytes(), [99, 98, 97]);
      }
    },
  );

  for (final throwError in [false, true]) {
    test(
      'setting persistence ${throwError ? 'exceptions' : 'false results'} roll back tables, files and notification state',
      () async {
        await fixture.settings.setThemeMode(ThemeMode.light);
        await fixture.settings.setTagFilterMemoryEnabled(true);
        await fixture.settings.setRememberedTagFilterIdsRaw('1,3');
        await fixture.settings.setCalendarDisplayOptionsRaw(
          '{"cellStyle":"heat"}',
        );
        await fixture.settings.setDiaryCardStyleRaw('{"v":1,"current":{}}');
        await fixture.settings.setDiaryPreviewStyleRaw(
          '{"v":1,"current":{"page":{"paper":"ink"}}}',
        );
        await fixture.settings.setDiaryShareOptionsRaw('{"title":false}');
        await fixture.settings.setDiaryExportOptionsRaw('{"format":"word"}');
        await fixture.settings.setDiaryTemplatePrefsRaw(
          '{"v":1,"strip":false}',
        );
        // 升级前还没迁移的旧版单份草稿：覆盖恢复会清掉它，失败时须原样回滚。
        await fixture.settings.setCreateDiaryDraftRaw(
          '{"title":"legacy draft"}',
        );
        final originalStore = SharedPreferencesStorePlatform.instance;
        final before = await originalStore.getAll();
        final store = _FailingPreferences(before, throwError);
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(
          () => SharedPreferencesStorePlatform.instance = originalStore,
        );
        final incoming = await fixture.capturePayload();
        final settings = incoming['settings'] as Map;
        settings['themeMode'] = 'dark';
        settings['fontScale'] = 1.25;
        settings['tagFilterMemoryEnabled'] = false;
        settings['diaryLocationPrecisionRaw'] = 'city';
        settings['calendarDisplayOptionsRaw'] = '{"cellStyle":"photo"}';
        settings['diaryCardStyleRaw'] = '{"v":1,"saved":[]}';
        settings['diaryPreviewStyleRaw'] = '{"v":1,"current":{}}';
        settings['diaryShareOptionsRaw'] = '{"title":true}';
        settings['diaryExportOptionsRaw'] = '{"format":"csv"}';
        settings['diaryTemplatePrefsRaw'] = '{"v":1,"auto":"builtin.daily"}';
        final row =
            ((incoming['database'] as Map)['diaries'] as List).single as Map;
        row['title'] = 'incoming diary';
        final draftRow =
            ((incoming['database'] as Map)['diaryDrafts'] as List).single
                as Map;
        draftRow['payload'] = '{"title":"incoming draft"}';
        final zip = await fixture.writeZip(
          incoming,
          files: {
            'diary_videos/keep.bin': [99],
          },
        );
        store.failNextLateWrite = true;
        await expectLater(
          fixture.import(zip),
          throwsA(throwError ? isA<PlatformException>() : isA<StateError>()),
        );
        expect(store.failed, isTrue);
        await fixture.expectCurrentDataIntact();
        expect(fixture.settings.themeModeNotifier.value, ThemeMode.light);
        expect(
          fixture.settings.fontScaleValue,
          SettingsService.defaultFontScale,
        );
        expect(fixture.settings.isTagFilterMemoryEnabled, isTrue);
        expect(fixture.settings.rememberedTagFilterIdsRaw, '1,3');
        expect(
          fixture.settings.calendarDisplayOptionsRaw,
          '{"cellStyle":"heat"}',
        );
        expect(fixture.settings.diaryCardStyleRaw, '{"v":1,"current":{}}');
        expect(
          fixture.settings.diaryPreviewStyleRaw,
          '{"v":1,"current":{"page":{"paper":"ink"}}}',
        );
        expect(fixture.settings.diaryShareOptionsRaw, '{"title":false}');
        expect(fixture.settings.diaryExportOptionsRaw, '{"format":"word"}');
        expect(fixture.settings.diaryTemplatePrefsRaw, '{"v":1,"strip":false}');
        expect(await store.getAll(), before);
        final recreated = await SettingsService.create();
        expect(recreated.themeModeNotifier.value, ThemeMode.light);
        expect(recreated.createDiaryDraftRaw, '{"title":"legacy draft"}');
        expect(recreated.calendarDisplayOptionsRaw, '{"cellStyle":"heat"}');
        expect(recreated.diaryCardStyleRaw, '{"v":1,"current":{}}');
        expect(
          recreated.diaryPreviewStyleRaw,
          '{"v":1,"current":{"page":{"paper":"ink"}}}',
        );
        expect(recreated.diaryTemplatePrefsRaw, '{"v":1,"strip":false}');
      },
    );
  }

  test(
    'simultaneous backup requests keep independent working directories',
    () async {
      final archives = await Future.wait([
        DataArchiveService.exportToZip(
          database: fixture.database,
          settingsService: fixture.settings,
        ),
        DataArchiveService.exportToZip(
          database: fixture.database,
          settingsService: fixture.settings,
        ),
      ]);
      expect(archives[0].path, isNot(archives[1].path));
      for (final archive in archives) {
        await fixture.import(archive);
        await fixture.expectCurrentDataIntact();
      }
    },
  );
}

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences(super.data, this.throwError) : super.withData();
  final bool throwError;
  // 恢复设置时最后写入的键：此前的设置都已改写，失败才能检验整体回滚。
  bool failNextLateWrite = false;
  bool failed = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failNextLateWrite && key.endsWith('diary_location_precision')) {
      failNextLateWrite = false;
      failed = true;
      if (throwError) throw PlatformException(code: 'write_failed');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
