import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_features_legacy.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'app.settings.app_features';
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addAnniversary() => db.createAnniversary(
    title: '在一起',
    baseDate: DateTime(2020, 5, 23),
    recurrence: AnniversaryRecurrence.solarYearly,
  );

  Future<SettingsService> settingsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SettingsService.create();
  }

  test('an upgraded user who already has anniversaries keeps them', () async {
    final settings = await settingsWith(<String, Object>{});
    await addAnniversary();

    await keepLegacyAnniversariesVisible(database: db, settings: settings);

    final features = AppFeatures.decode(settings.appFeaturesRaw);
    expect(features.anniversariesEnabled, isTrue);
    expect(features.copyWith(anniversaries: false), AppFeatures.defaults);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), settings.appFeaturesRaw);
  });

  test('without anniversaries the new default stays off', () async {
    final settings = await settingsWith(<String, Object>{});

    await keepLegacyAnniversariesVisible(database: db, settings: settings);

    expect(settings.appFeaturesRaw, isNull);
    expect(AppFeatures.decode(settings.appFeaturesRaw).anniversaries, isFalse);
  });

  test('a saved choice is left alone, even with anniversaries', () async {
    // 用户自己关掉纪念日（与默认相同，也整份落盘），之后的启动不会重新打开。
    final settings = await settingsWith(<String, Object>{
      key: AppFeatures.defaults.encode(),
    });
    await addAnniversary();

    await keepLegacyAnniversariesVisible(database: db, settings: settings);

    expect(settings.appFeaturesRaw, AppFeatures.defaults.encode());
    expect(AppFeatures.decode(settings.appFeaturesRaw).anniversaries, isFalse);
  });

  test('a choice saved by an older version is kept as stored', () async {
    // 老版本关掉过别的功能时整份落盘，纪念日那一项一定在里面。
    final raw = const AppFeatures(explore: false, anniversaries: true).encode();
    final settings = await settingsWith(<String, Object>{key: raw});
    await addAnniversary();

    await keepLegacyAnniversariesVisible(database: db, settings: settings);

    expect(settings.appFeaturesRaw, raw);
  });
}
