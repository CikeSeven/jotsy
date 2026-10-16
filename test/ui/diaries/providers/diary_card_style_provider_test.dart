import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/diaries/providers/diary_card_style_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rounded = DiaryCardStyle(
  surface: DiaryCardSurfaceStyle(cornerRadius: 10),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_card_style': DiaryCardStyleSettings.defaults
          .withCurrent(_rounded)
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

      expect(container.read(diaryCardStyleProvider), DiaryCardStyle.defaults);
      await container.read(settingsServiceProvider.future);
      // 同步 provider：settings 就绪后的第一次读取就是存储的样式，没有
      // loading 帧，日记页首帧不会先画默认样式。
      expect(container.read(diaryCardStyleProvider), _rounded);
    },
  );

  test(
    'follows writes, ignores identical ones and detaches on dispose',
    () async {
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      await container.read(settingsServiceProvider.future);
      final seen = <DiaryCardStyle>[];
      container.listen<DiaryCardStyle>(
        diaryCardStyleProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      final saved = DiaryCardStyleSettings.defaults
          .withCurrent(_rounded)
          .addSaved('A', _rounded);
      // 只多了一份“我的样式”，当前样式没变：列表不应收到通知。
      await saveDiaryCardStyleSettings(settings, saved);
      expect(container.read(diaryCardStyleSettingsProvider), saved);
      // 派生 provider 在读取（或下一帧）时才重算，读取后再检查通知记录。
      expect(container.read(diaryCardStyleProvider), _rounded);
      expect(seen, <DiaryCardStyle>[_rounded]);

      await saveDiaryCardStyleSettings(
        settings,
        DiaryCardStyleSettings.defaults,
      );
      expect(settings.diaryCardStyleRaw, isNull);
      expect(container.read(diaryCardStyleProvider), DiaryCardStyle.defaults);
      expect(seen, <DiaryCardStyle>[_rounded, DiaryCardStyle.defaults]);

      container.dispose();
      // 监听已解除：容器销毁后的写入不会访问已释放的 provider。
      await settings.setDiaryCardStyleRaw(saved.encode());
      expect(seen, hasLength(2));
    },
  );
}
