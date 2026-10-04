import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_card_section.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';
import '../widgets/settings_card_group.dart';

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
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final isZh = settingsService.appLocaleCode == 'zh';
        final isEn = settingsService.appLocaleCode == 'en';
        return AlertDialog(
          title: Text(l10n.languageDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isZh
                      ? colorScheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => Navigator.of(dialogContext).pop('zh'),
                  leading: FaIcon(
                    isZh ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
                    size: 16,
                    color: isZh
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    '中文',
                    style: TextStyle(
                      fontWeight: isZh ? FontWeight.w700 : FontWeight.w500,
                      color: isZh
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isEn
                      ? colorScheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => Navigator.of(dialogContext).pop('en'),
                  leading: FaIcon(
                    isEn ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
                    size: 16,
                    color: isEn
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'English',
                    style: TextStyle(
                      fontWeight: isEn ? FontWeight.w700 : FontWeight.w500,
                      color: isEn
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
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
          const SizedBox(height: 16),
          SettingsCardGroup(
            children: <Widget>[
              SettingsDiaryCardSection(settingsAsync: settingsAsync),
              settingsAsync.when(
                data: (settingsService) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      l10n.settingsLanguage,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(l10n.settingsLanguageSubtitle),
                    trailing: const FaIcon(
                      FontAwesomeIcons.angleRight,
                      size: 14,
                    ),
                    onTap: () =>
                        _showLanguagePickerDialog(context, settingsService),
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
      ),
    );
  }
}
