import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/app_surface_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_color_dialog.dart';
import '../../widgets/style_editor/style_custom_color_tile.dart';
import 'app_surface_image_section.dart';
import 'app_surface_labels.dart';

/// 一块背景的编辑器（全局背景与区域“单独设置”共用）：类型 [无 | 颜色 |
/// 图片]，颜色时展开颜色行，图片时展开图片、焦点与滑块。
///
/// 颜色与图片两组字段都保留：切换类型只改 `kind`，切回来之前调好的颜色、
/// 图片与焦点都还在（与模型语义一致）。类型相关的行与类型选择器合在分组
/// 里的同一项，经 [SettingsReveal] 展开收起（分组按位置复用子项，单独增删
/// 会多出分割线、让后面的行接手前一行的状态）。
class AppSurfaceBackgroundEditor extends StatelessWidget {
  const AppSurfaceBackgroundEditor({
    super.key,
    required this.controller,
    required this.area,
    required this.title,
    this.footer,
  });

  final AppSurfaceEditorController controller;

  /// 正在编辑的区域；null 为全局背景。
  final AppBackgroundArea? area;
  final String title;
  final String? footer;

  /// 第一次切到颜色时的起始颜色：浅色主题下原来的页面底色，用户从“看起来
  /// 没变”的颜色开始调，而不是一块突兀的色（与导航栏自定义底色同一做法）。
  int _seedColor(BuildContext context) => appSurfaceOpaqueArgb(
    ExpressiveSurfaces.pageBackground(
      appSurfaceLightScheme(context, controller.settingsService),
    ),
  );

  void _setKind(BuildContext context, AppBackgroundKind kind) {
    final background = controller.backgroundOf(area);
    final seed =
        kind == AppBackgroundKind.color && background.colorLight == null
        ? _seedColor(context)
        : null;
    controller.commitBackground(
      area,
      background.copyWith(
        kind: kind,
        colorLight: seed == null ? null : () => seed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final background = controller.backgroundOf(area);
    final kind = background.kind;
    return SettingsCardGroup(
      title: title,
      footer: footer,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ExpressiveButtonGroup<AppBackgroundKind>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<AppBackgroundKind>>[
                  for (final value in AppBackgroundKind.values)
                    ButtonSegment<AppBackgroundKind>(
                      value: value,
                      label: Text(appSurfaceKindLabel(l10n, value)),
                    ),
                ],
                selected: <AppBackgroundKind>{kind},
                onSelectionChanged: (Set<AppBackgroundKind> v) =>
                    _setKind(context, v.single),
              ),
            ),
            SettingsReveal(
              visible: kind == AppBackgroundKind.color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SettingsCardGroupDivider(),
                  // 一行同时管浅色与深色：取色对话框里深色默认“自动”
                  // （按表面角色推导），也可以单独指定。
                  StyleCustomColorTile(
                    title: l10n.appSurfaceBackgroundColor,
                    light: background.colorLight ?? _seedColor(context),
                    dark: background.colorDark,
                    role: DiaryCardColorRole.surface,
                    onChanged: (StyleCustomColor color) =>
                        controller.commitBackground(
                          area,
                          controller
                              .backgroundOf(area)
                              .copyWith(
                                colorLight: () => color.light,
                                colorDark: () => color.dark,
                              ),
                        ),
                  ),
                ],
              ),
            ),
            SettingsReveal(
              visible: kind == AppBackgroundKind.image,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SettingsCardGroupDivider(),
                  AppSurfaceImageSection(
                    controller: controller,
                    area: area,
                    background: background,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
