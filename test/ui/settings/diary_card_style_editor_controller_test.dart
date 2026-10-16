import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_code.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/settings/controllers/diary_card_style_editor_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rounded = DiaryCardStyle(
  surface: DiaryCardSurfaceStyle(cornerRadius: 9),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late DiaryCardStyleEditorController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    controller = DiaryCardStyleEditorController(settingsService: settings);
  });

  tearDown(() => controller.dispose());

  DiaryCardStyle stored() =>
      DiaryCardStyleSettings.decode(settings.diaryCardStyleRaw).current;

  test(
    'preview updates the draft without persisting; commit persists',
    () async {
      controller.preview(_rounded);
      expect(controller.style, _rounded);
      expect(settings.diaryCardStyleRaw, isNull);

      await controller.commit(_rounded);
      expect(stored(), _rounded);
      expect(controller.style, _rounded);
    },
  );

  test('mode edits only touch the layout being previewed', () async {
    controller.mode = DiaryCardMode.waterfall;
    await controller.commitMode((m) => m.copyWith(columns: 3));
    expect(stored().waterfall.columns, 3);
    expect(stored().list, DiaryCardModeStyle.listDefaults);
  });

  test('presets, reset and undo', () async {
    final before = await controller.applyPreset(DiaryCardPresetId.magazine);
    expect(before, DiaryCardStyle.defaults);
    expect(controller.matchingPreset, DiaryCardPresetId.magazine);
    expect(stored(), DiaryCardPresets.styleOf(DiaryCardPresetId.magazine));

    final previous = await controller.reset();
    expect(previous, DiaryCardPresets.styleOf(DiaryCardPresetId.magazine));
    // 默认样式且没有保存项：键被删除。
    expect(settings.diaryCardStyleRaw, isNull);

    await controller.applyStyle(previous);
    expect(controller.matchingPreset, DiaryCardPresetId.magazine);
  });

  test('saved styles can be saved, renamed, deleted and restored', () async {
    await controller.commit(_rounded);
    expect(await controller.saveCurrentAs('圆角'), isTrue);
    final saved = controller.settings.saved.single;
    expect(saved.style, _rounded);
    expect(controller.matchingSaved?.id, saved.id);

    await controller.renameSaved(saved.id, '小圆角');
    expect(controller.settings.saved.single.name, '小圆角');

    final removed = await controller.deleteSaved(saved.id);
    expect(controller.settings.saved, isEmpty);
    await controller.restoreSaved(removed!.$1, removed.$2);
    expect(
      DiaryCardStyleSettings.decode(
        settings.diaryCardStyleRaw,
      ).saved.single.name,
      '小圆角',
    );
  });

  test(
    'style codes export and import, keeping invalid input harmless',
    () async {
      await controller.commit(_rounded);
      final code = controller.exportCode();
      await controller.reset();

      final (result, previous) = await controller.importCode('看看 $code');
      expect(result.status, StyleCodeStatus.ok);
      expect(previous, DiaryCardStyle.defaults);
      expect(stored(), _rounded);

      final (invalid, untouched) = await controller.importCode('nope');
      expect(invalid.status, StyleCodeStatus.invalid);
      expect(untouched, isNull);
      expect(stored(), _rounded);
    },
  );

  test('external changes (e.g. a restore) replace the draft', () async {
    var notified = 0;
    controller.addListener(() => notified++);
    controller.preview(_rounded);
    await settings.setDiaryCardStyleRaw(
      DiaryCardStyleSettings.defaults
          .withCurrent(
            const DiaryCardStyle(
              surface: DiaryCardSurfaceStyle(cornerRadius: 30),
            ),
          )
          .encode(),
    );
    expect(controller.style.surface.cornerRadius, 30);
    expect(notified, greaterThanOrEqualTo(2));

    await settings.setDiaryCardTagLimit(5);
    expect(controller.tagLimit, 5);
  });
}
