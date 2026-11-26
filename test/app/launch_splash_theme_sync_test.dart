import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/launch_splash_theme.dart';
import 'package:node_diary/app/launch_splash_theme_sync.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 建好容器并开始监听，返回原生通道收到的档位（`null` = 默认主题）。
Future<(SettingsService, List<int?>)> _start({
  Map<String, Object> preferences = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final settings = await SettingsService.create();
  final sent = <int?>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(launchSplashThemeChannel, (call) async {
    expect(call.method, 'apply');
    sent.add((call.arguments as Map<Object?, Object?>)['index'] as int?);
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(launchSplashThemeChannel, null),
  );
  final container = ProviderContainer(
    overrides: [settingsServiceProvider.overrideWith((ref) async => settings)],
  );
  addTearDown(container.dispose);
  container.listen(launchSplashThemeSyncProvider, (_, _) {});
  await container.read(settingsServiceProvider.future);
  await pumpEventQueue();
  return (settings, sent);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pink = Color(0xFFD81B60);

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'the theme color reaches the native splash once settings load',
    () async {
      final (_, sent) = await _start(
        preferences: <String, Object>{
          'app.settings.theme_seed_color_value': pink.toARGB32(),
        },
      );
      // 升级上来、或在别处改过主题色的用户：读到设置就同步，下次启动即生效。
      expect(sent, <int?>[LaunchSplashTheme.indexFor(pink)]);
    },
  );

  test('only a change of splash slot is sent to native', () async {
    final (settings, sent) = await _start();
    // 默认主题色也要发一次：回到清单里的启动主题。
    expect(sent, <int?>[null]);

    await settings.setThemeSeedColor(pink);
    await pumpEventQueue();
    expect(sent, <int?>[null, LaunchSplashTheme.indexFor(pink)]);

    // 同一档里的另一个颜色：系统闪屏画法不变，不再打扰原生。
    final sameSlot = LaunchSplashTheme.seedFor(
      LaunchSplashTheme.indexFor(pink)!,
    );
    expect(sameSlot, isNot(pink));
    await settings.setThemeSeedColor(sameSlot);
    await pumpEventQueue();
    expect(sent, hasLength(2));

    await settings.setThemeSeedColor(
      const Color(SettingsService.defaultThemeSeedColorValue),
    );
    await pumpEventQueue();
    expect(sent, <int?>[null, LaunchSplashTheme.indexFor(pink), null]);
  });

  test('platforms without a system splash never call native', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final (settings, sent) = await _start();
    await settings.setThemeSeedColor(pink);
    await pumpEventQueue();
    expect(sent, isEmpty);
  });
}
