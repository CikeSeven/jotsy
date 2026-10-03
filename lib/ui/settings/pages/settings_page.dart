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
            _SettingsDestination(
              icon: FontAwesomeIcons.palette,
              title: l10n.settingsAppearanceLanguage,
              subtitle: l10n.settingsLanguageSubtitle,
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
            _SettingsDestination(
              icon: FontAwesomeIcons.penNib,
              title: l10n.settingsEditorTitle,
              subtitle: l10n.settingsEditorSubtitle,
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
            const SizedBox(height: 24),
            _SettingsDestination(
              icon: FontAwesomeIcons.tags,
              title: l10n.settingsTagManagement,
              subtitle: l10n.settingsTagManagementSubtitle,
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
            _SettingsDestination(
              icon: FontAwesomeIcons.shieldHalved,
              title: l10n.settingsDataPrivacy,
              subtitle: l10n.settingsDataPrivacySubtitle,
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
            _SettingsDestination(
              icon: FontAwesomeIcons.circleInfo,
              title: l10n.settingsAbout,
              subtitle: l10n.settingsAboutSubtitle,
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

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final FaIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card.filled(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FaIcon(icon, size: 20, color: colors.onSecondaryContainer),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: onTap,
        ),
      ),
    );
  }
}
