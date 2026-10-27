import 'package:flutter/material.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/sections/diaries_list_section.dart';
import '../../../diaries/sections/diary_head_section.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../../widgets/style_editor/style_preview_background.dart';

/// 卡片样式的实时预览：顶部工具条（[DiaryCardStylePreviewToolbar]）切换列表/
/// 瀑布流与预览明暗，下方用真实的 [DiariesListSection] 渲染示例日记，与日记
/// 列表看到的完全一致。窄屏时工具条由页面单独放在顶部（[showToolbar] 为
/// false），预览区随下方选项面板的拖动伸缩。
///
/// 预览可滚动；点按或长按示例卡片切换选中，便于查看选中态的描边与高亮。
/// 共享元素关闭（`enableCoverHero: false`），避免与真实列表的同名 Hero 冲突。
/// 明暗与应用当前主题相反时，用同一种子色另装配一份主题（按种子色缓存），
/// 减少动画时同样去掉控件动效，与应用外壳一致。
///
/// 卡片叠在日记页区域的背景上（[StylePreviewBackground]，在预览主题之内，
/// 明暗切换时背景遮罩随之切换），而不是设置页的背景上：半透明 / 玻璃卡片
/// 的文字对比度按该区域的估计色计算（[DiariesListSection] 读
/// `AppPageBackdrop.estimatedColorOf`），玻璃卡片在有背景图时共用预览区的
/// `contentBackdropKey` 模糊，调透明度与玻璃时看得出效果。日记页没有背景时
/// 仍铺预览主题的页面底色，与原来相同。
class DiaryCardStylePreview extends StatefulWidget {
  const DiaryCardStylePreview({
    super.key,
    required this.controller,
    required this.samples,
    required this.moodOptions,
    this.showToolbar = true,
    this.bottomPadding = 0,
  });

  final DiaryCardStyleEditorController controller;
  final List<DiaryWithTags> samples;
  final List<String> moodOptions;

  /// 是否在预览上方显示工具条。
  final bool showToolbar;

  /// 列表末尾额外留白：预览底部被面板圆角压住的部分，最后一张示例仍能完整
  /// 滚到可见处。
  final double bottomPadding;

  @override
  State<DiaryCardStylePreview> createState() => _DiaryCardStylePreviewState();
}

class _DiaryCardStylePreviewState extends State<DiaryCardStylePreview> {
  final Set<String> _selected = <String>{};

  void _toggle(String diaryId) {
    setState(() {
      if (!_selected.remove(diaryId)) {
        _selected.add(diaryId);
      }
    });
  }

  ThemeData _themeFor(
    ThemeData appTheme,
    Brightness brightness, {
    required bool reduceMotion,
  }) {
    if (brightness == appTheme.brightness) {
      return appTheme;
    }
    // 应用主题由种子色装配，主色就是种子色派生的；用设置里的种子色重建
    // 另一种明暗，与切换主题模式后看到的一致。缓存返回同一实例：卡片样式
    // 的解析结果以主题实例为键复用。
    return SeededThemeCache.of(
      Color(widget.controller.settingsService.themeSeedColorValue),
      brightness,
      reduceMotion: reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    final previewTheme = _themeFor(
      appTheme,
      brightness,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showToolbar)
          DiaryCardStylePreviewToolbar(controller: controller),
        Expanded(
          child: Theme(
            data: previewTheme,
            child: ClipRect(
              child: StylePreviewBackground(
                child: Builder(
                  builder: (BuildContext context) => Material(
                    // 日记页区域画了背景时透明、露出背景；否则即预览主题的
                    // 页面底色（与原来相同）。
                    color: AppPageBackdrop.pageColorOf(context),
                    child: CustomScrollView(
                      primary: false,
                      slivers: <Widget>[
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        DiariesListSection(
                          diaries: widget.samples,
                          layoutMode: controller.mode == DiaryCardMode.list
                              ? DiaryLayoutMode.list
                              : DiaryLayoutMode.waterfall,
                          selectedDiaryIds: _selected,
                          isSelectionMode: _selected.isNotEmpty,
                          maxVisibleTags: controller.tagLimit,
                          onCreate: () {},
                          onOpenEditor: (diary, _) =>
                              _toggle(diary.diary.diaryId),
                          onToggleSelection: (diaryId, _) => _toggle(diaryId),
                          cardStyle: controller.style,
                          moodOptions: widget.moodOptions,
                          enableCoverHero: false,
                          opensLockedCapsulePage: false,
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 12 + widget.bottomPadding),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 预览工具条：列表/瀑布流（同时决定“专属”分组编辑哪种布局）与预览明暗。
class DiaryCardStylePreviewToolbar extends StatelessWidget {
  const DiaryCardStylePreviewToolbar({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ExpressiveButtonGroup<DiaryCardMode>(
              minSegmentWidth: 96,
              segments: <ButtonSegment<DiaryCardMode>>[
                // 只放文字：预览顶栏与明暗按钮同行，窄屏大字号下带图标
                // 的“Waterfall”会折行。
                ButtonSegment<DiaryCardMode>(
                  value: DiaryCardMode.list,
                  label: Text(l10n.autoT0146),
                ),
                ButtonSegment<DiaryCardMode>(
                  value: DiaryCardMode.waterfall,
                  label: Text(l10n.autoT0147),
                ),
              ],
              selected: <DiaryCardMode>{controller.mode},
              onSelectionChanged: (Set<DiaryCardMode> selection) =>
                  controller.mode = selection.single,
            ),
          ),
          const SizedBox(width: 8),
          StylePreviewBrightnessButton(controller: controller),
        ],
      ),
    );
  }
}
