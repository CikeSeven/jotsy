import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';

/// 关于页面：以阅读化卡片布局展示应用信息、核心入口与协议信息。
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  static const String _appName = 'Jotsy';
  static const String _appIconAssetPath = 'assets/app_icon/mingcute_icon.png';
  static const String _repoUrl = 'https://github.com/CikeSeven/jotsy';
  static const String _issueUrl = 'https://github.com/CikeSeven/jotsy/issues';
  static const String _qqFeedbackGroupNumber = '678136434';

  static Future<String> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (info.buildNumber.trim().isEmpty) {
      return info.version;
    }
    return '${info.version}+${info.buildNumber}';
  }

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  late final Future<String> _appVersionFuture;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _appVersionFuture = AboutPage._loadAppVersion();
  }

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
      snackBar: SnackBar(
        content: Text(context.l10n.aboutOpenLinkFallbackCopied),
      ),
    );
  }

  Future<void> _copyQqFeedbackGroup(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: AboutPage._qqFeedbackGroupNumber),
    );
    if (!context.mounted) {
      return;
    }
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(context.l10n.aboutQqFeedbackGroupCopied),
      ),
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

  Future<void> _checkLatestRelease(BuildContext context) async {
    if (_checkingUpdate) {
      return;
    }
    setState(() => _checkingUpdate = true);
    try {
      final settingsService = await ref.read(settingsServiceProvider.future);
      final updateService = ref.read(appUpdateServiceProvider);
      final result = await updateService.checkLatestRelease(
        settingsService: settingsService,
      );
      if (!context.mounted) {
        return;
      }

      switch (result.status) {
        case AppUpdateCheckStatus.upToDate:
          unawaited(
            HomeHintVisibilityScope.showTrackedSnackBar(
              context: context,
              snackBar: SnackBar(
                content: Text(
                  context.l10n.aboutUpdateAlreadyLatest(
                    result.latestVersion ?? '--',
                  ),
                ),
              ),
            ),
          );
          return;
        case AppUpdateCheckStatus.updateAvailable:
          final url = result.downloadUrl;
          final version = result.latestVersion ?? '--';
          if (url == null || url.isEmpty) {
            unawaited(
              HomeHintVisibilityScope.showTrackedSnackBar(
                context: context,
                snackBar: SnackBar(
                  content: Text(context.l10n.aboutUpdateNoApkFound),
                ),
              ),
            );
            return;
          }
          final confirmed = await _showUpdateConfirmDialog(
            context,
            version: version,
            releaseNotes: result.releaseNotes,
          );
          if (!confirmed || !context.mounted) {
            return;
          }
          final opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!context.mounted) {
            return;
          }
          unawaited(
            HomeHintVisibilityScope.showTrackedSnackBar(
              context: context,
              snackBar: SnackBar(
                content: Text(
                  opened
                      ? context.l10n.aboutUpdateOpeningDownload(version)
                      : context.l10n.aboutUpdateOpenBrowserFailed,
                ),
              ),
            ),
          );
          return;
        case AppUpdateCheckStatus.failed:
          unawaited(
            HomeHintVisibilityScope.showTrackedSnackBar(
              context: context,
              snackBar: SnackBar(
                content: Text(context.l10n.aboutUpdateCheckFailed),
              ),
            ),
          );
          return;
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  Future<bool> _showUpdateConfirmDialog(
    BuildContext context, {
    required String version,
    String? releaseNotes,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final notes = (releaseNotes ?? '').trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.aboutUpdateDialogTitle(version)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                notes.isEmpty ? l10n.aboutUpdateDialogNoNotes : notes,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.aboutUpdateDialogConfirmDownload),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _appVersionFuture,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final appVersion = snapshot.data ?? '--';
        return _buildContent(context, appVersion: appVersion);
      },
    );
  }

  Widget _buildContent(BuildContext context, {required String appVersion}) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final contentTopPadding =
        topSafeInset + _AboutHeader.contentHeight + AppSpacing.m;

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
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                alignment: Alignment.center,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    AboutPage._appIconAssetPath,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AboutPage._appName,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${l10n.aboutVersion} $appVersion',
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
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Column(
                        children: <Widget>[
                          _AboutActionTile(
                            icon: FontAwesomeIcons.github,
                            title: l10n.aboutOpenSourceRepo,
                            onTap:
                                () => _openExternalUrl(
                                  context,
                                  AboutPage._repoUrl,
                                ),
                          ),
                          const Divider(height: 1),
                          _AboutActionTile(
                            icon: FontAwesomeIcons.arrowsRotate,
                            title: l10n.aboutCheckUpdate,
                            onTap:
                                _checkingUpdate
                                    ? null
                                    : () => _checkLatestRelease(context),
                            trailing:
                                _checkingUpdate
                                    ? const LoadingIndicatorM3E(
                                      variant:
                                          LoadingIndicatorM3EVariant.contained,
                                      constraints: BoxConstraints.tightFor(
                                        width: 18,
                                        height: 18,
                                      ),
                                    )
                                    : null,
                          ),
                          const Divider(height: 1),
                          _AboutActionTile(
                            icon: FontAwesomeIcons.bug,
                            title: l10n.aboutSubmitIssue,
                            onTap:
                                () => _openExternalUrl(
                                  context,
                                  AboutPage._issueUrl,
                                ),
                          ),
                          const Divider(height: 1),
                          _AboutActionTile(
                            icon: FontAwesomeIcons.qq,
                            title: l10n.aboutQqFeedbackGroup,
                            subtitle: l10n.aboutQqFeedbackGroupSubtitle,
                            onTap: () => _copyQqFeedbackGroup(context),
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
                            applicationName: AboutPage._appName,
                            applicationVersion: appVersion,
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
          _AboutHeader(
            title: l10n.aboutTitle,
            onBack: () => Navigator.of(context).maybePop(),
            backTooltip: l10n.commonBack,
          ),
        ],
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({
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
      child: ColoredBox(
        color: colorScheme.surface,
        child: Padding(
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
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AboutActionTile extends StatelessWidget {
  const _AboutActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final iconColor = colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 6, 18),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: FaIcon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                FaIcon(FontAwesomeIcons.angleRight, size: 15, color: iconColor),
          ],
        ),
      ),
    );
  }
}
