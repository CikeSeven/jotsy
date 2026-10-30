import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_manifest_builder.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/tag_order_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_test_devices.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    a = await SyncTestDevice.create('a');
    b = await SyncTestDevice.create('b');
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  Future<Map<String, int>> tags(AppDatabase db, List<String> names) async => {
    for (final name in names)
      name: await db
          .into(db.tags)
          .insert(TagsCompanion(name: Value(name), color: const Value(1))),
  };

  SyncRecord recordOf(
    SyncEntity entity,
    SyncRawSnapshot rows,
    SyncSettingsCapture captured,
  ) => syncBuildRecords(
    rows,
    settings: captured,
  ).singleWhere((record) => record.key.entity == entity);

  SyncRecord settingsRecord(
    SyncRawSnapshot rows,
    SyncSettingsCapture captured,
  ) => recordOf(SyncEntity.settings, rows, captured);

  SyncRecord prefsRecord(SyncRawSnapshot rows, SyncSettingsCapture captured) =>
      recordOf(SyncEntity.prefs, rows, captured);

  SyncSettingsCapture capture(SettingsService settings) =>
      syncCaptureSettings(settings, includeSettings: true);

  test(
    'settings restored on another device read back byte-for-byte equal',
    () async {
      final idsA = await tags(a.db, <String>['alpha', 'beta', 'gamma']);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settingsA = await SettingsService.create();
      await settingsA.setThemeMode(ThemeMode.dark);
      await settingsA.setThemeSeedColor(const Color(0xFF3F51B5));
      await settingsA.setFontScale(1.1);
      await settingsA.setDiarySortModeRaw('createdAsc');
      await settingsA.setAppLockEnabled(true);
      await settingsA.setTagFilterMemoryEnabled(true);
      await settingsA.setRememberedTagFilterIdsRaw('${idsA['alpha']}');
      await settingsA.setTagOrderRaw(
        encodeTagOrder(<int>[idsA['gamma']!, 999, idsA['alpha']!]),
      );
      await settingsA.setAppSurfaceRaw(
        jsonEncode(<String, Object?>{
          'v': 1,
          'global': <String, Object?>{'kind': 'image', 'image': 'bg_1.jpg'},
          'areas': <String, Object?>{
            'editor': <String, Object?>{
              'mode': 'custom',
              'background': <String, Object?>{
                'kind': 'image',
                'image': 'bg_2.png',
              },
            },
          },
        }),
      );
      final capturedA = capture(settingsA);
      expect(capturedA.values.containsKey('appLockEnabled'), isFalse);
      expect(
        capturedA.values.containsKey('rememberedTagFilterIdsRaw'),
        isFalse,
      );
      final rowsA = await a.db.readSyncRows();
      final recordA = settingsRecord(rowsA, capturedA);
      final prefsA = prefsRecord(rowsA, capturedA);

      // 标签顺序在 prefs 里（始终同步），不在 settings 里。
      expect(recordA.facets.containsKey('tagOrderRaw'), isFalse);
      expect(recordA.facets.containsKey(SyncPrefsFacet.tagOrder), isFalse);
      expect(prefsA.facets[SyncPrefsFacet.tagOrder], <String, Object?>{
        'value': <String>['gamma', 'alpha'],
      });
      expect(recordA.mediaKeys, <String>{
        'app_backgrounds/bg_1.jpg',
        'app_backgrounds/bg_2.png',
      });

      // 设备 B：标签本地 id 与 A 不同（倒序建）。
      final idsB = await tags(b.db, <String>['gamma', 'beta', 'alpha']);
      expect(idsB['gamma'], isNot(idsA['gamma']));
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settingsB = await SettingsService.create();
      final node = syncSettingsRestoreNode(
        recordA,
        dataRoot: b.dataRoot.path,
        localAppFeaturesRaw: settingsB.appFeaturesRaw,
      );
      final prefsNode = syncPrefsRestoreNode(
        prefsA,
        tagIdsByName: idsB,
        localAppFeaturesRaw: settingsB.appFeaturesRaw,
      );
      expect(
        prefsNode['tagOrderRaw'],
        encodeTagOrder(<int>[idsB['gamma']!, idsB['alpha']!]),
      );
      expect(node['appSurfaceRaw'], contains('"image":"bg_1.jpg"'));
      expect(node['appSurfaceRaw'], isNot(contains('jotsy-media:')));
      await BackupSettings.restore(settingsB, {...node, ...prefsNode});

      final rowsB = await b.db.readSyncRows();
      final recordB = settingsRecord(rowsB, capture(settingsB));
      expect(
        syncCanonicalJson(recordB.facets),
        syncCanonicalJson(recordA.facets),
      );
      expect(recordB.hashes, recordA.hashes);
      expect(prefsRecord(rowsB, capture(settingsB)).hashes, prefsA.hashes);
      // 应用锁与筛选记忆不随同步过来。
      expect(settingsB.isAppLockEnabled, isFalse);
      expect(settingsB.rememberedTagFilterIdsRaw, isNull);
    },
  );

  test('restore node only carries the requested facets', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final rows = await a.db.readSyncRows();
    final record = settingsRecord(rows, capture(settings));
    final node = syncSettingsRestoreNode(
      record,
      facets: <String>['themeMode'],
      dataRoot: a.dataRoot.path,
      localAppFeaturesRaw: null,
    );
    expect(node.keys.toSet(), <String>{'themeMode'});
    final prefsNode = syncPrefsRestoreNode(
      prefsRecord(rows, capture(settings)),
      facets: <String>[SyncPrefsFacet.tagOrder],
      tagIdsByName: const <String, int>{},
      localAppFeaturesRaw: null,
    );
    expect(prefsNode, <String, Object?>{'tagOrderRaw': ''});
  });

  test('功能开关：数据类在 prefs（每项一个分面），界面类留在 settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    await settings.setAppFeaturesRaw(
      jsonEncode(<String, Object?>{'comments': true, 'calendar': false}),
    );
    final rows = await a.db.readSyncRows();
    final prefs = prefsRecord(rows, capture(settings));
    expect(prefs.facets[SyncPrefsFacet.feature('comments')], {'on': true});
    expect(prefs.facets[SyncPrefsFacet.feature('notebooks')], {'on': true});
    expect(prefs.facets[SyncPrefsFacet.feature('anniversaries')], {
      'on': false,
    });
    expect(
      prefs.facets.containsKey(SyncPrefsFacet.feature('calendar')),
      isFalse,
    );
    final record = settingsRecord(rows, capture(settings));
    expect(record.facets['appFeaturesRaw'], {
      'value': {'calendar': false, 'explore': true, 'swipeArchive': true},
    });
  });

  test('不同步设置时只有 prefs，没有 settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final observation = syncObserveRows(
      await a.db.readSyncRows(),
      settings: syncCaptureSettings(settings, includeSettings: false),
    ).observation;
    expect(
      observation.manifest.keys.where(
        (key) =>
            key.entity == SyncEntity.settings || key.entity == SyncEntity.prefs,
      ),
      [const SyncKey(SyncEntity.prefs, kSyncPrefsId)],
    );
    expect(observation.observed, contains(SyncEntity.prefs));
    expect(observation.observed, isNot(contains(SyncEntity.settings)));
  });
}
