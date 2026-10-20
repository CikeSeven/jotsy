import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/settings/controllers/diary_code_block_style_editor_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late DiaryCodeBlockStyleEditorController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    controller = DiaryCodeBlockStyleEditorController(settingsService: settings);
  });

  tearDown(() => controller.dispose());

  DiaryCodeBlockStyle stored() =>
      DiaryCodeBlockStyle.decode(settings.diaryCodeBlockStyleRaw);

  test('preview updates the draft without persisting', () {
    var notified = 0;
    controller.addListener(() => notified++);

    controller.previewWith((s) => s.copyWith(fontScale: 1.2));

    expect(controller.style.fontScale, 1.2);
    expect(settings.diaryCodeBlockStyleRaw, isNull);
    expect(notified, 1);
  });

  test('commit persists and drops the draft', () async {
    controller.previewWith((s) => s.copyWith(radius: 20));
    await controller.commitWith(
      (s) => s.copyWith(theme: DiaryCodeThemeId.nord),
    );

    // 提交基于含草稿的当前样式：拖动中的值随之写入。
    expect(stored().theme, DiaryCodeThemeId.nord);
    expect(stored().radius, 20);
    expect(controller.style, stored());
  });

  test('reset returns the previous style for undo', () async {
    const custom = DiaryCodeBlockStyle(
      theme: DiaryCodeThemeId.dracula,
      lineNumbers: false,
    );
    await controller.commit(custom);
    expect(stored(), custom);

    final previous = await controller.reset();
    expect(previous, custom);
    expect(controller.style, DiaryCodeBlockStyle.defaults);
    // 默认样式：键被删除。
    expect(settings.diaryCodeBlockStyleRaw, isNull);

    await controller.applyStyle(previous);
    expect(stored(), custom);
  });

  test('an external raw change syncs and drops the draft', () async {
    controller.previewWith((s) => s.copyWith(lineHeight: 2));
    expect(controller.style.lineHeight, 2);

    const restored = DiaryCodeBlockStyle(theme: DiaryCodeThemeId.gruvbox);
    await settings.setDiaryCodeBlockStyleRaw(restored.encode());

    expect(controller.style, restored);
    expect(controller.style.lineHeight, DiaryCodeBlockStyle.defaultLineHeight);
  });

  test('preview brightness only notifies on change', () {
    var notified = 0;
    controller.addListener(() => notified++);
    controller.previewBrightness = Brightness.dark;
    controller.previewBrightness = Brightness.dark;
    expect(controller.previewBrightness, Brightness.dark);
    expect(notified, 1);
  });
}
