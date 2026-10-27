import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _glass = AppGlassStyle.defaults.withMode(AppGlassMode.glass);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.app_surface': AppSurfaceSettings.defaults
          .withGlass(_glass)
          .encode()!,
    });
  });

  test(
    'gives defaults while settings load, then the stored settings at once',
    () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appGlassStyleProvider), AppGlassStyle.defaults);
      await container.read(settingsServiceProvider.future);
      // 同步 provider：settings 就绪后的第一次读取就是存储的设置，没有
      // loading 帧，不会先画一帧经典材质再跳成玻璃。
      expect(container.read(appGlassStyleProvider), _glass);
    },
  );

  test(
    'follows writes, notifies only the parts that changed and detaches on dispose',
    () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      await container.read(settingsServiceProvider.future);
      final glassSeen = <AppGlassStyle>[];
      final editorSeen = <AppBackground>[];
      container.listen<AppGlassStyle>(
        appGlassStyleProvider,
        (_, next) => glassSeen.add(next),
        fireImmediately: true,
      );
      container.listen<AppBackground>(
        appAreaBackgroundProvider(AppBackgroundArea.editor),
        (_, next) => editorSeen.add(next),
        fireImmediately: true,
      );

      const background = AppBackground(
        kind: AppBackgroundKind.color,
        colorLight: 0xFF102030,
      );
      // 只改了全局背景：材质没变，玻璃组件不应收到通知；编辑页跟随全局。
      final changed = AppSurfaceSettings.defaults
          .withGlass(_glass)
          .withGlobal(background);
      await saveAppSurfaceSettings(settings, changed);
      expect(container.read(appSurfaceSettingsProvider), changed);
      // 派生 provider 在读取时才重算（与首页栏测试相同），先读再看通知。
      expect(container.read(appGlassStyleProvider), _glass);
      expect(
        container.read(appAreaBackgroundProvider(AppBackgroundArea.editor)),
        background,
      );
      expect(glassSeen, <AppGlassStyle>[_glass]);
      expect(editorSeen, <AppBackground>[AppBackground.defaults, background]);

      await saveAppSurfaceSettings(settings, AppSurfaceSettings.defaults);
      expect(settings.appSurfaceRaw, isNull);
      expect(container.read(appGlassStyleProvider), AppGlassStyle.defaults);
      expect(glassSeen, <AppGlassStyle>[_glass, AppGlassStyle.defaults]);

      container.dispose();
      // 监听已解除：容器销毁后的写入不会访问已释放的 provider。
      await settings.setAppSurfaceRaw(changed.encode());
      expect(glassSeen, hasLength(2));
    },
  );
}
