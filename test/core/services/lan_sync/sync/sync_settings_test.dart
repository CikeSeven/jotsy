import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
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
    // 待办默认关闭，同样是数据类开关、在 prefs 里。
    expect(prefs.facets[SyncPrefsFacet.feature('todos')], {'on': false});
    expect(
      prefs.facets.containsKey(SyncPrefsFacet.feature('calendar')),
      isFalse,
    );
    final record = settingsRecord(rows, capture(settings));
    expect(record.facets['appFeaturesRaw'], {
      'value': {
        'calendar': false,
        'explore': true,
        'swipeArchive': true,
        'ai': false,
      },
    });
  });

  test('专注计时开关：默认时不写进规范值，关掉才写；读回时没有即默认', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final rows = await a.db.readSyncRows();
    final defaults = settingsRecord(rows, capture(settings));
    expect(
      (defaults.facets['appFeaturesRaw']! as Map)['value'],
      isNot(contains('todoFocus')),
      reason: '已有设备的开关分面不变，历史哈希仍有效',
    );
    await settings.setAppFeaturesRaw(
      jsonEncode(<String, Object?>{'todos': true, 'todoFocus': false}),
    );
    final off = settingsRecord(rows, capture(settings));
    expect(
      (off.facets['appFeaturesRaw']! as Map)['value'],
      containsPair('todoFocus', false),
    );
    // 对方关掉 → 本机跟着关；对方开回默认（分面里没有）→ 本机跟着开。
    final localOn = AppFeatures.defaults.copyWith(todos: true).encode();
    final turnedOff = syncSettingsRestoreNode(
      off,
      facets: const <String>['appFeaturesRaw'],
      dataRoot: '/data',
      localAppFeaturesRaw: localOn,
    );
    final offRaw = turnedOff['appFeaturesRaw']! as String;
    expect(AppFeatures.decode(offRaw).todoFocus, isFalse);
    final turnedOn = syncSettingsRestoreNode(
      defaults,
      facets: const <String>['appFeaturesRaw'],
      dataRoot: '/data',
      localAppFeaturesRaw: offRaw,
    );
    expect(
      AppFeatures.decode(turnedOn['appFeaturesRaw'] as String?).todoFocus,
      isTrue,
    );
  });

  test('心情符号在 prefs（不开同步设置也同步）：默认为 null，改过为 10 个符号', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final rows = await a.db.readSyncRows();
    SyncRecord prefsOf() => prefsRecord(
      rows,
      syncCaptureSettings(settings, includeSettings: false),
    );
    expect(prefsOf().facets[SyncPrefsFacet.moodOptions], {'value': null});
    expect(
      prefsOf().hashes[SyncPrefsFacet.moodOptions],
      SyncPrefsFacet.unsetHash,
    );

    // 手动改回与默认相同的符号：仍是“没改过”。
    await settings.setMoodOptions(SettingsService.defaultMoodOptions);
    expect(prefsOf().facets[SyncPrefsFacet.moodOptions], {'value': null});
    // 读不出来的原文按默认处理，不让脏数据传到另一台。
    settings.moodOptionsRawNotifier.value = 'not json';
    expect(prefsOf().facets[SyncPrefsFacet.moodOptions], {'value': null});

    final custom = <String>[
      '😡',
      ...SettingsService.defaultMoodOptions.sublist(1, 9),
      '🥰',
    ];
    await settings.setMoodOptions(custom);
    final prefs = prefsOf();
    expect(prefs.facets[SyncPrefsFacet.moodOptions], {'value': custom});
    // 不在 settings 记录里（不受“同步设置”控制）。
    expect(
      settingsRecord(
        rows,
        capture(settings),
      ).facets.containsKey(kSyncMoodOptionsRawKey),
      isFalse,
    );

    final node = syncPrefsRestoreNode(
      prefs,
      facets: <String>[SyncPrefsFacet.moodOptions],
      tagIdsByName: const <String, int>{},
      localAppFeaturesRaw: null,
    );
    expect(node, <String, Object?>{
      kSyncMoodOptionsRawKey: SettingsService.encodeMoodOptions(custom),
    });
    final defaultNode = syncPrefsRestoreNode(
      SyncRecord(prefs.key, {
        ...prefs.facets,
        SyncPrefsFacet.moodOptions: SyncPrefsFacet.unsetValue,
      }),
      facets: <String>[SyncPrefsFacet.moodOptions],
      tagIdsByName: const <String, int>{},
      localAppFeaturesRaw: null,
    );
    expect(defaultNode, <String, Object?>{kSyncMoodOptionsRawKey: null});
  });

  test('心情颜色在 prefs：没改过为 null，改过为原文；还原节点交给 restore', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final rows = await a.db.readSyncRows();
    SyncRecord prefsOf() => prefsRecord(
      rows,
      syncCaptureSettings(settings, includeSettings: false),
    );
    expect(
      prefsOf().hashes[SyncPrefsFacet.moodColors],
      SyncPrefsFacet.unsetHash,
    );

    const raw = '{"1":"#FF112233"}';
    await settings.setMoodColorsRaw(' $raw ');
    final prefs = prefsOf();
    expect(prefs.facets[SyncPrefsFacet.moodColors], {'value': raw});
    expect(
      settingsRecord(
        rows,
        capture(settings),
      ).facets.containsKey(kSyncMoodColorsRawKey),
      isFalse,
    );

    final node = syncPrefsRestoreNode(
      prefs,
      facets: <String>[SyncPrefsFacet.moodColors],
      tagIdsByName: const <String, int>{},
      localAppFeaturesRaw: null,
    );
    expect(node, <String, Object?>{kSyncMoodColorsRawKey: raw});

    // 另一台按节点还原后，规范值逐字节相同。
    await settings.setMoodColorsRaw(null);
    await BackupSettings.restore(settings, node);
    expect(prefsOf().hashes, prefs.hashes);
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
