import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
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

  /// 本机现在的设置记录，[changes] 覆盖其中的分面值。
  Future<SyncRecord> settingsRecord([
    Map<String, Object?> changes = const {},
  ]) async {
    final current = (await rig.records(
      settings: syncCaptureSettings(settings),
    ))[settingsKey]!;
    return SyncRecord(settingsKey, {
      ...current.facets,
      for (final entry in changes.entries) entry.key: {'value': entry.value},
    });
  }

  Future<SyncApplyResult> applySettings(
    SyncRecord target, {
    SyncMediaStaging? staging,
  }) async => rig.applier.apply(
    await rig.planFor([target], settings: syncCaptureSettings(settings)),
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
      kSyncTagOrderNamesFacet: <String>[],
    });
    final result = await applySettings(target);

    expect(result.skipped, isEmpty);
    expect(settings.diaryToolbarOrderRaw, isNull);
    expect(settings.tagPickerSortRaw, isNull);
    expect(settings.diaryLocationPrecisionRaw, isNull);
    expect(decodeTagOrder(settings.tagOrderRaw), isEmpty);
    expect(settings.createDiaryDraftRaw, 'not json {');
    expect((await settingsRecord()).hashes, target.hashes);
  });

  test('按名称的标签顺序换回本机 id', () async {
    final target = await settingsRecord({
      kSyncTagOrderNamesFacet: ['beta', 'alpha', 'missing'],
    });
    await applySettings(target);
    expect(decodeTagOrder(settings.tagOrderRaw), [
      tagIds['beta'],
      tagIds['alpha'],
    ]);
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
      await rig.planFor([
        target,
        mood,
      ], settings: syncCaptureSettings(settings)),
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
    final captured = {
      ...syncCaptureSettings(settings),
      'appSurfaceRaw': appSurface,
    };
    final target = syncSettingsRecord(captured, {
      for (final entry in tagIds.entries) entry.value: entry.key,
    });
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
