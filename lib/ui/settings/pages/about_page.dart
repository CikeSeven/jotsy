import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';

/// 关于页面：以阅读化卡片布局展示应用信息、核心入口与协议信息。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _appName = 'Jotsy';
  static const String _appVersion = '0.1.0+1';
  static const String _appIconAssetPath = 'assets/app_icon/mingcute_icon.png';
  static const String _repoUrl = 'https://github.com/CikeSeven/jotsy';
  static const String _issueUrl = 'https://github.com/CikeSeven/jotsy/issues';

  /// 外链统一走这个入口：
  /// 1) 优先拉起系统浏览器；
  /// 2) 若系统无法处理 URL，则自动复制链接，避免用户丢失入口。
  Future<void> _openExternalUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(context.l10n.aboutOpenLinkFallbackCopied)),
    );
  }

  Future<void> _showPrivacyDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.aboutPrivacyDialogTitle),
          content: Text(l10n.aboutPrivacyDialogMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: Text(l10n.commonClose),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final contentTopPadding =
        topSafeInset + _AboutGlassHeader.contentHeight + AppSpacing.m;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  contentTopPadding,
                  AppSpacing.l,
                  0,
                ),
                sliver: SliverList.list(
                  children: <Widget>[
                    _SectionCard(
                      child: Builder(
                        builder: (BuildContext context) {
                          final colorScheme = Theme.of(context).colorScheme;
                          return Column(
                            children: <Widget>[
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(
                                    alpha: 0.62,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.28,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    _appIconAssetPath,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _appName,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${l10n.aboutVersion} $_appVersion',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.aboutPageSlogan,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      child: Column(
                        children: <Widget>[
                          _AboutActionTile(
                            icon: FontAwesomeIcons.github,
                            title: l10n.aboutOpenSourceRepo,
                            onTap: () => _openExternalUrl(context, _repoUrl),
                          ),
                          const Divider(height: 1),
                          _AboutActionTile(
                            icon: FontAwesomeIcons.bug,
                            title: l10n.aboutSubmitIssue,
                            onTap: () => _openExternalUrl(context, _issueUrl),
                          ),
                          const Divider(height: 1),
                          _AboutActionTile(
                            icon: FontAwesomeIcons.shieldHalved,
                            title: l10n.aboutPrivacyAndData,
                            onTap: () => _showPrivacyDialog(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      child: _AboutActionTile(
                        icon: FontAwesomeIcons.fileContract,
                        title: l10n.aboutOpenSourceLicenses,
                        onTap: () {
                          showLicensePage(
                            context: context,
                            applicationName: _appName,
                            applicationVersion: _appVersion,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.l,
                    AppSpacing.xl,
                    AppSpacing.l + bottomSafeInset,
                  ),
                  child: Builder(
                    builder: (BuildContext context) {
                      final colorScheme = Theme.of(context).colorScheme;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            l10n.aboutFooterMadeWith,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.aboutFooterCopyright,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          _AboutGlassHeader(
            title: l10n.aboutTitle,
            onBack: () => Navigator.of(context).maybePop(),
            backTooltip: l10n.commonBack,
          ),
        ],
      ),
    );
  }
}

class _AboutGlassHeader extends StatelessWidget {
  const _AboutGlassHeader({
    required this.title,
    required this.onBack,
    required this.backTooltip,
  });

  static const double contentHeight = 56;

  final String title;
  final VoidCallback onBack;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(boxShadow: AppEffects.softShadow),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.mirror),
            child: Container(
              color: colorScheme.surface.withValues(alpha: 0.24),
              padding: EdgeInsets.only(top: topSafeInset),
              child: SizedBox(
                height: contentHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: backTooltip,
                        onPressed: onBack,
                        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(boxShadow: AppEffects.softShadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16, tileMode: TileMode.mirror),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutActionTile extends StatelessWidget {
  const _AboutActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final iconColor =
        Theme.of(context).brightness == Brightness.dark
            ? colorScheme.onSurface
            : Colors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 6, 14),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: FaIcon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FaIcon(
              FontAwesomeIcons.angleRight,
              size: 15,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
