import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/appearance_language_page.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../notebooks/pages/notebooks_page.dart';
import '../../widgets/page_header.dart';
import '../../../app/theme/app_effects.dart';
import '../controllers/app_update_controller.dart';
import '../providers/app_features_provider.dart';
import '../widgets/app_update_badge.dart';

/// 设置页：按语义分组展示一级入口，降低首屏复杂度。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.pageBackgroundColor});

  final Color? pageBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    const listBottomPadding = 8.0;
    final pageBgColor =
        pageBackgroundColor ?? Theme.of(context).colorScheme.surface;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBgColor)),
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
            const SizedBox(height: 12),
            _SettingsDestination(
              icon: FontAwesomeIcons.toggleOn,
              title: l10n.settingsFeaturesTitle,
              subtitle: l10n.settingsFeaturesSubtitle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return const AppFeaturesPage();
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
            // 日记本功能关闭时连同其后的间距一起隐藏，避免出现双倍间隔。
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final enabled = ref.watch(
                  appFeaturesProvider.select((f) => f.notebooks),
                );
                if (!enabled) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SettingsDestination(
                      icon: FontAwesomeIcons.book,
                      title: l10n.notebookTitle,
                      subtitle: l10n.notebookSettingsSubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const NotebooksPage();
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
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
            // 有新版本时在“关于”入口上提示（自动检查或手动检查发现的）。
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final hasUpdate = ref.watch(
                  appUpdateControllerProvider.select(
                    (state) => state.hasUpdate,
                  ),
                );
                return _SettingsDestination(
                  icon: FontAwesomeIcons.circleInfo,
                  title: l10n.settingsAbout,
                  subtitle: l10n.settingsAboutSubtitle,
                  badge: hasUpdate ? const AppUpdateBadge() : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const AboutPage();
                        },
                      ),
                    );
                  },
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
    this.badge,
  });

  final FaIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 显示在右侧箭头之前的标记（如“新版本”）。
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppEffects.restingCardShadow(colors),
        ),
        child: Card.filled(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: ExpressiveSurfaces.cardBorderSide(colors),
          ),
          color: ExpressiveSurfaces.cardColor(colors),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: FaIcon(icon, size: 18, color: colors.onPrimaryContainer),
            ),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (badge != null) ...<Widget>[
                  badge!,
                  const SizedBox(width: 8),
                ],
                FaIcon(
                  FontAwesomeIcons.angleRight,
                  size: 14,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
