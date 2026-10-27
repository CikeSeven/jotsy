import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/diary_card_color_tile.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import 'diary_card_style_labels.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “色彩”标签页：卡片材质（实色 / 玻璃与模糊）、底色（来源与浓度）、卡片
/// 不透明度与两色渐变。两种布局共用；文字颜色在“字体”页，描边、色条与
/// 阴影在“质感”页。
///
/// 材质放在这一页：玻璃的观感主要由不透明度决定（模糊只是在透出来的背景
/// 上再加一层），两者放在一起调。模糊滑块是材质的从属行，与材质选择器
/// 合成分组里的同一项（[SettingsReveal] 展开收起）：分组按位置复用子项并
/// 在子项之间插分割线，单独增删会多出分割线、让下面的行错位复用。
class DiaryCardStyleColorTab extends StatelessWidget {
  const DiaryCardStyleColorTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final surface = style.surface;

    DiaryCardStyle withSurface(DiaryCardSurfaceStyle next) =>
        style.copyWith(surface: next);

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SettingsChoiceTile(
                  title: l10n.diaryCardStyleMaterial,
                  child: ExpressiveButtonGroup<DiaryCardMaterial>(
                    minSegmentWidth: 96,
                    segments: <ButtonSegment<DiaryCardMaterial>>[
                      ButtonSegment<DiaryCardMaterial>(
                        value: DiaryCardMaterial.solid,
                        label: Text(l10n.diaryCardStyleMaterialSolid),
                      ),
                      ButtonSegment<DiaryCardMaterial>(
                        value: DiaryCardMaterial.glass,
                        label: Text(l10n.diaryCardStyleMaterialGlass),
                      ),
                    ],
                    selected: <DiaryCardMaterial>{surface.material},
                    onSelectionChanged: (Set<DiaryCardMaterial> v) =>
                        controller.commit(
                          withSurface(surface.copyWith(material: v.single)),
                        ),
                  ),
                ),
                SettingsReveal(
                  visible: surface.isGlass,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      settingsNestedDivider,
                      SettingsSliderTile(
                        nested: true,
                        title: l10n.diaryCardStyleBlur,
                        subtitle: l10n.diaryCardStyleBlurSubtitle,
                        value: surface.blurSigma,
                        min: DiaryCardStyleLimits.blurSigma.min,
                        max: DiaryCardStyleLimits.blurSigma.max,
                        divisions: DiaryCardStyleLimits.blurSigma.divisions,
                        valueLabel: (double v) => '${v.round()}',
                        onChanged: (double v) => controller.preview(
                          withSurface(surface.copyWith(blurSigma: v)),
                        ),
                        onChangeEnd: (double v) => controller.commit(
                          withSurface(surface.copyWith(blurSigma: v)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            DiaryCardColorTile(
              title: l10n.diaryCardStyleBackground,
              spec: surface.background,
              role: DiaryCardColorRole.surface,
              onPreview: (spec) => controller.preview(
                withSurface(surface.copyWith(background: spec)),
              ),
              onCommit: (spec) => controller.commit(
                withSurface(surface.copyWith(background: spec)),
              ),
            ),
            SettingsSliderTile(
              title: l10n.diaryCardStyleOpacity,
              value: surface.opacity,
              min: DiaryCardStyleLimits.opacity.min,
              max: DiaryCardStyleLimits.opacity.max,
              divisions: DiaryCardStyleLimits.opacity.divisions,
              valueLabel: (double v) => diaryCardPercentLabel(l10n, v),
              onChanged: (double v) =>
                  controller.preview(withSurface(surface.copyWith(opacity: v))),
              onChangeEnd: (double v) =>
                  controller.commit(withSurface(surface.copyWith(opacity: v))),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleGradient,
              subtitle: l10n.diaryCardStyleGradientSubtitle,
              value: surface.gradient,
              onChanged: (bool v) =>
                  controller.commit(withSurface(surface.copyWith(gradient: v))),
            ),
            if (surface.gradient) ...<Widget>[
              DiaryCardColorTile(
                title: l10n.diaryCardStyleGradientEnd,
                spec: surface.gradientEnd,
                role: DiaryCardColorRole.surface,
                onPreview: (spec) => controller.preview(
                  withSurface(surface.copyWith(gradientEnd: spec)),
                ),
                onCommit: (spec) => controller.commit(
                  withSurface(surface.copyWith(gradientEnd: spec)),
                ),
              ),
              SettingsChoiceTile(
                title: l10n.diaryCardStyleGradientDirection,
                child: ExpressiveButtonGroup<DiaryCardGradientDirection>(
                  minSegmentWidth: 80,
                  segments: <ButtonSegment<DiaryCardGradientDirection>>[
                    ButtonSegment<DiaryCardGradientDirection>(
                      value: DiaryCardGradientDirection.vertical,
                      label: Text(l10n.diaryCardStyleDirectionVertical),
                    ),
                    ButtonSegment<DiaryCardGradientDirection>(
                      value: DiaryCardGradientDirection.horizontal,
                      label: Text(l10n.diaryCardStyleDirectionHorizontal),
                    ),
                    ButtonSegment<DiaryCardGradientDirection>(
                      value: DiaryCardGradientDirection.diagonal,
                      label: Text(l10n.diaryCardStyleDirectionDiagonal),
                    ),
                  ],
                  selected: <DiaryCardGradientDirection>{
                    surface.gradientDirection,
                  },
                  onSelectionChanged: (Set<DiaryCardGradientDirection> v) =>
                      controller.commit(
                        withSurface(
                          surface.copyWith(gradientDirection: v.single),
                        ),
                      ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
