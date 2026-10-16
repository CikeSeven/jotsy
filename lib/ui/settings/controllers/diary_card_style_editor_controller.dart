import '../../../core/services/settings_service.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../diaries/models/diary_card_style/diary_card_style_code.dart';
import '../../diaries/models/diary_card_style/diary_card_style_presets.dart';
import '../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../../diaries/providers/diary_card_style_provider.dart';
import 'style_editor_controller.dart';

/// 日记卡片样式编辑页的业务编排。
///
/// 输入：设置服务（读写 `diaryCardStyleRaw` 与独立的标签上限）；输出：当前
/// 样式、预览模式与明暗，以及套用预设、保存/删除“我的样式”、样式码导入
/// 导出等动作（通用部分见 [StyleEditorController]）。副作用：写入设置（经
/// [saveDiaryCardStyleSettings]，与默认相同时删除键）。
class DiaryCardStyleEditorController
    extends StyleEditorController<DiaryCardStyle, DiaryCardStyleSettings> {
  DiaryCardStyleEditorController({
    required this.settingsService,
    DiaryCardMode initialMode = DiaryCardMode.list,
  }) : _mode = initialMode,
       _tagLimit = settingsService.diaryCardTagLimit,
       super(
         rawNotifier: settingsService.diaryCardStyleRawNotifier,
         decode: DiaryCardStyleSettings.decode,
         persist: (DiaryCardStyleSettings value) =>
             saveDiaryCardStyleSettings(settingsService, value),
         codeFormat: DiaryCardStyleCode.format,
         defaultStyle: DiaryCardStyle.defaults,
       ) {
    settingsService.diaryCardTagLimitNotifier.addListener(_syncTagLimit);
  }

  final SettingsService settingsService;

  DiaryCardMode _mode;
  int _tagLimit;

  /// 正在编辑（也正在预览）的布局模式；“专属”分组改的就是它。
  DiaryCardMode get mode => _mode;
  DiaryCardModeStyle get modeStyle => style.mode(_mode);

  /// 卡片标签显示上限（独立的旧设置，预览同步使用）。
  int get tagLimit => _tagLimit;

  /// 当前样式对应的内置预设；不是任何预设时为 null。
  DiaryCardPresetId? get matchingPreset => DiaryCardPresets.match(style);

  set mode(DiaryCardMode value) {
    if (value == _mode) {
      return;
    }
    _mode = value;
    notify();
  }

  /// 便捷写法：改当前模式的专属样式。
  Future<void> commitMode(
    DiaryCardModeStyle Function(DiaryCardModeStyle current) update,
  ) => commit(style.withMode(_mode, update(modeStyle)));

  void previewMode(
    DiaryCardModeStyle Function(DiaryCardModeStyle current) update,
  ) => preview(style.withMode(_mode, update(modeStyle)));

  /// 套用内置预设；返回此前的样式供撤销。
  Future<DiaryCardStyle> applyPreset(DiaryCardPresetId id) =>
      applyStyle(DiaryCardPresets.styleOf(id));

  Future<void> setTagLimit(int value) async {
    _tagLimit = value;
    notify();
    await settingsService.setDiaryCardTagLimit(value);
  }

  void _syncTagLimit() {
    final next = settingsService.diaryCardTagLimit;
    if (next == _tagLimit) {
      return;
    }
    _tagLimit = next;
    notify();
  }

  @override
  void dispose() {
    settingsService.diaryCardTagLimitNotifier.removeListener(_syncTagLimit);
    super.dispose();
  }
}
