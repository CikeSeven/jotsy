import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/appearance_language_page.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import '../../widgets/page_header.dart';

/// 设置页：按语义分组展示一级入口，降低首屏复杂度。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.pageBackgroundColor});

  final Color pageBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            ListTile(
              title: Text(l10n.settingsAppearanceLanguage),
              subtitle: Text(l10n.settingsLanguageSubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const AppearanceLanguagePage();
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.settingsEditorTitle),
              subtitle: Text(l10n.settingsEditorSubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const EditorSettingsPage();
                    },
                  ),
                );
              },
            ),
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
