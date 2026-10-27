import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/app_surface_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'app_surface_area_chips.dart';
import 'app_surface_background_editor.dart';
import 'app_surface_labels.dart';

/// “背景”标签页：区域胶囊行，下面是所选区域的设置。
///
/// - 全局：直接是背景编辑器（[AppSurfaceBackgroundEditor]）；
/// - 某个区域：取值方式 [跟随全局 | 不显示 | 单独设置] 与一行说明，选
///   “单独设置”时经 [SettingsReveal] 在下面展开这个区域自己的背景编辑器。
///
/// 切换区域时内容经 [SettingsReveal.swap] 以高度 + 淡出换过去；内容按区域
/// 带 key，各区域的编辑器不会接手上一个区域的状态（如正在解析的图片）。
class AppSurfaceBackgroundTab extends StatelessWidget {
  const AppSurfaceBackgroundTab({super.key, required this.controller});

  final AppSurfaceEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final area = controller.area;
    return StyleEditorTabList(
      children: <Widget>[
        AppSurfaceAreaChips(
          settings: controller.style,
          selected: area,
          onSelected: (AppBackgroundArea? value) => controller.area = value,
        ),
        SettingsReveal.swap(
          child: KeyedSubtree(
            key: ValueKey<String>('appSurfaceArea.${area?.name ?? 'global'}'),
            child: area == null
                ? AppSurfaceBackgroundEditor(
                    controller: controller,
                    area: null,
                    title: l10n.appSurfaceGlobalBackground,
                    footer: l10n.appSurfaceGlobalFooter,
                  )
                : _AreaSettings(controller: controller, area: area),
          ),
        ),
      ],
    );
  }
}

/// 某个区域的取值方式、说明与（单独设置时的）背景编辑器。
class _AreaSettings extends StatelessWidget {
  const _AreaSettings({required this.controller, required this.area});

  final AppSurfaceEditorController controller;
  final AppBackgroundArea area;

  String _note(AppLocalizations l10n, AppSurfaceSettings settings) {
    final mode = settings.areaOf(area).mode;
    final global = settings.global;
    final note = switch (mode) {
      AppAreaBackgroundMode.follow => l10n.appSurfaceAreaFollowNote(
        appSurfaceKindLabel(
          l10n,
          global.isVisible ? global.kind : AppBackgroundKind.none,
        ),
      ),
      AppAreaBackgroundMode.off => l10n.appSurfaceAreaOffNote,
      AppAreaBackgroundMode.custom => l10n.appSurfaceAreaCustomNote,
    };
    // 预览页的纸张颜色是用户自定义的外观，优先于背景（见预览样式）。
    return area == AppBackgroundArea.preview
        ? '$note\n${l10n.appSurfaceAreaPreviewNote}'
        : note;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = controller.style;
    final mode = settings.areaOf(area).mode;
    // 编辑器分组与取值方式分组合成同一项：两组之间的间距放进 Reveal 一起
    // 展开收起，不单独设置时底部不会多出一段空白。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsCardGroup(
          title: appSurfaceAreaLabel(l10n, area),
          footer: _note(l10n, settings),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ExpressiveButtonGroup<AppAreaBackgroundMode>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<AppAreaBackgroundMode>>[
                  for (final value in AppAreaBackgroundMode.values)
                    ButtonSegment<AppAreaBackgroundMode>(
                      value: value,
                      label: Text(appSurfaceAreaModeLabel(l10n, value)),
                    ),
                ],
                selected: <AppAreaBackgroundMode>{mode},
                onSelectionChanged: (Set<AppAreaBackgroundMode> v) =>
                    controller.commitAreaMode(area, v.single),
              ),
            ),
          ],
        ),
        SettingsReveal(
          visible: mode == AppAreaBackgroundMode.custom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              AppSurfaceBackgroundEditor(
                controller: controller,
                area: area,
                title: l10n.appSurfaceAreaBackground,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
