import '../../../core/services/settings_service.dart';
import '../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../diaries/providers/diary_code_block_style_provider.dart';
import 'style_draft_controller.dart';

/// 代码块样式编辑页的业务编排。
///
/// 输入：设置服务（读写 `diaryCodeBlockStyleRaw`）；输出：当前样式与预览明暗，
/// 以及预览、提交与重置动作（见 [StyleDraftController]）。没有“我的样式”与
/// 样式码：设置本身就是样式。副作用：写入设置（经
/// [saveDiaryCodeBlockStyle]，与默认相同时删除键）。
class DiaryCodeBlockStyleEditorController
    extends StyleDraftController<DiaryCodeBlockStyle, DiaryCodeBlockStyle> {
  DiaryCodeBlockStyleEditorController({required this.settingsService})
    : super(
        rawNotifier: settingsService.diaryCodeBlockStyleRawNotifier,
        decode: DiaryCodeBlockStyle.decode,
        persist: (DiaryCodeBlockStyle value) =>
            saveDiaryCodeBlockStyle(settingsService, value),
        currentOf: _identity,
        withCurrent: _replace,
        defaultStyle: DiaryCodeBlockStyle.defaults,
      );

  final SettingsService settingsService;

  static DiaryCodeBlockStyle _identity(DiaryCodeBlockStyle value) => value;

  static DiaryCodeBlockStyle _replace(
    DiaryCodeBlockStyle value,
    DiaryCodeBlockStyle style,
  ) => style;

  /// 便捷写法：基于当前样式（含拖动中的草稿）改出新样式并写入。
  Future<void> commitWith(
    DiaryCodeBlockStyle Function(DiaryCodeBlockStyle current) update,
  ) => commit(update(style));

  /// 便捷写法：滑块拖动中的即时预览。
  void previewWith(
    DiaryCodeBlockStyle Function(DiaryCodeBlockStyle current) update,
  ) => preview(update(style));
}
