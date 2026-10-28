import '../../../core/services/settings_service.dart';
import '../../explore/models/explore_appearance.dart';
import '../../explore/models/explore_layout.dart';
import '../../explore/models/explore_layout_code.dart';
import '../../explore/models/explore_module_config.dart';
import '../../explore/models/explore_module_id.dart';
import '../../explore/models/explore_option_spec.dart';
import '../../explore/models/explore_period.dart';
import '../../explore/models/explore_presets.dart';
import '../../explore/models/explore_settings.dart';
import '../../explore/providers/explore_settings_provider.dart';
import 'style_editor_controller.dart';

/// 探索页自定义（`ExploreLayoutPage`）的业务编排。
///
/// 输入：设置服务（读写 `exploreLayoutRaw`）；输出：当前布局、统计范围、预览
/// 明暗与预览数据来源，以及显隐、排序、宽度、卡片选项、外观、预设、我的
/// 布局与布局码等动作（通用部分见 [StyleEditorController]）。副作用：写入
/// 设置（[saveExploreSettings]，全为默认时删除键）。
///
/// 写入时机与其他样式编辑页一致：开关、单选、排序松手即写入，探索页随之
/// 生效；圆角滑块拖动中只改草稿（[previewAppearance]），松手才写入。统计
/// 范围属于行为，不进预设与布局码，单独经 [setPeriod] 写入；“重置”回到默认
/// 布局但保留统计范围。
class ExploreLayoutEditorController
    extends StyleEditorController<ExploreLayout, ExploreSettings> {
  ExploreLayoutEditorController({required this.settingsService})
    : super(
        rawNotifier: settingsService.exploreLayoutRawNotifier,
        decode: ExploreSettings.decode,
        persist: (ExploreSettings value) =>
            saveExploreSettings(settingsService, value),
        codeFormat: ExploreLayoutCode.format,
        defaultStyle: ExploreLayout.defaults,
      );

  final SettingsService settingsService;

  bool _useSamples = false;

  /// 预览用示例数据（而不是自己的日记）。只在本页内存里。
  bool get useSamples => _useSamples;

  set useSamples(bool value) {
    if (value == _useSamples) return;
    _useSamples = value;
    notify();
  }

  ExplorePeriod get period => settings.behavior.period;

  /// 当前布局正好是哪套内置布局；都不是时为 null。
  ExplorePreset? get matchingPreset => ExplorePreset.matching(style);

  /// 套用内置布局（保留外观）；返回此前的布局供撤销。
  Future<ExploreLayout> applyPreset(ExplorePreset preset) =>
      applyStyle(preset.applyTo(style));

  Future<void> setModule(ExploreModuleConfig config) =>
      commit(style.withModule(config));

  Future<void> setVisible(ExploreModuleId id, bool visible) =>
      setModule(style.module(id).copyWith(visible: visible));

  Future<void> setSpan(ExploreModuleId id, ExploreModuleSpan span) =>
      setModule(style.module(id).copyWith(span: span));

  Future<void> setOption(
    ExploreModuleId id,
    ExploreOptionSpec option,
    Object value,
  ) => setModule(style.module(id).withOption(option, value));

  /// 已知卡片列表里第 [oldIndex] 张移到 [newIndex]（移除后的位置）。
  Future<void> moveModule(int oldIndex, int newIndex) =>
      commit(style.moveModule(oldIndex, newIndex));

  Future<void> setShowPeriodBar(bool value) =>
      commit(style.copyWith(showPeriodBar: value));

  Future<void> setAppearance(ExploreAppearance appearance) =>
      commit(style.copyWith(appearance: appearance));

  /// 滑块拖动中的即时预览，不写盘。
  void previewAppearance(ExploreAppearance appearance) =>
      preview(style.copyWith(appearance: appearance));

  Future<void> setPeriod(ExplorePeriod value) =>
      save(settings.withBehavior(settings.behavior.copyWith(period: value)));
}
