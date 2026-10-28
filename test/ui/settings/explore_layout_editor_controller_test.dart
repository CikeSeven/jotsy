import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/explore/models/explore_appearance.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_module_options.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/models/explore_presets.dart';
import 'package:node_diary/ui/explore/models/explore_settings.dart';
import 'package:node_diary/ui/settings/controllers/explore_layout_editor_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsService settings;
  late ExploreLayoutEditorController controller;

  ExploreSettings stored() => ExploreSettings.decode(settings.exploreLayoutRaw);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    controller = ExploreLayoutEditorController(settingsService: settings);
  });
  tearDown(() => controller.dispose());

  test('visibility, span, options and order are written at once', () async {
    await controller.setVisible(ExploreModuleId.greeting, false);
    await controller.setSpan(ExploreModuleId.heatmap, ExploreModuleSpan.half);
    await controller.setOption(
      ExploreModuleId.heatmap,
      ExploreOptions.heatmapBasis,
      ExploreHeatBasis.mood.name,
    );
    await controller.moveModule(0, 3);
    final layout = stored().current;
    expect(layout.module(ExploreModuleId.greeting).visible, isFalse);
    expect(layout.module(ExploreModuleId.heatmap).span, ExploreModuleSpan.half);
    expect(
      layout
          .module(ExploreModuleId.heatmap)
          .choice(ExploreOptions.heatmapBasis),
      ExploreHeatBasis.mood,
    );
    expect(layout.modules[3].id, ExploreModuleId.greeting);
  });

  test(
    'presets keep the appearance and undo restores the old layout',
    () async {
      const look = ExploreAppearance(density: ExploreDensity.relaxed);
      await controller.setAppearance(look);
      final previous = await controller.applyPreset(ExplorePreset.dataLover);
      expect(controller.matchingPreset, ExplorePreset.dataLover);
      expect(stored().current.appearance, look);
      await controller.applyStyle(previous);
      expect(
        stored().current,
        ExploreLayout.defaults.copyWith(appearance: look),
      );
    },
  );

  test('reset keeps the range and slider drafts are not persisted', () async {
    await controller.setPeriod(ExplorePeriod.week);
    controller.previewAppearance(
      controller.style.appearance.copyWith(radius: 12),
    );
    expect(controller.style.appearance.radius, 12);
    expect(stored().current.appearance.radius, ExploreAppearance.defaultRadius);
    await controller.reset();
    expect(stored().behavior.period, ExplorePeriod.week);
    expect(controller.style.isDefault, isTrue);
  });

  test('saved layouts and layout codes round trip', () async {
    await controller.applyPreset(ExplorePreset.memories);
    expect(await controller.saveCurrentAs('Mine'), isTrue);
    expect(stored().saved.single.name, 'Mine');
    final code = controller.exportCode();
    await controller.reset();
    final (result, _) = await controller.importCode(code);
    expect(result.name, 'Mine');
    expect(controller.matchingPreset, ExplorePreset.memories);
  });
}
