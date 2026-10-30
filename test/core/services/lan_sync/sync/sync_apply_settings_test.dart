import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_apply.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/tag_order_codec.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'sync_apply_test_support.dart';
import 'sync_test_devices.dart';

/// 设置的写入（规格 §6 第 5 步）：只应用变化的分面、`restore` 忽略的空值、
/// 失败回滚、背景图就位，以及不碰本机的旧版草稿。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncTestDevice device;
  late SettingsService settings;
  late SyncApplyRig rig;
  late Map<String, int> tagIds;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    device = await SyncTestDevice.create('apply_settings');
    rig = SyncApplyRig(device, settings: settings);
    tagIds = {
      for (final name in ['alpha', 'beta'])
        name: await device.db
            .into(device.db.tags)
            .insert(TagsCompanion(name: Value(name), color: const Value(1))),
    };
  });

  tearDown(() => device.dispose());

  const settingsKey = SyncKey(SyncEntity.settings, kSyncSettingsId);
  const prefsKey = SyncKey(SyncEntity.prefs, kSyncPrefsId);

  SyncSettingsCapture capture() =>
      syncCaptureSettings(settings, includeSettings: true);

  /// 本机现在的设置记录，[changes] 覆盖其中的分面值。
  Future<SyncRecord> settingsRecord([
    Map<String, Object?> changes = const {},
  ]) async {
    final current = (await rig.records(settings: capture()))[settingsKey]!;
    return SyncRecord(settingsKey, {
      ...current.facets,
      for (final entry in changes.entries) entry.key: {'value': entry.value},
    });
  }

  /// 本机现在的 prefs 记录，[tagOrder] / [features] 覆盖其中的分面。
  Future<SyncRecord> prefsRecord({
    List<String>? tagOrder,
    Map<String, bool> features = const {},
  }) async {
    final current = (await rig.records(settings: capture()))[prefsKey]!;
    return SyncRecord(prefsKey, {
      ...current.facets,
      if (tagOrder != null) SyncPrefsFacet.tagOrder: {'value': tagOrder},
      for (final entry in features.entries)
        SyncPrefsFacet.feature(entry.key): SyncPrefsFacet.featureValue(
          entry.value,
        ),
    });
  }

  Future<SyncApplyResult> applySettings(
    SyncRecord target, {
    SyncMediaStaging? staging,
  }) async => rig.applier.apply(
    await rig.planFor([target], settings: capture()),
    staging: staging,
    includeSettings: true,
  );

  test('只应用变化的分面，读回的规范值与目标逐字节相同', () async {
    await settings.setDiaryCardTagLimit(2);
    final target = await settingsRecord({
      'themeMode': 'dark',
      'fontScale': 1.2,
    });
    final result = await applySettings(target);

    expect(result.skipped, isEmpty);
    expect(settings.themeModeNotifier.value, ThemeMode.dark);
    expect(settings.fontScaleValue, 1.2);
    expect(settings.diaryCardTagLimit, 2);
    expect(result.manifest![settingsKey], target.hashes);
    expect((await settingsRecord()).hashes, target.hashes);
  });

  test('restore 忽略的空值直接调 setter 清空；本机旧版草稿原样保留', () async {
    await settings.setDiaryToolbarOrderRaw('bold,italic');
    await settings.setTagPickerSortRaw('alpha');
    await settings.setDiaryLocationPrecisionRaw('city');
    await settings.setTagOrderRaw(
      encodeTagOrder([tagIds['beta']!, tagIds['alpha']!]),
    );
    await settings.setCreateDiaryDraftRaw('not json {');
    final target = await settingsRecord({
      'diaryToolbarOrderRaw': null,
      'tagPickerSortRaw': null,
      'diaryLocationPrecisionRaw': null,
    });
    final result = await applySettings(target);
    final prefs = await prefsRecord(tagOrder: <String>[]);
    final prefsResult = await applySettings(prefs);

    expect(result.skipped, isEmpty);
    expect(prefsResult.skipped, isEmpty);
    expect(settings.diaryToolbarOrderRaw, isNull);
    expect(settings.tagPickerSortRaw, isNull);
    expect(settings.diaryLocationPrecisionRaw, isNull);
    expect(decodeTagOrder(settings.tagOrderRaw), isEmpty);
    expect(settings.createDiaryDraftRaw, 'not json {');
    expect((await settingsRecord()).hashes, target.hashes);
    expect((await prefsRecord()).hashes, prefs.hashes);
  });

  test('按名称的标签顺序换回本机 id（prefs，不必开启同步设置）', () async {
    final target = await prefsRecord(tagOrder: ['beta', 'alpha', 'missing']);
    final result = await rig.applier.apply(
      await rig.planFor([target], settings: capture()),
    );
    expect(result.skipped, isEmpty);
    expect(decodeTagOrder(settings.tagOrderRaw), [
      tagIds['beta'],
      tagIds['alpha'],
    ]);
  });

  test('数据类功能开关只打开、不关闭；界面类开关不受影响', () async {
    await settings.setAppFeaturesRaw(
      AppFeatures.defaults.copyWith(calendar: false).encode(),
    );
    final target = await prefsRecord(
      features: {'comments': true, 'notebooks': false},
    );
    final result = await applySettings(target);

    expect(result.skipped, isEmpty);
    final features = AppFeatures.decode(settings.appFeaturesRaw);
    expect(features.comments, isTrue);
    expect(features.notebooks, isTrue, reason: '关闭不会同步过来');
    expect(features.calendar, isFalse);
  });

  test('没存过功能开关、也没有要打开的：保持“没存过”', () async {
    expect(settings.appFeaturesRaw, isNull);
    final target = await prefsRecord(
      tagOrder: ['alpha'],
      features: {'notebooks': true},
    );
    await applySettings(target);
    expect(settings.appFeaturesRaw, isNull);
  });

  test('同步设置里的界面类开关合进本机开关，数据类开关保持本机值', () async {
    await settings.setAppFeaturesRaw(
      AppFeatures.defaults.copyWith(comments: true).encode(),
    );
    final target = await settingsRecord({
      'appFeaturesRaw': {
        'calendar': false,
        'explore': true,
        'swipeArchive': false,
      },
    });
    final result = await applySettings(target);

    expect(result.skipped, isEmpty);
    final features = AppFeatures.decode(settings.appFeaturesRaw);
    expect(features.calendar, isFalse);
    expect(features.swipeArchive, isFalse);
    expect(features.comments, isTrue);
    expect((await settingsRecord()).hashes, target.hashes);
  });

  test('设置写入失败：按快照回滚设置，这条记为 settingsFailed，数据库写入保留', () async {
    final original = SharedPreferencesStorePlatform.instance;
    final store = _FailingStore(await original.getAll());
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() => SharedPreferencesStorePlatform.instance = original);
    final before = await settingsRecord();
    final target = await settingsRecord({
      'themeMode': 'dark',
      'diaryLocationPrecisionRaw': 'city',
    });
    final mood = SyncRecord(const SyncKey(SyncEntity.dayMood, '2026-02-02'), {
      SyncFacet.main: {'mood': 'good', 'updatedAt': 1700000000000},
    });
    final result = await rig.applier.apply(
      await rig.planFor([target, mood], settings: capture()),
      includeSettings: true,
    );

    expect(store.failed, isTrue);
    expect(result.skipped, [
      const SyncApplySkip(settingsKey, SyncSkipReason.settingsFailed),
    ]);
    expect(settings.themeModeNotifier.value, isNot(ThemeMode.dark));
    expect(result.manifest![settingsKey], before.hashes);
    expect(result.manifest!.containsKey(mood.key), isTrue);
  });

  test('背景图从暂存目录就位，设置里还原成文件名', () async {
    final appSurface = jsonEncode({
      'v': 1,
      'global': {'kind': 'image', 'image': 'bg_9.jpg'},
    });
    final captured = {...capture().values, 'appSurfaceRaw': appSurface};
    final target = syncSettingsRecord(captured);
    expect(target.mediaKeys, {'app_backgrounds/bg_9.jpg'});
    final staging = SyncMediaStaging(
      dataRoot: device.dataRoot,
      sessionId: 'bg',
      index: rig.index,
    );
    final bytes = [1, 2, 3, 4];
    await staging.receive(
      'app_backgrounds/bg_9.jpg',
      Stream.value(bytes),
      size: bytes.length,
      sha256:
          '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    );
    final result = await applySettings(target, staging: staging);

    expect(result.skipped, isEmpty);
    final file = File(
      p.join(device.dataRoot.path, 'app_backgrounds', 'bg_9.jpg'),
    );
    expect(await file.readAsBytes(), bytes);
    expect(jsonDecode(settings.appSurfaceRaw!)['global']['image'], 'bg_9.jpg');
    expect((await settingsRecord()).hashes, target.hashes);
  });
}

/// 写到地址精度那个键时失败（`restore` 里靠后的一个键：此前的设置都已改写，
/// 才能检验整体回滚）。
class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(super.data) : super.withData();

  bool failed = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!failed && key.endsWith('diary_location_precision')) {
      failed = true;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
