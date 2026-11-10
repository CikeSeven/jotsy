import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/providers/home_bar_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 与默认不同的样式（默认样式编码为空，读不出“存储的样式”）。
const _custom = HomeBarStyle(blurSigma: 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.home_bar_style': HomeBarSettings.defaults
          .withCurrent(_custom)
          .encode()!,
    });
  });

  test(
    'gives defaults while settings load, then the stored style at once',
    () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(homeBarStyleProvider), HomeBarStyle.defaults);
      await container.read(settingsServiceProvider.future);
      // 同步 provider：settings 就绪后的第一次读取就是存储的样式，没有
      // loading 帧，首页底栏不会先画一帧默认样式再跳成存储的样式。
      expect(container.read(homeBarStyleProvider), _custom);
    },
  );

  test(
    'follows writes, ignores identical styles and detaches on dispose',
    () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      await container.read(settingsServiceProvider.future);
      final seen = <HomeBarStyle>[];
      container.listen<HomeBarStyle>(
        homeBarStyleProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      final changed = HomeBarSettings.defaults
          .withCurrent(_custom)
          .addSaved('A', _custom)
          .withBehavior(const HomeBarBehavior(hideOnScroll: true));
      // 只多了一份“我的样式”与行为变化，外观没变：栏不应收到通知。
      await saveHomeBarSettings(settings, changed);
      expect(container.read(homeBarSettingsProvider), changed);
      expect(container.read(homeBarBehaviorProvider).hideOnScroll, isTrue);
      expect(container.read(homeBarStyleProvider), _custom);
      expect(seen, <HomeBarStyle>[_custom]);

      await saveHomeBarSettings(settings, HomeBarSettings.defaults);
      expect(settings.homeBarStyleRaw, isNull);
      expect(container.read(homeBarStyleProvider), HomeBarStyle.defaults);
      expect(seen, <HomeBarStyle>[_custom, HomeBarStyle.defaults]);

      container.dispose();
      // 监听已解除：容器销毁后的写入不会访问已释放的 provider。
      await settings.setHomeBarStyleRaw(changed.encode());
      expect(seen, hasLength(2));
    },
  );
}
