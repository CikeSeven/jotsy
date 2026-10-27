import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/settings_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../../../home/models/home_bar_style/home_bar_settings.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/app_surface_editor_controller.dart';
import '../../pages/diary_card_style_page.dart';
import '../../pages/home_bar_style_page.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../diary_card_style/diary_card_style_labels.dart';
import '../home_bar_style/home_bar_style_labels.dart';
import 'app_surface_glass_texture_group.dart';
import 'app_surface_labels.dart';

/// “玻璃”标签页：组件风格总开关、六类组件的分别设置（另带导航栏样式与
/// 日记卡片样式两个入口），以及只在有组件实际是玻璃时出现的“玻璃质感”。
///
/// 导航栏与日记卡片有各自的样式页（各自的材质与外观设置），这里只放入口，
/// 不重复它们的选项。
class AppSurfaceGlassTab extends StatelessWidget {
  const AppSurfaceGlassTab({super.key, required this.controller});

  final AppSurfaceEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final glass = controller.style.glass;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // 不用 StyleEditorTabList：玻璃质感分组随条件展开收起，它与上方分组之间
    // 的间距要放进 Reveal 一起收拢（StyleEditorTabList 会在每项之间固定插
    // 16，收起后底部多出一段空白）。
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 24 + bottomInset),
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.appSurfaceGlassStyle,
          footer: l10n.appSurfaceGlassStyleFooter,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ExpressiveButtonGroup<AppGlassMode>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<AppGlassMode>>[
                  for (final mode in AppGlassMode.values)
                    ButtonSegment<AppGlassMode>(
                      value: mode,
                      label: Text(appSurfaceGlassModeLabel(l10n, mode)),
                    ),
                ],
                selected: <AppGlassMode>{glass.mode},
                onSelectionChanged: (Set<AppGlassMode> v) =>
                    controller.commitGlass(glass.withMode(v.single)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.appSurfaceGlassPerComponent,
          children: <Widget>[
            for (final component in AppGlassComponent.values)
              SettingsChoiceTile(
                title: appSurfaceComponentLabel(l10n, component),
                subtitle: appSurfaceComponentEffect(l10n, glass, component),
                child: ExpressiveButtonGroup<AppGlassOverride>(
                  minSegmentWidth: 72,
                  segments: <ButtonSegment<AppGlassOverride>>[
                    for (final value in AppGlassOverride.values)
                      ButtonSegment<AppGlassOverride>(
                        value: value,
                        label: Text(appSurfaceOverrideLabel(l10n, value)),
                      ),
                  ],
                  selected: <AppGlassOverride>{glass.overrideFor(component)},
                  onSelectionChanged: (Set<AppGlassOverride> v) => controller
                      .commitGlass(glass.withOverride(component, v.single)),
                ),
              ),
            _HomeBarStyleLink(settings: controller.settingsService),
            _DiaryCardStyleLink(settings: controller.settingsService),
          ],
        ),
        SettingsReveal(
          visible: glass.anyGlass,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              AppSurfaceGlassTextureGroup(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

const EdgeInsets _linkPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 4,
);

/// 跳到导航栏样式页；副标题为导航栏当前材质（实色 / 玻璃）。
class _HomeBarStyleLink extends StatelessWidget {
  const _HomeBarStyleLink({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<String?>(
      valueListenable: settings.homeBarStyleRawNotifier,
      builder: (BuildContext context, String? raw, Widget? child) => ListTile(
        contentPadding: _linkPadding,
        title: Text(l10n.homeBarStyleTitle),
        subtitle: Text(
          homeBarMaterialLabel(
            l10n,
            HomeBarSettings.decode(raw).current.material,
          ),
        ),
        trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                HomeBarStylePage(settingsService: settings),
          ),
        ),
      ),
    );
  }
}

/// 跳到日记卡片样式页；副标题与外观页的入口同一写法（当前样式名）。
class _DiaryCardStyleLink extends StatelessWidget {
  const _DiaryCardStyleLink({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<String?>(
      valueListenable: settings.diaryCardStyleRawNotifier,
      builder: (BuildContext context, String? raw, Widget? child) => ListTile(
        contentPadding: _linkPadding,
        title: Text(l10n.diaryCardStyleTitle),
        subtitle: Text(
          l10n.diaryCardStyleEntrySubtitle(
            diaryCardStyleDisplayName(l10n, DiaryCardStyleSettings.decode(raw)),
          ),
        ),
        trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                DiaryCardStylePage(settingsService: settings),
          ),
        ),
      ),
    );
  }
}
