import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_app_surface_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_card_style_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_preview_style_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_explore_layout_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_home_bar_style_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../providers/app_features_provider.dart';
import '../widgets/settings_card_group.dart';
import '../../widgets/form_width.dart';

/// 设置 → 外观。
///
/// 自上而下三组：「主题」（明暗模式与主题色）、「界面」（字体大小与标签页
/// 切换曲线，见 [SettingsThemeSection]）、「页面样式」（背景与材质、导航栏、
/// 日记卡片、日记预览页、探索页的样式入口，详细调整与实时预览在各自的
/// 样式页里）。语言在设置首页“通用”组。
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(settingsServiceProvider);

    // 设置区域的背景画在 Scaffold 外面；页面底色经 Builder 从背景组件之下
    // 读（有背景时透明，没有时就是原来的页面底色）。
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.settingsAppearance),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: <Widget>[
                  SettingsThemeSection(settingsAsync: settingsAsync),
                  const SizedBox(height: 16),
                  SettingsCardGroup(
                    title: l10n.settingsPageStylesGroup,
                    children: <Widget>[
                      SettingsAppSurfaceTile(settingsAsync: settingsAsync),
                      SettingsHomeBarStyleTile(settingsAsync: settingsAsync),
                      SettingsDiaryCardStyleTile(settingsAsync: settingsAsync),
                      SettingsDiaryPreviewStyleTile(
                        settingsAsync: settingsAsync,
                      ),
                      // 探索 Tab 关闭时不显示它的自定义入口（功能管理）。
                      if (ref.watch(appFeaturesProvider).explore)
                        SettingsExploreLayoutTile(settingsAsync: settingsAsync),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
