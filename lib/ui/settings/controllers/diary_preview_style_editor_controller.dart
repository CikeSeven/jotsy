import '../../../core/services/settings_service.dart';
import '../../diaries/models/diary_preview_style/diary_preview_behavior.dart';
import '../../diaries/models/diary_preview_style/diary_preview_presets.dart';
import '../../diaries/models/diary_preview_style/diary_preview_settings.dart';
import '../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../diaries/models/diary_preview_style/diary_preview_style_code.dart';
import '../../diaries/providers/diary_preview_style_provider.dart';
import 'style_editor_controller.dart';

/// 日记预览页样式编辑页的业务编排。
///
/// 输入：设置服务（读写 `diaryPreviewStyleRaw`）；输出：当前样式、阅读行为与
/// 预览明暗，以及套用预设、我的样式、样式码等动作（通用部分见
/// [StyleEditorController]）。副作用：写入设置（经 [saveDiaryPreviewSettings]，
/// 与默认相同时删除键）。阅读行为不进预设与样式码，单独经 [setBehavior]
/// 写入，与外观同存一个键。
class DiaryPreviewStyleEditorController
    extends StyleEditorController<DiaryPreviewStyle, DiaryPreviewSettings> {
  DiaryPreviewStyleEditorController({required this.settingsService})
    : super(
        rawNotifier: settingsService.diaryPreviewStyleRawNotifier,
        decode: DiaryPreviewSettings.decode,
        persist: (DiaryPreviewSettings value) =>
            saveDiaryPreviewSettings(settingsService, value),
        codeFormat: DiaryPreviewStyleCode.format,
        defaultStyle: DiaryPreviewStyle.defaults,
      );

  final SettingsService settingsService;

  DiaryPreviewBehavior get behavior => settings.behavior;

  /// 当前样式对应的内置预设；不是任何预设时为 null。
  DiaryPreviewPresetId? get matchingPreset => DiaryPreviewPresets.match(style);

  /// 套用内置预设；返回此前的样式供撤销。阅读行为保持不变。
  Future<DiaryPreviewStyle> applyPreset(DiaryPreviewPresetId id) =>
      applyStyle(DiaryPreviewPresets.styleOf(id));

  /// 便捷写法：基于当前样式（含拖动中的草稿）改出新样式并写入。
  Future<void> commitWith(
    DiaryPreviewStyle Function(DiaryPreviewStyle current) update,
  ) => commit(update(style));

  /// 便捷写法：滑块拖动中的即时预览。
  void previewWith(
    DiaryPreviewStyle Function(DiaryPreviewStyle current) update,
  ) => preview(update(style));

  Future<void> setBehavior(DiaryPreviewBehavior next) =>
      save(settings.withBehavior(next));
}
