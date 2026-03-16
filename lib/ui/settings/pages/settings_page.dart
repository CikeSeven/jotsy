import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../widgets/page_header.dart';

/// 设置页：按语义分组展示一级入口，降低首屏复杂度。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, required this.pageBackgroundColor});

  final Color pageBackgroundColor;

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
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    const listBottomPadding = 8.0;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBackgroundColor)),
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight,
            bottom: listBottomPadding,
          ),
          children: <Widget>[
            _SettingsGroupTitle(title: l10n.settingsAppearanceLanguage),
            SettingsThemeSection(settingsAsync: settingsAsync),
            const Divider(),
            settingsAsync.when(
              data: (settingsService) {
                return ListTile(
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(l10n.settingsLanguageSubtitle),
                  trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                  onTap:
                      () => _showLanguagePickerDialog(context, settingsService),
                );
              },
              loading:
                  () => ListTile(
                    title: Text(l10n.settingsLanguage),
                    subtitle: Text(l10n.settingsLanguageSubtitle),
                  ),
              error:
                  (_, __) => ListTile(
                    title: Text(l10n.settingsLanguage),
                    subtitle: Text(l10n.settingsLanguageSubtitle),
                  ),
            ),
            const SizedBox(height: 12),
            _SettingsGroupTitle(title: l10n.settingsEditorGroup),
            SettingsEditorSection(settingsAsync: settingsAsync),
            const Divider(),
            ListTile(
              title: Text(l10n.settingsTagManagement),
              subtitle: Text(l10n.settingsTagManagementSubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const TagManagementPage();
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _SettingsGroupTitle(title: l10n.settingsDataPrivacy),
            ListTile(
              title: Text(l10n.settingsDataPrivacy),
              subtitle: Text(l10n.settingsDataPrivacySubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const DataPrivacyPage();
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _SettingsGroupTitle(title: l10n.settingsAbout),
            ListTile(
              title: Text(l10n.settingsAbout),
              subtitle: Text(l10n.settingsAboutSubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const AboutPage();
                    },
                  ),
                );
              },
            ),
          ],
        ),
        PageHeader(title: l10n.settingsTitle),
      ],
    );
  }
}

class _SettingsGroupTitle extends StatelessWidget {
  const _SettingsGroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
