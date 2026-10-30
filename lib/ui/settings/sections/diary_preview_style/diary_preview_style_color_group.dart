import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../diaries/viewmodels/diary_preview_resolved_style.dart';
import '../../../widgets/color_swatch_button.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/expressive_icon_choice_row.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../pages/mood_options_page.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_custom_color_tile.dart';
import 'diary_preview_style_labels.dart';
import 'diary_preview_style_mood_picker.dart';

/// “页面”标签页的“配色”分组：配色基调及其从属项、纸张、正文颜色。
///
/// 基调的从属项随所选基调展开或收起（[SettingsReveal]，与基调行合成分组里
/// 的同一项，分割线不错位）：
/// - 自定义：基调颜色（只选一个颜色，两种明暗都由配色算法推出）；
/// - 心情：心情颜色入口（打开心情符号页）与预览心情（只换上方预览里示例的
///   心情，存在编辑页控制器里，不写设置）；
/// - 不是“跟随应用”：着色强度；
/// - 心情 / 首个标签：取不到颜色时的回退。
///
/// 纸张为“主题”且基调不是“跟随应用”时，纸张行下展开“纸张随基调染色”与
/// “背景遮罩随基调染色”（后者只在预览页画着背景与材质的背景图时可见效果）。
/// 样式改动经 [DiaryPreviewStyleEditorController.commitWith] 立即写入；预览
/// 心情只改控制器里的内存状态。
class DiaryPreviewStyleColorGroup extends StatelessWidget {
  const DiaryPreviewStyleColorGroup({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  /// 自定义颜色初次打开时的初始值：取当前主题主色。
  static int _initialColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.toARGB32();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = controller.style.page;
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    final seed = page.colorSeed;
    final perEntrySeed =
        seed == DiaryPreviewColorSeed.mood || seed == DiaryPreviewColorSeed.tag;

    void commit(DiaryPreviewPageStyle next) =>
        controller.commitWith((style) => style.copyWith(page: next));

    Color paperSwatch(DiaryPreviewPaper paper) {
      final preset = DiaryPreviewResolvedStyle.paperColors[paper];
      if (preset != null) {
        return Color(light ? preset.$1 : preset.$2);
      }
      return scheme.surface;
    }

    return SettingsCardGroup(
      title: l10n.diaryPreviewStyleColorGroup,
      footer: l10n.diaryPreviewStylePaperHint,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleColorSeed,
              subtitle: diaryPreviewSeedHint(l10n, seed),
              child: ExpressiveIconChoiceRow<DiaryPreviewColorSeed>(
                choices: diaryPreviewSeedChoices(l10n),
                selected: seed,
                onSelected: (DiaryPreviewColorSeed next) => commit(
                  page.copyWith(
                    colorSeed: next,
                    seedColor:
                        next == DiaryPreviewColorSeed.custom &&
                            page.seedColor == null
                        ? () => _initialColor(context)
                        : null,
                  ),
                ),
              ),
            ),
            SettingsReveal(
              visible: seed == DiaryPreviewColorSeed.custom,
              child: _nested(
                StyleCustomColorTile(
                  nested: true,
                  title: l10n.diaryPreviewStyleSeedColor,
                  light: page.seedColor ?? _initialColor(context),
                  dark: null,
                  role: DiaryCardColorRole.accent,
                  showDarkVariant: false,
                  onChanged: (color) =>
                      commit(page.copyWith(seedColor: () => color.light)),
                ),
              ),
            ),
            SettingsReveal(
              visible: seed == DiaryPreviewColorSeed.mood,
              child: _nested(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _MoodColorsLink(controller: controller),
                    settingsNestedDivider,
                    SettingsChoiceTile(
                      nested: true,
                      title: l10n.diaryPreviewStylePreviewMood,
                      subtitle: l10n.diaryPreviewStylePreviewMoodHint,
                      child: DiaryPreviewMoodPicker(
                        selected: controller.previewMood,
                        onSelected: (String? mood) =>
                            controller.previewMood = mood,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SettingsReveal(
              visible: seed != DiaryPreviewColorSeed.app,
              child: _nested(
                SettingsChoiceTile(
                  nested: true,
                  title: l10n.diaryPreviewStyleSeedIntensity,
                  subtitle: l10n.diaryPreviewStyleSeedIntensityHint,
                  child: ExpressiveButtonGroup<DiaryPreviewSeedIntensity>(
                    minSegmentWidth: 72,
                    segments: <ButtonSegment<DiaryPreviewSeedIntensity>>[
                      for (final value in DiaryPreviewSeedIntensity.values)
                        ButtonSegment<DiaryPreviewSeedIntensity>(
                          value: value,
                          label: Text(
                            diaryPreviewSeedIntensityLabel(l10n, value),
                          ),
                        ),
                    ],
                    selected: <DiaryPreviewSeedIntensity>{page.seedIntensity},
                    onSelectionChanged: (Set<DiaryPreviewSeedIntensity> v) =>
                        commit(page.copyWith(seedIntensity: v.single)),
                  ),
                ),
              ),
            ),
            SettingsReveal(
              visible: perEntrySeed,
              child: _nested(
                SettingsChoiceTile(
                  nested: true,
                  title: l10n.diaryPreviewStyleSeedFallback,
                  subtitle: l10n.diaryPreviewStyleSeedFallbackHint,
                  child: ExpressiveButtonGroup<DiaryPreviewSeedFallback>(
                    minSegmentWidth: 88,
                    segments: <ButtonSegment<DiaryPreviewSeedFallback>>[
                      for (final value in DiaryPreviewSeedFallback.values)
                        ButtonSegment<DiaryPreviewSeedFallback>(
                          value: value,
                          label: Text(
                            diaryPreviewSeedFallbackLabel(l10n, value),
                          ),
                        ),
                    ],
                    selected: <DiaryPreviewSeedFallback>{page.seedFallback},
                    onSelectionChanged: (Set<DiaryPreviewSeedFallback> v) =>
                        commit(page.copyWith(seedFallback: v.single)),
                  ),
                ),
              ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStylePaper,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  for (final paper in DiaryPreviewPaper.values)
                    if (paper == DiaryPreviewPaper.custom)
                      Tooltip(
                        message: diaryPreviewPaperLabel(l10n, paper),
                        child: IconButton.outlined(
                          isSelected: page.paper == paper,
                          // 第一次选自定义时从暖白纸起调（浅色值）。
                          onPressed: () => commit(
                            page.copyWith(
                              paper: paper,
                              paperLight: page.paperLight == null
                                  ? () => DiaryPreviewResolvedStyle
                                        .paperColors[DiaryPreviewPaper.warm]!
                                        .$1
                                  : null,
                            ),
                          ),
                          icon: const FaIcon(
                            FontAwesomeIcons.eyeDropper,
                            size: 16,
                          ),
                        ),
                      )
                    else
                      ColorSwatchButton(
                        color: paperSwatch(paper),
                        selected: page.paper == paper,
                        semanticLabel: diaryPreviewPaperLabel(l10n, paper),
                        onTap: () => commit(page.copyWith(paper: paper)),
                      ),
                ],
              ),
            ),
            // 选了内置或自定义纸色时以纸色为准，染色只作用于主题纸张；背景图
            // 也只在主题纸张时露出来，遮罩染色随之同样的条件。
            SettingsReveal(
              visible:
                  seed != DiaryPreviewColorSeed.app &&
                  page.paper == DiaryPreviewPaper.theme,
              child: _nested(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SettingsSwitchTile(
                      nested: true,
                      title: l10n.diaryPreviewStyleTintPaper,
                      subtitle: l10n.diaryPreviewStyleTintPaperHint,
                      value: page.tintPaper,
                      onChanged: (bool v) =>
                          commit(page.copyWith(tintPaper: v)),
                    ),
                    settingsNestedDivider,
                    SettingsSwitchTile(
                      key: const ValueKey<String>('previewTintScrim'),
                      nested: true,
                      title: l10n.diaryPreviewStyleTintScrim,
                      subtitle: l10n.diaryPreviewStyleTintScrimHint,
                      value: page.tintScrim,
                      onChanged: (bool v) =>
                          commit(page.copyWith(tintScrim: v)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (page.paper == DiaryPreviewPaper.custom && page.paperLight != null)
          StyleCustomColorTile(
            title: l10n.diaryPreviewStylePaperColor,
            light: page.paperLight!,
            dark: page.paperDark,
            role: DiaryCardColorRole.surface,
            onChanged: (color) => commit(
              page.copyWith(
                paperLight: () => color.light,
                paperDark: () => color.dark,
              ),
            ),
          ),
        SettingsSwitchTile(
          title: l10n.diaryPreviewStyleTextColor,
          subtitle: l10n.diaryPreviewStyleTextColorHint,
          value: page.textLight != null,
          onChanged: (bool on) => commit(
            page.copyWith(
              textLight: () => on ? scheme.onSurface.toARGB32() : null,
              textDark: () => null,
            ),
          ),
        ),
        if (page.textLight != null)
          StyleCustomColorTile(
            title: l10n.diaryPreviewStyleTextColor,
            light: page.textLight!,
            dark: page.textDark,
            role: DiaryCardColorRole.text,
            onChanged: (color) => commit(
              page.copyWith(
                textLight: () => color.light,
                textDark: () => color.dark,
              ),
            ),
          ),
      ],
    );
  }

  /// 从属行：上方一条与从属行内容对齐的分割线。
  static Widget _nested(Widget child) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[settingsNestedDivider, child],
  );
}

/// 打开心情符号页改各心情的颜色；从那里返回后，预览按新的心情色重画
/// （心情色板 provider 监听设置原文）。
class _MoodColorsLink extends StatelessWidget {
  const _MoodColorsLink({required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        SettingsSwitchTile.indentFor(nested: true),
        4,
        16,
        4,
      ),
      title: Text(
        l10n.diaryPreviewStyleMoodColors,
        style: SettingsSwitchTile.nestedTitleStyle,
      ),
      subtitle: Text(l10n.diaryPreviewStyleMoodColorsHint),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              MoodOptionsPage(settingsService: controller.settingsService),
        ),
      ),
    );
  }
}
