import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../../app/theme/app_effects.dart';
import '../../widgets/expressive_image_frame.dart';
import '../controllers/app_update_controller.dart';
import '../models/app_update_state.dart';
import '../widgets/app_update_badge.dart';
import '../widgets/external_link.dart';
import '../widgets/support_developer_sheet.dart';
import 'app_update_page.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

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
                            _SectionCard(
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
                            _SectionCard(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: Column(
                                children: <Widget>[
                                  _AboutActionTile(
                                    icon: FontAwesomeIcons.github,
                                    title: l10n.aboutOpenSourceRepo,
                                    onTap: () => openExternalLink(
                                      context,
                                      AboutPage._repoUrl,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  const _CheckUpdateTile(),
                                  const Divider(height: 1),
                                  _AboutActionTile(
                                    icon: FontAwesomeIcons.bug,
                                    title: l10n.aboutSubmitIssue,
                                    onTap: () => openExternalLink(
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
                                    icon: FontAwesomeIcons.mugHot,
                                    title: l10n.supportDeveloperTitle,
                                    subtitle:
                                        l10n.supportDeveloperEntrySubtitle,
                                    onTap: () =>
                                        showSupportDeveloperSheet(context),
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
                  );
                },
              ),
              _AboutHeader(
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
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ColoredBox(
        // 实色顶栏：设了纯色背景时与页面同色，图片背景时保持不透明。
        color: AppPageBackdrop.solidBarColorOf(context),
        child: Padding(
          padding: EdgeInsets.only(top: topSafeInset),
          child: SizedBox(
            height: contentHeight,
            // 宽窗口：返回键随内容列内收（与 AppTopBar 的 contentMaxWidth 同一口径）。
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          AppSpacing.m + FormWidth.extra(constraints.maxWidth),
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: backTooltip,
                          onPressed: onBack,
                          icon: const FaIcon(
                            FontAwesomeIcons.angleLeft,
                            size: 18,
                          ),
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
    // 玻璃材质时改为内容玻璃（共用页面背景读取、无背景图不模糊）；经典
    // 分支保持原来的 Card 写法不变。
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
        shadow: true,
        child: Padding(padding: padding, child: child),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: ExpressiveSurfaces.cardColor(colorScheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// “检查更新”行：打开软件更新页；副标题随全局更新状态显示新版本、下载
/// 进度或待安装，有新版本时右侧显示“新版本”胶囊。
class _CheckUpdateTile extends ConsumerWidget {
  const _CheckUpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(appUpdateControllerProvider);
    final release = state.release;
    final fraction = state.progress?.fraction;
    final String? subtitle = switch (state.phase) {
      AppUpdatePhase.downloading when fraction != null =>
        l10n.aboutUpdateSubtitleDownloading((fraction * 100).floor()),
      AppUpdatePhase.readyToInstall => l10n.aboutUpdateSubtitleReady,
      AppUpdatePhase.upToDate => l10n.appUpdateUpToDate,
      _ when state.hasUpdate && release != null =>
        l10n.aboutUpdateSubtitleAvailable('v${release.version.name}'),
      _ => null,
    };
    return _AboutActionTile(
      icon: FontAwesomeIcons.arrowsRotate,
      title: l10n.aboutCheckUpdate,
      subtitle: subtitle,
      trailing: state.hasUpdate
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AppUpdateBadge(),
                const SizedBox(width: 8),
                FaIcon(
                  FontAwesomeIcons.angleRight,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const AppUpdatePage(),
        ),
      ),
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

  final FaIconData icon;
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
