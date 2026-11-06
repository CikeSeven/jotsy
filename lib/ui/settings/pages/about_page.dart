import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/app_spacing.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/expressive_image_frame.dart';
import '../widgets/external_link.dart';
import '../widgets/support_developer_sheet.dart';
import 'changelog_page.dart';
import '../widgets/about_page_parts.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 关于页面：以阅读化卡片布局展示应用信息，下面三张卡片依次为更新（检查
/// 更新、更新日志）、反馈与支持、项目与协议（开源仓库、隐私说明、开源许可）。
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

  @override
  void initState() {
    super.initState();
    _appVersionFuture = AboutPage._loadAppVersion();
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
    await showAppDialog<void>(
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
        topSafeInset + AboutHeader.contentHeight + AppSpacing.m;

    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          body: Stack(
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final side = FormWidth.gutter(constraints.maxWidth);
                  return CustomScrollView(
                    slivers: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          side,
                          contentTopPadding,
                          side,
                          0,
                        ),
                        sliver: SliverList.list(
                          children: <Widget>[
                            AboutSectionCard(
                              child: Builder(
                                builder: (BuildContext context) {
                                  final colorScheme = Theme.of(
                                    context,
                                  ).colorScheme;
                                  return Column(
                                    children: <Widget>[
                                      Container(
                                        width: 92,
                                        height: 92,
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Image.asset(
                                            AboutPage._appIconAssetPath,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            frameBuilder:
                                                expressiveImageFrameBuilder,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        AboutPage._appName,
                                        style: textTheme.headlineSmall
                                            ?.copyWith(
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
                            // 更新：检查更新与更新日志。
                            AboutSectionCard(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: Column(
                                children: <Widget>[
                                  const AboutCheckUpdateTile(),
                                  const Divider(height: 1),
                                  AboutActionTile(
                                    icon: FontAwesomeIcons.clockRotateLeft,
                                    title: l10n.aboutChangelog,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) =>
                                            const ChangelogPage(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // 反馈与支持。
                            AboutSectionCard(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: Column(
                                children: <Widget>[
                                  AboutActionTile(
                                    icon: FontAwesomeIcons.bug,
                                    title: l10n.aboutSubmitIssue,
                                    onTap: () => openExternalLink(
                                      context,
                                      AboutPage._issueUrl,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  AboutActionTile(
                                    icon: FontAwesomeIcons.qq,
                                    title: l10n.aboutQqFeedbackGroup,
                                    subtitle: l10n.aboutQqFeedbackGroupSubtitle,
                                    onTap: () => _copyQqFeedbackGroup(context),
                                  ),
                                  const Divider(height: 1),
                                  AboutActionTile(
                                    icon: FontAwesomeIcons.mugHot,
                                    title: l10n.supportDeveloperTitle,
                                    subtitle:
                                        l10n.supportDeveloperEntrySubtitle,
                                    onTap: () =>
                                        showSupportDeveloperSheet(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // 项目与协议：开源仓库、隐私说明与开源许可。
                            AboutSectionCard(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: Column(
                                children: <Widget>[
                                  AboutActionTile(
                                    icon: FontAwesomeIcons.github,
                                    title: l10n.aboutOpenSourceRepo,
                                    onTap: () => openExternalLink(
                                      context,
                                      AboutPage._repoUrl,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  AboutActionTile(
                                    icon: FontAwesomeIcons.shieldHalved,
                                    title: l10n.aboutPrivacyAndData,
                                    onTap: () => _showPrivacyDialog(context),
                                  ),
                                  const Divider(height: 1),
                                  AboutActionTile(
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
                                ],
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
                  );
                },
              ),
              AboutHeader(
                title: l10n.aboutTitle,
                onBack: () => Navigator.of(context).maybePop(),
                backTooltip: l10n.commonBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
