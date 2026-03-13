import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/pages/data_management_page.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';

import '../../widgets/glass_bottom_nav.dart';
import '../../widgets/glass_page_header.dart';

/// 设置页：
/// 1. 主题模式切换；
/// 2. 标签删除管理。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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
              RadioListTile<String>(
                value: 'zh',
                groupValue: settingsService.appLocaleCode,
                title: const Text('中文'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => Navigator.of(dialogContext).pop(value),
              ),
              RadioListTile<String>(
                value: 'en',
                groupValue: settingsService.appLocaleCode,
                title: const Text('English'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => Navigator.of(dialogContext).pop(value),
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

  Future<void> _toggleAppLock(
    BuildContext context,
    SettingsService settingsService,
    bool enabled,
  ) async {
    if (enabled) {
      final localAuth = LocalAuthentication();
      final supported =
          await localAuth.isDeviceSupported() ||
          await localAuth.canCheckBiometrics;
      if (!context.mounted) {
        return;
      }
      if (!supported) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appLockNotSupported)),
        );
        return;
      }
    }
    await settingsService.setAppLockEnabled(enabled);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // 设置项分开监听，确保局部更新。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final headerHeight =
        MediaQuery.paddingOf(context).top + GlassPageHeader.contentHeight;
    final listBottomPadding =
        MediaQuery.paddingOf(context).bottom +
        GlassBottomNav.navHeight +
        GlassBottomNav.navBottomInset +
        12;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight,
            bottom: listBottomPadding,
          ),
          children: <Widget>[
            ListTile(title: Text(l10n.settingsThemeMode)),
            SettingsThemeSection(
              settingsAsync: settingsAsync,
            ),
            const Divider(),
            settingsAsync.when(
              data: (settingsService) {
                return ListTile(
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(l10n.settingsLanguageSubtitle),
                  trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                  onTap: () => _showLanguagePickerDialog(context, settingsService),
                );
              },
              loading:
                  () => ListTile(
                    title: Text(l10n.settingsLanguage),
                    subtitle: Text(l10n.settingsLanguageSubtitle),
                  ),
              error: (_, __) => ListTile(
                title: Text(l10n.settingsLanguage),
                subtitle: Text(l10n.settingsLanguageSubtitle),
              ),
            ),
            const Divider(),
            settingsAsync.when(
              data: (settingsService) {
                return SwitchListTile.adaptive(
                  value: settingsService.isAppLockEnabled,
                  title: Text(l10n.settingsAppLock),
                  subtitle: Text(l10n.settingsAppLockSubtitle),
                  onChanged:
                      (value) => _toggleAppLock(context, settingsService, value),
                );
              },
              loading:
                  () => ListTile(
                    title: Text(l10n.settingsAppLock),
                    subtitle: Text(l10n.settingsAppLockSubtitle),
                  ),
              error: (_, __) => ListTile(
                title: Text(l10n.settingsAppLock),
                subtitle: Text(l10n.settingsAppLockSubtitle),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.settingsEditorTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SettingsEditorSection(
              settingsAsync: settingsAsync,
            ),
            const Divider(),
            ListTile(
              title: Text(l10n.settingsDataManagement),
              subtitle: Text(l10n.settingsDataManagementSubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const DataManagementPage();
                    },
                  ),
                );
              },
            ),
            const Divider(),
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
            const Divider(),
            ListTile(
              title: Text(l10n.settingsRecycleBin),
              subtitle: Text(l10n.settingsRecycleBinSubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const RecycleBinPage();
                    },
                  ),
                );
              },
            ),
          ],
        ),
        GlassPageHeader(title: l10n.settingsTitle),
      ],
    );
  }
}
