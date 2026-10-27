import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_card_style_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_preview_style_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_home_bar_style_tile.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../widgets/settings_card_group.dart';
import '../../widgets/form_width.dart';

/// 设置-外观与语言二级页。
///
/// 职责：
/// - 收纳主题、日记卡片样式入口（标签显示数量也在样式页里）、标签页切换
///   曲线与语言配置；
/// - 降低设置首页信息密度，仅保留分组入口。
class AppearanceLanguagePage extends ConsumerWidget {
  const AppearanceLanguagePage({super.key});

  Future<void> _showLanguagePickerDialog(
    BuildContext context,
    SettingsService settingsService,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final colorScheme = Theme.of(dialogContext).colorScheme;
        // 选中底色交给 ListTile 自身绘制（tileColor 经 Ink 画在对话框 Material
        // 上），外层不再包不透明 Container，否则点击水波纹会被底色盖住。
        Widget buildOption(String code, String label) {
          final selected = settingsService.appLocaleCode == code;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              selected: selected,
              tileColor: selected ? colorScheme.secondaryContainer : null,
              selectedTileColor: colorScheme.secondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onTap: () => Navigator.of(dialogContext).pop(code),
              leading: FaIcon(
                selected ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
                size: 16,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(l10n.languageDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              buildOption('zh', '中文'),
              buildOption('en', 'English'),
            ],
          ),
        );
      },
    );
    if (result == null || result == settingsService.appLocaleCode) {
      return;
    }
    await settingsService.setAppLocaleCode(result);
  }

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
            title: Text(l10n.settingsAppearanceLanguage),
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
                    children: <Widget>[
                      SettingsHomeBarStyleTile(settingsAsync: settingsAsync),
                      SettingsDiaryCardStyleTile(settingsAsync: settingsAsync),
                      SettingsDiaryPreviewStyleTile(
                        settingsAsync: settingsAsync,
                      ),
                      settingsAsync.when(
                        data: (settingsService) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              l10n.settingsLanguage,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(l10n.settingsLanguageSubtitle),
                            trailing: const FaIcon(
                              FontAwesomeIcons.angleRight,
                              size: 14,
                            ),
                            onTap: () => _showLanguagePickerDialog(
                              context,
                              settingsService,
                            ),
                          );
                        },
                        loading: () => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(l10n.settingsLanguage),
                          subtitle: Text(l10n.settingsLanguageSubtitle),
                        ),
                        error: (_, __) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(l10n.settingsLanguage),
                          subtitle: Text(l10n.settingsLanguageSubtitle),
                        ),
                      ),
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
