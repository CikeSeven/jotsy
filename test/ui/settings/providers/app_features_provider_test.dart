import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stored = AppFeatures(calendar: false, templates: false);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.app_features': stored.encode()!,
    });
  });

  ProviderContainer containerFor(SettingsService settings) {
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'gives defaults while settings load, then the stored toggles at once',
    () async {
      final settings = await SettingsService.create();
      final container = containerFor(settings);

      expect(container.read(appFeaturesProvider), AppFeatures.defaults);
      await container.read(settingsServiceProvider.future);
      expect(container.read(appFeaturesProvider), stored);
    },
  );

  test('follows writes and ignores identical ones', () async {
    final settings = await SettingsService.create();
    final container = containerFor(settings);
    await container.read(settingsServiceProvider.future);
    final seen = <AppFeatures>[];
    container.listen<AppFeatures>(
      appFeaturesProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );

    const next = AppFeatures(explore: false);
    await saveAppFeatures(settings, next);
    expect(container.read(appFeaturesProvider), next);

    // 同一组开关换种写法（键序不同）：解码相等，不应再通知。
    await settings.setAppFeaturesRaw(
      '{"timeCapsules":true,"explore":false,"calendar":true}',
    );
    expect(seen, <AppFeatures>[stored, next]);

    await saveAppFeatures(settings, AppFeatures.defaults);
    expect(settings.appFeaturesRaw, isNull);
    expect(container.read(appFeaturesProvider), AppFeatures.defaults);
  });
}
