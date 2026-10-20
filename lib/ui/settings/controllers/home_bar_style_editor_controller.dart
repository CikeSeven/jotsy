import '../../../core/services/settings_service.dart';
import '../../home/models/home_bar_style/home_bar_behavior.dart';
import '../../home/models/home_bar_style/home_bar_presets.dart';
import '../../home/models/home_bar_style/home_bar_settings.dart';
import '../../home/models/home_bar_style/home_bar_style.dart';
import '../../home/models/home_bar_style/home_bar_style_code.dart';
import '../../home/providers/home_bar_settings_provider.dart';
import 'style_editor_controller.dart';

/// 导航栏（首页底栏与四个 Tab 的顶栏）样式编辑页的业务编排。
///
/// 输入：设置服务（读写 `homeBarStyleRaw`）；输出：当前样式、栏的行为与预览
/// 明暗，以及套用预设、我的样式、样式码等动作（通用部分见
/// [StyleEditorController]）。副作用：写入设置（经 [saveHomeBarSettings]，与
/// 默认相同时删除键）。栏的行为（下滑收起、指示器跟随）不进预设与样式码，
/// 单独经 [setBehavior] 写入，与外观同存一个键。
class HomeBarStyleEditorController
    extends StyleEditorController<HomeBarStyle, HomeBarSettings> {
  HomeBarStyleEditorController({required this.settingsService})
    : super(
        rawNotifier: settingsService.homeBarStyleRawNotifier,
        decode: HomeBarSettings.decode,
        persist: (HomeBarSettings value) =>
            saveHomeBarSettings(settingsService, value),
        codeFormat: HomeBarStyleCode.format,
        defaultStyle: HomeBarStyle.defaults,
      );

  final SettingsService settingsService;

  HomeBarBehavior get behavior => settings.behavior;

  /// 当前样式对应的内置预设；不是任何预设时为 null。
  HomeBarPreset? get matchingPreset => HomeBarPreset.matching(style);

  /// 套用内置预设；返回此前的样式供撤销。栏的行为保持不变。
  Future<HomeBarStyle> applyPreset(HomeBarPreset preset) =>
      applyStyle(preset.style);

  /// 便捷写法：基于当前样式（含拖动中的草稿）改出新样式并写入。
  Future<void> commitWith(HomeBarStyle Function(HomeBarStyle current) update) =>
      commit(update(style));

  /// 便捷写法：滑块拖动中的即时预览，不写盘。
  void previewWith(HomeBarStyle Function(HomeBarStyle current) update) =>
      preview(update(style));

  Future<void> setBehavior(HomeBarBehavior next) =>
      save(settings.withBehavior(next));
}
