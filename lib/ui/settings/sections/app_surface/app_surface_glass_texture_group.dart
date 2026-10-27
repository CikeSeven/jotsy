import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/app_surface_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_color_dialog.dart';
import '../../widgets/style_editor/style_custom_color_tile.dart';
import 'app_surface_common.dart';
import 'app_surface_labels.dart';

/// “玻璃质感”分组：模糊、不透明度、底色（自定义时展开从属的颜色行）与
/// 描边。只在有组件实际是玻璃时出现（由玻璃标签页经 SettingsReveal 控制）。
///
/// 自定义颜色行与底色选择器合在同一个位置固定的槽里（同导航栏样式的写法），
/// 下面的描边开关不会因它的出现而错位复用、补播开关动画。
class AppSurfaceGlassTextureGroup extends StatelessWidget {
  const AppSurfaceGlassTextureGroup({super.key, required this.controller});

  final AppSurfaceEditorController controller;

  /// 第一次切到自定义底色时的起始颜色：浅色主题下的中性底色（不透明），
  /// 用户从“看起来没变”的颜色开始调。
  int _neutralLightBase(BuildContext context) => appSurfaceOpaqueArgb(
    appSurfaceLightScheme(
      context,
      controller.settingsService,
    ).surfaceContainerLowest,
  );

  void _setTint(BuildContext context, AppGlassTint tint) {
    final glass = controller.style.glass;
    final seed = tint == AppGlassTint.custom && glass.tintColor == null
        ? _neutralLightBase(context)
        : null;
    controller.commitGlass(
      glass.copyWith(tint: tint, tintColor: seed == null ? null : () => seed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final glass = controller.style.glass;
    final isCustom = glass.tint == AppGlassTint.custom;
    return SettingsCardGroup(
      title: l10n.appSurfaceGlassTexture,
      footer: l10n.appSurfaceGlassHighContrast,
      children: <Widget>[
        appSurfaceSlider(
          title: l10n.appSurfaceBlur,
          range: AppSurfaceLimits.glassBlurSigma,
          value: glass.blurSigma,
          valueLabel: (double v) => '${v.round()}',
          onPreview: (double v) =>
              controller.previewGlass(glass.copyWith(blurSigma: v)),
          onCommit: (double v) =>
              controller.commitGlass(glass.copyWith(blurSigma: v)),
        ),
        appSurfaceSlider(
          title: l10n.appSurfaceGlassOpacity,
          range: AppSurfaceLimits.glassTintOpacity,
          value: glass.tintOpacity,
          valueLabel: (double v) => appSurfacePercentLabel(l10n, v),
          onPreview: (double v) =>
              controller.previewGlass(glass.copyWith(tintOpacity: v)),
          onCommit: (double v) =>
              controller.commitGlass(glass.copyWith(tintOpacity: v)),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.appSurfaceGlassTint,
              child: ExpressiveButtonGroup<AppGlassTint>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<AppGlassTint>>[
                  ButtonSegment<AppGlassTint>(
                    value: AppGlassTint.neutral,
                    label: Text(l10n.appSurfaceGlassTintNeutral),
                  ),
                  ButtonSegment<AppGlassTint>(
                    value: AppGlassTint.theme,
                    label: Text(l10n.appSurfaceGlassTintTheme),
                  ),
                  ButtonSegment<AppGlassTint>(
                    value: AppGlassTint.custom,
                    label: Text(l10n.styleEditorCustom),
                  ),
                ],
                selected: <AppGlassTint>{glass.tint},
                onSelectionChanged: (Set<AppGlassTint> v) =>
                    _setTint(context, v.single),
              ),
            ),
            SettingsReveal(
              visible: isCustom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  settingsNestedDivider,
                  // 一行同时管浅色与深色，深色在取色对话框里默认“自动”。
                  StyleCustomColorTile(
                    nested: true,
                    title: l10n.appSurfaceGlassTintColor,
                    light: glass.tintColor ?? _neutralLightBase(context),
                    dark: glass.tintColorDark,
                    role: DiaryCardColorRole.surface,
                    onChanged: (StyleCustomColor color) =>
                        controller.commitGlass(
                          controller.style.glass.copyWith(
                            tintColor: () => color.light,
                            tintColorDark: () => color.dark,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsSwitchTile(
          title: l10n.appSurfaceGlassBorder,
          subtitle: l10n.appSurfaceGlassBorderSubtitle,
          value: glass.border,
          onChanged: (bool v) =>
              controller.commitGlass(glass.copyWith(border: v)),
        ),
      ],
    );
  }
}
