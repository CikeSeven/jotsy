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

  SyncRecord settingsRecord(
    SyncRawSnapshot rows,
    Map<String, Object?> captured,
  ) => syncBuildRecords(
    rows,
    settings: captured,
  ).singleWhere((record) => record.key.entity == SyncEntity.settings);

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
      final capturedA = syncCaptureSettings(settingsA);
      expect(capturedA.containsKey('appLockEnabled'), isFalse);
      expect(capturedA.containsKey('rememberedTagFilterIdsRaw'), isFalse);
      final recordA = settingsRecord(await a.db.readSyncRows(), capturedA);

      expect(recordA.facets.containsKey('tagOrderRaw'), isFalse);
      expect(recordA.facets[kSyncTagOrderNamesFacet], <String, Object?>{
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
        tagIdsByName: idsB,
        dataRoot: b.dataRoot.path,
      );
      expect(
        node['tagOrderRaw'],
        encodeTagOrder(<int>[idsB['gamma']!, idsB['alpha']!]),
      );
      expect(node['appSurfaceRaw'], contains('"image":"bg_1.jpg"'));
      expect(node['appSurfaceRaw'], isNot(contains('jotsy-media:')));
      await BackupSettings.restore(settingsB, node);

      final recordB = settingsRecord(
        await b.db.readSyncRows(),
        syncCaptureSettings(settingsB),
      );
      expect(
        syncCanonicalJson(recordB.facets),
        syncCanonicalJson(recordA.facets),
      );
      expect(recordB.hashes, recordA.hashes);
      // 应用锁与筛选记忆不随同步过来。
      expect(settingsB.isAppLockEnabled, isFalse);
      expect(settingsB.rememberedTagFilterIdsRaw, isNull);
    },
  );

  test('restore node only carries the requested facets', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final record = settingsRecord(
      await a.db.readSyncRows(),
      syncCaptureSettings(settings),
    );
    final node = syncSettingsRestoreNode(
      record,
      facets: <String>['themeMode', kSyncTagOrderNamesFacet],
      tagIdsByName: const <String, int>{},
      dataRoot: a.dataRoot.path,
    );
    expect(node.keys.toSet(), <String>{'themeMode', 'tagOrderRaw'});
    expect(node['tagOrderRaw'], '');
  });
}
