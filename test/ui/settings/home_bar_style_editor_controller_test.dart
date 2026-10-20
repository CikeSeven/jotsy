import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/settings/controllers/home_bar_style_editor_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late HomeBarStyleEditorController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    controller = HomeBarStyleEditorController(settingsService: settings);
  });

  tearDown(() => controller.dispose());

  HomeBarSettings stored() => HomeBarSettings.decode(settings.homeBarStyleRaw);

  test('previewWith changes the draft without persisting', () {
    controller.previewWith((s) => s.copyWith(barHeight: 70));
    expect(controller.style.barHeight, 70);
    expect(settings.homeBarStyleRaw, isNull);
  });

  test('commitWith writes on top of the current draft', () async {
    controller.previewWith((s) => s.copyWith(barHeight: 70));
    await controller.commitWith(
      (s) => s.copyWith(material: HomeBarMaterial.glass),
    );
    expect(stored().current.barHeight, 70);
    expect(stored().current.material, HomeBarMaterial.glass);
    expect(controller.style, stored().current);
  });

  test('setBehavior persists apart from the look', () async {
    await controller.setBehavior(
      const HomeBarBehavior(hideOnScroll: true, indicatorFollowsSwipe: true),
    );
    expect(stored().behavior.hideOnScroll, isTrue);
    expect(stored().behavior.indicatorFollowsSwipe, isTrue);
    expect(stored().current, HomeBarStyle.defaults);
    expect(controller.behavior, stored().behavior);
  });

  test('applyPreset returns the previous style and keeps behavior', () async {
    await controller.setBehavior(const HomeBarBehavior(hideOnScroll: true));
    final previous = await controller.applyPreset(HomeBarPreset.frosted);
    expect(previous, HomeBarStyle.defaults);
    expect(stored().current, HomeBarPreset.frosted.style);
    expect(controller.matchingPreset, HomeBarPreset.frosted);
    expect(stored().behavior.hideOnScroll, isTrue);

    final again = await controller.applyPreset(HomeBarPreset.classic);
    expect(again, HomeBarPreset.frosted.style);
    expect(controller.matchingPreset, HomeBarPreset.classic);
    expect(stored().behavior.hideOnScroll, isTrue);
  });
}
