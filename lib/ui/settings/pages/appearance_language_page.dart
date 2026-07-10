import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_card_section.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';

/// 设置-外观与语言二级页。
///
/// 职责：
/// - 收纳主题、日记卡片展示、标签页切换曲线与语言配置；
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
        return AlertDialog(
          title: Text(l10n.languageDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.of(dialogContext).pop('zh'),
                leading: FaIcon(
                  settingsService.appLocaleCode == 'zh'
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: const Text('中文'),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.of(dialogContext).pop('en'),
                leading: FaIcon(
                  settingsService.appLocaleCode == 'en'
                      ? FontAwesomeIcons.circleDot
                      : FontAwesomeIcons.circle,
                  size: 16,
                ),
                title: const Text('English'),
              ),
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

    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.settingsAppearanceLanguage),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: <Widget>[
          SettingsThemeSection(settingsAsync: settingsAsync),
          const Divider(),
          SettingsDiaryCardSection(settingsAsync: settingsAsync),
          const Divider(),
          settingsAsync.when(
            data: (settingsService) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(l10n.settingsLanguage),
                subtitle: Text(l10n.settingsLanguageSubtitle),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap:
                    () => _showLanguagePickerDialog(context, settingsService),
              );
            },
            loading:
                () => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(l10n.settingsLanguageSubtitle),
                ),
            error:
                (_, __) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(l10n.settingsLanguageSubtitle),
                ),
          ),
        ],
      ),
    );
  }
}
